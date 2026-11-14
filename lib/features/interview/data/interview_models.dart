import 'package:cloud_firestore/cloud_firestore.dart';

import 'voice_answer.dart';

// ─── Difficulty ────────────────────────────────────────────────────────────────
enum InterviewDifficulty {
  easy('Easy', 'Fundamentals and definitions'),
  medium('Medium', 'Practical use, trade-offs, real scenarios'),
  hard('Hard', 'Internals, design decisions, edge cases');

  final String label;
  final String description;
  const InterviewDifficulty(this.label, this.description);

  static InterviewDifficulty fromName(String? name) {
    return InterviewDifficulty.values.firstWhere(
      (d) => d.name == name,
      orElse: () => InterviewDifficulty.medium,
    );
  }

  /// Sensible starting difficulty for the experience levels in CareerOptions.
  static InterviewDifficulty forExperience(String experience) {
    if (experience.startsWith('Student') || experience.startsWith('0')) {
      return InterviewDifficulty.easy;
    }
    if (experience.startsWith('5') || experience.startsWith('8')) {
      return InterviewDifficulty.hard;
    }
    return InterviewDifficulty.medium;
  }
}

// ─── Config ────────────────────────────────────────────────────────────────────
// What the user picked on the setup sheet, plus profile details for the prompt.
// Compared by identity on purpose: every started interview is a new session.
class InterviewConfig {
  final String topic;
  final InterviewDifficulty difficulty;
  final int questionCount;
  final String targetRole;
  final String experienceLevel;

  const InterviewConfig({
    required this.topic,
    required this.difficulty,
    required this.questionCount,
    this.targetRole = '',
    this.experienceLevel = '',
  });

  static const questionCounts = [3, 5, 8, 10];
}

// ─── Turn ──────────────────────────────────────────────────────────────────────
// One question, the user's answer and the AI's feedback on it.
class InterviewTurn {
  final String question;
  final bool isFollowUp;
  final String answer;
  final bool skipped;
  final int score; // 0–10
  final List<String> good;
  final List<String> missing;
  final String modelAnswer;
  final bool byVoice; // answer is the transcript of a recording
  final VoiceDelivery? delivery; // how it was spoken (voice answers only)

  const InterviewTurn({
    required this.question,
    required this.isFollowUp,
    required this.answer,
    required this.skipped,
    required this.score,
    required this.good,
    required this.missing,
    required this.modelAnswer,
    this.byVoice = false,
    this.delivery,
  });

  Map<String, dynamic> toMap() => {
    'question': question,
    'isFollowUp': isFollowUp,
    'answer': answer,
    'skipped': skipped,
    'score': score,
    'good': good,
    'missing': missing,
    'modelAnswer': modelAnswer,
    if (byVoice) 'byVoice': true,
    if (delivery != null) 'delivery': delivery!.toMap(),
  };

  factory InterviewTurn.fromMap(Map<String, dynamic> map) {
    return InterviewTurn(
      question: map['question'] as String? ?? '',
      isFollowUp: map['isFollowUp'] == true,
      answer: map['answer'] as String? ?? '',
      skipped: map['skipped'] == true,
      score: (map['score'] as num?)?.toInt().clamp(0, 10) ?? 0,
      good: _stringList(map['good']),
      missing: _stringList(map['missing']),
      modelAnswer: map['modelAnswer'] as String? ?? '',
      byVoice: map['byVoice'] == true,
      delivery: map['delivery'] is Map
          ? VoiceDelivery.fromMap(Map<String, dynamic>.from(map['delivery']))
          : null,
    );
  }
}

// ─── Report ────────────────────────────────────────────────────────────────────
class InterviewReport {
  final int overallScore; // 0–100, worked out from the answer scores
  final String summary;
  final List<String> strongAreas;
  final List<String> weakAreas;
  final List<String> practiceNext;

  const InterviewReport({
    required this.overallScore,
    required this.summary,
    required this.strongAreas,
    required this.weakAreas,
    required this.practiceNext,
  });

  /// Average of the answer scores (each out of 10) as a percentage.
  static int overallScoreFor(List<InterviewTurn> turns) {
    if (turns.isEmpty) return 0;
    final total = turns.fold<int>(0, (acc, t) => acc + t.score);
    return (total * 10 / turns.length).round();
  }

  Map<String, dynamic> toMap() => {
    'overallScore': overallScore,
    'summary': summary,
    'strongAreas': strongAreas,
    'weakAreas': weakAreas,
    'practiceNext': practiceNext,
  };

  factory InterviewReport.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return InterviewReport(
      overallScore: (data['overallScore'] as num?)?.toInt().clamp(0, 100) ?? 0,
      summary: data['summary'] as String? ?? '',
      strongAreas: _stringList(data['strongAreas']),
      weakAreas: _stringList(data['weakAreas']),
      practiceNext: _stringList(data['practiceNext']),
    );
  }
}

// ─── Session ───────────────────────────────────────────────────────────────────
// A finished interview, as saved in users/{uid}/interviews.
class InterviewSession {
  final String id;
  final String topic;
  final InterviewDifficulty difficulty;
  final DateTime createdAt;
  final List<InterviewTurn> turns;
  final InterviewReport report;

  const InterviewSession({
    this.id = '',
    required this.topic,
    required this.difficulty,
    required this.createdAt,
    required this.turns,
    required this.report,
  });

  Map<String, dynamic> toMap() => {
    'topic': topic,
    'difficulty': difficulty.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'turns': turns.map((t) => t.toMap()).toList(),
    'report': report.toMap(),
  };

  factory InterviewSession.fromMap(String id, Map<String, dynamic> map) {
    final created = map['createdAt'];
    return InterviewSession(
      id: id,
      topic: map['topic'] as String? ?? 'Interview',
      difficulty: InterviewDifficulty.fromName(map['difficulty'] as String?),
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      turns: (map['turns'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((t) => InterviewTurn.fromMap(Map<String, dynamic>.from(t)))
          .toList(),
      report: InterviewReport.fromMap(
        (map['report'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

// ─── Stats for the Interview tab ───────────────────────────────────────────────
class InterviewStats {
  final int sessions;
  final int? averageScore;
  final String? bestTopic;

  const InterviewStats({
    required this.sessions,
    this.averageScore,
    this.bestTopic,
  });

  factory InterviewStats.from(List<InterviewSession> sessions) {
    if (sessions.isEmpty) return const InterviewStats(sessions: 0);

    final total = sessions.fold<int>(
      0,
      (acc, s) => acc + s.report.overallScore,
    );

    final byTopic = <String, List<int>>{};
    for (final s in sessions) {
      byTopic.putIfAbsent(s.topic, () => []).add(s.report.overallScore);
    }
    String? best;
    var bestAverage = -1.0;
    byTopic.forEach((topic, scores) {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      if (avg > bestAverage) {
        bestAverage = avg;
        best = topic;
      }
    });

    return InterviewStats(
      sessions: sessions.length,
      averageScore: (total / sessions.length).round(),
      bestTopic: best,
    );
  }
}

List<String> _stringList(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
}
