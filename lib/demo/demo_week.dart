import 'package:flutter/material.dart';

enum QuestKind { konu, test, video, deneme }

class Quest {
  Quest({
    required this.lesson,
    required this.title,
    required this.kind,
    required this.color,
    this.lessonId,
  });

  final String lesson;
  final String title;
  final QuestKind kind;
  final Color color;
  final int? lessonId;
  bool done = false;
  String note = '';
  int seconds = 0;

  String get kindLabel => switch (kind) {
        QuestKind.konu => 'Konu',
        QuestKind.test => 'Test',
        QuestKind.video => 'Video',
        QuestKind.deneme => 'Deneme',
      };
}

class DayPlan {
  DayPlan({required this.quests});

  final List<Quest> quests;

  int get doneCount => quests.where((quest) => quest.done).length;
}

class LessonMission {
  LessonMission({
    required this.subject,
    required this.source,
    this.videoName,
    this.videoUrl,
    this.videoSource = 1,
    this.videoOrder,
    this.teacher,
    this.isVideo = false,
    this.id,
    this.subjectId,
  });

  final String subject;
  final String source;
  final String? videoName;
  final String? videoUrl;
  final int videoSource;
  final int? videoOrder;
  final String? teacher;
  final bool isVideo;
  final int? id;
  final int? subjectId;
  bool done = false;
}

class DemoMissions {
  static final _cache = <String, List<LessonMission>>{};

  static List<LessonMission> of(String lesson) {
    return _cache.putIfAbsent(lesson, () => _seed(lesson));
  }

  static List<LessonMission> _seed(String lesson) {
    final rows = _bank[lesson] ??
        [
          (subject: '$lesson tekrarı', source: lesson, video: '$lesson videosu', channel: 1),
          (subject: '$lesson soruları', source: 'Soru bankası', video: '$lesson soru çözümü', channel: 1),
          (subject: '$lesson pekiştirme', source: 'Orijinal', video: '$lesson özet', channel: 2),
        ];
    return [
      for (final row in rows)
        LessonMission(
          subject: row.subject,
          source: row.source,
          videoName: row.video,
          videoSource: row.channel,
          videoOrder: rows.indexOf(row) + 1,
          isVideo: true,
        ),
    ];
  }

  static const _bank = <String, List<({String subject, String source, String video, int channel})>>{
    'Matematik': [
      (subject: 'Fonksiyonlar', source: '3D Matematik', video: 'Fonksiyonlara giriş', channel: 1),
      (subject: 'Polinomlar', source: '3D Matematik', video: 'Polinomlar 1', channel: 1),
      (subject: 'Problemler', source: 'Orijinal', video: 'Problem çözümü', channel: 2),
      (subject: 'İkinci derece', source: 'Orijinal', video: 'Parabol', channel: 2),
    ],
    'Fizik': [
      (subject: 'Kuvvet ve hareket', source: '3D Fizik', video: 'Newton yasaları', channel: 1),
      (subject: 'Elektrik', source: '3D Fizik', video: 'Akım ve direnç', channel: 1),
      (subject: 'Optik', source: 'Orijinal', video: 'Aynalar', channel: 2),
    ],
    'Türkçe': [
      (subject: 'Paragraf', source: 'Paragraf denemesi', video: 'Ana fikir', channel: 1),
      (subject: 'Dil bilgisi', source: 'Soru bankası', video: 'Fiilimsi', channel: 1),
      (subject: 'Anlam bilgisi', source: 'Orijinal', video: 'Sözcükte anlam', channel: 2),
    ],
    'Geometri': [
      (subject: 'Üçgenler', source: '3D Geometri', video: 'Üçgende açılar', channel: 1),
      (subject: 'Dörtgenler', source: 'Orijinal', video: 'Özel dörtgenler', channel: 2),
    ],
    'Kimya': [
      (subject: 'Mol', source: '3D Kimya', video: 'Mol kavramı', channel: 1),
      (subject: 'Asit ve baz', source: 'Orijinal', video: 'pH', channel: 2),
    ],
    'Biyoloji': [
      (subject: 'Hücre', source: '3D Biyoloji', video: 'Organeller', channel: 1),
      (subject: 'Sistemler', source: 'Orijinal', video: 'Dolaşım', channel: 2),
    ],
    'Tarih': [
      (subject: 'İnkılap', source: 'Soru bankası', video: 'Atatürk ilkeleri', channel: 1),
      (subject: 'Osmanlı', source: 'Orijinal', video: 'Duraklama', channel: 2),
    ],
    'Edebiyat': [
      (subject: 'Şiir', source: 'Soru bankası', video: 'Şiir bilgisi', channel: 1),
      (subject: 'Roman', source: 'Orijinal', video: 'Tanzimat romanı', channel: 2),
    ],
    'Deneme': [
      (subject: 'TYT genel', source: 'Deneme kulübü', video: 'TYT analiz', channel: 1),
      (subject: 'Branş fizik', source: 'Ders denemesi', video: 'Fizik deneme', channel: 2),
    ],
    'Genel': [
      (subject: 'Haftalık tekrar', source: 'Program', video: 'Haftanın özeti', channel: 1),
    ],
  };
}

class DemoWeek {
  static const shortDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const fullDays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static const math = Color(0xFF2F6FE0);
  static const physics = Color(0xFF1A9B8E);
  static const turkish = Color(0xFFE09A3E);
  static const chemistry = Color(0xFF6B5BD2);
  static const biology = Color(0xFF3C9D5A);
  static const exam = Color(0xFFE10600);
  static const history = Color(0xFF3E6B9A);

  static List<DayPlan> build() {
    return [
      DayPlan(quests: [
        Quest(lesson: 'Matematik', title: 'Fonksiyonlar', kind: QuestKind.konu, color: math),
        Quest(lesson: 'Fizik', title: '20 soru', kind: QuestKind.test, color: physics),
        Quest(lesson: 'Türkçe', title: 'Paragraf videosu', kind: QuestKind.video, color: turkish),
      ]),
      DayPlan(quests: [
        Quest(lesson: 'Geometri', title: 'Üçgenler', kind: QuestKind.konu, color: math),
        Quest(lesson: 'Kimya', title: '15 soru', kind: QuestKind.test, color: chemistry),
        Quest(lesson: 'Biyoloji', title: 'Hücre videosu', kind: QuestKind.video, color: biology),
        Quest(lesson: 'Tarih', title: '10 soru', kind: QuestKind.test, color: history),
      ]),
      DayPlan(quests: [
        Quest(lesson: 'Matematik', title: 'Problemler', kind: QuestKind.konu, color: math),
        Quest(lesson: 'Fizik', title: 'TYT branş', kind: QuestKind.deneme, color: exam),
        Quest(lesson: 'Edebiyat', title: 'Şiir', kind: QuestKind.konu, color: turkish),
        Quest(lesson: 'Kimya', title: 'Mol videosu', kind: QuestKind.video, color: chemistry),
      ]),
      DayPlan(quests: [
        Quest(lesson: 'Türkçe', title: 'Dil bilgisi', kind: QuestKind.konu, color: turkish),
        Quest(lesson: 'Matematik', title: '30 soru', kind: QuestKind.test, color: math),
        Quest(lesson: 'Biyoloji', title: 'Sistemler', kind: QuestKind.konu, color: biology),
      ]),
      DayPlan(quests: [
        Quest(lesson: 'Deneme', title: 'TYT optik', kind: QuestKind.deneme, color: exam),
        Quest(lesson: 'Fizik', title: 'Elektrik', kind: QuestKind.konu, color: physics),
        Quest(lesson: 'Geometri', title: '12 soru', kind: QuestKind.test, color: math),
      ]),
      DayPlan(quests: [
        Quest(lesson: 'Matematik', title: 'Tekrar videosu', kind: QuestKind.video, color: math),
        Quest(lesson: 'Türkçe', title: '20 soru', kind: QuestKind.test, color: turkish),
      ]),
      DayPlan(quests: [
        Quest(lesson: 'Genel', title: 'Haftalık tekrar', kind: QuestKind.konu, color: history),
      ]),
    ];
  }
}
