import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../demo/demo_week.dart';
import '../theme/db_theme.dart';
import 'error_book.dart';

class SiteSession {
  SiteSession._();

  static final SiteSession instance = SiteSession._();
  static const liveKey = 'live_session_v1';
  static const origin = 'https://test.dbtakip.com';
  static const files = 'https://dbtakip.com';

  Dio? _dio;
  PersistCookieJar? _jar;
  Map<String, List<LessonMission>>? _missions;
  Map<String, dynamic>? _rawMissions;
  Map<String, dynamic>? _videoPacks;
  StudentProfile? _profile;

  Future<Dio> _client() async {
    if (_dio != null) return _dio!;
    final dir = await getApplicationDocumentsDirectory();
    for (final name in ['site_cookies', 'site_cookies_test']) {
      final old = Directory('${dir.path}/$name');
      if (old.existsSync()) old.deleteSync(recursive: true);
    }
    final jar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${dir.path}/site_cookies_test_v2'),
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
          final cookies = await jar.loadForRequest(options.uri);
          final latest = <String, Cookie>{};
          for (final cookie in cookies) {
            latest[cookie.name] = cookie;
          }
          if (latest.isNotEmpty) {
            options.headers[HttpHeaders.cookieHeader] = latest.entries
                .map((entry) => '${entry.key}=${entry.value.value}')
                .join('; ');
          }
          final xsrf = latest['XSRF-TOKEN'];
          if (xsrf != null) {
            options.headers['X-XSRF-TOKEN'] = Uri.decodeComponent(xsrf.value);
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
    _videoPacks = null;
    _profile = null;
    final jar = _jar;
    if (jar != null) await jar.deleteAll();
  }

  Future<String?> login(String email, String password) async {
    final dio = await _client();
    await clear();
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
    await _keepResponseCookies(res);
    _missions = null;
    _rawMissions = null;
    _videoPacks = null;
    _profile = null;
    return null;
  }

  Future<StudentProfile?> profile() async {
    if (_profile != null) return _profile;
    final dio = await _client();
    final res = await dio.get<String>(
      '/student/settings',
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        headers: {'Accept': 'text/html'},
      ),
    );
    final html = res.data ?? '';
    if (res.statusCode != 200 || html.contains('action="/userdologin"')) return null;
    final first = _input(html, 'name');
    if (first == null || first.isEmpty) return null;
    _profile = StudentProfile(
      firstName: first.split(RegExp(r'\s+')).first,
      surname: _input(html, 'surname') ?? '',
      email: _input(html, 'email') ?? '',
      phone: _input(html, 'phone') ?? '',
      bio: _textarea(html, 'bio') ?? '',
    );
    return _profile;
  }

  Future<Map<String, dynamic>> reportPanel(int missionId, {bool showAll = false}) async {
    final dio = await _client();
    final res = await dio.post<dynamic>(
      '/student/report/getPanel',
      data: {'mission_id': missionId, 'show_all': showAll ? 1 : 0},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    final data = res.data;
    if (data is! Map) throw SiteException('Rapor paneli açılmadı.');
    if (data['status'] != 1) {
      throw SiteException(data['error']?.toString() ?? 'Rapor paneli açılmadı.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<String> saveReport(Map<String, dynamic> body) async {
    final dio = await _client();
    final res = await dio.post<dynamic>(
      '/student/report/save',
      data: body,
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    final data = res.data;
    if (data is! Map) throw SiteException('Rapor kaydedilemedi.');
    if (data['status'] != 1) {
      throw SiteException(data['error']?.toString() ?? 'Rapor kaydedilemedi.');
    }
    return data['message']?.toString() ?? 'Rapor kaydedildi.';
  }

  Future<void> _keepResponseCookies(Response<dynamic> res) async {
    final jar = _jar;
    if (jar == null) return;
    final fresh = _cookiesFrom(res);
    if (fresh.isEmpty) return;
    await jar.deleteAll();
    await jar.saveFromResponse(Uri.parse('$origin/'), fresh);
  }

  List<Cookie> _cookiesFrom(Response<dynamic> res) {
    final header = res.headers[HttpHeaders.setCookieHeader];
    if (header == null || header.isEmpty) return const [];
    final cookies = <Cookie>[];
    for (final line in header) {
      for (final part in line.split(RegExp(r',(?=[^;]+?=)'))) {
        final value = part.trim();
        if (value.isEmpty) continue;
        try {
          cookies.add(Cookie.fromSetCookieValue(value));
        } catch (_) {}
      }
    }
    return cookies;
  }

  Future<Response<dynamic>> _postSchedule(Dio dio) {
    return dio.post<dynamic>(
      '/student/getWeeklySchedule',
      options: Options(headers: {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'}),
    );
  }

  bool _sessionRejected(Response<dynamic> res) {
    if (res.statusCode == 401 || res.statusCode == 419) return true;
    return res.data is! Map;
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
    var res = await _postSchedule(dio);
    if (_sessionRejected(res)) {
      await _keepResponseCookies(res);
      res = await _postSchedule(dio);
    }
    final data = res.data;
    if (_sessionRejected(res)) {
      throw SiteException('Oturum kapanmış. Tekrar gir.');
    }
    if (data['status'] != 1) {
      throw SiteException(data['error']?.toString() ?? 'Program bulunamadı.');
    }
    final days = data['days'];
    if (days is! List) throw SiteException('Çizelge boş geldi.');
    _missions = null;
    _rawMissions = null;
    _videoPacks = null;
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
    return ReportBoard.fromRaw(_rawMissions ?? {}, _videoPacks);
  }

  String? videoSourceName(int? lessonId, int source) {
    if (lessonId == null || _videoPacks == null) return null;
    final pack = _videoPacks!['$lessonId'];
    if (pack is! Map) return null;
    final sources = pack['sources'];
    if (sources is! List) return null;
    for (final src in sources) {
      if (src is! Map) continue;
      final index = src['sourceIndex'];
      final parsed = index is int ? index : int.tryParse('$index');
      if (parsed != source) continue;
      final name = src['qbName']?.toString().trim() ?? '';
      if (name.isEmpty) return null;
      return name;
    }
    return null;
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
    final packs = data['resourceVideoOrderByLesson'];
    _videoPacks = packs is Map ? Map<String, dynamic>.from(packs) : {};
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
    final videoName = _nullable(item['video_name']);
    final videoUrl = _nullable(item['video_link']);
    final videoId = _num(item['video_link_id']);
    final flagged = _isExtra(item['is_video_mission']) || _isExtra(item['has_resource_video']) || videoId != null;
    final number = _num(item['video_number']) ?? _orderFrom(item['resource_video_order']);
    final mission = LessonMission(
      subject: _text(item['subject_name'], fallback: ''),
      source: _text(item['material_name'], fallback: _text(item['class_level_name'], fallback: 'Kaynak')),
      videoName: videoName,
      videoUrl: videoUrl,
      videoSource: parsed == null || parsed <= 0 ? 1 : parsed,
      videoOrder: number,
      teacher: _nullable(item['video_teacher_name']),
      isVideo: flagged || videoName != null || videoUrl != null,
      id: _num(item['id']),
      subjectId: _num(item['subject_id']),
    );
    mission.done = item['completed'] == true || item['completed'] == 1 || item['completed'] == '1';
    return mission;
  }

  int? _num(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value == 0 ? null : value;
    return int.tryParse(value.toString());
  }

  int? _orderFrom(dynamic value) {
    if (value == null) return null;
    final index = value is int ? value : int.tryParse(value.toString());
    if (index == null || index >= 999999) return null;
    return index + 1;
  }

  String? _input(String html, String field) {
    final patterns = [
      RegExp('name="$field" value="([^"]*)"'),
      RegExp('id="$field"[^>]*value="([^"]*)"'),
      RegExp('value="([^"]*)"[^>]*name="$field"'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) return _html(match.group(1) ?? '');
    }
    return null;
  }

  String? _textarea(String html, String field) {
    final match = RegExp('name="$field"[^>]*>([\\s\\S]*?)</textarea>').firstMatch(html);
    if (match == null) return null;
    return _html(match.group(1) ?? '');
  }

  String _html(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
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

  static String? storageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) {
      if (raw.contains('/storage/question_banks/')) {
        return raw.replaceFirst(RegExp(r'https?://[^/]+'), files);
      }
      return raw;
    }
    final path = raw.replaceFirst(RegExp(r'^/+'), '');
    final host = path.contains('question_banks/') ? files : origin;
    return '$host/storage/$path';
  }

  Future<ErrorNotebook> errorNotebook() async {
    final data = await _studentJson('/student/hata-defteri', 'Hata defteri açılmadı.');
    if (data['success'] != true) {
      throw SiteException(data['message']?.toString() ?? 'Hata defteri açılmadı.');
    }
    return ErrorNotebook.fromJson(data);
  }

  Future<List<ErrorLesson>> errorLessons() async {
    final data = await _studentJson('/student/hata-defteri/lessons', 'Dersler alınamadı.');
    if (data['success'] != true) {
      throw SiteException(data['message']?.toString() ?? 'Dersler alınamadı.');
    }
    final rows = data['data'];
    if (rows is! List) return const [];
    return [
      for (final item in rows)
        if (item is Map) ErrorLesson.fromJson(item),
    ].where((lesson) => lesson.name.isNotEmpty).toList();
  }

  Future<ErrorLesson> addCustomLesson(String name, String color) async {
    final dio = await _client();
    final res = await dio.post<dynamic>(
      '/student/hata-defteri/custom-lessons',
      data: {'name': name, 'bgcolor': color},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: const {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    final data = _asJson(res, 'Özel ders eklenemedi.');
    if (data['success'] != true || data['data'] is! Map) {
      throw SiteException(_apiMessage(data, 'Özel ders eklenemedi.'));
    }
    return ErrorLesson.fromJson(data['data'] as Map);
  }

  Future<String> saveErrorQuestion({
    required String imagePath,
    required String correctAnswer,
    required String difficulty,
    int? lessonId,
    String? lessonName,
    int? subjectId,
    String? subjectName,
    int? kaynakId,
    int? questionBankId,
    String? questionBankName,
    int? denemeId,
  }) async {
    final dio = await _client();
    final form = FormData.fromMap({
      'image_file': await MultipartFile.fromFile(imagePath, filename: 'question.jpg'),
      'correct_answer': correctAnswer,
      'difficulty': difficulty,
      'lesson_id': ?lessonId,
      if (lessonName != null && lessonName.isNotEmpty) 'lesson_name': lessonName,
      'subject_id': ?subjectId,
      if (subjectName != null && subjectName.isNotEmpty) 'subject_name': subjectName,
      'hata_defteri_kaynak_id': ?kaynakId,
      'question_bank_id': ?questionBankId,
      if (questionBankName != null && questionBankName.isNotEmpty) 'question_bank_name': questionBankName,
      'deneme_id': ?denemeId,
    });
    final res = await dio.post<dynamic>(
      '/student/hata-defteri',
      data: form,
      options: Options(
        headers: const {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    final data = _asJson(res, 'Soru kaydedilemedi.');
    if (data['success'] != true) {
      throw SiteException(_apiMessage(data, 'Soru kaydedilemedi.'));
    }
    return data['message']?.toString() ?? 'Soru başarıyla kaydedildi.';
  }

  Future<Map<String, dynamic>> checkErrorAnswer(int id, String answer) async {
    return _errorPost('/student/hata-defteri/$id/check-answer', {'answer': answer}, 'Cevap kontrol edilemedi.');
  }

  Future<Map<String, dynamic>> toggleErrorSolved(int id) async {
    return _errorPost('/student/hata-defteri/$id/toggle-solved', const {}, 'Durum değiştirilemedi.');
  }

  Future<String> saveErrorNotes(int id, {String? correctNote, String? mistakeNote}) async {
    final data = await _errorPost('/student/hata-defteri/$id/notes', {
      'correct_solution_note': correctNote ?? '',
      'mistake_note': mistakeNote ?? '',
    }, 'Notlar kaydedilemedi.');
    return data['message']?.toString() ?? 'Notlar kaydedildi.';
  }

  Future<String> saveErrorSketch(int id, String filePath) async {
    final dio = await _client();
    final form = FormData.fromMap({
      'sketch_file': await MultipartFile.fromFile(filePath, filename: 'sketch.png'),
    });
    final res = await dio.post<dynamic>(
      '/student/hata-defteri/$id/save-solution-sketch',
      data: form,
      options: Options(
        headers: const {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    final data = _asJson(res, 'Çözüm karalaması kaydedilemedi.');
    if (data['success'] != true) {
      throw SiteException(_apiMessage(data, 'Çözüm karalaması kaydedilemedi.'));
    }
    final path = data['solution_sketch_path']?.toString().trim() ?? '';
    if (path.isEmpty) throw SiteException('Çözüm karalaması kaydedilemedi.');
    return path;
  }

  Future<int> deleteErrorQuestion(int id) async {
    final data = await _errorDelete('/student/hata-defteri/$id', 'Soru silinemedi.');
    return _asInt(data['trash_count']) ?? 0;
  }

  Future<ErrorTrash> errorTrash() async {
    final data = await _studentJson('/student/hata-defteri/trash', 'Çöp kutusu açılmadı.');
    if (data['success'] != true) {
      throw SiteException(data['message']?.toString() ?? 'Çöp kutusu açılmadı.');
    }
    final questions = data['questions'];
    final kaynaklar = data['kaynaklar'];
    return ErrorTrash(
      questions: questions is List
          ? [
              for (final item in questions)
                if (item is Map) ErrorQuestion.fromJson(item),
            ].where((item) => item.id > 0).toList()
          : const [],
      sources: kaynaklar is List
          ? [
              for (final item in kaynaklar)
                if (item is Map)
                  ErrorTrashSource(
                    id: _asInt(item['id']) ?? 0,
                    name: item['name']?.toString() ?? 'Kaynak',
                    daysLeft: _asInt(item['days_left']) ?? 0,
                  ),
            ].where((item) => item.id > 0).toList()
          : const [],
    );
  }

  Future<String> restoreErrorQuestion(int id) async {
    final data = await _errorPost('/student/hata-defteri/$id/restore', const {}, 'Soru geri alınamadı.');
    return data['message']?.toString() ?? 'Soru geri alındı.';
  }

  Future<String> restoreErrorSource(int id) async {
    final data = await _errorPost('/student/hata-defteri/kaynaklar/$id/restore', const {}, 'Kaynak geri alınamadı.');
    return data['message']?.toString() ?? 'Kaynak geri alındı.';
  }

  Future<Map<String, dynamic>> _errorPost(String path, Map<String, dynamic> body, String fallback) async {
    final dio = await _client();
    final res = await dio.post<dynamic>(
      path,
      data: body,
      options: Options(
        contentType: Headers.jsonContentType,
        headers: const {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    final data = _asJson(res, fallback);
    if (data['success'] != true) throw SiteException(_apiMessage(data, fallback));
    return data;
  }

  Future<Map<String, dynamic>> _errorDelete(String path, String fallback) async {
    final dio = await _client();
    final res = await dio.delete<dynamic>(
      path,
      options: Options(
        headers: const {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    final data = _asJson(res, fallback);
    if (data['success'] != true) throw SiteException(_apiMessage(data, fallback));
    return data;
  }

  Future<Map<String, dynamic>> _studentJson(String path, String fallback) async {
    final dio = await _client();
    final res = await dio.get<dynamic>(
      path,
      options: Options(
        headers: const {'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    return _asJson(res, fallback);
  }

  Map<String, dynamic> _asJson(Response<dynamic> res, String fallback) {
    if (res.statusCode == 401 || res.statusCode == 419) {
      throw SiteException('Oturum kapanmış. Tekrar gir.');
    }
    final data = res.data;
    if (data is String) {
      if (data.contains('userdologin') || data.contains('/login')) {
        throw SiteException('Oturum kapanmış. Tekrar gir.');
      }
      throw SiteException(fallback);
    }
    if (data is! Map) throw SiteException(fallback);
    if (res.statusCode != null && res.statusCode! >= 400) {
      throw SiteException(_apiMessage(data, fallback));
    }
    return Map<String, dynamic>.from(data);
  }

  String _apiMessage(Map<dynamic, dynamic> data, String fallback) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      if (first != null) return first.toString();
    }
    final message = data['message']?.toString().trim() ?? '';
    return message.isEmpty ? fallback : message;
  }
}

class ReportTopic {
  const ReportTopic({required this.name, required this.source, required this.done});

  final String name;
  final String source;
  final bool done;
}

class ReportVideo {
  const ReportVideo({
    required this.title,
    required this.done,
    this.subject = '',
    this.missionId,
    this.subjectId,
    this.url,
    this.order,
    this.teacher,
    this.source = 1,
    this.sourceName,
  });

  final String? sourceName;
  final String subject;
  final String title;
  final int? missionId;
  final int? subjectId;
  final String? url;
  final int? order;
  final String? teacher;
  final bool done;
  final int source;
}

class ReportLesson {
  ReportLesson({required this.name, required this.color, required this.topics, required this.videos});

  final String name;
  final Color color;
  final List<ReportTopic> topics;
  final List<ReportVideo> videos;

  int get total => topics.length;
  int get done => topics.where((topic) => topic.done).length;
  bool get finished {
    if (topics.isNotEmpty) return done == total;
    return videos.isNotEmpty && videos.every((video) => video.done);
  }
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
          () {
            final missions = DemoMissions.of(quest.lesson);
            return ReportLesson(
              name: quest.lesson,
              color: quest.color,
              topics: [
                for (final mission in missions)
                  if (mission.subject.isNotEmpty)
                    ReportTopic(name: mission.subject, source: mission.source, done: mission.done),
              ],
              videos: [
                for (final mission in missions)
                  if (mission.isVideo)
                    ReportVideo(
                      subject: mission.subject,
                      missionId: mission.id,
                      subjectId: mission.subjectId,
                      title: mission.videoName ?? mission.subject,
                      url: mission.videoUrl,
                      order: mission.videoOrder,
                      teacher: mission.teacher,
                      done: mission.done,
                      source: mission.videoSource,
                    ),
              ],
            );
          },
        );
      }
    }
    final lessons = byName.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return ReportBoard(lessons);
  }

  factory ReportBoard.fromRaw(Map<String, dynamic> raw, [Map<String, dynamic>? videoPacks]) {
    final topics = <String, Map<String, _TopicFold>>{};
    final videos = <String, List<ReportVideo>>{};
    final seenVideos = <String, Set<String>>{};
    final colors = <String, Color>{};
    for (final entry in raw.values) {
      if (entry is! List) continue;
      for (final item in entry) {
        if (item is! Map) continue;
        if (_isExtra(item['ek_gorev'])) continue;
        final lesson = item['lesson_name']?.toString().trim() ?? '';
        if (lesson.isEmpty) continue;
        colors.putIfAbsent(lesson, () => _parseColor(item['lesson_bgcolor']?.toString()));
        final subject = item['subject_name']?.toString().trim() ?? '';
        final videoName = item['video_name']?.toString().trim() ?? '';
        final videoUrl = item['video_link']?.toString().trim() ?? '';
        final videoId = item['video_link_id'];
        final hasVideoId = videoId != null && videoId != 0 && '$videoId'.isNotEmpty && '$videoId' != 'null';
        final isVideo = _isExtra(item['is_video_mission']) ||
            _isExtra(item['has_resource_video']) ||
            hasVideoId ||
            videoName.isNotEmpty ||
            videoUrl.isNotEmpty;
        final done = item['completed'] == true || item['completed'] == 1 || item['completed'] == '1';
        if (subject.isNotEmpty) {
          final key = item['subject_id']?.toString() ?? subject;
          final fold = topics.putIfAbsent(lesson, () => {})[key];
          final source = item['material_name']?.toString().trim() ?? '';
          if (fold == null) {
            topics[lesson]![key] = _TopicFold(subject, source, done);
          } else {
            fold.done = fold.done && done;
          }
        }
        if (!isVideo) continue;
        final title = videoName.isNotEmpty ? videoName : subject;
        if (title.isEmpty && videoUrl.isEmpty) continue;
        final identity = hasVideoId ? 'id:$videoId' : (videoUrl.isNotEmpty ? videoUrl : title);
        final known = seenVideos.putIfAbsent(lesson, () => {});
        if (!known.add(identity)) continue;
        final orderRaw = item['video_number'];
        final order = orderRaw is int
            ? orderRaw
            : int.tryParse('${orderRaw ?? ''}') ??
                () {
                  final index = item['resource_video_order'];
                  final parsed = index is int ? index : int.tryParse('$index');
                  return parsed == null ? null : parsed + 1;
                }();
        final sourceIndex = item['resource_source_index'];
        final source = sourceIndex is int ? sourceIndex : int.tryParse('$sourceIndex') ?? 1;
        videos.putIfAbsent(lesson, () => []).add(
          ReportVideo(
            subject: subject,
            missionId: _asInt(item['id']),
            subjectId: _asInt(item['subject_id']),
            title: title.isEmpty ? 'Video' : title,
            url: videoUrl.isEmpty ? null : videoUrl,
            order: order,
            teacher: item['video_teacher_name']?.toString(),
            done: done,
            source: source <= 0 ? 1 : source,
            sourceName: _packSourceName(videoPacks, item['lesson_id'], source <= 0 ? 1 : source),
          ),
        );
      }
    }
    final names = {...topics.keys, ...videos.keys}.toList()..sort();
    return ReportBoard([
      for (final name in names)
        ReportLesson(
          name: name,
          color: colors[name] ?? DbColors.navy,
          topics: [
            for (final fold in (topics[name] ?? {}).values)
              ReportTopic(name: fold.name, source: fold.source, done: fold.done),
          ],
          videos: (videos[name] ?? [])..sort((a, b) => (a.order ?? 9999).compareTo(b.order ?? 9999)),
        ),
    ]);
  }
}

class _TopicFold {
  _TopicFold(this.name, this.source, this.done);

  final String name;
  final String source;
  bool done;
}

bool _isExtra(dynamic value) => value == true || value == 1 || value == '1';

String? _packSourceName(Map<String, dynamic>? packs, dynamic lessonId, int source) {
  if (packs == null || lessonId == null) return null;
  final pack = packs['$lessonId'];
  if (pack is! Map) return null;
  final sources = pack['sources'];
  if (sources is! List) return null;
  for (final src in sources) {
    if (src is! Map) continue;
    final index = src['sourceIndex'];
    final parsed = index is int ? index : int.tryParse('$index');
    if (parsed != source) continue;
    final name = src['qbName']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    return name;
  }
  return null;
}

int? _asInt(dynamic value) {
  if (value == null || value == false) return null;
  if (value is int) return value == 0 ? null : value;
  final parsed = int.tryParse(value.toString());
  if (parsed == null || parsed == 0) return null;
  return parsed;
}

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return DbColors.navy;
  var raw = hex.replaceAll('#', '');
  if (raw.length == 6) raw = 'FF$raw';
  final value = int.tryParse(raw, radix: 16);
  if (value == null) return DbColors.navy;
  return Color(value);
}

class StudentProfile {
  const StudentProfile({
    required this.firstName,
    required this.surname,
    required this.email,
    required this.phone,
    required this.bio,
  });

  final String firstName;
  final String surname;
  final String email;
  final String phone;
  final String bio;
}

class SiteException implements Exception {
  SiteException(this.message);

  final String message;

  @override
  String toString() => message;
}
