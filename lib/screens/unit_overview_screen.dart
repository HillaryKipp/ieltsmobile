import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../auth_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/error_view.dart';

class UnitOverviewScreen extends StatefulWidget {
  final String unitId;

  const UnitOverviewScreen({super.key, required this.unitId});

  @override
  State<UnitOverviewScreen> createState() => _UnitOverviewScreenState();
}

class _UnitOverviewScreenState extends State<UnitOverviewScreen> {
  bool _isLoading = true;
  Unit? _unit;
  int _questionCount = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUnitDetails();
  }

  Future<void> _loadUnitDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final unitRes = await supabase.from('units').select().eq('id', widget.unitId).single();
      final questionsRes = await supabase.from('questions').select('id').eq('unit_id', widget.unitId);

      if (mounted) {
        setState(() {
          _unit = Unit.fromJson(unitRes);
          _questionCount = questionsRes.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _unit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unit Overview')),
        body: ErrorView(
          error: _errorMessage,
          title: 'Failed to Load Unit Details',
          onRetry: _loadUnitDetails,
        ),
      );
    }

    final unit = _unit!;
    final cfg = AppTheme.skills[unit.skill]!;
    
    // Check access
    final isUnlocked = unit.isFree || auth.isAdmin || (auth.profile?.isPaid ?? false);

    // Dynamic duration text matching skill type
    String durationText = '45 minutes';
    if (unit.skill == 'reading' || unit.skill == 'writing') {
      durationText = '60 minutes';
    } else if (unit.skill == 'speaking') {
      durationText = '15 - 20 minutes';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(unit.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/skills/${unit.skill}'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Card
            Card(
              color: cfg.soft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cfg.primary.withOpacity(0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cfg.icon, color: cfg.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cfg.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cfg.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            unit.isFree ? 'Free Access Practice Unit' : 'Premium IELTS Academic Test',
                            style: TextStyle(
                              fontSize: 12,
                              color: cfg.foreground.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Exam Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Practice Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.timer_outlined, 'Estimated Duration', durationText, isDark),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.question_answer_outlined, 
                      'Total Questions', 
                      _questionCount > 0 ? '$_questionCount questions' : 'Varies by section', 
                      isDark
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.bar_chart_outlined, 
                      'Scoring System', 
                      unit.skill == 'writing' || unit.skill == 'speaking' ? 'Self-rating criteria' : 'Automatic band-score estimation', 
                      isDark
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description or guidelines
            const Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletPoint('Work through the sections sequentially.', isDark),
                  const SizedBox(height: 8),
                  _buildBulletPoint('Your progress is saved automatically if you need to pause.', isDark),
                  const SizedBox(height: 8),
                  if (unit.skill == 'listening') ...[
                    _buildBulletPoint('The audio is designed to be played once only. Find a quiet space.', isDark),
                  ] else if (unit.skill == 'reading') ...[
                    _buildBulletPoint('Read the passage carefully. You can refer back to it at any time.', isDark),
                  ] else if (unit.skill == 'writing') ...[
                    _buildBulletPoint('Ensure you meet the minimum word requirements (150 words for Task 1, 250 for Task 2).', isDark),
                  ] else if (unit.skill == 'speaking') ...[
                    _buildBulletPoint('Answer the interview questions. Listen to your recordings and check the model answers.', isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Start or lock action button
            isUnlocked
                ? ElevatedButton(
                    onPressed: () => context.go('/units/${widget.unitId}/practice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cfg.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow),
                        SizedBox(width: 8),
                        Text('Start Practice Test', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: () {
                      context.go('/profile');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Purchase a premium membership to unlock all tests!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      shadowColor: Colors.transparent,
                      side: BorderSide(color: isDark ? Colors.grey[700]! : const Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline),
                        SizedBox(width: 8),
                        Text('Upgrade to Unlock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0, right: 8.0),
          child: Container(
            height: 6,
            width: 6,
            decoration: BoxDecoration(
              color: isDark ? Colors.white70 : Colors.black54,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }
}
