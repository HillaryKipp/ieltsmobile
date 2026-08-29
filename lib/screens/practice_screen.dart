import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth_state.dart';
import '../models.dart';
import '../theme.dart';
import '../grading.dart';

class PracticeScreen extends StatefulWidget {
  final String unitId;

  const PracticeScreen({super.key, required this.unitId});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  bool _isLoading = true;
  Unit? _unit;
  List<Question> _flatQuestions = [];
  List<QuestionGroup> _groupedQuestions = [];
  
  final Map<String, dynamic> _answers = {};
  bool _submitted = false;
  bool _saving = false;
  String? _errorMessage;
  int _seed = 0;

  // Audio & Timer
  AudioPlayer? _audioPlayer;
  Timer? _countdownTimer;
  int _secondsRemaining = 45 * 60; // Default 45 mins
  bool _timerExpired = false;

  // Self assessment variables
  String? _selfRating;
  final List<bool> _writingChecklist = [false, false, false, false, false];

  // Reading view toggle
  int _readingTab = 0; // 0 = Passage, 1 = Questions

  @override
  void initState() {
    super.initState();
    _seed = DateTime.now().millisecondsSinceEpoch % 100000;
    _loadPracticeData();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPracticeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final uid = auth.user?.id;

      // 1. Fetch unit
      final unitRes = await supabase.from('units').select().eq('id', widget.unitId).single();
      final loadedUnit = Unit.fromJson(unitRes);

      // 2. Fetch questions
      final questionsRes = await supabase
          .from('questions')
          .select('*')
          .eq('unit_id', widget.unitId)
          .order('section', ascending: true, nullsFirst: true)
          .order('order_index');
      
      final List<dynamic> questionsData = questionsRes as List<dynamic>;
      final List<Question> loadedQuestions = questionsData.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();

      // 3. Group and shuffle questions deterministic by section
      final List<QuestionGroup> groups = [];
      final Map<int, List<Question>> bySection = {};
      for (final q in loadedQuestions) {
        final sec = q.section ?? 0;
        bySection.putIfAbsent(sec, () => []);
        bySection[sec]!.add(q);
      }

      final sortedSectionKeys = bySection.keys.toList()..sort();
      for (final sec in sortedSectionKeys) {
        final sectionList = bySection[sec]!;
        final Map<String, List<Question>> byType = {};
        for (final q in sectionList) {
          byType.putIfAbsent(q.questionType, () => []);
          byType[q.questionType]!.add(q);
        }

        for (final entry in byType.entries) {
          final shuffledItems = shuffleQuestions(entry.value, _seed + sec);
          groups.add(QuestionGroup(
            section: sec,
            type: entry.key,
            items: shuffledItems,
          ));
        }
      }

      final flattened = groups.expand((g) => g.items).toList();

      // 4. Fetch previous attempt if any to prefill answers
      if (uid != null) {
        final attemptRes = await supabase
            .from('user_attempts')
            .select('answers')
            .eq('user_id', uid)
            .eq('unit_id', widget.unitId)
            .maybeSingle();
        
        if (attemptRes != null && attemptRes['answers'] != null) {
          final Map<String, dynamic> savedAnswers = Map<String, dynamic>.from(attemptRes['answers'] as Map);
          _answers.addAll(savedAnswers);
        }
      }

      // Initialize Timer based on skill type
      int durationSeconds = 45 * 60;
      if (loadedUnit.skill == 'reading' || loadedUnit.skill == 'writing') {
        durationSeconds = 60 * 60;
      } else if (loadedUnit.skill == 'speaking') {
        durationSeconds = 15 * 60;
      }

      if (mounted) {
        setState(() {
          _unit = loadedUnit;
          _groupedQuestions = groups;
          _flatQuestions = flattened;
          _secondsRemaining = durationSeconds;
          _isLoading = false;
        });

        // Initialize Audio player if it's listening skill
        if (loadedUnit.skill == 'listening' && flattened.isNotEmpty && flattened[0].audioUrl != null) {
          _audioPlayer = AudioPlayer();
          try {
            await _audioPlayer!.setUrl(flattened[0].audioUrl!);
          } catch (e) {
            debugPrint('Error loading audio: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to load audio: ${e.toString().split(':').last.trim()}')),
              );
            }
          }
        }

        // Start countdown timer
        _startTimer();
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

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _timerExpired = true;
        });
        _autoSubmit();
      }
    });
  }

  Future<void> _autoSubmit() async {
    if (_submitted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Time is up! Submitting your answers...'), backgroundColor: Colors.orange),
    );
    await _submitTest();
  }

  Future<void> _saveProgress() async {
    final auth = Provider.of<AuthState>(context, listen: false);
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save progress')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await supabase.from('user_attempts').upsert({
        'user_id': auth.user!.id,
        'unit_id': widget.unitId,
        'answers': _answers,
        'score': null,
        'band_score': null,
        'completed_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save progress: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitTest() async {
    final auth = Provider.of<AuthState>(context, listen: false);
    
    final graded = gradeAll(_flatQuestions, _answers);
    final band = bandFromPercent(graded.pct);

    setState(() {
      _submitted = true;
      _saving = true;
    });

    try {
      if (auth.user != null) {
        await supabase.from('user_attempts').upsert({
          'user_id': auth.user!.id,
          'unit_id': widget.unitId,
          'answers': _answers,
          'score': graded.pct,
          'band_score': band,
          'breakdown': graded.byType.map((k, v) => MapEntry(k, v.toJson())),
          'completed_at': DateTime.now().toIso8601String(),
        });

        // Insert into history
        await supabase.from('score_history').insert({
          'user_id': auth.user!.id,
          'unit_id': widget.unitId,
          'skill': _unit!.skill,
          'band_score': band,
        });
        
        await auth.refreshProfile();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test submitted! Estimated Band Score: $band'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit attempts: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSpeakingRating(String rating) async {
    final auth = Provider.of<AuthState>(context, listen: false);
    setState(() {
      _selfRating = rating;
    });

    final band = rating == 'Confident' ? 7.5 : rating == 'Okay' ? 6.5 : 5.5;

    try {
      if (auth.user != null) {
        await supabase.from('score_history').insert({
          'user_id': auth.user!.id,
          'unit_id': widget.unitId,
          'skill': 'speaking',
          'band_score': band,
          'confidence': rating,
        });
        await auth.refreshProfile();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rating saved! Estimated Band Score: $band'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save rating: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTimerText() {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildMediaUrlWidget(String? mediaUrl) {
    if (mediaUrl == null || mediaUrl.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: mediaUrl,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const SizedBox.shrink(),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || _unit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('An error occurred loading questions.'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadPracticeData, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final unit = _unit!;
    final cfg = AppTheme.skills[unit.skill]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Handle Speaking
    if (unit.skill == 'speaking') {
      return _buildSpeakingView(unit, cfg, isDark);
    }

    // Handle Writing
    if (unit.skill == 'writing') {
      return _buildWritingView(unit, cfg, isDark);
    }

    // Handle Listening / Reading
    return _buildAutoGradableView(unit, cfg, isDark);
  }

  // --- SPEAKING VIEW ---
  Widget _buildSpeakingView(Unit unit, SkillTheme cfg, bool isDark) {
    return Scaffold(
      appBar: _buildPracticeAppBar(unit, cfg),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timer card
            _buildTimerBar(isDark),
            const SizedBox(height: 20),

            ...List.generate(_flatQuestions.length, (index) {
              final q = _flatQuestions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        q.prompt ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      // Band 7+ sample answer expander
                      ExpansionTile(
                        title: Text(
                          'Reveal Band 7+ model answer',
                          style: TextStyle(color: cfg.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              q.explanation ?? 'No model answer provided.',
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),
            // Self rating card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  children: [
                    const Text(
                      'How did you feel about your speaking responses?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['Struggled', 'Okay', 'Confident'].map((rating) {
                        final isSelected = _selfRating == rating;
                        return ElevatedButton(
                          onPressed: () => _saveSpeakingRating(rating),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected ? cfg.primary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                            foregroundColor: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text(rating),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WRITING VIEW ---
  Widget _buildWritingView(Unit unit, SkillTheme cfg, bool isDark) {
    final q = _flatQuestions.isNotEmpty ? _flatQuestions[0] : null;
    if (q == null) return const Scaffold(body: Center(child: Text('No writing tasks defined.')));
    
    final essayText = _answers[q.id]?.toString() ?? '';
    final int wordCount = essayText.trim().isEmpty ? 0 : essayText.trim().split(RegExp(r'\s+')).length;
    final int minWords = q.wordLimit ?? 150;

    return Scaffold(
      appBar: _buildPracticeAppBar(unit, cfg),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTimerBar(isDark),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Writing Prompt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _buildMediaUrlWidget(q.mediaUrl),
                    Text(
                      q.prompt ?? '',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Writing text field
            TextField(
              maxLines: 15,
              enabled: !_submitted,
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: essayText,
                  selection: TextSelection.collapsed(offset: essayText.length),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _answers[q.id] = val;
                });
              },
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
                hintText: 'Write your response here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Word counter
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$wordCount / $minWords+ words',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: wordCount >= minWords ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (!_submitted) ...[
              ElevatedButton(
                onPressed: _saving ? null : _submitTest,
                style: ElevatedButton.styleFrom(backgroundColor: cfg.primary),
                child: const Text('Submit Writing Test'),
              ),
            ] else ...[
              // Model answer and checklist
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Model Essay Answer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Text(
                        q.explanation ?? 'No model essay provided.',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const Divider(height: 32),
                      const Text('Self-Assessment Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ...List.generate(5, (index) {
                        final checklistItems = [
                          'Addressed all parts of the task prompt',
                          'Clear introduction and general overview paragraph',
                          'Compared or grouped data logically',
                          'Used a wide range of vocabulary and correct grammar',
                          'Met word count: 150+ for Task 1, 250+ for Task 2',
                        ];
                        return CheckboxListTile(
                          value: _writingChecklist[index],
                          title: Text(checklistItems[index], style: const TextStyle(fontSize: 13)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: cfg.primary,
                          onChanged: (val) {
                            setState(() {
                              _writingChecklist[index] = val ?? false;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/skills/${unit.skill}'),
                style: ElevatedButton.styleFrom(backgroundColor: cfg.primary),
                child: const Text('Back to Unit List'),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- AUTO GRADABLE VIEW (LISTENING / READING) ---
  Widget _buildAutoGradableView(Unit unit, SkillTheme cfg, bool isDark) {
    final graded = _submitted ? gradeAll(_flatQuestions, _answers) : null;
    
    // For Reading, we use a custom dual-panel tab system (Passage tab vs Questions tab) on mobile.
    final isReading = unit.skill == 'reading';
    final hasPassage = isReading && _flatQuestions.isNotEmpty && _flatQuestions[0].passageText != null;

    return Scaffold(
      appBar: _buildPracticeAppBar(unit, cfg),
      body: Column(
        children: [
          // Segmented Reading Tabs if it's Reading passage
          if (hasPassage && !_submitted) ...[
            Container(
              color: isDark ? const Color(0xFF1E1E24) : Colors.grey[200],
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _readingTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _readingTab == 0 ? cfg.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          'Passage',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _readingTab == 0 ? cfg.primary : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _readingTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _readingTab == 1 ? cfg.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          'Questions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _readingTab == 1 ? cfg.primary : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTimerBar(isDark),
                  const SizedBox(height: 16),

                  // Listening Audio Player
                  if (unit.skill == 'listening' && _audioPlayer != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Listening Test Audio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            StreamBuilder<PlayerState>(
                              stream: _audioPlayer!.playerStateStream,
                              builder: (context, snapshot) {
                                final playerState = snapshot.data;
                                final processingState = playerState?.processingState;
                                final playing = playerState?.playing;
                                
                                if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                                  return const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                                } else if (playing != true) {
                                  return ElevatedButton.icon(
                                    onPressed: _audioPlayer!.play,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Play Audio (Single Play)'),
                                    style: ElevatedButton.styleFrom(backgroundColor: cfg.primary, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16)),
                                  );
                                } else if (processingState != ProcessingState.completed) {
                                  return Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.pause),
                                        onPressed: _audioPlayer!.pause,
                                      ),
                                      const Expanded(child: Text('Playing Section Audio...', style: TextStyle(fontSize: 12))),
                                    ],
                                  );
                                } else {
                                  return const Text('Audio Finished.', style: TextStyle(color: Colors.grey, fontSize: 12));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Display Reading Passage
                  if (isReading && hasPassage && (!_submitted && _readingTab == 0)) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PASSAGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 12),
                            Text(
                              _flatQuestions[0].passageText!,
                              style: const TextStyle(fontSize: 14, height: 1.5, leadingDistribution: TextLeadingDistribution.proportional),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (isReading && hasPassage && _submitted) ...[
                    // Revealed passage in result mode
                    Card(
                      child: ExpansionTile(
                        title: const Text('View Reading Passage', style: TextStyle(fontWeight: FontWeight.bold)),
                        childrenPadding: const EdgeInsets.all(16.0),
                        children: [
                          Text(
                            _flatQuestions[0].passageText!,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Display Questions Panel (if questions tab is selected, or if we submitted, or if not Reading)
                  if (!isReading || _readingTab == 1 || _submitted) ...[
                    // Grouped question lists
                    ..._groupedQuestions.map((group) {
                      final label = questionTypeLabels[group.type] ?? group.type;
                      final sectionLabel = group.section > 0 ? 'Section ${group.section} · ' : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cfg.primary.withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section header badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cfg.soft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$sectionLabel$label',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cfg.foreground,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            ...List.generate(group.items.length, (qi) {
                              final q = group.items[qi];
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${qi + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Expanded(
                                          child: Text(
                                            q.prompt ?? '',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildMediaUrlWidget(q.mediaUrl),
                                          _buildQuestionInputWidget(
                                            question: q,
                                            value: _answers[q.id],
                                            onChange: (val) {
                                              if (_submitted) return;
                                              setState(() {
                                                _answers[q.id] = val;
                                              });
                                            },
                                            isDark: isDark,
                                            cfg: cfg,
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Reveal answers if submitted
                                    if (_submitted) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16.0, top: 12.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text('Your answer: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                  Text(
                                                    '${_answers[q.id] ?? 'None'}', 
                                                    style: TextStyle(
                                                      color: gradeAnswer(q, _answers[q.id]) ? Colors.green : Colors.red,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Text('Correct answer: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                  Text('${q.correctAnswer}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                                                ],
                                              ),
                                              if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(q.explanation!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    
                    if (!_submitted) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _saveProgress,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save progress'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _saving ? null : _submitTest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cfg.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text('Submit test'),
                          ),
                        ],
                      ),
                    ] else if (graded != null) ...[
                      // Graded score overview card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    height: 70,
                                    width: 70,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: cfg.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      bandFromPercent(graded.pct).toStringAsFixed(1),
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Estimated Band Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${graded.correct} / ${graded.total} correct answers (${graded.pct}%)',
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              const Text('Breakdown by question type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 12),
                              ...graded.byType.entries.map((entry) {
                                final pct = entry.value.total > 0 ? ((entry.value.correct / entry.value.total) * 100).round() : 0;
                                final label = questionTypeLabels[entry.key] ?? entry.key;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                                          Text('${entry.value.correct}/${entry.value.total} · $pct%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: pct / 100,
                                        color: cfg.primary,
                                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _submitted = false;
                                          _selfRating = null;
                                          _answers.clear();
                                          _seed = DateTime.now().millisecondsSinceEpoch % 100000;
                                          _loadPracticeData();
                                        });
                                      },
                                      child: const Text('Retry Test'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => context.go('/skills/${unit.skill}'),
                                      style: ElevatedButton.styleFrom(backgroundColor: cfg.primary),
                                      child: const Text('Back to Skill'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Question input picker depending on exact database schema question types
  Widget _buildQuestionInputWidget({
    required Question question,
    required dynamic value,
    required Function(dynamic) onChange,
    required bool isDark,
    required SkillTheme cfg,
  }) {
    switch (question.questionType) {
      case 'mcq_single':
        {
          final options = question.options is List ? question.options as List : [];
          final currentVal = value is List && value.isNotEmpty ? value[0] : null;

          return Column(
            children: options.map((opt) {
              final optId = opt['id']?.toString() ?? '';
              final optText = opt['text']?.toString() ?? '';
              final isSelected = currentVal == optId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: InkWell(
                  onTap: _submitted ? null : () => onChange([optId]),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? cfg.primary.withOpacity(0.08) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? cfg.primary : (isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: optId,
                          groupValue: currentVal?.toString(),
                          activeColor: cfg.primary,
                          onChanged: _submitted ? null : (val) => onChange([optId]),
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text(optText, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }
      case 'mcq_multi':
        {
          final options = question.options is List ? question.options as List : [];
          final Set<String> currentVals = Set<String>.from((value is List ? value : []).map((e) => e.toString()));

          return Column(
            children: options.map((opt) {
              final optId = opt['id']?.toString() ?? '';
              final optText = opt['text']?.toString() ?? '';
              final isSelected = currentVals.contains(optId);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: InkWell(
                  onTap: _submitted ? null : () {
                    final next = Set<String>.from(currentVals);
                    if (next.contains(optId)) {
                      next.remove(optId);
                    } else {
                      next.add(optId);
                    }
                    onChange(next.toList());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? cfg.primary.withOpacity(0.08) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? cfg.primary : (isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: cfg.primary,
                          onChanged: _submitted ? null : (val) {
                            final next = Set<String>.from(currentVals);
                            if (isSelected) {
                              next.remove(optId);
                            } else {
                              next.add(optId);
                            }
                            onChange(next.toList());
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text(optText, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }
      case 'true_false_not_given':
      case 'yes_no_not_given':
        {
          final choices = question.questionType == 'true_false_not_given'
              ? ['TRUE', 'FALSE', 'NOT_GIVEN']
              : ['YES', 'NO', 'NOT_GIVEN'];
          final currentVal = value is List && value.isNotEmpty ? value[0] : null;

          return Row(
            children: choices.map((choice) {
              final isSelected = currentVal == choice;
              final label = choice.replaceAll('_', ' ');

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: _submitted ? null : () => onChange([choice]),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? cfg.primary : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      foregroundColor: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          );
        }
      case 'matching_information':
      case 'matching_headings':
      case 'matching_features':
      case 'matching_sentence_endings':
      case 'summary_completion_bank':
      case 'flow_chart_completion':
      case 'diagram_labelling':
        {
          final correctMap = question.correctAnswer is Map ? Map<String, dynamic>.from(question.correctAnswer as Map) : {};
          final gaps = correctMap.keys.toList()..sort();
          final options = question.options is List ? question.options as List : [];
          final Map<String, String> currentMap = Map<String, String>.from(value is Map ? value : {});

          return Column(
            children: [
              ...gaps.map((gap) {
                final selectedVal = currentMap[gap.toString()] ?? '';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Gap $gap', 
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          )
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedVal.isEmpty ? null : selectedVal,
                          hint: const Text('Select...', style: TextStyle(fontSize: 13)),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: _submitted ? null : (newValue) {
                            final next = Map<String, String>.from(currentMap);
                            if (newValue != null) {
                              next[gap.toString()] = newValue;
                              onChange(next);
                            }
                          },
                          items: options.map((opt) {
                            final id = opt['id']?.toString() ?? '';
                            final text = opt['text']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text('$id. $text', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        }
      case 'sentence_completion':
      case 'note_completion':
      case 'table_completion':
      case 'form_completion':
      case 'summary_completion_text':
      case 'short_answer':
        {
          final currentText = value?.toString() ?? '';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                enabled: !_submitted,
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: currentText,
                    selection: TextSelection.collapsed(offset: currentText.length),
                  ),
                ),
                onChanged: (val) => onChange(val),
                decoration: InputDecoration(
                  hintText: question.wordLimit != null ? 'No more than ${question.wordLimit} words' : 'Type your answer',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              if (question.wordLimit != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Word limit: ${question.wordLimit}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ],
          );
        }
      default:
        return const Text('Unsupported question type.', style: TextStyle(color: Colors.grey, fontSize: 13));
    }
  }

  // Layout blocks
  AppBar _buildPracticeAppBar(Unit unit, SkillTheme cfg) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            cfg.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cfg.primary,
              letterSpacing: 1.1,
            ),
          ),
          Text(
            unit.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          _audioPlayer?.stop();
          context.go('/skills/${unit.skill}');
        },
      ),
    );
  }

  Widget _buildTimerBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _secondsRemaining < 5 * 60 
            ? Colors.red[50] 
            : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _secondsRemaining < 5 * 60 
              ? Colors.red[200]! 
              : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time_outlined, 
            size: 18, 
            color: _secondsRemaining < 5 * 60 ? Colors.red : Colors.grey
          ),
          const SizedBox(width: 8),
          Text(
            _timerExpired ? 'TIME EXPIRED' : _formatTimerText(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _secondsRemaining < 5 * 60 ? Colors.red : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionGroup {
  final int section;
  final String type;
  final List<Question> items;

  QuestionGroup({required this.section, required this.type, required this.items});
}
