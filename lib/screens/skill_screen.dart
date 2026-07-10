import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_state.dart';
import '../models.dart';
import '../theme.dart';

class SkillScreen extends StatefulWidget {
  final String skill;

  const SkillScreen({super.key, required this.skill});

  @override
  State<SkillScreen> createState() => _SkillScreenState();
}

class _SkillScreenState extends State<SkillScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Unit> _units = [];
  Map<String, double> _completedScores = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        supabase.from('units').select('*').eq('skill', widget.skill).order('order_index'),
        uid != null 
            ? supabase.from('user_attempts').select('unit_id, band_score').eq('user_id', uid)
            : Future.value([]),
      ]);

      final List<dynamic> unitsData = results[0] as List<dynamic>;
      final List<dynamic> attemptsData = results[1] as List<dynamic>;

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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final cfg = AppTheme.skills[widget.skill]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check if everything is unlocked
    final isUnlocked = auth.isAdmin || (auth.profile?.isPaid ?? false);

    // Filter units
    final allUnits = _units;
    final mockUnits = _units.where((u) => u.title.toLowerCase().contains('mock') || u.title.toLowerCase().contains('exam')).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          cfg.label.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1.2),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: cfg.primary),
                      const SizedBox(height: 16),
                      Text('Failed to load ${cfg.label} units', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadSkillData,
                        style: ElevatedButton.styleFrom(backgroundColor: cfg.primary),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cfg.soft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cfg.primary.withOpacity(0.1)),
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
                                          color: cfg.foreground.withOpacity(0.85),
                                          fontWeight: FontWeight.w500,
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
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: cfg.primary,
                            labelColor: cfg.primary,
                            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            tabs: const [
                              Tab(text: 'All Tests'),
                              Tab(text: 'Mock Tests'),
                            ],
                          ),
                          isDark ? const Color(0xFF121214) : const Color(0xFFF9F9F8),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTestList(allUnits, isUnlocked, cfg, isDark),
                      _buildTestList(mockUnits, isUnlocked, cfg, isDark, isMockTab: true),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTestList(List<Unit> units, bool isUnlocked, SkillTheme cfg, bool isDark, {bool isMockTab = false}) {
    if (units.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(cfg.icon, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                isMockTab ? 'No Mock Exams Available' : 'No tests found in this category.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                isMockTab ? 'Mock tests will be released soon. Standard practice units are available.' : 'Check back later for updates.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: units.length,
      itemBuilder: (context, index) {
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
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        if (unit.isFree) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Free',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[300] : Colors.grey[600],
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
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                      onTap: () => context.go('/units/${unit.id}'),
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
                  : InkWell(
                      onTap: () => context.go('/profile'),
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
                            Icon(Icons.lock_outline, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Upgrade',
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _bgColor;

  _SliverAppBarDelegate(this._tabBar, this._bgColor);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _bgColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
