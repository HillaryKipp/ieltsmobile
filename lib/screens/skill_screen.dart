import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/error_view.dart';

class SkillScreen extends StatefulWidget {
  final String skill;

  const SkillScreen({super.key, required this.skill});

  @override
  State<SkillScreen> createState() => _SkillScreenState();
}

class _SkillScreenState extends State<SkillScreen> {
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  List<Unit> _units = [];
  Map<String, double> _completedScores = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSkillData();
  }

  @override
  void didUpdateWidget(SkillScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.skill != widget.skill) {
      _loadSkillData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthState>(context);
    if (!auth.isLoading && auth.user != null && !_hasLoadedOnce && !_isLoading) {
      _loadSkillData();
    }
  }

  Future<void> _loadSkillData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final uid = auth.user?.id;

      final results = await Future.wait([
        supabase.from('units').select('*').eq('skill', widget.skill).order('is_free', ascending: false).order('order_index', ascending: true),
        uid != null 
            ? supabase.from('user_attempts').select('unit_id, band_score').eq('user_id', uid)
            : Future.value([]),
      ]);

      final unitsData = results[0];
      final attemptsData = results[1];

      final loadedUnits = unitsData.map((e) => Unit.fromJson(e as Map<String, dynamic>)).toList();
      
      final Map<String, double> scores = {};
      for (final a in attemptsData) {
        if (a['unit_id'] != null && a['band_score'] != null) {
          scores[a['unit_id'] as String] = (a['band_score'] as num).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _units = loadedUnits;
          _completedScores = scores;
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        if (_hasLoadedOnce && _units.isNotEmpty) {
          setState(() {
            _isLoading = false;
          });
          ErrorUtils.showErrorSnackBar(context, e, prefix: 'Failed to refresh units');
        } else {
          setState(() {
            _errorMessage = ErrorUtils.getFriendlyMessage(e);
            _isLoading = false;
            _hasLoadedOnce = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final cfg = AppTheme.skills[widget.skill]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isUnlocked = auth.user != null && (auth.isAdmin || (auth.profile?.isPaid ?? false));
    final allUnits = _units;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        title: Text(
          cfg.label.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.2,
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
          ),
        ),
        centerTitle: true,
        actions: [
          if (auth.user != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'profile') {
                  context.go('/profile');
                } else if (value == 'privacy') {
                  context.push('/privacy-policy');
                }
              },
              icon: Icon(Icons.account_circle_outlined, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
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
            )
          else
            IconButton(
              icon: Icon(Icons.login, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
              onPressed: () => context.go('/auth'),
            ),
        ],
      ),
      body: _isLoading && !_hasLoadedOnce
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _units.isEmpty
              ? ErrorView(
                  error: _errorMessage,
                  title: 'Failed to Load ${cfg.label} Units',
                  onRetry: _loadSkillData,
                  iconColor: cfg.primary,
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cfg.soft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cfg.primary.withOpacity(0.15)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cfg.label,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: cfg.foreground,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cfg.tagline,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: cfg.foreground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(cfg.icon, color: cfg.primary, size: 48),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Available Practice Units',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                          ),
                        ),
                      ),
                    ),
                    _buildSliverTestList(allUnits, auth, cfg, isDark),
                  ],
                ),
    );
  }

  Widget _buildSliverTestList(List<Unit> units, AuthState auth, SkillTheme cfg, bool isDark) {
    final isUnlocked = auth.user != null && (auth.isAdmin || (auth.profile?.isPaid ?? false));
    if (units.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cfg.icon, size: 48, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
                const SizedBox(height: 16),
                Text(
                  'No tests found in this category.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for updates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final unit = units[index];
            final isAccessible = unit.isFree || isUnlocked;
            final hasScore = _completedScores.containsKey(unit.id);
            final score = _completedScores[unit.id];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  // Index Circle
                  Container(
                    height: 38,
                    width: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cfg.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cfg.foreground,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title and Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                unit.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                ),
                              ),
                            ),
                            if (unit.isFree) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Free',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (unit.description != null && unit.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            unit.description!,
                            style: TextStyle(
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Completed Score Badge (if applicable)
                  if (hasScore && score != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: cfg.soft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cfg.primary.withOpacity(0.2)),
                      ),
                      child: Text(
                        score.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: cfg.foreground,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],

                  // Action button (Play, Lock, or Upgrade)
                  isAccessible
                      ? InkWell(
                          onTap: () => context.push('/units/${unit.id}'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: cfg.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasScore ? Icons.refresh_outlined : Icons.play_arrow_outlined, 
                                  color: Colors.white, 
                                  size: 16
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasScore ? 'Retry' : 'Start',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      : auth.user != null 
                          ? InkWell(
                              onTap: () => context.push('/upgrade'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? Colors.grey[700]! : const Color(0xFFD1D5DB)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Upgrade',
                                      style: TextStyle(
                                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => context.push('/auth?mode=signin'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Sign in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const Text('|', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                TextButton(
                                  onPressed: () => context.push('/auth?mode=signup'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Create account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                ],
              ),
            );
          },
          childCount: units.length,
        ),
      ),
    );
  }
}
