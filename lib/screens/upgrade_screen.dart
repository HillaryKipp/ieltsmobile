import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../auth_state.dart';
import '../theme.dart';
import '../utils/error_utils.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  double? _price;
  bool _isLoadingPrice = true;
  bool _isInitiatingPayment = false;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _fetchPrice();
    _prefillPhone();
  }

  void _prefillPhone() {
    final auth = Provider.of<AuthState>(context, listen: false);
    if (auth.profile?.phone != null) {
      _phoneController.text = auth.profile!.phone!;
    }
  }

  Future<void> _fetchPrice() async {
    setState(() {
      _isLoadingPrice = true;
      _priceError = null;
    });
    try {
      final res = await Supabase.instance.client.rpc('get_public_price');
      if (mounted) {
        setState(() {
          _price = (res as num?)?.toDouble();
          _isLoadingPrice = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPrice = false;
          _priceError = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isInitiatingPayment = true);
    
    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      await auth.initiateMpesaPayment(_phoneController.text.trim());
      if (mounted) {
        ErrorUtils.showSuccessSnackBar(context, 'Payment initiated! Please check your phone for the STK Push.');
        // Optionally navigate back or show a success view
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showErrorSnackBar(context, e, prefix: 'Payment failed');
      }
    } finally {
      if (mounted) setState(() => _isInitiatingPayment = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Benefit Icons/Text
            const Icon(Icons.auto_awesome_outlined, size: 64, color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            Text(
              'Unlock Full Access',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Get lifetime access to all practice units, detailed performance analytics, and premium study materials.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Price Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Text(
                    'ONE-TIME PAYMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingPrice)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    )
                  else if (_priceError != null)
                    Text(_priceError!, style: const TextStyle(color: Colors.red))
                  else if (_price != null)
                    Text(
                      'KES ${_price!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Payment Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'M-Pesa Phone Number',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '0712345678',
                      prefixIcon: Icon(Icons.phone_android_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Phone number is required';
                      if (val.length < 10) return 'Enter a valid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isInitiatingPayment || _isLoadingPrice || _price == null ? null : _handlePayment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: _isInitiatingPayment
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Pay Now with M-Pesa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Text(
              'Secure payment processed via M-Pesa. You will receive an STK Push on your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
