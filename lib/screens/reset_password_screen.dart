import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../auth_state.dart';
import '../utils/error_utils.dart';
import '../widgets/error_view.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      await auth.updatePassword(_passwordController.text.trim());
      if (mounted) {
        ErrorUtils.showSuccessSnackBar(context, 'Password updated successfully!');
        context.go('/');
      }
    } catch (_) {
      // Error handled by AuthState and displayed via InlineErrorBanner
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Password', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Set New Password',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please enter your new password below.',
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      
                      // Password input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'New Password',
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
                      const SizedBox(height: 16),
                      
                      // Confirm password input
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_clock_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please confirm your password';
                          if (val != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
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
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Update Password'),
                      ),
                      const SizedBox(height: 12),
                      
                      TextButton(
                        onPressed: () {
                          // Clear recovery states and go back to auth
                          Provider.of<AuthState>(context, listen: false).clearResetPasswordRequired();
                          context.go('/auth');
                        },
                        child: const Text('Cancel & Return to Login', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
