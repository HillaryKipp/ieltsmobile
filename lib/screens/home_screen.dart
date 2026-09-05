import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/error_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingData = true;
  bool _hasLoadedOnce = false;
  String? _lastUserId;
  List<UserAttempt> _attempts = [];
  List<Map<String, dynamic>> _rawUnits = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initial load will happen in didChangeDependencies or here
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthState>(context);
    final currentUid = auth.user?.id;

    if (!auth.isLoading) {
      if (!_hasLoadedOnce || currentUid != _lastUserId) {
        _lastUserId = currentUid;
        _loadDashboardData();
      }
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
      }

      final results = await Future.wait(futures);

      final List<dynamic> unitsData = results[0] as List<dynamic>;
      final List<dynamic> attemptsData = uid != null ? (results[1] as List<dynamic>) : [];

      if (mounted) {
        setState(() {
          _attempts = attemptsData.map((e) => UserAttempt.fromJson(e as Map<String, dynamic>)).toList();
          _rawUnits = List<Map<String, dynamic>>.from(unitsData);
          _isLoadingData = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        if (_hasLoadedOnce && _rawUnits.isNotEmpty) {
          // Keep existing data on pull-to-refresh failure and show SnackBar
          setState(() {
            _isLoadingData = false;
          });
          ErrorUtils.showErrorSnackBar(context, e, prefix: 'Failed to refresh dashboard');
        } else {
          setState(() {
            _errorMessage = ErrorUtils.getFriendlyMessage(e);
            _isLoadingData = false;
            _hasLoadedOnce = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingData && !_hasLoadedOnce) {
      return Scaffold(
        appBar: _buildAppBar(auth, isDark),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _rawUnits.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(auth, isDark),
        body: ErrorView(
          error: _errorMessage,
          title: 'Failed to Load Dashboard',
          onRetry: _loadDashboardData,
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
              if (auth.authError != null)
                InlineErrorBanner(
                  message: auth.authError,
                  onDismiss: () => auth.clearAuthError(),
                ),
              // Welcome Header
              Text(
                auth.user != null 
                  ? 'Welcome back, ${auth.profile?.fullName?.split(" ").first ?? "learner"}!'
                  : 'Welcome to IELTSPrep!',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                auth.user != null ? "Let's continue your IELTS preparation journey." : "Start your IELTS preparation journey today.",
                style: TextStyle(
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
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
                              Text('Overall Band Score', style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 13, fontWeight: FontWeight.w700)),
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
                            SizedBox(width: 75, height: 75, child: CircularProgressIndicator(value: (overallPct ?? 0) / 100, strokeWidth: 9, color: Colors.white, backgroundColor: Colors.white.withOpacity(0.25), strokeCap: StrokeCap.round)),
                            Text('${overallPct ?? 0}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isWide) const SizedBox(width: 20) else const SizedBox(height: 20),
                  // Progress Summary ("Your Progress" Card)
                  Container(
                    constraints: const BoxConstraints(minHeight: 140),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Progress',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['listening', 'reading', 'writing', 'speaking'].map((s) {
                            final cfg = AppTheme.skills[s]!;
                            final summary = skillData[s]!;
                            return Column(
                              children: [
                                Icon(cfg.icon, color: cfg.primary, size: 24),
                                const SizedBox(height: 8),
                                Text(
                                  summary.avgBand > 0 ? summary.avgBand.toStringAsFixed(1) : '—',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cfg.label,
                                  style: TextStyle(
                                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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

              // Skill Grid (Cards AFTER Your Progress)
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

              // Recent Tests Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Tests',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/stats'),
                    child: const Text('View All', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_attempts.isEmpty)
                _buildEmptyState(isDark)
              else
                ...List.generate(_attempts.length > 5 ? 5 : _attempts.length, (index) => _buildRecentAttemptItem(_attempts[index], isDark)),
              if (auth.user == null) ...[
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/privacy-policy'),
                    icon: Icon(
                      Icons.privacy_tip_outlined,
                      size: 18,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                    label: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
              ],
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
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cfg.label.toUpperCase(),
                style: TextStyle(color: cfg.primary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2),
              ),
              Icon(cfg.icon, color: cfg.primary, size: 28),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cfg.tagline,
            style: TextStyle(
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Text(
            'Latest Test',
            style: TextStyle(
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          if (latest != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.unit?.title ?? 'Practice Test',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, yyyy').format(latest.completedAt),
                        style: TextStyle(
                          color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  latest.bandScore?.toStringAsFixed(1) ?? '—',
                  style: GoogleFonts.outfit(color: cfg.primary, fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ],
            )
          else
            Text(
              'No tests taken yet',
              style: TextStyle(
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          Divider(height: 24, thickness: 1, color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB)),
          _buildStatRow('Available Units', summary.availableTests.toString(), isDark),
          const SizedBox(height: 8),
          _buildStatRow('Average Score', summary.avgBand > 0 ? summary.avgBand.toStringAsFixed(1) : '—', isDark, isBold: true),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => context.go('/skills/$skillKey'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFD1D5DB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Start Practicing',
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: cfg.primary),
                ],
              ),
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
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
          ),
        ),
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
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: cfg.soft, borderRadius: BorderRadius.circular(12)),
            child: Icon(cfg.icon, color: cfg.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            attempt.bandScore != null ? attempt.bandScore!.toStringAsFixed(1) : '—',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 40, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
          const SizedBox(height: 12),
          Text(
            'No tests completed yet. Start practicing with a free unit!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(AuthState auth, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('IELTS', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryColor, fontFamily: 'Outfit', fontSize: 22)),
          Text('Prep', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight, fontFamily: 'Outfit', fontSize: 22)),
        ],
      ),
      centerTitle: false,
      actions: [
        if (auth.user != null)
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'profile') {
                  context.push('/profile');
                } else if (value == 'privacy') {
                  context.push('/privacy-policy');
                }
              },
              offset: const Offset(0, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 20),
                      SizedBox(width: 12),
                      Text('My Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'privacy',
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Privacy Policy'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 20, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                    const SizedBox(width: 8),
                    Text(
                      'My Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                  ],
                ),
              ),
            ),
          )
        else
          TextButton.icon(onPressed: () => context.push('/auth'), icon: const Icon(Icons.login), label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold))),
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
