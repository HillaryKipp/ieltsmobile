import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_state.dart';
import '../models.dart';
import '../theme.dart';
import '../grading.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  List<UserAttempt> _attempts = [];
  List<ScoreHistory> _history = [];
  int _totalUnits = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatsData();
  }

  Future<void> _loadStatsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      if (auth.user == null) return;
      final uid = auth.user!.id;

      final results = await Future.wait([
        supabase.from('user_attempts').select('*, units(skill, title)').eq('user_id', uid),
        supabase.from('score_history').select('*').eq('user_id', uid).order('recorded_at', ascending: true),
        supabase.from('units').select('id'),
      ]);

      final List<dynamic> attemptsData = results[0] as List<dynamic>;
      final List<dynamic> historyData = results[1] as List<dynamic>;
      final List<dynamic> unitsData = results[2] as List<dynamic>;

      if (mounted) {
        setState(() {
          _attempts = attemptsData.map((e) => UserAttempt.fromJson(e as Map<String, dynamic>)).toList();
          _history = historyData.map((e) => ScoreHistory.fromJson(e as Map<String, dynamic>)).toList();
          _totalUnits = unitsData.length;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistics', style: TextStyle(fontWeight: FontWeight.bold))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistics', style: TextStyle(fontWeight: FontWeight.bold))),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text('Failed to load statistics', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadStatsData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // --- CALCULATIONS ---
    final overall = _attempts.isNotEmpty
        ? (_attempts.map((a) => a.bandScore ?? 0.0).reduce((a, b) => a + b) / _attempts.length)
        : 0.0;

    final progressPct = _totalUnits > 0 ? ((_attempts.length / _totalUnits) * 100).round() : 0;

    // Skill breakdowns
    final Map<String, double> skillAverages = {};
    for (final skill in ['listening', 'reading', 'writing', 'speaking']) {
      final list = _attempts.where((a) => a.unit?.skill == skill).toList();
      skillAverages[skill] = list.isNotEmpty
          ? (list.map((a) => a.bandScore ?? 0.0).reduce((a, b) => a + b) / list.length)
          : 0.0;
    }
    final activeSkills = skillAverages.values.where((v) => v > 0).length;

    // Question type strengths and weaknesses
    final Map<String, TypeBreakdown> aggregatedTypes = {};
    for (final a in _attempts) {
      if (a.breakdown == null) continue;
      a.breakdown!.forEach((type, data) {
        if (data is Map) {
          final correct = data['correct'] as int? ?? 0;
          final total = data['total'] as int? ?? 0;
          aggregatedTypes.putIfAbsent(type, () => TypeBreakdown());
          aggregatedTypes[type]!.correct += correct;
          aggregatedTypes[type]!.total += total;
        }
      });
    }

    final List<QuestionTypeStat> typeStats = aggregatedTypes.entries.map((entry) {
      final pct = entry.value.total > 0 ? ((entry.value.correct / entry.value.total) * 100).round() : 0;
      final label = questionTypeLabels[entry.key] ?? entry.key;
      return QuestionTypeStat(type: entry.key, label: label, pct: pct);
    }).toList();

    // Sort to find weakest and strongest
    typeStats.sort((a, b) => a.pct.compareTo(b.pct));
    final weakest = typeStats.take(3).toList();
    final strongest = typeStats.reversed.take(3).toList();

    // Speaking histories
    final speakingHistoryList = _history.where((h) => h.skill == 'speaking' && h.confidence != null).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Statistics', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatsData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Grid Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildSummaryCard('Overall Band', overall > 0 ? overall.toStringAsFixed(1) : '—', isDark),
                  _buildSummaryCard('Tests Completed', _attempts.length.toString(), isDark),
                  _buildSummaryCard('Progress', '$progressPct%', isDark),
                  _buildSummaryCard('Skills Active', '$activeSkills / 4', isDark),
                ],
              ),
              const SizedBox(height: 24),

              // Band score trend chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Band score trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 24),
                      _history.isEmpty
                          ? const SizedBox(
                              height: 160,
                              child: Center(
                                child: Text('No historical score data. Start practicing to generate charts!', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ),
                            )
                          : SizedBox(
                              height: 180,
                              child: LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 2,
                                        getTitlesWidget: (val, meta) => Text(
                                          val.toStringAsFixed(0),
                                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (val, meta) {
                                          final idx = val.toInt();
                                          if (idx >= 0 && idx < _history.length) {
                                            if (idx % (_history.length > 5 ? _history.length ~/ 4 : 1) == 0) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 6.0),
                                                child: Text(
                                                  DateFormat('Md').format(_history[idx].recordedAt),
                                                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                                                ),
                                              );
                                            }
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  minX: 0,
                                  maxX: (_history.length - 1).toDouble(),
                                  minY: 0,
                                  maxY: 9.0,
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: List.generate(_history.length, (i) {
                                        return FlSpot(i.toDouble(), _history[i].bandScore);
                                      }),
                                      isCurved: true,
                                      color: AppTheme.primaryColor,
                                      barWidth: 3,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Skill Breakdown horizontal bars
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Skill breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 16),
                      ...['listening', 'reading', 'writing', 'speaking'].map((s) {
                        final val = skillBandsPercent(skillAverages[s] ?? 0.0);
                        final cfg = AppTheme.skills[s]!;
                        final label = cfg.label;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(
                                    skillAverages[s]! > 0 ? skillAverages[s]!.toStringAsFixed(1) : '—',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cfg.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: val,
                                color: cfg.primary,
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Weakest and Strongest Question Types
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Weakest question types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 12),
                            weakest.isEmpty
                                ? const Text('Take a Listening or Reading practice test.', style: TextStyle(color: Colors.grey, fontSize: 11))
                                : Column(
                                    children: weakest.map((stat) => _buildStatRow(stat.label, stat.pct, isWeak: true)).toList(),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Strongest question types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 12),
                            strongest.isEmpty
                                ? const Text('Take a Listening or Reading practice test.', style: TextStyle(color: Colors.grey, fontSize: 11))
                                : Column(
                                    children: strongest.map((stat) => _buildStatRow(stat.label, stat.pct, isWeak: false)).toList(),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Speaking confidence histories
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Speaking confidence over time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      speakingHistoryList.isEmpty
                          ? const Text(
                              'Complete a Speaking practice unit to see your confidence logs.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: speakingHistoryList.length,
                              itemBuilder: (context, idx) {
                                final h = speakingHistoryList[idx];
                                final formattedDate = DateFormat.yMMMd().format(h.recordedAt);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text(
                                        h.confidence ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: h.confidence == 'Confident'
                                              ? Colors.green
                                              : (h.confidence == 'Okay' ? Colors.orange : Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  double skillBandsPercent(double avgBand) {
    if (avgBand <= 0) return 0.0;
    return avgBand / 9.0;
  }

  Widget _buildSummaryCard(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int pct, {required bool isWeak}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, overflow: TextOverflow.ellipsis),
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isWeak ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionTypeStat {
  final String type;
  final String label;
  final int pct;

  QuestionTypeStat({required this.type, required this.label, required this.pct});
}
