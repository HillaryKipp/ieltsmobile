import 'models.dart';

String normStr(String s) {
  return s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool isAutoGradable(String qt) {
  return qt != 'short_answer';
}

bool gradeAnswer(Question q, dynamic submitted) {
  final correct = q.correctAnswer;
  if (submitted == null) return false;

  switch (q.questionType) {
    case 'mcq_single':
    case 'true_false_not_given':
    case 'yes_no_not_given':
      {
        dynamic s = submitted is List ? (submitted.isNotEmpty ? submitted[0] : '') : submitted;
        dynamic c = correct is List ? (correct.isNotEmpty ? correct[0] : '') : correct;
        return s.toString().trim().toUpperCase() == c.toString().trim().toUpperCase();
      }
    case 'mcq_multi':
      {
        final submittedList = submitted is List ? List<String>.from(submitted.map((e) => e.toString())) : <String>[];
        final correctList = correct is List ? List<String>.from(correct.map((e) => e.toString())) : <String>[];

        final sSet = Set<String>.from(submittedList);
        final cSet = Set<String>.from(correctList);

        if (sSet.length != cSet.length) return false;
        for (final val in sSet) {
          if (!cSet.contains(val)) return false;
        }
        return true;
      }
    case 'sentence_completion':
    case 'note_completion':
    case 'table_completion':
    case 'form_completion':
    case 'summary_completion_text':
    case 'short_answer':
      {
        final s = normStr(submitted.toString());
        final correctList = correct is List ? List<String>.from(correct.map((e) => e.toString())) : <String>[];
        if (correctList.isEmpty) return false;
        return correctList.any((val) => normStr(val) == s);
      }
    case 'matching_information':
    case 'matching_headings':
    case 'matching_features':
    case 'matching_sentence_endings':
    case 'summary_completion_bank':
    case 'flow_chart_completion':
    case 'diagram_labelling':
      {
        final sMap = submitted is Map ? Map<String, String>.from(submitted.map((k, v) => MapEntry(k.toString(), v.toString()))) : <String, String>{};
        final cMap = correct is Map ? Map<String, String>.from(correct.map((k, v) => MapEntry(k.toString(), v.toString()))) : <String, String>{};

        final keys = cMap.keys.toList();
        if (keys.isEmpty) return false;
        return keys.every((k) => normStr(sMap[k] ?? '') == normStr(cMap[k] ?? ''));
      }
    default:
      return false;
  }
}

class GradeResult {
  final int correct;
  final int total;
  final int pct;
  final Map<String, TypeBreakdown> byType;

  GradeResult({
    required this.correct,
    required this.total,
    required this.pct,
    required this.byType,
  });
}

class TypeBreakdown {
  int correct;
  int total;

  TypeBreakdown({this.correct = 0, this.total = 0});

  Map<String, dynamic> toJson() => {
    'correct': correct,
    'total': total,
  };
}

GradeResult gradeAll(List<Question> questions, Map<String, dynamic> answers) {
  final auto = questions.where((q) => q.questionType != 'short_answer').toList();
  int correct = 0;
  for (final q in auto) {
    if (gradeAnswer(q, answers[q.id])) {
      correct++;
    }
  }
  final total = auto.length;
  final pct = total > 0 ? ((correct / total) * 100).round() : 0;

  final Map<String, TypeBreakdown> byType = {};
  for (final q in auto) {
    byType.putIfAbsent(q.questionType, () => TypeBreakdown());
    byType[q.questionType]!.total += 1;
    if (gradeAnswer(q, answers[q.id])) {
      byType[q.questionType]!.correct += 1;
    }
  }

  return GradeResult(correct: correct, total: total, pct: pct, byType: byType);
}

double bandFromPercent(int pct) {
  if (pct >= 89) return 9.0;
  if (pct >= 82) return 8.5;
  if (pct >= 75) return 8.0;
  if (pct >= 67) return 7.5;
  if (pct >= 60) return 7.0;
  if (pct >= 52) return 6.5;
  if (pct >= 45) return 6.0;
  if (pct >= 37) return 5.5;
  if (pct >= 30) return 5.0;
  if (pct >= 22) return 4.5;
  if (pct >= 15) return 4.0;
  return 3.5;
}

List<T> shuffleQuestions<T>(List<T> arr, int seed) {
  final a = List<T>.from(arr);
  int s = seed;
  for (int i = a.length - 1; i > 0; i--) {
    s = (s * 9301 + 49297) % 233280;
    final j = ((s / 233280) * (i + 1)).floor();
    final temp = a[i];
    a[i] = a[j];
    a[j] = temp;
  }
  return a;
}

const Map<String, String> questionTypeLabels = {
  'mcq_single': 'Multiple choice (single answer)',
  'mcq_multi': 'Multiple choice (multiple answers)',
  'true_false_not_given': 'True / False / Not Given',
  'yes_no_not_given': 'Yes / No / Not Given',
  'matching_information': 'Matching information',
  'matching_headings': 'Matching headings',
  'matching_features': 'Matching features',
  'matching_sentence_endings': 'Matching sentence endings',
  'sentence_completion': 'Sentence completion',
  'note_completion': 'Note completion',
  'table_completion': 'Table completion',
  'form_completion': 'Form completion',
  'summary_completion_text': 'Summary completion (from passage)',
  'summary_completion_bank': 'Summary completion (from word bank)',
  'flow_chart_completion': 'Flow-chart completion',
  'diagram_labelling': 'Diagram labelling',
  'short_answer': 'Short-answer',
};
