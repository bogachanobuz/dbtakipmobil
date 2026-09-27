import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../demo/demo_week.dart';
import '../theme/db_theme.dart';

class SiteSession {
  SiteSession._();

  static final SiteSession instance = SiteSession._();
  static const liveKey = 'live_session_v1';
  static const origin = 'https://test.dbtakip.com';

  Dio? _dio;
  PersistCookieJar? _jar;
  Map<String, List<LessonMission>>? _missions;
  Map<String, dynamic>? _rawMissions;

  Future<Dio> _client() async {
    if (_dio != null) return _dio!;
    final dir = await getApplicationDocumentsDirectory();
    final jar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${dir.path}/site_cookies_test'),
    );
    final dio = Dio(
      BaseOptions(
        baseUrl: origin,
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (code) => code != null && code < 500,
        headers: const {
          'Accept': 'text/html, application/json',
        },
      ),
    );
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final cookies = await jar.loadForRequest(Uri.parse(origin));
          for (final cookie in cookies) {
            if (cookie.name != 'XSRF-TOKEN') continue;
            options.headers['X-XSRF-TOKEN'] = Uri.decodeComponent(cookie.value);
          }
          handler.next(options);
        },
      ),
    );
    _jar = jar;
    _dio = dio;
    return dio;
  }

  Future<void> clear() async {
    _missions = null;
    _rawMissions = null;
    final jar = _jar;
    if (jar != null) await jar.deleteAll();
  }

  Future<String?> login(String email, String password) async {
    final dio = await _client();
    final page = await dio.get<String>(
      '/tr/login',
      options: Options(responseType: ResponseType.plain, headers: {'Accept': 'text/html'}),
    );
    final html = page.data ?? '';
    final token = _csrf(html);
    if (token == null) return 'Giriş sayfası açılmadı.';

    final captcha = await dio.get<Map<String, dynamic>>('/login/captcha');
    final question = captcha.data?['question']?.toString() ?? '';
    final answer = _solve(question);
    if (answer == null) return 'Güvenlik sorusu okunamadı.';

    final res = await dio.post<String>(
      '/userdologin',
      data: {
        '_token': token,
        'email': email,
        'password': password,
        'captcha': '$answer',
        'kvkk_aydinlatma': '1',
        'lang_code': 'tr',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        followRedirects: false,
        headers: {'Accept': 'text/html'},
      ),
    );
    final target = _location(res);
    if (target.contains('waitingConfirmation')) {
      return 'Hesap henüz onaylanmamış.';
    }
    if (target.contains('/admin') || target.contains('parent')) {
      await clear();
      return 'Bu giriş öğrenci hesabı değil.';
    }
    if (res.statusCode == 419) {
      return 'Sayfa süresi doldu. Bir kez daha dene.';
    }
    if (target.contains('/login') || target.contains('userdologin')) {
      final again = await dio.get<String>(
        '/tr/login',
        options: Options(responseType: ResponseType.plain, headers: {'Accept': 'text/html'}),
      );
      return _loginError(again.data ?? '') ?? 'Kullanıcı adı veya şifre hatalı.';
    }
    _missions = null;
    _rawMissions = null;
    return null;
  }

  String _location(Response<dynamic> res) {
    final raw = res.headers.value('location');
    if (raw == null || raw.isEmpty) return res.realUri.path;
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    return uri.hasScheme ? uri.path : Uri.parse(origin).resolve(raw).path;
  }

  Future<List<DayPlan>> weekly() async {
    final dio = await _client();
    var res = await dio.post<dynamic>(
      '/student/getWeeklySchedule',
      options: Options(headers: {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'}),
    );
    if (res.statusCode == 419) {
      await dio.get<String>(
        '/tr/login',
        options: Options(responseType: ResponseType.plain, headers: {'Accept': 'text/html'}),
      );
      res = await dio.post<dynamic>('/student/getWeeklySchedule');
    }
    final data = res.data;
    if (data is! Map) {
      throw SiteException('Program alınamadı. Oturum kapanmış olabilir.');
    }
    if (data['status'] != 1) {
      throw SiteException(data['error']?.toString() ?? 'Program bulunamadı.');
    }
    final days = data['days'];
    if (days is! List) throw SiteException('Çizelge boş geldi.');
    _missions = null;
    _rawMissions = null;
    unawaited(missionsFor(null));
    final plans = [
      for (final day in days)
        if (day is Map) _day(day),
    ];
    while (plans.length < 7) {
      plans.add(DayPlan(quests: []));
    }
    return plans.take(7).toList();
  }

  Future<ReportBoard> reportBoard() async {
    _missions ??= await _fetchMissions();
    return ReportBoard.fromRaw(_rawMissions ?? {});
  }

  Future<List<LessonMission>> missionsFor(int? lessonId) async {
    _missions ??= await _fetchMissions();
    if (lessonId == null) return const [];
    return _missions!['$lessonId'] ?? const [];
  }

  Future<Map<String, List<LessonMission>>> _fetchMissions() async {
    final dio = await _client();
    final res = await dio.get<dynamic>(
      '/student/ProgramDraft/getAllMissionsData',
      options: Options(headers: {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'}),
    );
    final data = res.data;
    if (data is! Map) return {};
    final raw = data['allMissionsData'];
    if (raw is! Map) return {};
    _rawMissions = Map<String, dynamic>.from(raw);
    return {
      for (final entry in raw.entries)
        entry.key.toString(): [
          if (entry.value is List)
            for (final item in entry.value as List)
              if (item is Map) _mission(item),
        ],
    };
  }

  DayPlan _day(Map day) {
    final lessons = day['lessons'];
    return DayPlan(
      quests: [
        if (lessons is List)
          for (final lesson in lessons)
            if (lesson is Map) _quest(lesson),
      ],
    );
  }

  Quest _quest(Map lesson) {
    final type = lesson['material_type']?.toString() ?? '';
    final kind = switch (type) {
      'video' => QuestKind.video,
      'test' => QuestKind.test,
      'exam' || 'deneme' => QuestKind.deneme,
      _ => lesson['is_video'] == true ? QuestKind.video : QuestKind.konu,
    };
    final subject = lesson['subject_name']?.toString().trim() ?? '';
    final next = lesson['next_mission'];
    final nextName = next is Map ? next['subject_name']?.toString().trim() ?? '' : '';
    final title = subject.isNotEmpty
        ? subject
        : (nextName.isNotEmpty ? nextName : (lesson['course']?.toString() ?? 'Görev'));
    final id = lesson['lesson_id'];
    final quest = Quest(
      lesson: lesson['lesson_name']?.toString() ?? 'Ders',
      title: title,
      kind: kind,
      color: _color(lesson['lesson_color']?.toString()),
      lessonId: id is int ? id : int.tryParse('$id'),
    );
    quest.done = lesson['completed'] == true || lesson['completed'] == 1 || lesson['completed'] == '1';
    return quest;
  }

  LessonMission _mission(Map item) {
    final sourceIndex = item['resource_source_index'];
    final parsed = sourceIndex is int ? sourceIndex : int.tryParse('$sourceIndex');
    final mission = LessonMission(
      subject: _text(item['subject_name'], fallback: 'Konu'),
      source: _text(item['material_name'], fallback: _text(item['class_level_name'], fallback: 'Kaynak')),
      videoName: _nullable(item['video_name']),
      videoSource: parsed == null || parsed <= 0 ? 1 : parsed,
    );
    mission.done = item['completed'] == true || item['completed'] == 1 || item['completed'] == '1';
    return mission;
  }

  String? _csrf(String html) {
    final named = RegExp('name="_token" value="([^"]+)"').firstMatch(html);
    if (named != null) return named.group(1);
    return RegExp('value="([^"]+)" name="_token"').firstMatch(html)?.group(1);
  }

  int? _solve(String question) {
    final match = RegExp(r'(\d+)\s*([+\-])\s*(\d+)').firstMatch(question);
    if (match == null) return null;
    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(3)!);
    return match.group(2) == '+' ? a + b : a - b;
  }

  String? _loginError(String html) {
    final match = RegExp(
      r'class="alert-error-custom"[^>]*>[\s\S]*?<span>(.*?)</span>',
    ).firstMatch(html);
    final text = match?.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String _text(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Color _color(String? hex) {
    if (hex == null || hex.isEmpty) return DbColors.navy;
    var raw = hex.replaceAll('#', '');
    if (raw.length == 6) raw = 'FF$raw';
    final value = int.tryParse(raw, radix: 16);
    if (value == null) return DbColors.navy;
    return Color(value);
  }
}

class ReportTopic {
  const ReportTopic({required this.name, required this.source, required this.done});

  final String name;
  final String source;
  final bool done;
}

class ReportLesson {
  ReportLesson({required this.name, required this.color, required this.topics});

  final String name;
  final Color color;
  final List<ReportTopic> topics;

  int get total => topics.length;
  int get done => topics.where((topic) => topic.done).length;
  bool get finished => total > 0 && done == total;
}

class ReportBoard {
  const ReportBoard(this.lessons);

  final List<ReportLesson> lessons;

  int get total => lessons.fold(0, (sum, lesson) => sum + lesson.total);
  int get done => lessons.fold(0, (sum, lesson) => sum + lesson.done);

  factory ReportBoard.demo() {
    final byName = <String, ReportLesson>{};
    for (final day in DemoWeek.build()) {
      for (final quest in day.quests) {
        byName.putIfAbsent(
          quest.lesson,
          () => ReportLesson(
            name: quest.lesson,
            color: quest.color,
            topics: [
              for (final mission in DemoMissions.of(quest.lesson))
                ReportTopic(name: mission.subject, source: mission.source, done: mission.done),
            ],
          ),
        );
      }
    }
    final lessons = byName.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return ReportBoard(lessons);
  }

  factory ReportBoard.fromRaw(Map<String, dynamic> raw) {
    final grouped = <String, List<ReportTopic>>{};
    final colors = <String, Color>{};
    for (final entry in raw.values) {
      if (entry is! List) continue;
      for (final item in entry) {
        if (item is! Map) continue;
        if (_isExtra(item['ek_gorev'])) continue;
        final name = item['lesson_name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final subject = item['subject_name']?.toString().trim() ?? '';
        final source = item['material_name']?.toString().trim() ?? '';
        grouped.putIfAbsent(name, () => []).add(
          ReportTopic(
            name: subject.isEmpty ? (source.isEmpty ? 'Görev' : source) : subject,
            source: source,
            done: item['completed'] == true || item['completed'] == 1 || item['completed'] == '1',
          ),
        );
        colors.putIfAbsent(name, () => _parseColor(item['lesson_bgcolor']?.toString()));
      }
    }
    final lessons = [
      for (final name in grouped.keys.toList()..sort())
        ReportLesson(name: name, color: colors[name] ?? DbColors.navy, topics: grouped[name]!),
    ];
    return ReportBoard(lessons);
  }
}

bool _isExtra(dynamic value) => value == true || value == 1 || value == '1';

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return DbColors.navy;
  var raw = hex.replaceAll('#', '');
  if (raw.length == 6) raw = 'FF$raw';
  final value = int.tryParse(raw, radix: 16);
  if (value == null) return DbColors.navy;
  return Color(value);
}

class SiteException implements Exception {
  SiteException(this.message);

  final String message;

  @override
  String toString() => message;
}
