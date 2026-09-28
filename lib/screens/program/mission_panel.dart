import 'package:flutter/material.dart';

import '../../data/site_session.dart';
import '../../demo/demo_week.dart';
import '../../theme/db_theme.dart';
import '../../widgets/video_showcase.dart';
import 'did_what_sheet.dart';

class MissionPanel extends StatefulWidget {
  const MissionPanel({super.key, required this.lesson, required this.color, this.lessonId});

  final String lesson;
  final Color color;
  final int? lessonId;

  @override
  State<MissionPanel> createState() => _MissionPanelState();
}

class _MissionPanelState extends State<MissionPanel> {
  final _topicSearch = TextEditingController();
  final _videoSearch = TextEditingController();
  var _videoOrder = false;
  var _source = 0;
  var _showDone = false;
  var _loading = false;
  String? _error;
  List<LessonMission>? _remote;

  List<LessonMission> get _all {
    if (widget.lessonId != null) return _remote ?? const [];
    return DemoMissions.of(widget.lesson);
  }

  @override
  void initState() {
    super.initState();
    if (widget.lessonId != null) {
      _loading = true;
      _loadRemote();
    }
  }

  Future<void> _loadRemote() async {
    try {
      final items = await SiteSession.instance.missionsFor(widget.lessonId);
      if (!mounted) return;
      setState(() {
        _remote = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Görevler alınamadı.';
      });
    }
  }

  @override
  void dispose() {
    _topicSearch.dispose();
    _videoSearch.dispose();
    super.dispose();
  }

  List<LessonMission> _ordered() {
    final items = List<LessonMission>.of(_all);
    if (!_videoOrder) {
      final seen = <String>{};
      return [
        for (final mission in items)
          if (mission.subject.isNotEmpty && seen.add(mission.subject))
            mission,
      ];
    }
    final sources = _videoSources(items);
    final selected = sources.length > 1 ? (sources.contains(_source) ? _source : sources.first) : null;
    final videos = [
      for (final mission in items)
        if (mission.isVideo && (selected == null || mission.videoSource == selected)) mission,
    ]..sort((a, b) => (a.videoOrder ?? 9999).compareTo(b.videoOrder ?? 9999));
    return videos;
  }

  String _activeSourceName() {
    final sources = _videoSources(_all);
    if (sources.isEmpty) return '';
    final selected = sources.length > 1 ? (sources.contains(_source) ? _source : sources.first) : sources.first;
    return SiteSession.instance.videoSourceName(widget.lessonId, selected) ?? '$selected. kaynak';
  }

  List<int> _videoSources(List<LessonMission> items) {
    final sources = items.where((mission) => mission.isVideo).map((mission) => mission.videoSource).toSet().toList()
      ..sort();
    return sources;
  }

  bool _locked(LessonMission mission, List<LessonMission> ordered) {
    final index = ordered.indexOf(mission);
    if (index <= 0) return false;
    return !ordered[index - 1].done;
  }

  @override
  Widget build(BuildContext context) {
    final query = (_videoOrder ? _videoSearch : _topicSearch).text.trim().toLowerCase();
    final ordered = _ordered();
    final visible = ordered.where((mission) {
      if (query.isEmpty) return true;
      final label = _videoOrder ? (mission.videoName ?? mission.subject) : mission.subject;
      return label.toLowerCase().contains(query);
    }).toList();
    final open = visible.where((mission) => !mission.done).toList();
    final done = visible.where((mission) => mission.done).toList();
    final pool = _videoOrder
        ? _ordered()
        : _ordered();
    final doneCount = pool.where((mission) => mission.done).length;
    final progress = pool.isEmpty ? 0.0 : doneCount / pool.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: DbColors.ink),
                  ),
                  const Spacer(),
                  Text(
                    '$doneCount/${pool.length}',
                    style: DbText.style(size: 15, weight: FontWeight.w800, color: DbColors.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                widget.lesson,
                style: DbText.style(size: 32, weight: FontWeight.w900, height: 1.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Text(
                _videoOrder
                    ? '$doneCount video bitti · ${pool.length - doneCount} kaldı'
                    : '$doneCount konu bitti · ${pool.length - doneCount} kaldı',
                style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white,
                  color: widget.color,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: ValueKey(_videoOrder),
                controller: _videoOrder ? _videoSearch : _topicSearch,
                onChanged: (_) => setState(() {}),
                style: DbText.style(size: 15, weight: FontWeight.w700),
                cursorColor: DbColors.navy,
                decoration: InputDecoration(
                  hintText: _videoOrder ? 'Video ara' : 'Konu ara',
                  hintStyle: DbText.style(size: 15, weight: FontWeight.w700, color: const Color(0xFF9AA3B2)),
                  prefixIcon: const Icon(Icons.search_rounded, color: DbColors.navy),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _seg('Konu sırası', !_videoOrder, () => setState(() => _videoOrder = false)),
                    _seg('Video sırası', _videoOrder, () => setState(() => _videoOrder = true)),
                  ],
                ),
              ),
            ),
            if (_videoOrder && _activeSourceName().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  _activeSourceName(),
                  style: DbText.style(size: 20, weight: FontWeight.w900),
                ),
              ),
            ],
            if (_videoOrder && _videoSources(_all).length > 1) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final source in _videoSources(_all))
                      _sourceChip(
                        source,
                        source ==
                            (_videoSources(_all).contains(_source) ? _source : _videoSources(_all).first),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: DbColors.navy))
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: DbText.style(size: 15, weight: FontWeight.w800, color: DbColors.muted),
                          ),
                        )
                      : _videoOrder
                          ? _videoList(visible)
                          : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (open.isEmpty && done.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Text(
                        'Bu sırada konu yok.',
                        style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted),
                      ),
                    ),
                  for (final mission in open) ...[
                    _MissionCard(
                      mission: mission,
                      lesson: widget.lesson,
                      color: widget.color,
                      videoOrder: _videoOrder,
                      locked: _locked(mission, ordered),
                      videos: [
                        for (final item in _all)
                          if (item.videoName != null) item.videoName!,
                      ],
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!_videoOrder && done.isNotEmpty)
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => setState(() => _showDone = !_showDone),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.check_rounded, color: DbColors.navy, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tamamladıklarım',
                                  style: DbText.style(size: 15, weight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                '${done.length}',
                                style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.muted),
                              ),
                              Icon(
                                _showDone ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: DbColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!_videoOrder && _showDone)
                    for (final mission in done) ...[
                      const SizedBox(height: 12),
                      _MissionCard(
                        mission: mission,
                        lesson: widget.lesson,
                        color: widget.color,
                        videoOrder: _videoOrder,
                        locked: false,
                        videos: [
                          for (final item in _all)
                            if (item.videoName != null) item.videoName!,
                        ],
                        onChanged: () => setState(() {}),
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoList(List<LessonMission> visible) {
    if (visible.isEmpty) {
      return Center(
        child: Text(
          'Bu kaynakta video yok.',
          style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final mission = visible[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VideoCard(
            actions: true,
            video: VideoTileData(
              subject: mission.subject,
              lesson: widget.lesson,
              missionId: mission.id,
              subjectId: mission.subjectId,
              title: mission.videoName ?? mission.subject,
              url: mission.videoUrl,
              order: mission.videoOrder,
              teacher: mission.teacher,
              done: mission.done,
              onDone: () {
                mission.done = !mission.done;
                setState(() {});
              },
            ),
          ),
        );
      },
    );
  }

  Widget _seg(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? DbColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
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
      ),
    );
  }

  Widget _sourceChip(int source, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _source = source),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? widget.color : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$source. kaynak',
          style: DbText.style(
            size: 13,
            weight: FontWeight.w800,
            color: selected ? Colors.white : DbColors.ink,
          ),
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.lesson,
    required this.color,
    required this.videoOrder,
    required this.locked,
    required this.videos,
    required this.onChanged,
  });

  final LessonMission mission;
  final String lesson;
  final Color color;
  final bool videoOrder;
  final bool locked;
  final List<String> videos;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 36,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mission.subject, style: DbText.style(size: 17, weight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          videoOrder ? (mission.videoName ?? mission.source) : mission.source,
                          style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (mission.done)
                    const Icon(Icons.check_circle_rounded, color: DbColors.navy, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              if (locked)
                Text(
                  'Önce bir önceki görevi bitir',
                  style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted),
                )
              else
                Row(
                  children: [
                    _round(Icons.play_arrow_rounded, () => _videos(context)),
                    const SizedBox(width: 8),
                    _meb(context),
                    const SizedBox(width: 8),
                    _round(
                      mission.done ? Icons.undo_rounded : Icons.check_rounded,
                      () {
                        mission.done = !mission.done;
                        onChanged();
                      },
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _report(context),
                      style: TextButton.styleFrom(
                        foregroundColor: DbColors.navy,
                        backgroundColor: DbColors.mist,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Ne yaptın?', style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.navy)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) {
    return Material(
      color: DbColors.mist,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: DbColors.navy),
        ),
      ),
    );
  }

  Widget _meb(BuildContext context) {
    return Material(
      color: DbColors.mist,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _mebSheet(context),
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 36,
          width: 52,
          child: Center(
            child: Text('MEB', style: DbText.style(size: 12, weight: FontWeight.w900, color: DbColors.navy)),
          ),
        ),
      ),
    );
  }

  void _videos(BuildContext context) {
    final names = videos;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF6F3EE),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Video dersler', style: DbText.style(size: 20, weight: FontWeight.w900)),
              const SizedBox(height: 12),
              for (final name in names.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_fill_rounded, color: DbColors.navy),
                      title: Text(name, style: DbText.style(size: 15, weight: FontWeight.w800)),
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _mebSheet(BuildContext context) {
    const kinds = ['Sesli Anlatım', 'Test', 'Özet', 'Deneme'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF6F3EE),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MEB kaynakları', style: DbText.style(size: 20, weight: FontWeight.w900)),
              Text(mission.subject, style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: [
                  for (final kind in kinds)
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context),
                        child: Center(
                          child: Text(kind, style: DbText.style(size: 15, weight: FontWeight.w800)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _report(BuildContext context) {
    showDidWhat(
      context,
      missionId: mission.id,
      subjectId: mission.subjectId,
      lesson: lesson,
      subject: mission.subject,
      videoName: mission.videoName,
      videoUrl: mission.videoUrl,
      videoOrder: mission.videoOrder,
      teacherName: mission.teacher,
    );
  }
}

