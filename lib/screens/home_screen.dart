import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_state.dart';
import '../models.dart';
import '../theme.dart';
import '../grading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingData = true;
  List<UserAttempt> _attempts = [];
  List<ScoreHistory> _history = [];
  List<Map<String, dynamic>> _rawUnits = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      if (auth.user == null) return;
      final uid = auth.user!.id;

      final results = await Future.wait([
        supabase.from('user_attempts').select('*, units(*)').eq('user_id', uid),
        supabase
            .from('score_history')
            .select('*')
            .eq('user_id', uid)
            .order('recorded_at', ascending: false)
            .limit(20),
        supabase.from('units').select('id, skill'),
      ]);

      final List<dynamic> attemptsData = results[0] as List<dynamic>;
      final List<dynamic> historyData = results[1] as List<dynamic>;
      final List<dynamic> unitsData = results[2] as List<dynamic>;

      if (mounted) {
        setState(() {
          _attempts = attemptsData.map((e) => UserAttempt.fromJson(e as Map<String, dynamic>)).toList();
          _history = historyData.map((e) => ScoreHistory.fromJson(e as Map<String, dynamic>)).toList();
          _rawUnits = List<Map<String, dynamic>>.from(unitsData);
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingData) {
      return Scaffold(
        appBar: _buildAppBar(auth, isDark),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: _buildAppBar(auth, isDark),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text('Failed to load dashboard data', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDashboardData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Calculations
    final overallBand = _attempts.isNotEmpty
        ? (_attempts.map((a) => a.bandScore ?? 0.0).reduce((a, b) => a + b) / _attempts.length)
        : null;

    final overallPct = _attempts.isNotEmpty
        ? (_attempts.map((a) => a.score ?? 0.0).reduce((a, b) => a + b) / _attempts.length).round()
        : null;

    String overallText = 'No tests yet';
    if (overallBand != null) {
      if (overallBand >= 7.0) {
        overallText = 'Great!';
      } else if (overallBand >= 6.0) {
        overallText = 'Good';
      } else {
        overallText = 'Keep practicing';
      }
    }

    // Skill summaries
    final Map<String, double?> skillBands = {};
    for (final skill in ['listening', 'reading', 'writing', 'speaking']) {
      final skillAttempts = _attempts.where((a) => a.unit?.skill == skill).toList();
      skillBands[skill] = skillAttempts.isNotEmpty
          ? (skillAttempts.map((a) => a.bandScore ?? 0.0).reduce((a, b) => a + b) / skillAttempts.length)
          : null;
    }

    return Scaffold(
      appBar: _buildAppBar(auth, isDark),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                'Welcome back, ${auth.profile?.fullName?.split(" ").first ?? "learner"}!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Let's continue your IELTS preparation journey.",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Overall Band Card
              Card(
                color: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overall Band Score',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              overallBand != null ? overallBand.toStringAsFixed(1) : '—',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              overallText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Keep practicing to improve your score',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (overallPct != null) ...[
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: overallPct / 100,
                                strokeWidth: 8,
                                color: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            Text(
                              '$overallPct%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Progress Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Progress',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => context.go('/stats'),
                    child: const Text('View All', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Horizontal Skills List
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['listening', 'reading', 'writing', 'speaking'].map((s) {
                    final cfg = AppTheme.skills[s]!;
                    final band = skillBands[s];
                    return GestureDetector(
                      onTap: () => context.go('/skills/$s'),
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: cfg.soft,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(cfg.icon, color: cfg.primary, size: 22),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              band != null ? band.toStringAsFixed(1) : '—',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cfg.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),

              // Recent Tests Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Tests',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => context.go('/stats'),
                    child: const Text('View All', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              if (_attempts.isEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No tests completed yet. Start practicing with a free unit!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _attempts.length > 8 ? 8 : _attempts.length,
                  itemBuilder: (context, index) {
                    final attempt = _attempts[index];
                    final unit = attempt.unit;
                    if (unit == null) return const SizedBox();
                    final cfg = AppTheme.skills[unit.skill]!;
                    final formattedDate = DateFormat.yMMMd().format(attempt.completedAt);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: cfg.soft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(cfg.icon, color: cfg.primary, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unit.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            attempt.bandScore != null ? attempt.bandScore!.toStringAsFixed(1) : '—',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: cfg.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(AuthState auth, bool isDark) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'IELTS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
              fontFamily: 'Outfit',
            ),
          ),
          Text(
            'Prep',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.grey[800],
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => context.go('/profile'),
        ),
      ],
    );
  }
}
