import 'package:flutter_test/flutter_test.dart';
import '../lib/models.dart';
import '../lib/grading.dart';

void main() {
  group('IELTS Grading Tests', () {
    test('normStr normalizes whitespace and case', () {
      expect(normStr('  HELLO   world  '), 'hello world');
      expect(normStr('A   B C'), 'a b c');
    });

    test('bandFromPercent maps percentages to correct IELTS bands', () {
      expect(bandFromPercent(90), 9.0);
      expect(bandFromPercent(85), 8.5);
      expect(bandFromPercent(78), 8.0);
      expect(bandFromPercent(70), 7.5);
      expect(bandFromPercent(63), 7.0);
      expect(bandFromPercent(55), 6.5);
      expect(bandFromPercent(48), 6.0);
      expect(bandFromPercent(40), 5.5);
      expect(bandFromPercent(33), 5.0);
      expect(bandFromPercent(25), 4.5);
      expect(bandFromPercent(18), 4.0);
      expect(bandFromPercent(10), 3.5);
    });

    test('gradeAnswer for mcq_single', () {
      final q = Question(
        id: 'q1',
        unitId: 'u1',
        orderIndex: 0,
        questionType: 'mcq_single',
        correctAnswer: 'A',
      );
      
      expect(gradeAnswer(q, 'A'), true);
      expect(gradeAnswer(q, 'a'), true);
      expect(gradeAnswer(q, ['A']), true);
      expect(gradeAnswer(q, 'B'), false);
    });

    test('gradeAnswer for mcq_multi', () {
      final q = Question(
        id: 'q2',
        unitId: 'u1',
        orderIndex: 0,
        questionType: 'mcq_multi',
        correctAnswer: ['A', 'B'],
      );

      expect(gradeAnswer(q, ['A', 'B']), true);
      expect(gradeAnswer(q, ['B', 'A']), true);
      expect(gradeAnswer(q, ['A']), false);
      expect(gradeAnswer(q, ['A', 'B', 'C']), false);
    });

    test('gradeAnswer for yes_no_not_given', () {
      final q = Question(
        id: 'q3',
        unitId: 'u1',
        orderIndex: 0,
        questionType: 'yes_no_not_given',
        correctAnswer: 'YES',
      );

      expect(gradeAnswer(q, 'YES'), true);
      expect(gradeAnswer(q, ['YES']), true);
      expect(gradeAnswer(q, 'NO'), false);
    });

    test('gradeAnswer for sentence_completion list of answers', () {
      final q = Question(
        id: 'q4',
        unitId: 'u1',
        orderIndex: 0,
        questionType: 'sentence_completion',
        correctAnswer: ['sunlight', 'solar energy'],
      );

      expect(gradeAnswer(q, 'sunlight'), true);
      expect(gradeAnswer(q, ' SOLAR ENERGY '), true);
      expect(gradeAnswer(q, 'water'), false);
    });

    test('gradeAnswer for matching_headings map of gaps', () {
      final q = Question(
        id: 'q5',
        unitId: 'u1',
        orderIndex: 0,
        questionType: 'matching_headings',
        correctAnswer: {'1': 'v', '2': 'i'},
      );

      expect(gradeAnswer(q, {'1': 'v', '2': 'i'}), true);
      expect(gradeAnswer(q, {'1': 'V ', '2': ' I'}), true);
      expect(gradeAnswer(q, {'1': 'v', '2': 'iii'}), false);
      expect(gradeAnswer(q, {'1': 'v'}), false);
    });

    test('gradeAll aggregates scores correctly', () {
      final questions = [
        Question(
          id: 'q1',
          unitId: 'u1',
          orderIndex: 0,
          questionType: 'mcq_single',
          correctAnswer: 'A',
        ),
        Question(
          id: 'q2',
          unitId: 'u1',
          orderIndex: 1,
          questionType: 'sentence_completion',
          correctAnswer: ['sunlight'],
        ),
        Question(
          id: 'q3',
          unitId: 'u1',
          orderIndex: 2,
          questionType: 'short_answer', // Should be skipped in auto-grading
          correctAnswer: 'essay prompt',
        ),
      ];

      final answers = {
        'q1': 'A',
        'q2': 'sunlight',
        'q3': 'some answer',
      };

      final result = gradeAll(questions, answers);
      expect(result.correct, 2);
      expect(result.total, 2);
      expect(result.pct, 100);
      expect(result.byType['mcq_single']!.correct, 1);
      expect(result.byType['short_answer'], null); // short_answer skipped in auto-grade
    });

    test('shuffleQuestions is deterministic with same seed', () {
      final list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final res1 = shuffleQuestions(list, 42);
      final res2 = shuffleQuestions(list, 42);
      final res3 = shuffleQuestions(list, 43);

      expect(res1, res2);
      expect(res1 == res3, false); // Shuffled differently with different seed
    });
  });
}
