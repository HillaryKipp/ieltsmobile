import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/error_view.dart';

class AdminScreen extends StatefulWidget {
  final String? initialUnitId;

  const AdminScreen({super.key, this.initialUnitId});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Units State
  List<Unit> _units = [];
  bool _isLoadingUnits = true;
  String? _unitsError;
  String _selectedSkillFilter = 'all';

  // Questions State
  List<Question> _questions = [];
  bool _isLoadingQuestions = false;
  String? _questionsError;
  String? _selectedUnitIdForQuestions;

  // Settings State
  final _priceController = TextEditingController();
  bool _isLoadingSettings = true;
  String? _settingsError;
  bool _isSavingSettings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.initialUnitId != null) {
      _selectedUnitIdForQuestions = widget.initialUnitId;
      _tabController.index = 1;
    }

    _loadUnits();
    _loadQuestions();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // --- DATA LOADING METHODS ---

  Future<void> _loadUnits() async {
    setState(() {
      _isLoadingUnits = true;
      _unitsError = null;
    });
    try {
      final res = await supabase.from('units').select('*').order('skill', ascending: true).order('order_index', ascending: true);
      final list = (res as List<dynamic>).map((e) => Unit.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _units = list;
          _isLoadingUnits = false;
          _unitsError = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading units: $e');
      if (mounted) {
        setState(() {
          _isLoadingUnits = false;
          _unitsError = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoadingQuestions = true;
      _questionsError = null;
    });
    try {
      var query = supabase.from('questions').select('*');
      if (_selectedUnitIdForQuestions != null && _selectedUnitIdForQuestions!.isNotEmpty) {
        query = query.eq('unit_id', _selectedUnitIdForQuestions!);
      }
      final res = await query.order('section', ascending: true).order('order_index', ascending: true);
      final list = (res as List<dynamic>).map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _questions = list;
          _isLoadingQuestions = false;
          _questionsError = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
      if (mounted) {
        setState(() {
          _isLoadingQuestions = false;
          _questionsError = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoadingSettings = true;
      _settingsError = null;
    });
    try {
      // Fetch public price via RPC or app_settings table
      final priceRes = await supabase.rpc('get_public_price');
      if (priceRes != null) {
        _priceController.text = (priceRes as num).toString();
      } else {
        final settingRes = await supabase.from('app_settings').select('value').eq('key', 'public_price').maybeSingle();
        if (settingRes != null && settingRes['value'] != null) {
          _priceController.text = settingRes['value'].toString();
        }
      }
      if (mounted) {
        setState(() {
          _isLoadingSettings = false;
          _settingsError = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isLoadingSettings = false;
          _settingsError = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  // --- UNIT CRUD METHODS ---

  Future<void> _showAddEditUnitDialog([Unit? unit]) async {
    final isEditing = unit != null;
    final formKey = GlobalKey<FormState>();

    final titleCtrl = TextEditingController(text: unit?.title ?? '');
    final descCtrl = TextEditingController(text: unit?.description ?? '');
    final orderCtrl = TextEditingController(text: (unit?.orderIndex ?? (_units.length + 1)).toString());
    String skill = unit?.skill ?? 'listening';
    bool isFree = unit?.isFree ?? false;
    bool isSaving = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Unit' : 'Add New Unit', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogError != null)
                        InlineErrorBanner(
                          message: dialogError,
                          onDismiss: () => setDialogState(() => dialogError = null),
                        ),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Listening Practice Test 1'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: skill,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Skill'),
                        items: const [
                          DropdownMenuItem(value: 'listening', child: Text('Listening')),
                          DropdownMenuItem(value: 'reading', child: Text('Reading')),
                          DropdownMenuItem(value: 'writing', child: Text('Writing')),
                          DropdownMenuItem(value: 'speaking', child: Text('Speaking')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => skill = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description (Optional)'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: orderCtrl,
                        decoration: const InputDecoration(labelText: 'Order Index'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Order index required';
                          if (int.tryParse(val.trim()) == null) return 'Must be a valid integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Free Unit'),
                        subtitle: const Text('Accessible without premium membership'),
                        value: isFree,
                        onChanged: (val) => setDialogState(() => isFree = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          dialogError = null;
                        });

                        try {
                          final data = {
                            'title': titleCtrl.text.trim(),
                            'skill': skill,
                            'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                            'order_index': int.parse(orderCtrl.text.trim()),
                            'is_free': isFree,
                          };

                          if (isEditing) {
                            await supabase.from('units').update(data).eq('id', unit.id);
                          } else {
                            await supabase.from('units').insert(data);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadUnits();
                          if (mounted) {
                            ErrorUtils.showSuccessSnackBar(context, isEditing ? 'Unit updated successfully!' : 'Unit created successfully!');
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            dialogError = ErrorUtils.getFriendlyMessage(e);
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? 'Save Changes' : 'Create Unit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteUnit(Unit unit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit'),
        content: Text('Are you sure you want to delete "${unit.title}" and all associated questions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('units').delete().eq('id', unit.id);
        _loadUnits();
        if (_selectedUnitIdForQuestions == unit.id) {
          _selectedUnitIdForQuestions = null;
          _loadQuestions();
        }
        if (mounted) {
          ErrorUtils.showSuccessSnackBar(context, 'Unit "${unit.title}" deleted');
        }
      } catch (e) {
        if (mounted) {
          ErrorUtils.showErrorSnackBar(context, e, prefix: 'Failed to delete unit');
        }
      }
    }
  }

  // --- QUESTION CRUD METHODS ---

  Future<void> _showAddEditQuestionDialog([Question? question]) async {
    final isEditing = question != null;
    final formKey = GlobalKey<FormState>();

    String unitId = question?.unitId ?? (_selectedUnitIdForQuestions ?? (_units.isNotEmpty ? _units.first.id : ''));
    final sectionCtrl = TextEditingController(text: question?.section?.toString() ?? '1');
    final orderCtrl = TextEditingController(text: (question?.orderIndex ?? (_questions.length + 1)).toString());
    String qType = question?.questionType ?? 'mcq_single';

    const Map<String, String> knownQuestionTypes = {
      'mcq_single': 'Multiple Choice (Single Answer)',
      'mcq_multi': 'Multiple Choice (Multiple Answers)',
      'true_false_not_given': 'True / False / Not Given',
      'true_false': 'True / False',
      'yes_no_not_given': 'Yes / No / Not Given',
      'matching': 'Matching',
      'matching_headings': 'Matching Headings',
      'sentence_completion': 'Sentence Completion',
      'short_answer': 'Short Answer',
      'essay': 'Essay / Writing Prompt',
      'fill_in_blanks': 'Fill in the Blanks',
      'multiple_choice': 'Multiple Choice',
      'single_choice': 'Single Choice',
    };

    final typeMap = Map<String, String>.from(knownQuestionTypes);
    if (!typeMap.containsKey(qType)) {
      typeMap[qType] = qType;
    }

    final promptCtrl = TextEditingController(text: question?.prompt ?? '');
    final passageCtrl = TextEditingController(text: question?.passageText ?? '');
    final audioCtrl = TextEditingController(text: question?.audioUrl ?? '');
    final mediaCtrl = TextEditingController(text: question?.mediaUrl ?? '');
    
    // Format options as readable string (JSON or list)
    String optionsText = '';
    if (question?.options != null) {
      if (question!.options is List) {
        optionsText = (question.options as List).join('\n');
      } else {
        optionsText = jsonEncode(question.options);
      }
    }
    final optionsCtrl = TextEditingController(text: optionsText);

    // Format correct answer
    String ansText = '';
    if (question?.correctAnswer != null) {
      if (question!.correctAnswer is String) {
        ansText = question.correctAnswer as String;
      } else {
        ansText = jsonEncode(question.correctAnswer);
      }
    }
    final ansCtrl = TextEditingController(text: ansText);

    final wordLimitCtrl = TextEditingController(text: question?.wordLimit?.toString() ?? '');
    final explanationCtrl = TextEditingController(text: question?.explanation ?? '');

    if (_units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please create a Unit first before adding questions.'), backgroundColor: Colors.orange),
      );
      return;
    }

    bool isSaving = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Question' : 'Add Question', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 550),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogError != null)
                        InlineErrorBanner(
                          message: dialogError,
                          onDismiss: () => setDialogState(() => dialogError = null),
                        ),
                      DropdownButtonFormField<String>(
                        value: _units.any((u) => u.id == unitId) ? unitId : _units.first.id,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: _units.map((u) {
                          return DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              '[${u.skill.toUpperCase()}] ${u.title}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => unitId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: sectionCtrl,
                              decoration: const InputDecoration(labelText: 'Section / Part'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: orderCtrl,
                              decoration: const InputDecoration(labelText: 'Order Index'),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                if (int.tryParse(val.trim()) == null) return 'Integer';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: qType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Question Type'),
                        items: typeMap.entries.map((e) {
                          return DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => qType = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: promptCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Question Prompt / Instructions',
                          hintText: 'e.g. What is the author\'s main argument?',
                        ),
                        maxLines: 2,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Prompt is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passageCtrl,
                        decoration: const InputDecoration(labelText: 'Passage Text (Optional)'),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: audioCtrl,
                        decoration: const InputDecoration(labelText: 'Audio URL (Optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: mediaCtrl,
                        decoration: const InputDecoration(labelText: 'Media / Image URL (Optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: optionsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Options (List or JSON, Optional)',
                          hintText: 'One per line or ["Option A", "Option B"]',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ansCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Correct Answer (Text or JSON)',
                          hintText: 'e.g. Option A or true',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: wordLimitCtrl,
                        decoration: const InputDecoration(labelText: 'Word Limit (Optional)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: explanationCtrl,
                        decoration: const InputDecoration(labelText: 'Explanation (Optional)'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          dialogError = null;
                        });

                        // Parse options
                        dynamic parsedOptions;
                        final rawOpt = optionsCtrl.text.trim();
                        if (rawOpt.isNotEmpty) {
                          try {
                            parsedOptions = jsonDecode(rawOpt);
                          } catch (_) {
                            // Treat as newline separated list
                            parsedOptions = rawOpt.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                          }
                        }

                        // Parse correct answer
                        dynamic parsedAnswer;
                        final rawAns = ansCtrl.text.trim();
                        if (rawAns.isNotEmpty) {
                          try {
                            parsedAnswer = jsonDecode(rawAns);
                          } catch (_) {
                            parsedAnswer = rawAns;
                          }
                        }

                        try {
                          final data = {
                            'unit_id': unitId,
                            'section': int.tryParse(sectionCtrl.text.trim()),
                            'order_index': int.parse(orderCtrl.text.trim()),
                            'question_type': qType,
                            'prompt': promptCtrl.text.trim(),
                            'passage_text': passageCtrl.text.trim().isEmpty ? null : passageCtrl.text.trim(),
                            'audio_url': audioCtrl.text.trim().isEmpty ? null : audioCtrl.text.trim(),
                            'media_url': mediaCtrl.text.trim().isEmpty ? null : mediaCtrl.text.trim(),
                            'options': parsedOptions,
                            'correct_answer': parsedAnswer,
                            'word_limit': int.tryParse(wordLimitCtrl.text.trim()),
                            'explanation': explanationCtrl.text.trim().isEmpty ? null : explanationCtrl.text.trim(),
                          };

                          if (isEditing) {
                            await supabase.from('questions').update(data).eq('id', question.id);
                          } else {
                            await supabase.from('questions').insert(data);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadQuestions();
                          if (mounted) {
                            ErrorUtils.showSuccessSnackBar(context, isEditing ? 'Question updated successfully!' : 'Question created successfully!');
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            dialogError = ErrorUtils.getFriendlyMessage(e);
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? 'Save Changes' : 'Create Question'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteQuestion(Question q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('questions').delete().eq('id', q.id);
        _loadQuestions();
        if (mounted) {
          ErrorUtils.showSuccessSnackBar(context, 'Question deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          ErrorUtils.showErrorSnackBar(context, e, prefix: 'Failed to delete question');
        }
      }
    }
  }

  // --- SETTINGS SAVE METHOD ---

  Future<void> _saveSettings() async {
    final priceText = _priceController.text.trim();
    if (priceText.isEmpty || double.tryParse(priceText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numeric price.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSavingSettings = true);
    try {
      await supabase.from('app_settings').upsert({
        'key': 'public_price',
        'value': priceText,
      });

      if (mounted) {
        ErrorUtils.showSuccessSnackBar(context, 'App settings updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showErrorSnackBar(context, e, prefix: 'Failed to update settings');
      }
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  // --- BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gpp_maybe_outlined, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Admin Access Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('You do not have permission to access the admin section.'),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.go('/'), child: const Text('Return Home')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Control Panel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder_outlined), text: 'Units'),
            Tab(icon: Icon(Icons.quiz_outlined), text: 'Questions'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUnitsTab(isDark),
          _buildQuestionsTab(isDark),
          _buildSettingsTab(isDark),
        ],
      ),
    );
  }

  // --- UNITS TAB UI ---

  Widget _buildUnitsTab(bool isDark) {
    List<Unit> filteredUnits = _units;
    if (_selectedSkillFilter != 'all') {
      filteredUnits = _units.where((u) => u.skill == _selectedSkillFilter).toList();
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditUnitDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'listening', 'reading', 'writing', 'speaking'].map((s) {
                  final isSelected = _selectedSkillFilter == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(s.toUpperCase()),
                      onSelected: (_) => setState(() => _selectedSkillFilter = s),
                      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      checkmarkColor: AppTheme.primaryColor,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // List of Units
            Expanded(
              child: _isLoadingUnits
                  ? const Center(child: CircularProgressIndicator())
                  : _unitsError != null
                      ? ErrorView(
                          error: _unitsError,
                          title: 'Failed to Load Units',
                          onRetry: _loadUnits,
                        )
                      : filteredUnits.isEmpty
                          ? Center(
                              child: Text(
                                _selectedSkillFilter == 'all'
                                    ? 'No units created yet.'
                                    : 'No units found for ${_selectedSkillFilter.toUpperCase()}.',
                              ),
                            )
                          : RefreshIndicator(
                          onRefresh: _loadUnits,
                          child: ListView.builder(
                            itemCount: filteredUnits.length,
                            itemBuilder: (context, index) {
                              final unit = filteredUnits[index];
                              final cfg = AppTheme.skills[unit.skill];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                borderOnForeground: true,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: cfg?.soft ?? Colors.grey[200],
                                    child: Icon(cfg?.icon ?? Icons.description, color: cfg?.primary ?? AppTheme.primaryColor),
                                  ),
                                  title: Text(unit.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${unit.skill.toUpperCase()} • Order: ${unit.orderIndex} • ${unit.isFree ? "Free" : "Premium"}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.quiz_outlined, color: Colors.blue),
                                        tooltip: 'Manage Questions',
                                        onPressed: () {
                                          setState(() {
                                            _selectedUnitIdForQuestions = unit.id;
                                          });
                                          _loadQuestions();
                                          _tabController.animateTo(1);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _showAddEditUnitDialog(unit),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteUnit(unit),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- QUESTIONS TAB UI ---

  Widget _buildQuestionsTab(bool isDark) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditQuestionDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _selectedUnitIdForQuestions,
                  hint: const Text('Filter by Unit (All Units)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Units'),
                    ),
                    ..._units.map((u) => DropdownMenuItem<String?>(
                          value: u.id,
                          child: Text('[${u.skill.toUpperCase()}] ${u.title}'),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedUnitIdForQuestions = val);
                    _loadQuestions();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Questions list
            Expanded(
              child: _isLoadingQuestions
                  ? const Center(child: CircularProgressIndicator())
                  : _questionsError != null
                      ? ErrorView(
                          error: _questionsError,
                          title: 'Failed to Load Questions',
                          onRetry: _loadQuestions,
                        )
                      : _questions.isEmpty
                          ? Center(
                              child: Text(
                                _selectedUnitIdForQuestions != null
                                    ? 'No questions found for the selected unit.'
                                    : 'No questions created yet.',
                              ),
                            )
                          : RefreshIndicator(
                          onRefresh: _loadQuestions,
                          child: ListView.builder(
                            itemCount: _questions.length,
                            itemBuilder: (context, index) {
                              final q = _questions[index];
                              final parentUnit = _units.cast<Unit?>().firstWhere(
                                    (u) => u?.id == q.unitId,
                                    orElse: () => null,
                                  );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Chip(
                                            label: Text(q.questionType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            'Sec ${q.section ?? 1} • Order ${q.orderIndex}',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (parentUnit != null)
                                        Text('Unit: ${parentUnit.title}', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        q.prompt ?? '(No prompt)',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (q.passageText != null) ...[
                                        const SizedBox(height: 4),
                                        Text('Passage: ${q.passageText}', style: TextStyle(color: Colors.grey[500], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined),
                                            onPressed: () => _showAddEditQuestionDialog(q),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _deleteQuestion(q),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SETTINGS TAB UI ---

  Widget _buildSettingsTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('App Pricing & Global Settings', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Configure global application settings stored in app_settings table.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Public Membership Price (KSH)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  if (_isLoadingSettings)
                    const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                  else if (_settingsError != null) ...[
                    InlineErrorBanner(
                      message: _settingsError,
                      onDismiss: () => setState(() => _settingsError = null),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loadSettings,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry Loading Settings'),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'One-time Payment Price',
                        prefixText: 'KSH ',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isSavingSettings ? null : _saveSettings,
                      child: _isSavingSettings
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Settings'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
