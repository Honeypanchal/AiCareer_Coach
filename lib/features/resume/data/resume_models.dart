import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Score categories ──────────────────────────────────────────────────────────
// The overall score is a weighted average of these, worked out in the app so
// it stays consistent between checks.
class ResumeCategory {
  final String key;
  final String label;
  final int weight; // percent of the overall score
  final String rubric;

  const ResumeCategory(this.key, this.label, this.weight, this.rubric);

  static const all = [
    ResumeCategory(
      'formatting',
      'ATS & formatting',
      20,
      'Standard section headings, simple single-column layout, consistent dates and styling, readable length (1 page for under ~5 years experience, max 2), no tables/images/graphics that ATS parsers miss.',
    ),
    ResumeCategory(
      'impact',
      'Impact & achievements',
      25,
      'Bullets start with strong action verbs and show results, scope or numbers instead of listing duties.',
    ),
    ResumeCategory(
      'relevance',
      'Role match & keywords',
      25,
      'Skills, projects and experience match the target role (and job description if given); important role keywords are present.',
    ),
    ResumeCategory(
      'clarity',
      'Clarity & writing',
      15,
      'Concise, specific wording, no spelling or grammar mistakes, no filler or vague claims.',
    ),
    ResumeCategory(
      'completeness',
      'Completeness',
      15,
      'Has contact details (email, phone, location, LinkedIn/GitHub/portfolio where relevant), summary, skills, experience or projects, and education.',
    ),
  ];

  static ResumeCategory? byKey(String key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }
}

class CategoryScore {
  final String key;
  final int score; // 0–10
  final String comment;

  const CategoryScore({
    required this.key,
    required this.score,
    required this.comment,
  });

  String get label => ResumeCategory.byKey(key)?.label ?? key;

  Map<String, dynamic> toMap() => {
    'key': key,
    'score': score,
    'comment': comment,
  };

  factory CategoryScore.fromMap(Map<String, dynamic> map) => CategoryScore(
    key: map['key'] as String? ?? '',
    score: (map['score'] as num?)?.round().clamp(0, 10) ?? 0,
    comment: (map['comment'] as String?)?.trim() ?? '',
  );
}

enum ImprovementPriority {
  high('High'),
  medium('Medium'),
  low('Low');

  final String label;
  const ImprovementPriority(this.label);

  static ImprovementPriority fromName(String? name) =>
      ImprovementPriority.values.firstWhere(
        (p) => p.name == name,
        orElse: () => ImprovementPriority.medium,
      );
}

class ResumeImprovement {
  final ImprovementPriority priority;
  final String section;
  final String issue;
  final String suggestion;
  final String before; // exact text from the resume, may be empty
  final String after; // suggested rewrite, may be empty

  const ResumeImprovement({
    required this.priority,
    required this.section,
    required this.issue,
    required this.suggestion,
    this.before = '',
    this.after = '',
  });

  Map<String, dynamic> toMap() => {
    'priority': priority.name,
    'section': section,
    'issue': issue,
    'suggestion': suggestion,
    'before': before,
    'after': after,
  };

  factory ResumeImprovement.fromMap(Map<String, dynamic> map) =>
      ResumeImprovement(
        priority: ImprovementPriority.fromName(map['priority'] as String?),
        section: (map['section'] as String?)?.trim() ?? '',
        issue: (map['issue'] as String?)?.trim() ?? '',
        suggestion: (map['suggestion'] as String?)?.trim() ?? '',
        before: (map['before'] as String?)?.trim() ?? '',
        after: (map['after'] as String?)?.trim() ?? '',
      );
}

// ─── Analysis ──────────────────────────────────────────────────────────────────
// One resume check, as saved in users/{uid}/resumes.
class ResumeAnalysis {
  final String id;
  final String fileName;
  final String targetRole;
  final bool usedJobDescription;
  final DateTime createdAt;
  final String summary;
  final List<CategoryScore> categories;
  final List<String> strengths;
  final List<ResumeImprovement> improvements;
  final List<String> missingKeywords;
  final ImprovedResume? improvedResume;
  // Text of the uploaded resume, used to check the rewrite. Not saved.
  final String originalText;

  const ResumeAnalysis({
    this.id = '',
    required this.fileName,
    required this.targetRole,
    this.usedJobDescription = false,
    required this.createdAt,
    required this.summary,
    required this.categories,
    required this.strengths,
    required this.improvements,
    required this.missingKeywords,
    this.improvedResume,
    this.originalText = '',
  });

  /// Weighted average of the category scores, as a percentage.
  int get overallScore => overallScoreFor(categories);

  static int overallScoreFor(List<CategoryScore> categories) {
    var weighted = 0.0;
    var weights = 0;
    for (final category in ResumeCategory.all) {
      final match = categories.where((c) => c.key == category.key);
      if (match.isEmpty) continue;
      weighted += match.first.score * 10 * category.weight;
      weights += category.weight;
    }
    if (weights == 0) return 0;
    return (weighted / weights).round();
  }

  ResumeAnalysis copyWith({String? id, ImprovedResume? improvedResume}) {
    return ResumeAnalysis(
      id: id ?? this.id,
      fileName: fileName,
      targetRole: targetRole,
      usedJobDescription: usedJobDescription,
      createdAt: createdAt,
      summary: summary,
      categories: categories,
      strengths: strengths,
      improvements: improvements,
      missingKeywords: missingKeywords,
      improvedResume: improvedResume ?? this.improvedResume,
      originalText: originalText,
    );
  }

  Map<String, dynamic> toMap() => {
    'fileName': fileName,
    'targetRole': targetRole,
    'usedJobDescription': usedJobDescription,
    'createdAt': Timestamp.fromDate(createdAt),
    'overallScore': overallScore,
    'summary': summary,
    'categories': categories.map((c) => c.toMap()).toList(),
    'strengths': strengths,
    'improvements': improvements.map((i) => i.toMap()).toList(),
    'missingKeywords': missingKeywords,
    if (improvedResume != null) 'improvedResume': improvedResume!.toMap(),
  };

  factory ResumeAnalysis.fromMap(String id, Map<String, dynamic> map) {
    final created = map['createdAt'];
    final improved = map['improvedResume'];
    return ResumeAnalysis(
      id: id,
      fileName: map['fileName'] as String? ?? 'Resume',
      targetRole: map['targetRole'] as String? ?? '',
      usedJobDescription: map['usedJobDescription'] == true,
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      summary: map['summary'] as String? ?? '',
      categories: _maps(map['categories']).map(CategoryScore.fromMap).toList(),
      strengths: stringList(map['strengths']),
      improvements: _maps(
        map['improvements'],
      ).map(ResumeImprovement.fromMap).toList(),
      missingKeywords: stringList(map['missingKeywords']),
      improvedResume: improved is Map
          ? ImprovedResume.fromMap(Map<String, dynamic>.from(improved))
          : null,
    );
  }
}

// ─── Improved resume ───────────────────────────────────────────────────────────
// The rewritten resume content, turned into a PDF by resume_pdf.dart.
class ResumeEntry {
  final String title; // job title, degree or project name
  final String organization; // company, college or tech used
  final String location;
  final String period;
  final List<String> bullets;

  const ResumeEntry({
    required this.title,
    this.organization = '',
    this.location = '',
    this.period = '',
    this.bullets = const [],
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'organization': organization,
    'location': location,
    'period': period,
    'bullets': bullets,
  };

  factory ResumeEntry.fromMap(Map<String, dynamic> map) => ResumeEntry(
    title: (map['title'] as String?)?.trim() ?? '',
    organization: (map['organization'] as String?)?.trim() ?? '',
    location: (map['location'] as String?)?.trim() ?? '',
    period: (map['period'] as String?)?.trim() ?? '',
    bullets: stringList(map['bullets']),
  );
}

class ResumeListSection {
  final String title;
  final List<String> items;

  const ResumeListSection({required this.title, required this.items});

  Map<String, dynamic> toMap() => {'title': title, 'items': items};

  factory ResumeListSection.fromMap(Map<String, dynamic> map) =>
      ResumeListSection(
        title: (map['title'] as String?)?.trim() ?? '',
        items: stringList(map['items']),
      );
}

class ImprovedResume {
  final String name;
  final String headline;
  final List<String> contact; // email, phone, location, links
  final String summary;
  final List<ResumeListSection> skills; // grouped, e.g. "Languages: …"
  final List<ResumeEntry> experience;
  final List<ResumeEntry> projects;
  final List<ResumeEntry> education;
  final List<ResumeListSection> extraSections; // certifications, awards…
  final List<String> tips; // things the user should add themself

  const ImprovedResume({
    required this.name,
    this.headline = '',
    this.contact = const [],
    this.summary = '',
    this.skills = const [],
    this.experience = const [],
    this.projects = const [],
    this.education = const [],
    this.extraSections = const [],
    this.tips = const [],
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'headline': headline,
    'contact': contact,
    'summary': summary,
    'skills': skills.map((s) => s.toMap()).toList(),
    'experience': experience.map((e) => e.toMap()).toList(),
    'projects': projects.map((e) => e.toMap()).toList(),
    'education': education.map((e) => e.toMap()).toList(),
    'extraSections': extraSections.map((s) => s.toMap()).toList(),
    'tips': tips,
  };

  factory ImprovedResume.fromMap(Map<String, dynamic> map) => ImprovedResume(
    name: (map['name'] as String?)?.trim() ?? '',
    headline: (map['headline'] as String?)?.trim() ?? '',
    contact: stringList(map['contact']),
    summary: (map['summary'] as String?)?.trim() ?? '',
    skills: _maps(
      map['skills'],
    ).map(ResumeListSection.fromMap).where((s) => s.items.isNotEmpty).toList(),
    experience: _entries(map['experience']),
    projects: _entries(map['projects']),
    education: _entries(map['education']),
    extraSections: _maps(map['extraSections'])
        .map(ResumeListSection.fromMap)
        .where((s) => s.title.isNotEmpty && s.items.isNotEmpty)
        .toList(),
    tips: stringList(map['tips']),
  );

  static List<ResumeEntry> _entries(dynamic value) => _maps(value)
      .map(ResumeEntry.fromMap)
      .where((e) => e.title.isNotEmpty || e.organization.isNotEmpty)
      .toList();
}

List<String> stringList(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> _maps(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
}
