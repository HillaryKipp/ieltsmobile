import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:app_links/app_links.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'config.dart';
import 'utils/error_utils.dart';

final supabase = Supabase.instance.client;

class AuthState extends ChangeNotifier {
  User? _user;
  Profile? _profile;
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _resetPasswordRequired = false;
  String? _authError;
  String? _profileError;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<dynamic>? _authSubscription;

  User? get user => _user;
  Profile? get profile => _profile;
  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  bool get resetPasswordRequired => _resetPasswordRequired;
  String? get authError => _authError;
  String? get profileError => _profileError;

  void clearAuthError() {
    _authError = null;
    notifyListeners();
  }

  void clearProfileError() {
    _profileError = null;
    notifyListeners();
  }

  AuthState() {
    _init();
  }

  void _init() {
    // Listen to Supabase auth changes
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      try {
        debugPrint('[SUPABASE/AUTH] Auth event: ${data.event} | Session user: ${data.session?.user.id ?? "none"}');
        _user = data.session?.user ?? supabase.auth.currentUser;
        if (data.event == AuthChangeEvent.passwordRecovery) {
          debugPrint('[SUPABASE/AUTH] Password recovery event detected -> enabling reset password flag');
          _resetPasswordRequired = true;
        } else if (data.event == AuthChangeEvent.signedIn) {
          debugPrint('[SUPABASE/AUTH] Signed in event detected -> clearing reset password flag');
          _resetPasswordRequired = false;
        }

        if (_user != null) {
          debugPrint('[SUPABASE/AUTH] Active user identified: ${_user!.id} (${_user!.email})');
          await _fetchProfileAndRole();
        } else {
          debugPrint('[SUPABASE/AUTH] No active user session');
          _profile = null;
          _isAdmin = false;
          _profileError = null;
          _resetPasswordRequired = false;
        }
      } catch (e) {
        debugPrint('[SUPABASE/AUTH] Auth listener error: $e');
        _authError = e.toString();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });

    // Listen to deep links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      debugPrint('[DEEP_LINK] Stream received URI: $uri');
      await _handleIncomingLink(uri);
    }, onError: (err) {
      debugPrint('[DEEP_LINK] Stream error: $err');
      _authError = 'Error processing authentication link: $err';
      notifyListeners();
    });

    // Handle initial link if app was closed
    _appLinks.getInitialLink().then((uri) async {
      if (uri != null) {
        debugPrint('[DEEP_LINK] Initial launch URI: $uri');
        await _handleIncomingLink(uri);
      }
    });
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    try {
      debugPrint('[DEEP_LINK] Processing link: $uri (query: ${uri.queryParameters}, fragment: ${uri.fragment})');
      
      // Exchange code for session using PKCE
      if (uri.queryParameters.containsKey('code') || uri.fragment.contains('code=')) {
        debugPrint('[DEEP_LINK] Exchanging authorization code for session via PKCE');
        await supabase.auth.getSessionFromUrl(uri);
        debugPrint('[DEEP_LINK] Successfully exchanged code for session');
      }

      // Check if this is a password recovery flow
      final isRecovery = uri.queryParameters['type'] == 'recovery' || 
                         uri.fragment.contains('type=recovery');
      
      if (isRecovery) {
        debugPrint('[DEEP_LINK] Link matches password recovery flow');
        _resetPasswordRequired = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DEEP_LINK] Error handling deep link: $e');
      _authError = 'Failed to authenticate via link: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> _fetchProfileAndRole() async {
    if (_user == null) return;
    try {
      final uid = _user!.id;
      debugPrint('[SUPABASE/DB] Fetching profile & role for user: $uid');
      
      // Fetch profile
      final res = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
      if (res != null) {
        _profile = Profile.fromJson(res);
        debugPrint('[SUPABASE/DB] Profile loaded: name="${_profile?.fullName}", paid=${_profile?.isPaid}, phone="${_profile?.phone}"');
      } else {
        debugPrint('[SUPABASE/DB] No existing profile row found for user: $uid');
      }

      // Fetch admin role
      final adminRes = await supabase.rpc('has_role', params: {
        '_user_id': uid,
        '_role': 'admin',
      });
      _isAdmin = adminRes as bool? ?? false;
      debugPrint('[SUPABASE/DB] Role check complete: isAdmin=$_isAdmin');
      _profileError = null;
    } catch (e) {
      debugPrint('[SUPABASE/DB] Error fetching profile/role: $e');
      _profileError = 'Unable to fetch your user profile: $e';
    }
  }

  Future<void> refreshProfile() async {
    if (_user == null) return;
    debugPrint('[SUPABASE/DB] Refreshing profile data for: ${_user!.id}');
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
    debugPrint('[SUPABASE/DB] Updating profile for ${_user!.id}: $updateData');
    
    await supabase.from('profiles').update(updateData).eq('id', _user!.id);
    debugPrint('[SUPABASE/DB] Profile successfully updated');
    await refreshProfile();
  }

  Future<void> signUp({required String email, required String password, required String fullName}) async {
    debugPrint('[SUPABASE/AUTH] signUp requested: email=$email, fullName=$fullName');
    _isLoading = true;
    _authError = null;
    _resetPasswordRequired = false;
    notifyListeners();
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: Env.authRedirect,
      );
      debugPrint('[SUPABASE/AUTH] signUp response: user=${res.user?.id}, session=${res.session != null ? "active" : "unconfirmed"}');
      _user = res.user ?? supabase.auth.currentUser;
      if (_user != null) {
        await _fetchProfileAndRole();
      }
    } catch (e) {
      debugPrint('[SUPABASE/AUTH] SignUp Error: $e');
      _authError = ErrorUtils.getFriendlyMessage(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    debugPrint('[SUPABASE/AUTH] signIn requested: email=$email');
    _isLoading = true;
    _authError = null;
    _resetPasswordRequired = false;
    notifyListeners();
    try {
      final res = await supabase.auth.signInWithPassword(email: email, password: password);
      debugPrint('[SUPABASE/AUTH] signIn success: userId=${res.user?.id}, email=${res.user?.email}');
      _user = res.user;
      await _fetchProfileAndRole();
      debugPrint('[SUPABASE/AUTH] Session ready: user=${_user?.id}, role isAdmin=$_isAdmin');
    } catch (e) {
      debugPrint('[SUPABASE/AUTH] SignIn Error: $e');
      _authError = ErrorUtils.getFriendlyMessage(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    debugPrint('[SUPABASE/AUTH] signInWithGoogle requested');
    _isLoading = true;
    _authError = null;
    _resetPasswordRequired = false;
    notifyListeners();
    try {
      // 1. Native Google Sign-In for Android/iOS
      const webClientId = 'YOUR_WEB_CLIENT_ID_FOR_GOOGLE_SIGN_IN';
      const iosClientId = 'YOUR_IOS_CLIENT_ID_FOR_GOOGLE_SIGN_IN';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[SUPABASE/AUTH] Google sign in was cancelled by user');
        _isLoading = false;
        notifyListeners();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      debugPrint('[SUPABASE/AUTH] Google ID token obtained, signing in with Supabase');
      final res = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      debugPrint('[SUPABASE/AUTH] Google sign-in success: userId=${res.user?.id}');
      _user = res.user;
      await _fetchProfileAndRole();
    } catch (e) {
      debugPrint('[SUPABASE/AUTH] Google Sign-In Native Error: $e -> Trying OAuth fallback');
      
      // Fallback to OAuth if native fails or for web
      try {
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Env.authRedirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
      } catch (inner) {
        debugPrint('[SUPABASE/AUTH] Google OAuth Fallback Error: $inner');
        _authError = ErrorUtils.getFriendlyMessage(inner);
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    debugPrint('[SUPABASE/AUTH] sendPasswordResetEmail requested: email=$email');
    _authError = null;
    notifyListeners();
    try {
      await supabase.auth.resetPasswordForEmail(email, redirectTo: Env.authRedirect);
      debugPrint('[SUPABASE/AUTH] Password reset email dispatched');
    } catch (e) {
      debugPrint('[SUPABASE/AUTH] Reset Password Email Error: $e');
      _authError = ErrorUtils.getFriendlyMessage(e);
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    debugPrint('[SUPABASE/AUTH] updatePassword requested for user: ${_user?.id}');
    _authError = null;
    notifyListeners();
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      debugPrint('[SUPABASE/AUTH] Password updated successfully');
      clearResetPasswordRequired();
    } catch (e) {
      debugPrint('[SUPABASE/AUTH] Update Password Error: $e');
      _authError = ErrorUtils.getFriendlyMessage(e);
      rethrow;
    }
  }

  Future<void> initiateMpesaPayment(String phone) async {
    final session = supabase.auth.currentSession;
    if (session == null) throw Exception('No active session. Please sign in.');

    debugPrint('[SERVER/MPESA] Initiating STK Push: url=${Env.webOrigin}/api/public/mpesa/initiate, phone=$phone');
    final response = await http.post(
      Uri.parse('${Env.webOrigin}/api/public/mpesa/initiate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({'phone': phone}),
    );

    debugPrint('[SERVER/MPESA] Response: status=${response.statusCode}, body=${response.body}');
    if (response.statusCode != 200) {
      String errorMessage = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          errorMessage = decoded['error'].toString();
        } else if (decoded is Map && decoded['message'] != null) {
          errorMessage = decoded['message'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  void clearResetPasswordRequired() {
    debugPrint('[SUPABASE/AUTH] clearResetPasswordRequired invoked');
    _resetPasswordRequired = false;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    if (_user == null) return;
    debugPrint('[SUPABASE/AUTH] deleteAccount invoked for user: ${_user!.id}');
    // Perform soft delete by removing profile rows (as RLS enables delete for self or admin)
    await supabase.from('profiles').delete().eq('id', _user!.id);
    debugPrint('[SUPABASE/AUTH] Profile records deleted');
    await signOut();
  }

  Future<void> signOut() async {
    debugPrint('[SUPABASE/AUTH] signOut requested');
    _isLoading = true;
    notifyListeners();
    await supabase.auth.signOut();
    debugPrint('[SUPABASE/AUTH] Supabase signOut completed');
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
