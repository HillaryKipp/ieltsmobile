import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../auth_state.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  DateTime? _selectedExamDate;
  bool _isSavingProfile = false;
  bool _isUpdatingPassword = false;
  bool _isInitiatingPayment = false;
  double? _price;
  bool _isLoadingPrice = true;

  @override
  void initState() {
    super.didChangeDependencies();
    _prefillFields();
    _fetchPrice();
  }

  Future<void> _fetchPrice() async {
    try {
      final res = await supabase.rpc('get_public_price');
      if (mounted) {
        setState(() {
          _price = (res as num?)?.toDouble();
          _isLoadingPrice = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching price: $e');
      if (mounted) {
        setState(() => _isLoadingPrice = false);
      }
    }
  }

  void _prefillFields() {
    final auth = Provider.of<AuthState>(context, listen: false);
    if (auth.profile != null) {
      _nameController.text = auth.profile!.fullName ?? '';
      _phoneController.text = auth.profile!.phone ?? '';
      _selectedExamDate = auth.profile!.examDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectExamDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExamDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedExamDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    
    setState(() => _isSavingProfile = true);
    
    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      await auth.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        examDate: _selectedExamDate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isUpdatingPassword = true);

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      await auth.updatePassword(_passwordController.text.trim());
      _passwordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete your profile data and test history? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final auth = Provider.of<AuthState>(context, listen: false);
        await auth.deleteAccount();
        if (mounted) {
          context.go('/auth');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting account: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _initiatePayment() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isInitiatingPayment = true);
    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      await auth.initiateMpesaPayment(phone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('STK Push sent! Please check your phone.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment initiation failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitiatingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final profile = auth.profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int? daysToExam;
    if (_selectedExamDate != null) {
      final difference = _selectedExamDate!.difference(DateTime.now()).inDays;
      daysToExam = difference >= 0 ? difference + 1 : 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: auth.user != null ? [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await auth.signOut();
              if (mounted) context.go('/auth');
            },
          ),
        ] : null,
      ),
      body: auth.user == null 
          ? _buildGuestView(isDark)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Admin Panel Card for Admins
                  if (auth.isAdmin) ...[
                    Card(
                      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                      child: InkWell(
                        onTap: () => context.go('/admin'),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primaryColor, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Admin Control Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Manage units, questions, and app settings', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: AppTheme.primaryColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Countdown Card
                  if (daysToExam != null) ...[
              Card(
                color: AppTheme.primaryColor,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exam countdown',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$daysToExam days',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'until your IELTS exam on ${DateFormat.yMMMMd().format(_selectedExamDate!)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Profile info form card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Edit Profile details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 20),
                      
                      // Full name input
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Phone input
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone (for payments)',
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: '+2547...',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Exam Date Picker field
                      InkWell(
                        onTap: _selectExamDate,
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Exam Date',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            _selectedExamDate != null 
                                ? DateFormat.yMMMMd().format(_selectedExamDate!) 
                                : 'Select exam date...',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedExamDate != null 
                                  ? (isDark ? Colors.white : Colors.black87) 
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isSavingProfile ? null : _saveProfile,
                        child: _isSavingProfile
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Change password card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Change password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: Icon(Icons.lock_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Password is required';
                          if (val.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _isUpdatingPassword ? null : _changePassword,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: isDark ? Colors.white : Colors.black87, side: BorderSide(color: isDark ? Colors.grey[700]! : const Color(0xFFD1D5DB)), shadowColor: Colors.transparent),
                        child: _isUpdatingPassword
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Update password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Membership status and Upgrade card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Membership Access Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          profile?.isPaid == true ? Icons.check_circle_outline : Icons.lock_outline,
                          color: profile?.isPaid == true ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            profile?.isPaid == true
                                ? 'You have full unlocked access to all tests.'
                                : 'You have access to free tests only.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    if (profile?.isPaid != true) ...[
                      const Divider(height: 32),
                      const Text(
                        'Unlock all practice units and detailed analytics with a one-time premium membership.',
                        style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingPrice)
                        const Center(child: CircularProgressIndicator())
                      else if (_price != null) ...[
                        Text(
                          'KSH ${_price!.toStringAsFixed(0)} One-time Payment',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isInitiatingPayment ? null : _initiatePayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isInitiatingPayment
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Upgrade via M-Pesa STK Push', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ensure your phone number is correct above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Danger zone card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.red, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                    const SizedBox(height: 8),
                    const Text(
                      'Deleting your account will remove all your statistics, profile details, and test attempts from our databases. This action is permanent and cannot be undone.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _deleteAccount,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete My Account'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          const Text(
            'Personalize Your Experience',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in to track your progress, save your test history, and unlock premium features.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign In or Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
