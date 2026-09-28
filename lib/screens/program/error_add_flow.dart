import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/error_book.dart';
import '../../data/site_session.dart';
import '../../theme/db_theme.dart';

Future<void> captureErrorQuestion(
  BuildContext context, {
  required bool live,
  VoidCallback? onSaved,
}) async {
  if (!live) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hata defterine yüklemek için site hesabıyla gir.')),
    );
    return;
  }
  try {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (shot == null || !context.mounted) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: shot.path,
      maxWidth: 2048,
      maxHeight: 2048,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Soruyu kırp',
          toolbarColor: DbColors.navy,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: DbColors.navy,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.original,
        ),
        IOSUiSettings(title: 'Soruyu kırp'),
      ],
    );
    if (cropped == null || !context.mounted) return;
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => ErrorAddFlow(imagePath: cropped.path)),
    );
    if (saved == null || !context.mounted) return;
    onSaved?.call();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved)));
  } catch (error) {
    if (!context.mounted) return;
    final message = error is SiteException ? error.message : 'Fotoğraf açılamadı.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class ErrorCameraBar extends StatelessWidget {
  const ErrorCameraBar({super.key, required this.live, this.onSaved});

  final bool live;
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F3EE),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Center(
            child: Material(
              color: DbColors.navy,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => captureErrorQuestion(context, live: live, onSaved: onSaved),
                child: const SizedBox(
                  width: 58,
                  height: 58,
                  child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorAddFlow extends StatefulWidget {
  const ErrorAddFlow({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<ErrorAddFlow> createState() => _ErrorAddFlowState();
}

class _ErrorAddFlowState extends State<ErrorAddFlow> {
  static const _steps = ['Ders', 'Kaynak', 'Konu', 'Doğru şık', 'Zorluk'];
  static const _answers = ['A', 'B', 'C', 'D', 'E'];
  static const _difficulties = [('kolay', 'Kolay'), ('orta', 'Orta'), ('zor', 'Zor')];
  static const _swatches = [
    '#4F46E5',
    '#0EA5E9',
    '#16A34A',
    '#EA580C',
    '#DB2777',
    '#1E4D8C',
  ];

  var _step = 0;
  var _loading = true;
  var _saving = false;
  String? _error;
  List<ErrorLesson> _lessons = const [];
  ErrorNotebook? _notebook;
  final _query = TextEditingController();
  final _customName = TextEditingController();
  var _customColor = _swatches.first;
  var _addingLesson = false;

  ErrorLesson? _lesson;
  ErrorKaynak? _kaynak;
  ErrorSubject? _subject;
  String? _answer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    _customName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lessons = await SiteSession.instance.errorLessons();
      ErrorNotebook? notebook;
      try {
        notebook = await SiteSession.instance.errorNotebook();
      } catch (_) {
        notebook = null;
      }
      if (!mounted) return;
      setState(() {
        _lessons = lessons;
        _notebook = notebook;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is SiteException ? error.message : 'Dersler alınamadı.';
      });
    }
  }

  List<ErrorKaynak> get _sources {
    final lesson = _lesson;
    final notebook = _notebook;
    if (lesson == null || notebook == null) {
      return const [ErrorKaynak(kind: 'all', name: 'Tüm sorular')];
    }
    return notebook.sourcesFor(
      ErrorLessonGroup(
        key: lesson.key,
        name: lesson.name,
        color: lesson.color,
        isCustom: lesson.isCustom,
        customId: lesson.customId,
        lessonId: lesson.isCustom ? null : lesson.id,
      ),
    );
  }

  void _back() {
    if (_saving) return;
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    if (_step == 3 && (_lesson?.subjects.isEmpty ?? true)) {
      setState(() => _step = 1);
      return;
    }
    setState(() => _step -= 1);
  }

  Future<void> _addCustom() async {
    final name = _customName.text.trim();
    if (name.length < 2 || _addingLesson) return;
    setState(() => _addingLesson = true);
    try {
      final lesson = await SiteSession.instance.addCustomLesson(name, _customColor);
      if (!mounted) return;
      setState(() {
        _lessons = [..._lessons.where((item) => item.name != lesson.name), lesson];
        _lesson = lesson;
        _kaynak = null;
        _subject = null;
        _addingLesson = false;
        _customName.clear();
        _step = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _addingLesson = false);
      final message = error is SiteException ? error.message : 'Özel ders eklenemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save(String difficulty) async {
    final lesson = _lesson;
    final kaynak = _kaynak;
    final answer = _answer;
    if (lesson == null || kaynak == null || answer == null || _saving) return;
    setState(() => _saving = true);
    try {
      final message = await SiteSession.instance.saveErrorQuestion(
        imagePath: widget.imagePath,
        correctAnswer: answer,
        difficulty: difficulty,
        lessonId: lesson.isCustom ? null : lesson.id,
        lessonName: lesson.name,
        subjectId: _subject?.id,
        subjectName: _subject?.name,
        kaynakId: kaynak.kind == 'custom' ? kaynak.id : null,
        questionBankId: kaynak.kind == 'assigned' ? kaynak.questionBankId : null,
        questionBankName: kaynak.kind == 'assigned' ? (kaynak.questionBankName ?? kaynak.name) : null,
        denemeId: kaynak.kind == 'deneme' ? kaynak.denemeId : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = error is SiteException ? error.message : 'Soru kaydedilemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _lessons.where((lesson) {
      final q = _query.text.trim().toLowerCase();
      return q.isEmpty || lesson.name.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        leading: IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded)),
        title: Text(_steps[_step], style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
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
                        const SizedBox(height: 12),
                        TextButton(onPressed: _load, child: const Text('Yeniden dene')),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(widget.imagePath),
                              width: 72,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_step + 1} / ${_steps.length}',
                            style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _stepBody(shown)),
                  ],
                ),
    );
  }

  Widget _stepBody(List<ErrorLesson> shown) {
    if (_saving) {
      return const Center(child: CircularProgressIndicator(color: DbColors.navy));
    }
    return switch (_step) {
      0 => _lessonStep(shown),
      1 => _choiceList(
          items: [
            for (final kaynak in _sources)
              _Choice(title: kaynak.name, subtitle: kaynak.countLabel, onTap: () {
                setState(() {
                  _kaynak = kaynak;
                  _subject = null;
                  _step = (_lesson?.subjects.isEmpty ?? true) ? 3 : 2;
                });
              }),
          ],
        ),
      2 => _choiceList(
          items: [
            _Choice(
              title: 'Konu seçmeden devam',
              subtitle: 'İsteğe bağlı',
              onTap: () => setState(() {
                _subject = null;
                _step = 3;
              }),
            ),
            for (final subject in _lesson?.subjects ?? const <ErrorSubject>[])
              _Choice(
                title: subject.name,
                onTap: () => setState(() {
                  _subject = subject;
                  _step = 3;
                }),
              ),
          ],
        ),
      3 => _choiceList(
          items: [
            for (final letter in _answers)
              _Choice(
                title: letter,
                onTap: () => setState(() {
                  _answer = letter;
                  _step = 4;
                }),
              ),
          ],
        ),
      _ => _choiceList(
          items: [
            for (final item in _difficulties)
              _Choice(title: item.$2, onTap: () => _save(item.$1)),
          ],
        ),
    };
  }

  Widget _lessonStep(List<ErrorLesson> shown) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: _field('Ders ara'),
          ),
        ),
        Expanded(
          child: _choiceList(
            items: [
              for (final lesson in shown)
                _Choice(
                  title: lesson.isCustom ? '${lesson.name} (özel)' : lesson.name,
                  color: lesson.color,
                  onTap: () => setState(() {
                    _lesson = lesson;
                    _kaynak = null;
                    _subject = null;
                    _step = 1;
                  }),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Özel ders', style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted)),
              const SizedBox(height: 8),
              TextField(
                controller: _customName,
                decoration: _field('Listede yoksa ders adı yaz'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final color in _swatches)
                    GestureDetector(
                      onTap: () => setState(() => _customColor = color),
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _customColor == color ? DbColors.ink : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _addingLesson ? null : _addCustom,
                    child: Text(_addingLesson ? 'Ekleniyor' : 'Ekle'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceList({required List<_Choice> items}) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => items[index],
    );
  }

  InputDecoration _field(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      hintStyle: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.onTap, this.subtitle, this.color});

  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              if (color != null) ...[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DbText.style(size: 16, weight: FontWeight.w900)),
                    if (subtitle != null)
                      Text(subtitle!, style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: DbColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

Color _color(String hex) {
  final value = int.parse(hex.replaceAll('#', ''), radix: 16);
  return Color(0xFF000000 | value);
}
