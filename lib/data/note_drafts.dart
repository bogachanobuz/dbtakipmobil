import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'error_book.dart';
import 'site_session.dart';

class NoteDraft {
  const NoteDraft({
    required this.correct,
    required this.mistake,
    required this.baseCorrect,
    required this.baseMistake,
    required this.revision,
  });

  final String correct;
  final String mistake;
  final String baseCorrect;
  final String baseMistake;
  final int revision;
}

class NoteDrafts {
  NoteDrafts._();

  static final NoteDrafts instance = NoteDrafts._();
  static const _storeKey = 'note_drafts_v1';
  static const accountKey = 'live_account_v1';

  final _timers = <String, Timer>{};
  final _sent = <String, void Function(String correct, String mistake)>{};
  var _revision = 0;

  Future<void> rememberAccount(String email) async {
    final account = email.trim().toLowerCase();
    if (account.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accountKey, account);
  }

  Future<String?> currentAccount() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(SiteSession.liveKey) ?? false)) return null;
    final saved = prefs.getString(accountKey)?.trim().toLowerCase() ?? '';
    if (saved.isNotEmpty) return saved;
    final profile = await SiteSession.instance.profile();
    final email = profile?.email.trim().toLowerCase() ?? '';
    if (email.isEmpty) return null;
    await prefs.setString(accountKey, email);
    return email;
  }

  Future<void> stage({
    required String account,
    required int questionId,
    required String correct,
    required String mistake,
    required String baseCorrect,
    required String baseMistake,
    void Function(String correct, String mistake)? onSent,
  }) async {
    final key = _timerKey(account, questionId);
    final revision = ++_revision;
    if (onSent != null) _sent[key] = onSent;
    await _write(
      account,
      questionId,
      NoteDraft(
        correct: correct,
        mistake: mistake,
        baseCorrect: baseCorrect,
        baseMistake: baseMistake,
        revision: revision,
      ),
    );
    _timers[key]?.cancel();
    _timers[key] = Timer(const Duration(seconds: 10), () {
      _timers.remove(key);
      flushQuestion(account, questionId, revision);
    });
  }

  Future<void> drop(String account, int questionId) async {
    final key = _timerKey(account, questionId);
    _timers[key]?.cancel();
    _timers.remove(key);
    _sent.remove(key);
    await _remove(account, questionId);
  }

  Future<NoteDraft?> peek(String account, int questionId) async {
    final all = await _readAll();
    return _draft(all, account, questionId);
  }

  Future<void> overlay(List<ErrorQuestion> questions) async {
    final account = await currentAccount();
    if (account == null) return;
    final all = await _readAll();
    final bucket = all[account];
    if (bucket is! Map) return;
    for (final question in questions) {
      final draft = _fromRow(bucket['${question.id}']);
      if (draft == null) continue;
      question.correctSolutionNote = draft.correct.isEmpty ? null : draft.correct;
      question.mistakeNote = draft.mistake.isEmpty ? null : draft.mistake;
    }
  }

  Future<void> flushCurrent() async {
    final account = await currentAccount();
    if (account == null) return;
    final all = await _readAll();
    final bucket = all[account];
    if (bucket is! Map) return;
    for (final id in bucket.keys) {
      final questionId = int.tryParse(id);
      final draft = _fromRow(bucket[id]);
      if (questionId == null || draft == null) continue;
      _timers[_timerKey(account, questionId)]?.cancel();
      await flushQuestion(account, questionId, draft.revision);
    }
  }

  Future<void> flushQuestion(String account, int questionId, int revision) async {
    final draft = await peek(account, questionId);
    if (draft == null || draft.revision != revision) return;
    try {
      await SiteSession.instance.saveErrorNotes(
        questionId,
        correctNote: draft.correct,
        mistakeNote: draft.mistake,
      );
    } catch (_) {
      return;
    }
    final again = await peek(account, questionId);
    if (again == null || again.revision != revision) return;
    await _remove(account, questionId);
    final notify = _sent.remove(_timerKey(account, questionId));
    notify?.call(draft.correct, draft.mistake);
  }

  String _timerKey(String account, int questionId) => '$account:$questionId';

  Future<Map<String, dynamic>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _write(String account, int questionId, NoteDraft draft) async {
    final all = await _readAll();
    final bucket = all[account];
    final next = bucket is Map ? Map<String, dynamic>.from(bucket) : <String, dynamic>{};
    next['$questionId'] = {
      'correct': draft.correct,
      'mistake': draft.mistake,
      'baseCorrect': draft.baseCorrect,
      'baseMistake': draft.baseMistake,
      'revision': draft.revision,
    };
    all[account] = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKey, jsonEncode(all));
  }

  Future<void> _remove(String account, int questionId) async {
    final all = await _readAll();
    final bucket = all[account];
    if (bucket is! Map) return;
    final next = Map<String, dynamic>.from(bucket);
    next.remove('$questionId');
    if (next.isEmpty) {
      all.remove(account);
    } else {
      all[account] = next;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKey, jsonEncode(all));
  }

  NoteDraft? _draft(Map<String, dynamic> all, String account, int questionId) {
    final bucket = all[account];
    if (bucket is! Map) return null;
    return _fromRow(bucket['$questionId']);
  }

  NoteDraft? _fromRow(dynamic row) {
    if (row is! Map) return null;
    return NoteDraft(
      correct: row['correct']?.toString() ?? '',
      mistake: row['mistake']?.toString() ?? '',
      baseCorrect: row['baseCorrect']?.toString() ?? '',
      baseMistake: row['baseMistake']?.toString() ?? '',
      revision: row['revision'] is int ? row['revision'] as int : int.tryParse('${row['revision']}') ?? 0,
    );
  }
}
