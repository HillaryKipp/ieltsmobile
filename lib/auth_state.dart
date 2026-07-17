import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'config.dart';

final supabase = Supabase.instance.client;

class AuthState extends ChangeNotifier {
  User? _user;
  Profile? _profile;
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _resetPasswordRequired = false;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<dynamic>? _authSubscription;

  User? get user => _user;
  Profile? get profile => _profile;
  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  bool get resetPasswordRequired => _resetPasswordRequired;

  AuthState() {
    _init();
  }

  void _init() {
    // Listen to Supabase auth changes
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      try {
        _user = data.session?.user ?? supabase.auth.currentUser;
        if (_user != null) {
          await _fetchProfileAndRole();
        } else {
          _profile = null;
          _isAdmin = false;
        }
      } catch (e) {
        debugPrint('Auth listener error: $e');
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });

    // Listen to deep links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      await _handleIncomingLink(uri);
    }, onError: (err) {
      debugPrint('Deep Link Error: $err');
    });

    // Handle initial link if app was closed
    _appLinks.getInitialLink().then((uri) async {
      if (uri != null) {
        await _handleIncomingLink(uri);
      }
    });
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    try {
      debugPrint('Incoming deep link: $uri');
      
      // Exchange code for session using PKCE
      if (uri.queryParameters.containsKey('code') || uri.fragment.contains('code=')) {
        await supabase.auth.getSessionFromUrl(uri);
      }

      // Check if this is a password recovery flow
      final isRecovery = uri.queryParameters['type'] == 'recovery' || 
                         uri.fragment.contains('type=recovery') || 
                         uri.toString().contains('recovery');
      
      if (isRecovery) {
        _resetPasswordRequired = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }

  Future<void> _fetchProfileAndRole() async {
    if (_user == null) return;
    try {
      final uid = _user!.id;
      
      // Fetch profile
      final res = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
      if (res != null) {
        _profile = Profile.fromJson(res);
      }

      // Fetch admin role
      final adminRes = await supabase.rpc('has_role', params: {
        '_user_id': uid,
        '_role': 'admin',
      });
      _isAdmin = adminRes as bool? ?? false;
    } catch (e) {
      debugPrint('Error fetching profile/role: $e');
    }
  }

  Future<void> refreshProfile() async {
    if (_user == null) return;
    await _fetchProfileAndRole();
    notifyListeners();
  }

  Future<void> updateProfile({required String fullName, required String phone, DateTime? examDate}) async {
    if (_user == null) return;
    final Map<String, dynamic> updateData = {
      'full_name': fullName,
      'phone': phone,
      'exam_date': examDate?.toIso8601String().substring(0, 10),
    };
    
    await supabase.from('profiles').update(updateData).eq('id', _user!.id);
    await refreshProfile();
  }

  Future<void> signUp({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: Env.authRedirect,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await supabase.auth.resetPasswordForEmail(email, redirectTo: Env.authRedirect);
  }

  Future<void> updatePassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
    clearResetPasswordRequired();
  }

  Future<void> initiateMpesaPayment(String phone) async {
    final session = supabase.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final response = await http.post(
      Uri.parse('${Env.webOrigin}/api/public/mpesa/initiate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to initiate payment: ${response.body}');
    }
  }

  void clearResetPasswordRequired() {
    _resetPasswordRequired = false;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    if (_user == null) return;
    // Perform soft delete by removing profile rows (as RLS enables delete for self or admin)
    await supabase.from('profiles').delete().eq('id', _user!.id);
    await signOut();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    await supabase.auth.signOut();
    _user = null;
    _profile = null;
    _isAdmin = false;
    _resetPasswordRequired = false;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
