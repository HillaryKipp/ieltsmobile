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
  bool _hasLoadedOnce = false;
  List<UserAttempt> _attempts = [];
  List<ScoreHistory> _history = [];
  List<Map<String, dynamic>> _rawUnits = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthState>(context);
    if (!auth.isLoading && auth.user != null && !_hasLoadedOnce && !_isLoadingData) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final uid = auth.user?.id;

      final List<Future> futures = [
        supabase.from('units').select('id, skill, title'),
      ];

      if (uid != null) {
        futures.add(supabase.from('user_attempts').select('*, units(*)').eq('user_id', uid));
        futures.add(supabase
            .from('score_history')
            .select('*')
            .eq('user_id', uid)
            .order('recorded_at', ascending: false)
            .limit(20));
      }

      final results = await Future.wait(futures);

      final List<dynamic> unitsData = results[0] as List<dynamic>;
      final List<dynamic> attemptsData = uid != null ? (results[1] as List<dynamic>) : [];
      final List<dynamic> historyData = uid != null ? (results[2] as List<dynamic>) : [];

      if (mounted) {
        setState(() {
          _attempts = attemptsData.map((e) => UserAttempt.fromJson(e as Map<String, dynamic>)).toList();
          _history = historyData.map((e) => ScoreHistory.fromJson(e as Map<String, dynamic>)).toList();
          _rawUnits = List<Map<String, dynamic>>.from(unitsData);
          _isLoadingData = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingData = false;
          _hasLoadedOnce = true;
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

    String overallText = 'Keep practicing';
    if (overallBand != null) {
      if (overallBand >= 7.0) overallText = 'Great!';
      else if (overallBand >= 6.0) overallText = 'Good';
    }

    // Skill summaries
    final Map<String, _SkillSummary> skillData = {};
    for (final skill in ['listening', 'reading', 'writing', 'speaking']) {
      final skillAttempts = _attempts.where((a) => a.unit?.skill == skill).toList();
      
      UserAttempt? latest;
      if (skillAttempts.isNotEmpty) {
        latest = skillAttempts.reduce((a, b) => a.completedAt.isAfter(b.completedAt) ? a : b);
      }

      final allUnitsForSkill = _rawUnits.where((u) => u['skill'] == skill).length;

      skillData[skill] = _SkillSummary(
        avgBand: skillAttempts.isNotEmpty
            ? (skillAttempts.map((a) => a.bandScore ?? 0.0).reduce((a, b) => a + b) / skillAttempts.length)
            : 0.0,
        latestAttempt: latest,
        totalAttempts: skillAttempts.length,
        availableTests: allUnitsForSkill,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF9F9F8),
      appBar: _buildAppBar(auth, isDark),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                auth.user != null 
                  ? 'Welcome back, ${auth.profile?.fullName?.split(" ").first ?? "learner"}!'
                  : 'Welcome to IELTSPrep!',
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                auth.user != null ? "Let's continue your IELTS preparation journey." : "Start your IELTS preparation journey today.",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 28),

              // Overview Row
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final cards = [
                  // Overall Band Card
                  Container(
                    constraints: const BoxConstraints(minHeight: 140),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Overall Band Score', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(overallBand != null ? overallBand.toStringAsFixed(1) : '—', style: GoogleFonts.outfit(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(overallBand != null ? overallText : 'No tests yet', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(width: 75, height: 75, child: CircularProgressIndicator(value: (overallPct ?? 0) / 100, strokeWidth: 9, color: Colors.white, backgroundColor: Colors.white.withOpacity(0.2), strokeCap: StrokeCap.round)),
                            Text('${overallPct ?? 0}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isWide) const SizedBox(width: 20) else const SizedBox(height: 20),
                  // Progress Summary
                  Container(
                    constraints: const BoxConstraints(minHeight: 140),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF3F4F6), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Progress', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['listening', 'reading', 'writing', 'speaking'].map((s) {
                            final cfg = AppTheme.skills[s]!;
                            final summary = skillData[s]!;
                            return Column(
                              children: [
                                Icon(cfg.icon, color: cfg.primary, size: 22),
                                const SizedBox(height: 8),
                                Text(summary.avgBand > 0 ? summary.avgBand.toStringAsFixed(1) : '—', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                Text(cfg.label, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w600)),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ];

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: cards[0]),
                      cards[1], // SizedBox
                      Expanded(flex: 4, child: cards[2]),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cards[0],
                      cards[1], // SizedBox
                      cards[2],
                    ],
                  );
                }
              }),
              const SizedBox(height: 32),

              // Skill Grid
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isMedium = constraints.maxWidth > 600;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : (isMedium ? 2 : 1),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: isWide ? 0.72 : (isMedium ? 0.85 : 0.95),
                  children: ['listening', 'reading', 'writing', 'speaking'].map((s) => _buildSkillDetailCard(s, skillData[s]!, isDark)).toList(),
                );
              }),
              const SizedBox(height: 32),

              // Recent Tests
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Tests', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => context.go('/stats'), child: const Text('View All', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 12),
              if (_attempts.isEmpty)
                _buildEmptyState(isDark)
              else
                ...List.generate(_attempts.length > 5 ? 5 : _attempts.length, (index) => _buildRecentAttemptItem(_attempts[index], isDark)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillDetailCard(String skillKey, _SkillSummary summary, bool isDark) {
    final cfg = AppTheme.skills[skillKey]!;
    final latest = summary.latestAttempt;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(cfg.label.toUpperCase(), style: TextStyle(color: cfg.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
              Icon(cfg.icon, color: cfg.primary, size: 28),
            ],
          ),
          const SizedBox(height: 8),
          Text(cfg.tagline, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          Text('Latest Test', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (latest != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(latest.unit?.title ?? 'Practice Test', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(DateFormat('MMM d, yyyy').format(latest.completedAt), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ])),
                Text(latest.bandScore?.toStringAsFixed(1) ?? '—', style: GoogleFonts.outfit(color: cfg.primary, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            )
          else
            Text('No tests taken yet', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          const Spacer(),
          const Divider(height: 24, thickness: 1),
          _buildStatRow('Available Units', summary.availableTests.toString(), isDark),
          const SizedBox(height: 8),
          _buildStatRow('Average Score', summary.avgBand > 0 ? summary.avgBand.toStringAsFixed(1) : '—', isDark, isBold: true),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => context.go('/skills/$skillKey'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Start Practicing', style: TextStyle(color: isDark ? Colors.white : Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 13)),
                Icon(Icons.chevron_right, size: 18, color: cfg.primary),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, bool isDark, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.grey[800])),
      ],
    );
  }

  Widget _buildRecentAttemptItem(UserAttempt attempt, bool isDark) {
    final unit = attempt.unit;
    if (unit == null) return const SizedBox();
    final cfg = AppTheme.skills[unit.skill]!;
    final formattedDate = DateFormat('MMMM d, yyyy').format(attempt.completedAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E24) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF3F4F6), width: 1.5)),
      child: Row(
        children: [
          Container(height: 48, width: 48, decoration: BoxDecoration(color: cfg.soft, borderRadius: BorderRadius.circular(12)), child: Icon(cfg.icon, color: cfg.primary, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(unit.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(formattedDate, style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
          ])),
          Text(attempt.bandScore != null ? attempt.bandScore!.toStringAsFixed(1) : '—', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E24) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF3F4F6), width: 1.5)),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No tests completed yet. Start practicing with a free unit!', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  AppBar _buildAppBar(AuthState auth, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('IELTS', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryColor, fontFamily: 'Outfit', fontSize: 22)),
          Text('Prep', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.grey[800], fontFamily: 'Outfit', fontSize: 22)),
        ],
      ),
      centerTitle: false,
      actions: [
        if (auth.user != null)
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => context.go('/profile'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text('My Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                  ],
                ),
              ),
            ),
          )
        else
          TextButton.icon(onPressed: () => context.go('/auth'), icon: const Icon(Icons.login), label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}

class _SkillSummary {
  final double avgBand;
  final UserAttempt? latestAttempt;
  final int totalAttempts;
  final int availableTests;

  _SkillSummary({
    required this.avgBand,
    this.latestAttempt,
    required this.totalAttempts,
    required this.availableTests,
  });
}
