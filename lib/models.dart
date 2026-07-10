import 'dart:convert';

class Profile {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final DateTime? examDate;
  final bool isPaid;
  final DateTime? paidUntil;
  final DateTime createdAt;

  Profile({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.examDate,
    required this.isPaid,
    this.paidUntil,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      examDate: json['exam_date'] != null ? DateTime.tryParse(json['exam_date'] as String) : null,
      isPaid: json['is_paid'] as bool? ?? false,
      paidUntil: json['paid_until'] != null ? DateTime.tryParse(json['paid_until'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'exam_date': examDate?.toIso8601String().substring(0, 10), // YYYY-MM-DD
      'is_paid': isPaid,
      'paid_until': paidUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Unit {
  final String id;
  final String skill; // 'listening', 'reading', 'writing', 'speaking'
  final String title;
  final String? description;
  final int orderIndex;
  final bool isFree;
  final DateTime createdAt;

  Unit({
    required this.id,
    required this.skill,
    required this.title,
    this.description,
    required this.orderIndex,
    required this.isFree,
    required this.createdAt,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as String,
      skill: json['skill'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      isFree: json['is_free'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Question {
  final String id;
  final String unitId;
  final int? section;
  final int orderIndex;
  final String questionType;
  final String? prompt;
  final String? passageText;
  final String? audioUrl;
  final String? mediaUrl;
  final dynamic options; 
  final dynamic correctAnswer; 
  final int? wordLimit;
  final String? explanation;

  Question({
    required this.id,
    required this.unitId,
    this.section,
    required this.orderIndex,
    required this.questionType,
    this.prompt,
    this.passageText,
    this.audioUrl,
    this.mediaUrl,
    this.options,
    required this.correctAnswer,
    this.wordLimit,
    this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      unitId: json['unit_id'] as String,
      section: json['section'] as int?,
      orderIndex: json['order_index'] as int? ?? 0,
      questionType: json['question_type'] as String,
      prompt: json['prompt'] as String?,
      passageText: json['passage_text'] as String?,
      audioUrl: json['audio_url'] as String?,
      mediaUrl: json['media_url'] as String?,
      options: json['options'],
      correctAnswer: json['correct_answer'],
      wordLimit: json['word_limit'] as int?,
      explanation: json['explanation'] as String?,
    );
  }
}

class UserAttempt {
  final String userId;
  final String unitId;
  final Map<String, dynamic> answers;
  final Map<String, dynamic>? breakdown;
  final double? score;
  final double? bandScore;
  final DateTime completedAt;
  final Unit? unit;

  UserAttempt({
    required this.userId,
    required this.unitId,
    required this.answers,
    this.breakdown,
    this.score,
    this.bandScore,
    required this.completedAt,
    this.unit,
  });

  factory UserAttempt.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'];
    Map<String, dynamic> parsedAnswers = {};
    if (rawAnswers is Map) {
      parsedAnswers = Map<String, dynamic>.from(rawAnswers);
    } else if (rawAnswers is String) {
      try {
        parsedAnswers = Map<String, dynamic>.from(jsonDecode(rawAnswers));
      } catch (_) {}
    }

    final rawBreakdown = json['breakdown'];
    Map<String, dynamic>? parsedBreakdown;
    if (rawBreakdown is Map) {
      parsedBreakdown = Map<String, dynamic>.from(rawBreakdown);
    } else if (rawBreakdown is String) {
      try {
        parsedBreakdown = Map<String, dynamic>.from(jsonDecode(rawBreakdown));
      } catch (_) {}
    }

    return UserAttempt(
      userId: json['user_id'] as String,
      unitId: json['unit_id'] as String,
      answers: parsedAnswers,
      breakdown: parsedBreakdown,
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      bandScore: json['band_score'] != null ? (json['band_score'] as num).toDouble() : null,
      completedAt: DateTime.parse(json['completed_at'] as String),
      unit: json['units'] != null ? Unit.fromJson(json['units'] as Map<String, dynamic>) : null,
    );
  }
}

class ScoreHistory {
  final String id;
  final String userId;
  final String? unitId;
  final String skill;
  final double bandScore;
  final String? confidence;
  final DateTime recordedAt;

  ScoreHistory({
    required this.id,
    required this.userId,
    this.unitId,
    required this.skill,
    required this.bandScore,
    this.confidence,
    required this.recordedAt,
  });

  factory ScoreHistory.fromJson(Map<String, dynamic> json) {
    return ScoreHistory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      unitId: json['unit_id'] as String?,
      skill: json['skill'] as String,
      bandScore: (json['band_score'] as num).toDouble(),
      confidence: json['confidence'] as String?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}
