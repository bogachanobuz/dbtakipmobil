import 'package:flutter/material.dart';

import '../../data/error_book.dart';
import '../../data/note_drafts.dart';
import '../../data/site_session.dart';
import '../../demo/demo_week.dart';
import '../../theme/db_theme.dart';
import 'error_add_flow.dart';
import 'error_sketch_page.dart';
import 'today_review_page.dart';
import 'error_solution_panel.dart';

class ErrorBookScreen extends StatefulWidget {
  const ErrorBookScreen({super.key, this.live = false});

  final bool live;

  @override
  State<ErrorBookScreen> createState() => _ErrorBookScreenState();
}

class _ErrorBookScreenState extends State<ErrorBookScreen> {
  var _loading = false;
  String? _error;
  ErrorNotebook? _book;
  List<ErrorLesson> _lessons = const [];

  @override
  void initState() {
    super.initState();
    if (widget.live) _load();
  }

  Future<void> _addLesson() async {
    final result = await showDialog<_NewLesson>(
      context: context,
      builder: (_) => const _AddLessonDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await SiteSession.instance.addCustomLesson(result.name, result.color);
      await _load();
    } catch (error) {
      if (!mounted) return;
      final message = error is SiteException ? error.message : 'Özel ders eklenemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final book = await SiteSession.instance.errorNotebook();
      await NoteDrafts.instance.overlay(book.questions);
      List<ErrorLesson> lessons = const [];
      try {
        lessons = await SiteSession.instance.errorLessons();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _book = book;
        _lessons = lessons;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is SiteException ? error.message : 'Hata defteri açılmadı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.live) return const _DemoBook();
    final book = _book;
    final groups = book?.groups(_lessons) ?? const <ErrorLessonGroup>[];
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text('Hata Defteri', style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      bottomNavigationBar: ErrorCameraBar(live: true, onSaved: _load),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DbColors.navy))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: DbText.style(size: 15, weight: FontWeight.w800)),
                        TextButton(onPressed: _load, child: const Text('Yeniden dene')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: DbColors.navy,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      Text(
                        'Dersini seç, kaynaklarına geç.',
                        style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      _SpecialTile(
                        icon: Icons.replay_rounded,
                        title: 'Bugünün tekrarları',
                        subtitle: (book?.dueQuestions.length ?? 0) == 0
                            ? 'Bugün bekleyen tekrar yok'
                            : '${book!.dueQuestions.length} soru tekrar zamanı geldi',
                        onTap: book == null
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => TodayReviewPage(questions: book.dueQuestions),
                                  ),
                                ).then((_) => _load());
                              },
                      ),
                      const SizedBox(height: 10),
                      _SpecialTile(
                        icon: Icons.add_rounded,
                        title: 'Ders ekle',
                        subtitle: 'Listede yoksa kendine özel ders oluştur',
                        onTap: _addLesson,
                      ),
                      const SizedBox(height: 10),
                      _SpecialTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Çöp kutusu',
                        subtitle: (book?.trashCount ?? 0) == 0
                            ? 'Boş'
                            : '${book!.trashCount} öğe · 3 gün içinde silinir',
                        onTap: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => const _TrashPage()))
                              .then((_) => _load());
                        },
                      ),
                      const SizedBox(height: 16),
                      if (groups.isEmpty)
                        Text(
                          'Henüz soru yok. Alttaki kamerayla ilk yanlışını ekle.',
                          style: DbText.style(size: 15, weight: FontWeight.w800, height: 1.35),
                        )
                      else
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.35,
                          children: [
                            for (final lesson in groups)
                              _LessonTile(
                                lesson: lesson,
                                onTap: () {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => _SourcePage(book: book!, lesson: lesson),
                                        ),
                                      )
                                      .then((_) => _load());
                                },
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _NewLesson {
  const _NewLesson(this.name, this.color);

  final String name;
  final String color;
}

class _AddLessonDialog extends StatefulWidget {
  const _AddLessonDialog();

  @override
  State<_AddLessonDialog> createState() => _AddLessonDialogState();
}

class _AddLessonDialogState extends State<_AddLessonDialog> {
  final _name = TextEditingController();
  var _color = '#4F46E5';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close(_NewLesson? result) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('Özel ders ekle', style: DbText.style(size: 18, weight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Örn: Paragraf'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final swatch in ['#4F46E5', '#0EA5E9', '#16A34A', '#EA580C', '#DB2777', '#1E4D8C'])
                GestureDetector(
                  onTap: () => setState(() => _color = swatch),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(int.parse(swatch.replaceAll('#', ''), radix: 16) + 0xFF000000),
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == swatch ? DbColors.ink : Colors.transparent, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => _close(null), child: const Text('Vazgeç')),
        TextButton(onPressed: _submit, child: const Text('Ekle')),
      ],
    );
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.length < 2) return;
    _close(_NewLesson(name, _color));
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.onTap});

  final ErrorLessonGroup lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = lesson.total == 0
        ? 'Henüz soru yok'
        : lesson.unsolved == 0
            ? '${lesson.total} soru'
            : '${lesson.unsolved} çözülmedi';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: lesson.color, shape: BoxShape.circle)),
              const Spacer(),
              Text(lesson.name, style: DbText.style(size: 17, weight: FontWeight.w900)),
              Text(count, style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourcePage extends StatefulWidget {
  const _SourcePage({required this.book, required this.lesson});

  final ErrorNotebook book;
  final ErrorLessonGroup lesson;

  @override
  State<_SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<_SourcePage> {
  late ErrorNotebook _book = widget.book;

  Future<void> _reload() async {
    try {
      final book = await SiteSession.instance.errorNotebook();
      if (!mounted) return;
      setState(() => _book = book);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final sources = _book.sourcesFor(lesson);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text(lesson.name, style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      bottomNavigationBar: ErrorCameraBar(live: true, onSaved: _reload),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            'Hangi kaynaktaki hatalarını görmek istiyorsun?',
            style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted, height: 1.35),
          ),
          const SizedBox(height: 16),
          for (final source in sources) ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _QuestionPage(
                        lesson: lesson,
                        kaynak: source,
                        questions: _book.questionsFor(lesson.key, source),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 36,
                        decoration: BoxDecoration(color: lesson.color, borderRadius: BorderRadius.circular(6)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(source.name, style: DbText.style(size: 16, weight: FontWeight.w900)),
                            Text(source.countLabel, style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _QuestionPage extends StatefulWidget {
  const _QuestionPage({required this.questions, this.lesson, this.kaynak});

  final ErrorLessonGroup? lesson;
  final ErrorKaynak? kaynak;
  final List<ErrorQuestion> questions;

  @override
  State<_QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<_QuestionPage> {
  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;
    final title = widget.kaynak?.name ?? 'Sorular';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text(title, style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      body: questions.isEmpty
          ? Center(
              child: Text(
                'Bu kaynakta soru yok.',
                style: DbText.style(size: 15, weight: FontWeight.w800, color: DbColors.muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final question = questions[index];
                final image = SiteSession.storageUrl(question.imagePath);
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => _QuestionDetail(
                                question: question,
                                onChanged: () {
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                          )
                          .then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: image == null
                                ? const _ThumbFallback()
                                : Image.network(
                                    image,
                                    width: 96,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    cacheWidth: 288,
                                    errorBuilder: (_, _, _) => const _ThumbFallback(),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${question.lessonKey == '__other__' ? 'Diğer' : question.lessonKey} · ${question.subjectName ?? 'Konu yok'}',
                                  style: DbText.style(size: 15, weight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                _RetentionBar(filled: question.retentionFilled, mastered: question.mastered),
                                const SizedBox(height: 6),
                                Text(question.preview, style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted)),
                                if (question.originLine != null)
                                  Text(question.originLine!, style: DbText.style(size: 12, weight: FontWeight.w800, color: DbColors.navy)),
                                if (question.errorReasonLabel != null || question.difficultyLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      [
                                        if (question.errorReasonLabel != null) question.errorReasonLabel!,
                                        if (question.difficultyLabel != null) question.difficultyLabel!,
                                      ].join(' · '),
                                      style: DbText.style(size: 12, weight: FontWeight.w800, color: DbColors.ink),
                                    ),
                                  ),
                                if (question.mistakeNote != null)
                                  Text(question.mistakeNote!, style: DbText.style(size: 12, weight: FontWeight.w700, color: DbColors.muted)),
                                if (question.correctSolutionNote != null)
                                  Text(question.correctSolutionNote!, style: DbText.style(size: 12, weight: FontWeight.w700, color: DbColors.navy)),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (_dayLabel(question.createdAt) != null) _dayLabel(question.createdAt)!,
                                    if (question.mastered) 'Öğrenildi',
                                    if (question.due) 'Tekrar',
                                    if (question.studentAnswer != null && !question.solved) 'Yanlış: ${question.studentAnswer}',
                                  ].join(' · '),
                                  style: DbText.style(size: 12, weight: FontWeight.w700, color: DbColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _QuestionDetail extends StatefulWidget {
  const _QuestionDetail({required this.question, this.onChanged});

  final ErrorQuestion question;
  final VoidCallback? onChanged;

  @override
  State<_QuestionDetail> createState() => _QuestionDetailState();
}

class _QuestionDetailState extends State<_QuestionDetail> {
  late final TextEditingController _correct;
  late final TextEditingController _mistake;
  var _busy = false;
  var _notesReady = false;
  String? _notice;
  String? _noteStatus;
  String? _account;
  var _syncedCorrect = '';
  var _syncedMistake = '';

  ErrorQuestion get question => widget.question;

  @override
  void initState() {
    super.initState();
    _correct = TextEditingController();
    _mistake = TextEditingController();
    _bootNotes();
  }

  Future<void> _bootNotes() async {
    final account = await NoteDrafts.instance.currentAccount();
    final draft = account == null ? null : await NoteDrafts.instance.peek(account, question.id);
    final correct = draft?.correct ?? question.correctSolutionNote ?? '';
    final mistake = draft?.mistake ?? question.mistakeNote ?? '';
    _syncedCorrect = draft?.baseCorrect ?? (question.correctSolutionNote ?? '').trim();
    _syncedMistake = draft?.baseMistake ?? (question.mistakeNote ?? '').trim();
    _account = account;
    _correct.text = correct;
    _mistake.text = mistake;
    question.correctSolutionNote = correct.trim().isEmpty ? null : correct.trim();
    question.mistakeNote = mistake.trim().isEmpty ? null : mistake.trim();
    _correct.addListener(_onNotesChanged);
    _mistake.addListener(_onNotesChanged);
    if (!mounted) return;
    setState(() => _notesReady = true);
  }

  @override
  void dispose() {
    _correct.removeListener(_onNotesChanged);
    _mistake.removeListener(_onNotesChanged);
    _correct.dispose();
    _mistake.dispose();
    super.dispose();
  }

  Future<void> _onNotesChanged() async {
    if (!_notesReady) return;
    final correct = _correct.text.trim();
    final mistake = _mistake.text.trim();
    question.correctSolutionNote = correct.isEmpty ? null : correct;
    question.mistakeNote = mistake.isEmpty ? null : mistake;
    widget.onChanged?.call();
    final account = _account;
    if (account == null) return;
    if (correct == _syncedCorrect && mistake == _syncedMistake) {
      await NoteDrafts.instance.drop(account, question.id);
      if (mounted) setState(() => _noteStatus = null);
      return;
    }
    if (mounted) setState(() => _noteStatus = 'Kaydedilecek');
    await NoteDrafts.instance.stage(
      account: account,
      questionId: question.id,
      correct: correct,
      mistake: mistake,
      baseCorrect: _syncedCorrect,
      baseMistake: _syncedMistake,
      onSent: (sentCorrect, sentMistake) {
        if (!mounted) return;
        if (_correct.text.trim() != sentCorrect || _mistake.text.trim() != sentMistake) return;
        _syncedCorrect = sentCorrect;
        _syncedMistake = sentMistake;
        setState(() => _noteStatus = 'Kaydedildi');
      },
    );
  }

  Future<void> _answer(String letter) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await SiteSession.instance.checkErrorAnswer(question.id, letter);
      question.studentAnswer = letter;
      question.applyReview(data);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice = data['message']?.toString();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final message = error is SiteException ? error.message : 'Cevap kontrol edilemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _trash() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SiteSession.instance.deleteErrorQuestion(question.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final message = error is SiteException ? error.message : 'Soru silinemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = SiteSession.storageUrl(question.imagePath);
    final answered = question.studentAnswer;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text(question.subjectName ?? 'Soru', style: DbText.style(size: 18, weight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _busy ? null : _trash, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: image == null
                ? const _ThumbFallback(wide: true)
                : Image.network(
                    image,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _ThumbFallback(wide: true),
                  ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final path = await Navigator.of(context).push<String>(
                  MaterialPageRoute<String>(
                    builder: (_) => ErrorSketchPage(
                      questionId: question.id,
                      sketchPath: question.solutionSketchPath,
                      questionImagePath: question.imagePath,
                    ),
                  ),
                );
                if (path == null || !mounted) return;
                setState(() => question.solutionSketchPath = path);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SiteSession.storageUrl(question.solutionSketchPath) == null
                          ? Container(
                              width: 72,
                              height: 52,
                              color: DbColors.mist,
                              alignment: Alignment.center,
                              child: const Icon(Icons.edit_rounded, color: DbColors.navy),
                            )
                          : Image.network(
                              SiteSession.storageUrl(question.solutionSketchPath)!,
                              width: 72,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.edit_rounded, color: DbColors.navy),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Karalama Defteri', style: DbText.style(size: 15, weight: FontWeight.w900)),
                          Text(
                            question.solutionSketchPath == null ? 'Büyütüp çizmek için tıkla' : 'Devam etmek için tıkla',
                            style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _RetentionBar(filled: question.retentionFilled, mastered: question.mastered),
          const SizedBox(height: 10),
          Text(question.preview, style: DbText.style(size: 15, weight: FontWeight.w800, height: 1.35)),
          if (question.originLine != null) ...[
            const SizedBox(height: 6),
            Text(question.originLine!, style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.navy)),
          ],
          const SizedBox(height: 8),
          Text(
            [
              if (question.errorReasonLabel != null) question.errorReasonLabel!,
              if (question.difficultyLabel != null) question.difficultyLabel!,
              if (question.mastered) 'Öğrenildi',
              if (question.due) 'Tekrar zamanı',
              question.solved ? 'Çözüldü' : 'Çözülmedi',
            ].join(' · '),
            style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted),
          ),
          const SizedBox(height: 16),
          Text('Şıkkın', style: DbText.style(size: 14, weight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final letter in question.options)
                ChoiceChip(
                  label: Text(letter, style: DbText.style(size: 16, weight: FontWeight.w900, color: _chipColor(letter, answered))),
                  selected: answered == letter || (question.solved && question.correctAnswer == letter),
                  onSelected: _busy ? null : (_) => _answer(letter),
                ),
            ],
          ),
          if (_notice != null) ...[
            const SizedBox(height: 10),
            Text(_notice!, style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.navy)),
          ],
          const SizedBox(height: 18),
          Text('Neyi yanlış yaptın?', style: DbText.style(size: 16, weight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Nerede takıldın, hangi adımı kaçırdın?', style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.navy)),
          const SizedBox(height: 8),
          TextField(
            controller: _mistake,
            minLines: 3,
            maxLines: 6,
            decoration: _noteField('Kısaca yaz…'),
          ),
          if (question.solved || _mistake.text.trim().isNotEmpty || _correct.text.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Bu soru bana ne öğretti?', style: DbText.style(size: 16, weight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Doğru çözümü kendi cümlelerinle yaz.', style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.navy)),
            const SizedBox(height: 8),
            TextField(
              controller: _correct,
              minLines: 3,
              maxLines: 6,
              decoration: _noteField('Ne öğrendin?'),
            ),
          ],
          if (_noteStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_noteStatus!, style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.navy)),
            ),
          const SizedBox(height: 18),
          ErrorSolutionPanel(question: question),
        ],
      ),
    );
  }

  Color _chipColor(String letter, String? answered) {
    if (question.solved && question.correctAnswer == letter) return DbColors.navy;
    if (answered == letter && !question.solved) return DbColors.red;
    return DbColors.ink;
  }

  InputDecoration _noteField(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      hintStyle: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }
}

class _RetentionBar extends StatelessWidget {
  const _RetentionBar({required this.filled, required this.mastered});

  final int filled;
  final bool mastered;

  @override
  Widget build(BuildContext context) {
    const labels = ['3. gün', '7. gün', '30. gün'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < filled || mastered ? DbColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                labels[i],
                style: DbText.style(
                  size: 11,
                  weight: FontWeight.w800,
                  color: i < filled || mastered ? Colors.white : DbColors.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SpecialTile extends StatelessWidget {
  const _SpecialTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: DbColors.navy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DbText.style(size: 16, weight: FontWeight.w900)),
                    Text(subtitle, style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrashPage extends StatefulWidget {
  const _TrashPage();

  @override
  State<_TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<_TrashPage> {
  var _loading = true;
  String? _error;
  ErrorTrash? _trash;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trash = await SiteSession.instance.errorTrash();
      if (!mounted) return;
      setState(() {
        _trash = trash;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is SiteException ? error.message : 'Çöp kutusu açılmadı.';
      });
    }
  }

  Future<void> _restoreQuestion(int id) async {
    try {
      final message = await SiteSession.instance.restoreErrorQuestion(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (error) {
      if (!mounted) return;
      final message = error is SiteException ? error.message : 'Geri alınamadı.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _restoreSource(int id) async {
    try {
      final message = await SiteSession.instance.restoreErrorSource(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (error) {
      if (!mounted) return;
      final message = error is SiteException ? error.message : 'Geri alınamadı.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trash = _trash;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text('Çöp kutusu', style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DbColors.navy))
          : _error != null
              ? Center(child: Text(_error!, style: DbText.style(size: 15, weight: FontWeight.w800)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    if ((trash?.questions.isEmpty ?? true) && (trash?.sources.isEmpty ?? true))
                      Text('Çöp kutusu boş.', style: DbText.style(size: 15, weight: FontWeight.w800, color: DbColors.muted)),
                    if (trash != null && trash.questions.isNotEmpty) ...[
                      Text('Sorular', style: DbText.style(size: 14, weight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (final question in trash.questions) ...[
                        _TrashRow(
                          title: question.lessonKey == '__other__' ? 'Diğer' : question.lessonKey,
                          subtitle: _days(question.daysLeft),
                          onRestore: () => _restoreQuestion(question.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (trash != null && trash.sources.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Kaynaklar', style: DbText.style(size: 14, weight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (final source in trash.sources) ...[
                        _TrashRow(
                          title: source.name,
                          subtitle: _days(source.daysLeft),
                          onRestore: () => _restoreSource(source.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
    );
  }

  String _days(int? left) {
    if (left == null) return '3 gün içinde silinir';
    if (left <= 0) return 'Bugün silinir';
    return '$left gün kaldı';
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({required this.title, required this.subtitle, required this.onRestore});

  final String title;
  final String subtitle;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DbText.style(size: 15, weight: FontWeight.w900)),
                  Text(subtitle, style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted)),
                ],
              ),
            ),
            TextButton(onPressed: onRestore, child: const Text('Geri al')),
          ],
        ),
      ),
    );
  }
}

String? _dayLabel(String? raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : 96,
      height: wide ? 180 : 64,
      color: DbColors.mist,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: DbColors.muted),
    );
  }
}

class _DemoBook extends StatelessWidget {
  const _DemoBook();

  static const _lessons = [
    ('Matematik', DemoWeek.math),
    ('Fizik', DemoWeek.physics),
    ('Türkçe', DemoWeek.turkish),
    ('Kimya', DemoWeek.chemistry),
    ('Biyoloji', DemoWeek.biology),
    ('Tarih', DemoWeek.history),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text('Hata Defteri', style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      bottomNavigationBar: const ErrorCameraBar(live: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            'Dersini seç, kaynaklarındaki sorulara geç.',
            style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted, height: 1.35),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (final lesson in _lessons)
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: lesson.$2, shape: BoxShape.circle),
                        ),
                        const Spacer(),
                        Text(lesson.$1, style: DbText.style(size: 18, weight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
