import 'package:flutter/material.dart';

import '../../data/site_session.dart';
import '../../demo/demo_week.dart';
import '../../theme/db_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.live = false});

  final bool live;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportBoard? _board;
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.live) {
      _loading = true;
      _load();
    } else {
      _board = ReportBoard.demo();
    }
  }

  Future<void> _load() async {
    try {
      final board = await SiteSession.instance.reportBoard();
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is SiteException ? error.message : 'Rapor alınamadı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return _Hub(
      title: 'Raporlar',
      lead: 'Ders bazlı performans.',
      child: _loading
          ? const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator(color: DbColors.navy)),
            )
          : _error != null
              ? Column(
                  children: [
                    Text(_error!, style: DbText.style(size: 16, weight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      },
                      style: FilledButton.styleFrom(backgroundColor: DbColors.navy),
                      child: Text('Yeniden dene', style: DbText.style(size: 15, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                )
              : _ReportBody(board: board ?? const ReportBoard([])),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.board});

  final ReportBoard board;

  @override
  Widget build(BuildContext context) {
    final percent = board.total == 0 ? 0 : (board.done * 100 / board.total).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ders raporları', style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.muted)),
                    const SizedBox(height: 4),
                    Text('${board.done} / ${board.total} görev', style: DbText.style(size: 26, weight: FontWeight.w900)),
                  ],
                ),
              ),
              Text('%$percent', style: DbText.style(size: 28, weight: FontWeight.w900, color: DbColors.navy)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Dersler', style: DbText.style(size: 18, weight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (board.lessons.isEmpty)
          Text('Henüz görev kaydı yok.', style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted))
        else
          for (final lesson in board.lessons) ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => _LessonReportPage(lesson: lesson)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 64,
                        decoration: BoxDecoration(
                          color: lesson.color,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lesson.name, style: DbText.style(size: 17, weight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(
                              'Detaylı performans raporu',
                              style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: lesson.total == 0 ? 0 : lesson.done / lesson.total,
                                minHeight: 6,
                                backgroundColor: DbColors.mist,
                                color: lesson.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (lesson.finished)
                        const Icon(Icons.check_circle_rounded, color: DbColors.navy)
                      else
                        Text(
                          '${lesson.done}/${lesson.total}',
                          style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.muted),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _LessonReportPage extends StatelessWidget {
  const _LessonReportPage({required this.lesson});

  final ReportLesson lesson;

  @override
  Widget build(BuildContext context) {
    final pending = lesson.topics.where((topic) => !topic.done).toList();
    final done = lesson.topics.where((topic) => topic.done).toList();
    return _Hub(
      title: lesson.name,
      lead: '${lesson.done} bitti · ${lesson.total - lesson.done} kaldı',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isNotEmpty) ...[
            const _SectionLabel('Bekleyen'),
            for (final topic in pending) _topic(topic),
          ],
          if (done.isNotEmpty) ...[
            const _SectionLabel('Tamamlanan'),
            for (final topic in done) _topic(topic),
          ],
        ],
      ),
    );
  }

  Widget _topic(ReportTopic topic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Card(
        child: Row(
          children: [
            Icon(
              topic.done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: topic.done ? DbColors.navy : const Color(0xFFC5CDD8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.name, style: DbText.style(size: 16, weight: FontWeight.w900)),
                  if (topic.source.isNotEmpty)
                    Text(topic.source, style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBookScreen extends StatelessWidget {
  const ErrorBookScreen({super.key});

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
    return _Hub(
      title: 'Hata Defteri',
      lead: 'Dersini seç, kaynaklarındaki sorulara geç.',
      child: GridView.count(
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
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ErrorSources(lesson: lesson.$1, color: lesson.$2),
                    ),
                  );
                },
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
            ),
        ],
      ),
    );
  }
}

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _Hub(
      title: 'Denemeler',
      lead: 'Kulüp denemeleri, sonuç girişi ve ders denemeleri.',
      child: const Column(
        children: [
          _SectionLabel('Deneme Kulübü'),
          _PlainRow(title: 'TYT Genel Deneme 3', subtitle: 'Kendini test et', icon: Icons.edit_rounded),
          SizedBox(height: 8),
          _PlainRow(title: 'AYT Sayısal Deneme 1', subtitle: 'Atanmış deneme', icon: Icons.edit_rounded),
          SizedBox(height: 18),
          _SectionLabel('Sonuç girişi'),
          _PlainRow(title: 'TYT Genel', subtitle: 'Sonuç bekleniyor', icon: Icons.fact_check_rounded),
          SizedBox(height: 18),
          _SectionLabel('Ders denemelerim'),
          _PlainRow(title: 'Matematik branş', subtitle: '2 deneme', icon: Icons.menu_book_rounded),
          SizedBox(height: 8),
          _PlainRow(title: 'Fizik branş', subtitle: '1 deneme', icon: Icons.menu_book_rounded),
        ],
      ),
    );
  }
}

class ProgramEditScreen extends StatefulWidget {
  const ProgramEditScreen({super.key});

  @override
  State<ProgramEditScreen> createState() => _ProgramEditScreenState();
}

class _ProgramEditScreenState extends State<ProgramEditScreen> {
  static const _lessons = ['Matematik', 'Fizik', 'Türkçe', 'Kimya', 'Biyoloji'];
  String? _lesson;
  final _subjects = <String>{};
  final _days = <int>{};
  String? _saved;

  static const _subjectBank = {
    'Matematik': ['Fonksiyonlar', 'Problemler', 'Polinomlar'],
    'Fizik': ['Kuvvet', 'Elektrik', 'Optik'],
    'Türkçe': ['Paragraf', 'Dil bilgisi', 'Anlam'],
    'Kimya': ['Mol', 'Asit baz', 'Organik'],
    'Biyoloji': ['Hücre', 'Sistemler', 'Ekoloji'],
  };

  @override
  Widget build(BuildContext context) {
    final subjects = _lesson == null ? const <String>[] : _subjectBank[_lesson]!;
    return _Hub(
      title: 'Program düzenleme',
      lead: 'Dersi, konuları ve günleri seç.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Ders'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lesson in _lessons)
                _Choice(
                  label: lesson,
                  selected: _lesson == lesson,
                  onTap: () => setState(() {
                    _lesson = lesson;
                    _subjects.clear();
                    _saved = null;
                  }),
                ),
            ],
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionLabel('Konular'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final subject in subjects)
                  _Choice(
                    label: subject,
                    selected: _subjects.contains(subject),
                    onTap: () => setState(() {
                      if (!_subjects.add(subject)) _subjects.remove(subject);
                      _saved = null;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const _SectionLabel('Günler'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < DemoWeek.shortDays.length; i++)
                _Choice(
                  label: DemoWeek.shortDays[i],
                  selected: _days.contains(i),
                  onTap: () => setState(() {
                    if (!_days.add(i)) _days.remove(i);
                    _saved = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _lesson == null || _subjects.isEmpty || _days.isEmpty
                ? null
                : () {
                    final dayNames = (_days.toList()..sort());
                    setState(() {
                      _saved =
                          '$_lesson · ${_subjects.join(', ')} · ${dayNames.map((i) => DemoWeek.fullDays[i]).join(', ')}';
                    });
                  },
            style: FilledButton.styleFrom(
              backgroundColor: DbColors.navy,
              disabledBackgroundColor: const Color(0xFFD5DBE6),
              foregroundColor: Colors.white,
              disabledForegroundColor: DbColors.muted,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Günlere ekle',
              style: DbText.style(
                size: 16,
                weight: FontWeight.w800,
                color: _lesson == null || _subjects.isEmpty || _days.isEmpty
                    ? DbColors.muted
                    : Colors.white,
              ),
            ),
          ),
          if (_saved != null) ...[
            const SizedBox(height: 14),
            Text(_saved!, style: DbText.style(size: 15, weight: FontWeight.w800, color: DbColors.navy, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class _ErrorSources extends StatelessWidget {
  const _ErrorSources({required this.lesson, required this.color});

  final String lesson;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Hub(
      title: lesson,
      lead: 'Hangi kaynaktaki hatalarını görmek istiyorsun?',
      child: Column(
        children: [
          for (final source in ['$lesson Soru Bankası', 'Orijinal $lesson']) ...[
            _Card(
              child: Row(
                children: [
                  Container(width: 6, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(source, style: DbText.style(size: 16, weight: FontWeight.w900))),
                  Text('0 soru', style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Hub extends StatelessWidget {
  const _Hub({required this.title, required this.lead, required this.child});

  final String title;
  final String lead;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text(title, style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(lead, style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted, height: 1.35)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted)),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _Card(
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
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? DbColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: DbText.style(
            size: 14,
            weight: FontWeight.w800,
            color: selected ? Colors.white : DbColors.ink,
          ),
        ),
      ),
    );
  }
}
