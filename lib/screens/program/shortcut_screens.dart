import 'package:flutter/material.dart';

import '../../data/site_session.dart';
import '../../demo/demo_week.dart';
import '../../theme/db_theme.dart';
import '../../widgets/video_showcase.dart';

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

class _ReportBody extends StatefulWidget {
  const _ReportBody({required this.board});

  final ReportBoard board;

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  final _search = TextEditingController();

  ReportBoard get board => widget.board;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _count(ReportLesson lesson) => lesson.topics.isEmpty ? lesson.videos.length : lesson.total;

  int _finished(ReportLesson lesson) =>
      lesson.topics.isEmpty ? lesson.videos.where((video) => video.done).length : lesson.done;

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final lessons = board.lessons.where((lesson) {
      if (query.isEmpty) return true;
      return lesson.name.toLowerCase().contains(query);
    }).toList();
    final total = lessons.fold<int>(0, (sum, lesson) => sum + _count(lesson));
    final done = lessons.fold<int>(0, (sum, lesson) => sum + _finished(lesson));
    final percent = total == 0 ? 0 : (done * 100 / total).round();
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
                    Text('$done / $total görev', style: DbText.style(size: 26, weight: FontWeight.w900)),
                  ],
                ),
              ),
              Text('%$percent', style: DbText.style(size: 28, weight: FontWeight.w900, color: DbColors.navy)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: DbText.style(size: 15, weight: FontWeight.w700),
          cursorColor: DbColors.navy,
          decoration: InputDecoration(
            hintText: 'Ders ara',
            hintStyle: DbText.style(size: 15, weight: FontWeight.w700, color: const Color(0xFF9AA3B2)),
            prefixIcon: const Icon(Icons.search_rounded, color: DbColors.navy),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        Text('Dersler', style: DbText.style(size: 18, weight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (lessons.isEmpty)
          Text('Henüz görev kaydı yok.', style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted))
        else
          for (final lesson in lessons) ...[
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
                              lesson.topics.isEmpty
                                  ? '${lesson.videos.length} video'
                                  : lesson.videos.isEmpty
                                      ? 'Detaylı performans raporu'
                                      : '${lesson.total} konu · ${lesson.videos.length} video',
                              style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _count(lesson) == 0 ? 0 : _finished(lesson) / _count(lesson),
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
                          lesson.topics.isEmpty ? '${lesson.videos.length} video' : '${lesson.done}/${lesson.total}',
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

class _LessonReportPage extends StatefulWidget {
  const _LessonReportPage({required this.lesson});

  final ReportLesson lesson;

  @override
  State<_LessonReportPage> createState() => _LessonReportPageState();
}

class _LessonReportPageState extends State<_LessonReportPage> {
  final _topicSearch = TextEditingController();
  final _videoSearch = TextEditingController();
  var _source = 0;
  var _videoLimit = 20;

  @override
  void dispose() {
    _topicSearch.dispose();
    _videoSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final topicQuery = _topicSearch.text.trim().toLowerCase();
    final videoQuery = _videoSearch.text.trim().toLowerCase();
    final topics = lesson.topics.where((topic) {
      if (topicQuery.isEmpty) return true;
      return topic.name.toLowerCase().contains(topicQuery);
    }).toList();
    final sources = lesson.videos.map((video) => video.source).toSet().toList()..sort();
    final selected = sources.length > 1 ? (sources.contains(_source) ? _source : sources.first) : null;
    final videos = lesson.videos.where((video) {
      if (selected != null && video.source != selected) return false;
      if (videoQuery.isEmpty) return true;
      final label = '${video.subject} ${video.title}'.toLowerCase();
      return label.contains(videoQuery);
    }).toList();
    final pending = topics.where((topic) => !topic.done).toList();
    final done = topics.where((topic) => topic.done).toList();
    return _Hub(
      title: lesson.name,
      lead: '${lesson.done} bitti · ${lesson.total - lesson.done} kaldı',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchBox(_topicSearch, 'Konu ara'),
          const SizedBox(height: 14),
          if (pending.isNotEmpty) ...[
            const _SectionLabel('Konular'),
            for (final topic in pending) _topic(topic),
          ],
          if (done.isNotEmpty) ...[
            const _SectionLabel('Tamamlanan konular'),
            for (final topic in done) _topic(topic),
          ],
          if (topics.isEmpty)
            Text('Bu aramada konu yok.', style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted)),
          if (lesson.videos.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _SectionLabel('Video sırası'),
            _searchBox(_videoSearch, 'Video ara'),
            if (sources.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in sources)
                    _sourceChip(source, source == selected),
                ],
              ),
            ],
            if (_sourceName(videos, selected).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _sourceName(videos, selected),
                style: DbText.style(size: 20, weight: FontWeight.w900),
              ),
            ],
            const SizedBox(height: 10),
            VideoShowcase(
              actions: false,
              videos: [
                for (final video in videos.take(_videoLimit))
                  VideoTileData(
                    subject: video.subject,
                    lesson: lesson.name,
                    title: video.title,
                    url: video.url,
                    order: video.order,
                    teacher: video.teacher,
                    done: video.done,
                  ),
              ],
            ),
            if (videos.length > _videoLimit)
              TextButton(
                onPressed: () => setState(() => _videoLimit += 20),
                child: Text(
                  'Daha fazla (${videos.length - _videoLimit})',
                  style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.navy),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _sourceName(List<ReportVideo> videos, int? selected) {
    for (final video in videos) {
      final name = video.sourceName;
      if (name != null && name.isNotEmpty) return name;
    }
    if (selected == null) return '';
    return '$selected. kaynak';
  }

  Widget _searchBox(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() => _videoLimit = 20),
      style: DbText.style(size: 15, weight: FontWeight.w700),
      cursorColor: DbColors.navy,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: DbText.style(size: 15, weight: FontWeight.w700, color: const Color(0xFF9AA3B2)),
        prefixIcon: const Icon(Icons.search_rounded, color: DbColors.navy),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _sourceChip(int source, bool selected) {
    return GestureDetector(
      onTap: () => setState(() {
        _source = source;
        _videoLimit = 20;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? DbColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$source. kaynak',
          style: DbText.style(size: 13, weight: FontWeight.w800, color: selected ? Colors.white : DbColors.ink),
        ),
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
