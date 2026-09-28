import 'package:flutter/material.dart';

class ErrorSubject {
  const ErrorSubject({required this.id, required this.name});

  final int id;
  final String name;

  factory ErrorSubject.fromJson(Map<dynamic, dynamic> json) {
    return ErrorSubject(id: _int(json['id']) ?? 0, name: '${json['name'] ?? ''}'.trim());
  }
}

class ErrorLesson {
  const ErrorLesson({
    required this.name,
    required this.color,
    required this.subjects,
    this.id,
    this.customId,
    this.isCustom = false,
  });

  final int? id;
  final int? customId;
  final bool isCustom;
  final String name;
  final Color color;
  final List<ErrorSubject> subjects;

  String get key => name.isEmpty ? '__other__' : name;

  factory ErrorLesson.fromJson(Map<dynamic, dynamic> json) {
    final subjects = json['subjects'];
    return ErrorLesson(
      id: _int(json['id']),
      customId: _int(json['custom_id']),
      isCustom: json['is_custom'] == true || json['is_custom'] == 1,
      name: '${json['name'] ?? ''}'.trim(),
      color: _color(json['bgcolor']?.toString()),
      subjects: subjects is List
          ? [
              for (final item in subjects)
                if (item is Map) ErrorSubject.fromJson(item),
            ].where((item) => item.id > 0 && item.name.isNotEmpty).toList()
          : const [],
    );
  }
}

class ErrorKaynak {
  const ErrorKaynak({
    required this.kind,
    required this.name,
    this.id,
    this.questionBankId,
    this.questionBankName,
    this.denemeId,
    this.total = 0,
    this.unsolved = 0,
  });

  final String kind;
  final String name;
  final int? id;
  final int? questionBankId;
  final String? questionBankName;
  final int? denemeId;
  final int total;
  final int unsolved;

  String get countLabel {
    if (total == 0) return 'Henüz soru yok';
    if (unsolved == 0) return 'Hepsi çözüldü · $total soru';
    return '$unsolved çözülmedi · $total soru';
  }
}

class ErrorQuestion {
  ErrorQuestion({
    required this.id,
    required this.lessonKey,
    required this.solved,
    this.lessonId,
    this.subjectId,
    this.subjectName,
    this.imagePath,
    this.correctAnswer,
    this.difficulty,
    this.difficultyLabel,
    this.kaynakId,
    this.questionBankId,
    this.questionBankName,
    this.denemeId,
    this.source,
    this.questionText,
    this.questionNo,
    this.optikStatus,
    this.errorReasonLabel,
    this.correctSolutionNote,
    this.mistakeNote,
    this.studentAnswer,
    this.mastered = false,
    this.dueReview = false,
    this.retentionStage = 0,
    this.createdAt,
    this.solutionSketchPath,
    this.daysLeft,
    this.options = const ['A', 'B', 'C', 'D', 'E'],
  });

  final int id;
  final String lessonKey;
  final int? lessonId;
  final int? subjectId;
  final String? subjectName;
  final String? imagePath;
  final String? correctAnswer;
  final String? difficulty;
  final String? difficultyLabel;
  bool solved;
  final int? kaynakId;
  final int? questionBankId;
  final String? questionBankName;
  final int? denemeId;
  final String? source;
  final String? questionText;
  final int? questionNo;
  final String? optikStatus;
  final String? errorReasonLabel;
  String? correctSolutionNote;
  String? mistakeNote;
  String? studentAnswer;
  bool mastered;
  bool dueReview;
  int retentionStage;
  final String? createdAt;
  String? solutionSketchPath;
  final int? daysLeft;
  final List<String> options;

  int get retentionFilled {
    if (mastered) return 3;
    if (retentionStage <= 0) return 0;
    if (retentionStage == 1) return 1;
    if (retentionStage == 2) return 2;
    return 3;
  }

  bool get due => !mastered && dueReview;

  String get preview {
    final text = questionText?.trim() ?? '';
    if (text.isNotEmpty) return text.length > 120 ? text.substring(0, 120) : text;
    if (questionNo != null) {
      final bank = questionBankName;
      return 'Soru $questionNo${bank == null ? '' : ' · $bank'}';
    }
    return 'Fotoğraflı soru';
  }

  String? get originLine {
    final parts = <String>[];
    if (source == 'deneme') {
      parts.add('Deneme');
    } else if (source == 'optik') {
      parts.add('Optik');
    }
    if (questionNo != null) parts.add('Soru $questionNo');
    if (questionBankName != null) parts.add(questionBankName!);
    if (optikStatus == 'empty') {
      parts.add('Boş');
    } else if (optikStatus == 'wrong') {
      parts.add('Yanlış');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  void applyReview(Map<dynamic, dynamic> data) {
    if (data['is_solved'] != null) solved = _flag(data['is_solved']);
    final stage = _int(data['retention_stage']);
    if (stage != null) retentionStage = stage;
    if (data['is_mastered'] != null) mastered = _flag(data['is_mastered']);
    if (data['is_due_review'] != null) dueReview = _flag(data['is_due_review']);
    if (data.containsKey('student_answer')) studentAnswer = _text(data['student_answer']);
    if (data.containsKey('correct_solution_note')) correctSolutionNote = _text(data['correct_solution_note']);
    if (data.containsKey('mistake_note')) mistakeNote = _text(data['mistake_note']);
  }

  factory ErrorQuestion.fromJson(Map<dynamic, dynamic> json) {
    final lesson = json['lesson'];
    final lessonName = '${json['lesson_name'] ?? ''}'.trim().isNotEmpty
        ? '${json['lesson_name']}'.trim()
        : (lesson is Map ? '${lesson['name'] ?? ''}'.trim() : '');
    final cropped = '${json['cropped_image_path'] ?? ''}'.trim();
    final image = '${json['image_path'] ?? ''}'.trim();
    return ErrorQuestion(
      id: _int(json['id']) ?? 0,
      lessonKey: lessonName.isEmpty ? '__other__' : lessonName,
      lessonId: _int(json['lesson_id']),
      subjectId: _int(json['subject_id']),
      subjectName: _text(json['subject_name']),
      imagePath: cropped.isNotEmpty ? cropped : (image.isNotEmpty ? image : null),
      correctAnswer: _text(json['correct_answer']),
      difficulty: _text(json['difficulty']),
      difficultyLabel: _text(json['difficulty_label']),
      solved: _flag(json['is_solved']),
      kaynakId: _int(json['hata_defteri_kaynak_id']),
      questionBankId: _int(json['question_bank_id']),
      questionBankName: _text(json['question_bank_name']),
      denemeId: _int(json['deneme_id']),
      source: _text(json['source']),
      questionText: _text(json['question_text']),
      questionNo: _int(json['question_no']),
      optikStatus: _text(json['optik_status']),
      errorReasonLabel: _text(json['error_reason_label']),
      correctSolutionNote: _text(json['correct_solution_note']),
      mistakeNote: _text(json['mistake_note']),
      studentAnswer: _text(json['student_answer']),
      mastered: _flag(json['is_mastered']),
      dueReview: _flag(json['is_due_review']),
      retentionStage: _int(json['retention_stage']) ?? 0,
      createdAt: _text(json['created_at']),
      solutionSketchPath: _text(json['solution_sketch_path']),
      daysLeft: _int(json['days_left']),
      options: _options(json['options']),
    );
  }
}

class ErrorTrash {
  const ErrorTrash({required this.questions, required this.sources});

  final List<ErrorQuestion> questions;
  final List<ErrorTrashSource> sources;
}

class ErrorTrashSource {
  const ErrorTrashSource({required this.id, required this.name, required this.daysLeft});

  final int id;
  final String name;
  final int daysLeft;
}

class ErrorNamedImage {
  const ErrorNamedImage({required this.name, this.image});

  final String name;
  final String? image;
}

class ErrorNotebook {
  const ErrorNotebook({
    required this.questions,
    required this.kaynaklar,
    required this.customLessons,
    required this.banks,
    required this.denemeler,
    required this.trashCount,
  });

  final List<ErrorQuestion> questions;
  final List<ErrorSourceRow> kaynaklar;
  final List<ErrorLesson> customLessons;
  final Map<String, ErrorNamedImage> banks;
  final Map<String, ErrorNamedImage> denemeler;
  final int trashCount;

  List<ErrorQuestion> get dueQuestions => questions.where((item) => item.due).toList();

  factory ErrorNotebook.fromJson(Map<dynamic, dynamic> json) {
    final rows = json['data'];
    final sources = json['kaynaklar'];
    final customs = json['custom_lessons'];
    return ErrorNotebook(
      questions: rows is List
          ? [
              for (final item in rows)
                if (item is Map) ErrorQuestion.fromJson(item),
            ].where((item) => item.id > 0).toList()
          : const [],
      kaynaklar: sources is List
          ? [
              for (final item in sources)
                if (item is Map) ErrorSourceRow.fromJson(item),
            ].where((item) => item.id > 0 && item.name.isNotEmpty).toList()
          : const [],
      customLessons: _lessonList(customs),
      banks: _namedMap(json['question_bank_map']),
      denemeler: _namedMap(json['deneme_map']),
      trashCount: _int(json['trash_count']) ?? 0,
    );
  }

  List<ErrorLessonGroup> groups(List<ErrorLesson> catalog) {
    final map = <String, ErrorLessonGroup>{};
    for (final question in questions) {
      final group = map.putIfAbsent(question.lessonKey, () {
        final known = _match(catalog, question.lessonKey);
        return ErrorLessonGroup(
          key: question.lessonKey,
          name: question.lessonKey == '__other__' ? 'Diğer' : question.lessonKey,
          color: known?.color ?? const Color(0xFF4F46E5),
          isCustom: known?.isCustom ?? false,
          customId: known?.customId,
          lessonId: known?.id ?? question.lessonId,
        );
      });
      group.total++;
      if (!question.solved) group.unsolved++;
    }
    for (final custom in customLessons) {
      if (custom.name.isEmpty) continue;
      map.putIfAbsent(custom.name, () {
        return ErrorLessonGroup(
          key: custom.name,
          name: custom.name,
          color: custom.color,
          isCustom: true,
          customId: custom.customId,
          lessonId: null,
        );
      });
    }
    final list = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<ErrorKaynak> sourcesFor(ErrorLessonGroup lesson) {
    final rows = questions.where((item) => item.lessonKey == lesson.key).toList();
    final cards = <ErrorKaynak>[
      ErrorKaynak(
        kind: 'all',
        name: 'Tüm sorular',
        total: rows.length,
        unsolved: rows.where((item) => !item.solved).length,
      ),
    ];
    for (final kaynak in kaynaklar) {
      final sameId = lesson.lessonId != null && kaynak.lessonId != null && lesson.lessonId == kaynak.lessonId;
      final lessonName = kaynak.lessonName ?? '';
      final sameName = lessonName.isNotEmpty && (lessonName == lesson.name || lessonName == lesson.key);
      if (!sameId && !sameName) continue;
      final matched = rows.where((item) => item.kaynakId == kaynak.id).toList();
      cards.add(
        ErrorKaynak(
          kind: 'custom',
          id: kaynak.id,
          name: kaynak.name,
          total: matched.length,
          unsolved: matched.where((item) => !item.solved).length,
        ),
      );
    }
    final assigned = <String, List<ErrorQuestion>>{};
    for (final item in rows) {
      if (item.kaynakId != null) continue;
      if (item.denemeId != null || item.source == 'deneme') continue;
      String? key;
      if (item.questionBankId != null) {
        key = 'qb:${item.questionBankId}';
      } else if ((item.questionBankName ?? '').isNotEmpty) {
        key = 'qbn:${item.questionBankName}';
      } else if (item.source == 'optik') {
        key = 'optik';
      }
      if (key == null) continue;
      assigned.putIfAbsent(key, () => []).add(item);
    }
    final assignedKeys = assigned.keys.toList()..sort();
    for (final key in assignedKeys) {
      final sample = assigned[key]!.first;
      final bank = sample.questionBankId == null ? null : banks['${sample.questionBankId}'];
      final name = bank?.name ??
          sample.questionBankName ??
          (sample.questionBankId != null ? 'Kaynak #${sample.questionBankId}' : 'Optik kaynak');
      cards.add(
        ErrorKaynak(
          kind: 'assigned',
          name: name,
          questionBankId: sample.questionBankId,
          questionBankName: sample.questionBankName,
          total: assigned[key]!.length,
          unsolved: assigned[key]!.where((item) => !item.solved).length,
        ),
      );
    }
    final denemeRows = <String, List<ErrorQuestion>>{};
    for (final item in rows) {
      if (item.denemeId == null && item.source != 'deneme') continue;
      denemeRows.putIfAbsent('deneme:${item.denemeId ?? 0}', () => []).add(item);
    }
    final denemeKeys = denemeRows.keys.toList()..sort();
    for (final key in denemeKeys) {
      final sample = denemeRows[key]!.first;
      final meta = sample.denemeId == null ? null : denemeler['${sample.denemeId}'];
      cards.add(
        ErrorKaynak(
          kind: 'deneme',
          name: meta?.name ?? (sample.denemeId != null ? 'Deneme #${sample.denemeId}' : 'Deneme'),
          denemeId: sample.denemeId,
          total: denemeRows[key]!.length,
          unsolved: denemeRows[key]!.where((item) => !item.solved).length,
        ),
      );
    }
    return cards;
  }

  List<ErrorQuestion> questionsFor(String lessonKey, ErrorKaynak kaynak) {
    return questions.where((item) {
      if (item.lessonKey != lessonKey) return false;
      return switch (kaynak.kind) {
        'custom' => item.kaynakId == kaynak.id,
        'assigned' => item.kaynakId == null &&
            item.denemeId == null &&
            item.source != 'deneme' &&
            (kaynak.questionBankId != null
                ? item.questionBankId == kaynak.questionBankId
                : (kaynak.questionBankName ?? '').isNotEmpty
                    ? item.questionBankName == kaynak.questionBankName
                    : item.source == 'optik'),
        'deneme' => kaynak.denemeId != null
            ? item.denemeId == kaynak.denemeId
            : item.source == 'deneme' && item.denemeId == null,
        _ => true,
      };
    }).toList();
  }

  static List<ErrorLesson> _lessonList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) ErrorLesson.fromJson(item),
    ];
  }

  static Map<String, ErrorNamedImage> _namedMap(dynamic raw) {
    if (raw is! Map) return const {};
    final map = <String, ErrorNamedImage>{};
    raw.forEach((key, value) {
      if (value is! Map) return;
      final name = '${value['name'] ?? ''}'.trim();
      if (name.isEmpty) return;
      map['$key'] = ErrorNamedImage(name: name, image: _text(value['image']));
    });
    return map;
  }

  static ErrorLesson? _match(List<ErrorLesson> catalog, String key) {
    for (final lesson in catalog) {
      if (lesson.name == key) return lesson;
    }
    return null;
  }
}

class ErrorLessonGroup {
  ErrorLessonGroup({
    required this.key,
    required this.name,
    required this.color,
    required this.isCustom,
    this.customId,
    this.lessonId,
  });

  final String key;
  final String name;
  final Color color;
  final bool isCustom;
  final int? customId;
  final int? lessonId;
  var total = 0;
  var unsolved = 0;
}

class ErrorSourceRow {
  const ErrorSourceRow({
    required this.id,
    required this.name,
    this.lessonId,
    this.lessonName,
  });

  final int id;
  final String name;
  final int? lessonId;
  final String? lessonName;

  factory ErrorSourceRow.fromJson(Map<dynamic, dynamic> json) {
    return ErrorSourceRow(
      id: _int(json['id']) ?? 0,
      name: '${json['name'] ?? ''}'.trim(),
      lessonId: _int(json['lesson_id']),
      lessonName: _text(json['lesson_name']) ?? _text(json['lesson_key']),
    );
  }
}

bool _flag(dynamic value) => value == true || value == 1 || value == '1';

List<String> _options(dynamic raw) {
  if (raw is List) {
    final letters = [for (final item in raw) '$item'.trim().toUpperCase()].where((item) => item.isNotEmpty).toList();
    if (letters.isNotEmpty) return letters;
  }
  if (raw is Map && raw.isNotEmpty) {
    return raw.keys.map((key) => '$key'.trim().toUpperCase()).where((item) => item.isNotEmpty).toList();
  }
  return const ['A', 'B', 'C', 'D', 'E'];
}

int? _int(dynamic value) {
  if (value == null || value == false) return null;
  if (value is int) return value;
  return int.tryParse('$value');
}

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

Color _color(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF4F46E5);
  var raw = hex.replaceAll('#', '');
  if (raw.length == 6) raw = 'FF$raw';
  final value = int.tryParse(raw, radix: 16);
  return value == null ? const Color(0xFF4F46E5) : Color(value);
}
