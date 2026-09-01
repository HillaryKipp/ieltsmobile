import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth_state.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/error_view.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _errorMessage = null;
    });

    final auth = Provider.of<AuthState>(context, listen: false);
    
    try {
      if (_isSignUp) {
        await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          ErrorUtils.showSuccessSnackBar(
            context,
            'Verification email sent! Check your inbox to confirm your account.',
          );
        }
      } else {
        await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (_) {
      // Error handled by AuthState and displayed via InlineErrorBanner
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _errorMessage = null;
    });

    final auth = Provider.of<AuthState>(context, listen: false);
    
    try {
      await auth.signInWithGoogle();
    } catch (_) {
      // Error handled by AuthState and displayed via InlineErrorBanner
    }
  }

  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController(text: _emailController.text);
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!dialogFormKey.currentState!.validate()) return;
                final email = emailResetController.text.trim();
                
                try {
                  final auth = Provider.of<AuthState>(context, listen: false);
                  await auth.sendPasswordResetEmail(email: email);
                  if (mounted) {
                    Navigator.pop(context);
                    ErrorUtils.showSuccessSnackBar(context, 'Password reset link sent to $email!');
                  }
                } catch (e) {
                  if (mounted) {
                    ErrorUtils.showErrorSnackBar(context, e, prefix: 'Failed to send reset link');
                  }
                }
              },
              child: const Text('Send Link'),
            ),
          ],
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isSignUp ? 'Create an Account' : 'Welcome Back',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),
                          
                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
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
                          const SizedBox(height: 16),
                          
                          // Password field
                          TextFormField(
                            controller: _passwordController,
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
                              if (val == null || val.isEmpty) return 'Password is required';
                              if (val.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          
                          if (!_isSignUp) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
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
                          
                          const SizedBox(height: 20),
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Google Button
                          OutlinedButton(
                            onPressed: isLoading ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey[300]!,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                  height: 20,
                                  width: 20,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isSignUp ? 'Sign up with Google' : 'Sign in with Google',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.grey[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
