import 'package:flutter/material.dart';

import '../../data/site_session.dart';
import '../../demo/demo_week.dart';
import '../../theme/db_theme.dart';

class MissionPanel extends StatefulWidget {
  const MissionPanel({super.key, required this.lesson, required this.color, this.lessonId});

  final String lesson;
  final Color color;
  final int? lessonId;

  @override
  State<MissionPanel> createState() => _MissionPanelState();
}

class _MissionPanelState extends State<MissionPanel> {
  final _search = TextEditingController();
  var _videoOrder = false;
  var _source = 1;
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
    _search.dispose();
    super.dispose();
  }

  List<LessonMission> _ordered() {
    final items = List<LessonMission>.of(_all);
    if (!_videoOrder) return items;
    items.retainWhere((mission) => mission.videoSource == _source && mission.videoName != null);
    return items;
  }

  bool _locked(LessonMission mission, List<LessonMission> ordered) {
    final index = ordered.indexOf(mission);
    if (index <= 0) return false;
    return !ordered[index - 1].done;
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final ordered = _ordered();
    final visible = ordered.where((mission) {
      if (query.isEmpty) return true;
      return mission.subject.toLowerCase().contains(query);
    }).toList();
    final open = visible.where((mission) => !mission.done).toList();
    final done = visible.where((mission) => mission.done).toList();
    final doneCount = _all.where((mission) => mission.done).length;
    final progress = _all.isEmpty ? 0.0 : doneCount / _all.length;

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
                    '$doneCount/${_all.length}',
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
                '$doneCount görev bitti · ${_all.length - doneCount} kaldı',
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
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: DbText.style(size: 15, weight: FontWeight.w700),
                cursorColor: DbColors.navy,
                decoration: InputDecoration(
                  hintText: 'Konu ara',
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
            if (_videoOrder) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _sourceChip(1),
                    const SizedBox(width: 8),
                    _sourceChip(2),
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
                      : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (open.isEmpty && done.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Text(
                        'Bu sırada görev yok.',
                        style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted),
                      ),
                    ),
                  for (final mission in open) ...[
                    _MissionCard(
                      mission: mission,
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
                  if (done.isNotEmpty)
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
                  if (_showDone)
                    for (final mission in done) ...[
                      const SizedBox(height: 12),
                      _MissionCard(
                        mission: mission,
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

  Widget _sourceChip(int source) {
    final selected = _source == source;
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
    required this.color,
    required this.videoOrder,
    required this.locked,
    required this.videos,
    required this.onChanged,
  });

  final LessonMission mission;
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ReportSheet(mission: mission),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.mission});

  final LessonMission mission;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  var _videoTab = false;
  var _saved = false;
  final _dogru = TextEditingController(text: '0');
  final _yanlis = TextEditingController(text: '0');
  final _bos = TextEditingController(text: '0');
  final _note = TextEditingController();
  final _teacher = TextEditingController();
  final _number = TextEditingController();

  @override
  void dispose() {
    _dogru.dispose();
    _yanlis.dispose();
    _bos.dispose();
    _note.dispose();
    _teacher.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ne yaptın?', style: DbText.style(size: 22, weight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              widget.mission.subject,
              style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted),
            ),
            const SizedBox(height: 14),
            Container(
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: DbColors.mist,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _tab('Soru Çözdüm', !_videoTab, () => setState(() => _videoTab = false)),
                  _tab('Video İzledim', _videoTab, () => setState(() => _videoTab = true)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_videoTab) ...[
              Text(widget.mission.source, style: DbText.style(size: 15, weight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _num('Doğru', _dogru),
                  const SizedBox(width: 8),
                  _num('Yanlış', _yanlis),
                  const SizedBox(width: 8),
                  _num('Boş', _bos),
                ],
              ),
            ] else ...[
              if (widget.mission.videoName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DbColors.mist,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill_rounded, color: DbColors.navy),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sıradaki video', style: DbText.style(size: 12, weight: FontWeight.w800, color: DbColors.muted)),
                            Text(widget.mission.videoName!, style: DbText.style(size: 15, weight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _field(_teacher, 'Anlatıcı'),
              const SizedBox(height: 8),
              _field(_number, 'Kaçıncı video?', number: true),
            ],
            const SizedBox(height: 12),
            _field(_note, 'Açıklama'),
            if (_saved) ...[
              const SizedBox(height: 12),
              Text('Kaydedildi', style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.navy)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _saved = true),
              style: FilledButton.styleFrom(
                backgroundColor: DbColors.navy,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Kaydet', style: DbText.style(size: 16, weight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: DbText.style(size: 13, weight: FontWeight.w800, color: selected ? DbColors.ink : DbColors.muted),
          ),
        ),
      ),
    );
  }

  Widget _num(String label, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DbText.style(size: 12, weight: FontWeight.w800, color: DbColors.muted)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: DbText.style(size: 16, weight: FontWeight.w800),
            decoration: InputDecoration(
              filled: true,
              fillColor: DbColors.mist,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: DbText.style(size: 15, weight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: DbText.style(size: 14, weight: FontWeight.w700, color: const Color(0xFF9AA3B2)),
        filled: true,
        fillColor: DbColors.mist,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
