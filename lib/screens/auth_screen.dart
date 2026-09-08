import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_state.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/error_view.dart';

class AuthScreen extends StatefulWidget {
  final bool initialIsSignUp;
  const AuthScreen({super.key, this.initialIsSignUp = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  late bool _isSignUp;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _hasSubmitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');
    if (savedEmail != null && mounted) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('remembered_email', _emailController.text.trim());
    } else {
      await prefs.remove('remembered_email');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    TextInput.finishAutofillContext();
    setState(() {
      _hasSubmitted = true;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthState>(context, listen: false);
    
    try {
      if (_isSignUp) {
        await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );
        if (mounted) {
          ErrorUtils.showSuccessSnackBar(
            context,
            'Verification email sent! Check your inbox to confirm your account, then sign in.',
          );
          setState(() {
            _isSignUp = false;
          });
        }
      } else {
        await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        await _saveEmail();
        if (mounted) {
          debugPrint('[AUTH_UI] Sign in complete -> navigating to /');
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showErrorSnackBar(
          context,
          e,
          prefix: _isSignUp ? 'Sign Up Failed' : 'Sign In Failed',
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController(text: _emailController.text.trim());
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your email address and we will send you a link to reset your password.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailResetController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'email@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          final email = emailResetController.text.trim();
                          setDialogState(() => isSending = true);
                          try {
                            final auth = Provider.of<AuthState>(context, listen: false);
                            await auth.sendPasswordResetEmail(email: email);
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ErrorUtils.showSuccessSnackBar(
                                context,
                                'Password reset link sent to $email! Please check your email.',
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSending = false);
                            if (mounted) {
                              ErrorUtils.showErrorSnackBar(
                                context,
                                e,
                                prefix: 'Failed to send reset link',
                              );
                            }
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Send Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResendConfirmationDialog() {
    final emailResendController = TextEditingController(text: _emailController.text.trim());
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text('Resend Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your email address to receive a new account verification link.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailResendController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'email@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          final email = emailResendController.text.trim();
                          setDialogState(() => isSending = true);
                          try {
                            final auth = Provider.of<AuthState>(context, listen: false);
                            await auth.resendConfirmationEmail(email: email);
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ErrorUtils.showSuccessSnackBar(
                                context,
                                'Confirmation email resent to $email! Please check your inbox.',
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSending = false);
                            if (mounted) {
                              ErrorUtils.showErrorSnackBar(
                                context,
                                e,
                                prefix: 'Failed to resend confirmation',
                              );
                            }
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Resend Email'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final isLoading = auth.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Branding Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'IELTS',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    Text(
                      'Prep',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.grey[800],
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Path to Success',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Form Card
                Card(
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _hasSubmitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isSignUp ? 'Create an Account' : 'Welcome Back',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 24),
                            
                            if (_isSignUp) ...[
                              TextFormField(
                                controller: _nameController,
                                autofillHints: const [AutofillHints.name],
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (val) {
                                  final text = (val != null && val.trim().isNotEmpty) ? val : _nameController.text;
                                  if (text.trim().isEmpty) return 'Full name is required';
                                  if (text.trim().length < 2) return 'Enter your full name';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email field
                            TextFormField(
                              controller: _emailController,
                              autofillHints: const [AutofillHints.email, AutofillHints.username],
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (val) {
                                final text = (val != null && val.trim().isNotEmpty) ? val : _emailController.text;
                                if (text.trim().isEmpty) return 'Email is required';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(text.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              autofillHints: _isSignUp 
                                  ? const [AutofillHints.newPassword] 
                                  : const [AutofillHints.password],
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (val) {
                                final text = (val != null && val.isNotEmpty) ? val : _passwordController.text;
                                if (text.isEmpty) return 'Password is required';
                                if (text.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                            
                            if (!_isSignUp) ...[
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberMe = val ?? false;
                                        });
                                      },
                                      activeColor: AppTheme.primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                                    child: Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                            
                            if (_errorMessage != null || auth.authError != null) ...[
                              InlineErrorBanner(
                                message: _errorMessage ?? auth.authError,
                                onDismiss: () {
                                  setState(() => _errorMessage = null);
                                  auth.clearAuthError();
                                },
                              ),
                              if ((_errorMessage ?? auth.authError ?? '').toLowerCase().contains('confirm')) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _showResendConfirmationDialog,
                                    icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                                    label: const Text(
                                      'Resend Confirmation Email',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],

                            ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _showResendConfirmationDialog,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Resend confirmation email',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Toggle Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Already have an account? ' : 'New to IELTSPrep? ',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _hasSubmitted = false;
                          _errorMessage = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up Now',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: Text(
                    'Continue as Guest',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
