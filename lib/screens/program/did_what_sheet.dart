import 'package:flutter/material.dart';

import '../../data/site_session.dart';
import '../../theme/db_theme.dart';

Future<void> showDidWhat(
  BuildContext context, {
  required int? missionId,
  required int? subjectId,
  required String lesson,
  required String subject,
  String? videoName,
  String? videoUrl,
  int? videoOrder,
  String? teacherName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => DidWhatSheet(
      missionId: missionId,
      subjectId: subjectId,
      lesson: lesson,
      subject: subject,
      videoName: videoName,
      videoUrl: videoUrl,
      videoOrder: videoOrder,
      teacherName: teacherName,
    ),
  );
}

class DidWhatSheet extends StatefulWidget {
  const DidWhatSheet({
    super.key,
    required this.missionId,
    required this.subjectId,
    required this.lesson,
    required this.subject,
    this.videoName,
    this.videoUrl,
    this.videoOrder,
    this.teacherName,
  });

  final int? missionId;
  final int? subjectId;
  final String lesson;
  final String subject;
  final String? videoName;
  final String? videoUrl;
  final int? videoOrder;
  final String? teacherName;

  @override
  State<DidWhatSheet> createState() => _DidWhatSheetState();
}

class _DidWhatSheetState extends State<DidWhatSheet> {
  var _videoTab = false;
  var _showAll = false;
  var _othersOpen = false;
  var _loading = false;
  var _saving = false;
  String? _error;
  String? _saved;
  List<_Bank> _banks = [];
  List<_Bank> _otherBanks = [];
  List<_Teacher> _teachers = [];
  List<_VideoSource> _sources = [];
  List<String> _past = [];
  _Bank? _bank;
  _Teacher? _teacher;
  _VideoSource? _source;
  final _soru = TextEditingController(text: '0');
  final _dogru = TextEditingController(text: '0');
  final _yanlis = TextEditingController(text: '0');
  final _bos = TextEditingController(text: '0');
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.missionId != null) _load();
  }

  @override
  void dispose() {
    _soru.dispose();
    _dogru.dispose();
    _yanlis.dispose();
    _bos.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SiteSession.instance.reportPanel(widget.missionId!, showAll: _showAll);
      final banks = <_Bank>[];
      final others = <_Bank>[];
      final rawBanks = data['questionBanks'];
      if (rawBanks is List) {
        for (final item in rawBanks) {
          if (item is! Map) continue;
          final id = _asInt(item['id']);
          if (id == null || id == 9999999) continue;
          final assigned = item['is_assigned'] == true || item['is_assigned'] == 1;
          final hidden = item['is_vitrine_hidden'] == true || item['is_vitrine_hidden'] == 1;
          final bank = _Bank(id, item['name']?.toString() ?? 'Kaynak', _image(item['image']?.toString()), assigned && !hidden);
          if (!_showAll || bank.assigned) {
            banks.add(bank);
          } else {
            others.add(bank);
          }
        }
      }
      if (_showAll && banks.isEmpty) {
        banks.addAll(others);
        others.clear();
      }
      final teachers = <_Teacher>[];
      final rawTeachers = data['videoTeachers'];
      if (rawTeachers is List) {
        for (final item in rawTeachers) {
          if (item is! Map) continue;
          final id = _asInt(item['id']);
          if (id == null) continue;
          teachers.add(_Teacher(id, item['name']?.toString() ?? 'Anlatıcı'));
        }
      }
      final assigned = data['assignedVideo'];
      _Teacher? teacher;
      if (assigned is Map) {
        final id = _asInt(assigned['video_teacher_id']);
        if (id != null) {
          for (final item in teachers) {
            if (item.id == id) teacher = item;
          }
          teacher ??= _Teacher(id, assigned['video_teacher_name']?.toString() ?? 'Anlatıcı');
        }
      }
      final past = <String>[];
      final reports = data['reports'];
      if (reports is List) {
        for (final report in reports.take(4)) {
          if (report is! Map) continue;
          final type = report['report_type']?.toString() ?? 'rapor';
          final when = report['created_at']?.toString() ?? '';
          past.add('$type · $when');
        }
      }
      final sources = _readSources(data['lessonVideoPack']);
      if (!mounted) return;
      setState(() {
        _banks = banks;
        _otherBanks = others;
        _teachers = teachers;
        _teacher = teacher ?? _teacher;
        _sources = sources;
        _source = _pickSource(sources);
        _bank = _bank ?? banks.where((bank) => bank.assigned).firstOrNull ?? (banks.isEmpty ? null : banks.first);
        _past = past;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is SiteException ? error.message : 'Rapor paneli açılmadı.';
      });
    }
  }

  _VideoSource? _pickSource(List<_VideoSource> sources) {
    if (sources.isEmpty) return null;
    if (sources.length == 1) return sources.first;
    for (final source in sources) {
      if (source.index == _source?.index) return source;
    }
    return sources.first;
  }

  List<_VideoSource> _readSources(dynamic pack) {
    if (pack is! Map) return const [];
    final raw = pack['sources'];
    if (raw is! List) return const [];
    final sources = <_VideoSource>[];
    for (final src in raw) {
      if (src is! Map) continue;
      final index = _asInt(src['sourceIndex']) ?? sources.length + 1;
      final videos = <_PackVideo>[];
      final byVideo = src['by_video'];
      if (byVideo is Map) {
        for (final meta in byVideo.values) {
          if (meta is! Map) continue;
          final orderRaw = meta['order'];
          final order = orderRaw is int ? orderRaw : int.tryParse('$orderRaw') ?? videos.length;
          videos.add(
            _PackVideo(
              name: meta['video_name']?.toString() ?? 'Video',
              url: meta['video_url']?.toString(),
              order: order + 1,
              teacherId: _asInt(meta['video_teacher_id']),
              teacherName: meta['video_teacher_name']?.toString(),
            ),
          );
        }
      }
      videos.sort((a, b) => a.order.compareTo(b.order));
      sources.add(
        _VideoSource(
          index,
          src['qbName']?.toString().trim().isNotEmpty == true ? src['qbName'].toString() : '$index. Kaynak',
          _asInt(src['qbId']),
          videos,
        ),
      );
    }
    sources.sort((a, b) => a.index.compareTo(b.index));
    return sources;
  }

  String? _image(String? image) {
    if (image == null || image.isEmpty) return null;
    if (image.startsWith('http')) return image;
    return '${SiteSession.files}/storage/$image';
  }

  Future<void> _save() async {
    final missionId = widget.missionId;
    final subjectId = widget.subjectId;
    if (missionId == null) return;
    if (!_videoTab) {
      final bank = _bank;
      if (bank == null || subjectId == null) {
        setState(() => _error = 'Kaynak veya konu bulunamadı.');
        return;
      }
      final soru = int.tryParse(_soru.text) ?? 0;
      final dogru = int.tryParse(_dogru.text) ?? 0;
      final yanlis = int.tryParse(_yanlis.text) ?? 0;
      final bos = int.tryParse(_bos.text) ?? 0;
      if (soru > 0 && dogru + yanlis + bos < soru) {
        setState(() => _error = '$soru soru girdin. Doğru, yanlış ve boş toplamı en az $soru olmalı.');
        return;
      }
      setState(() {
        _saving = true;
        _error = null;
      });
      try {
        final message = await SiteSession.instance.saveReport({
          'mission_id': missionId,
          'studentNotes': _note.text,
          'questionBanks': [
            {
              'bankId': bank.id,
              'subjects': {
                '$subjectId': {
                  'selected': '1',
                  'soruSayisi': soru,
                  'dogruSayisi': dogru,
                  'yanlisSayisi': yanlis,
                  'bosSayisi': bos,
                },
              },
            },
          ],
        });
        if (!mounted) return;
        setState(() {
          _saving = false;
          _saved = message;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = error is SiteException ? error.message : 'Rapor kaydedilemedi.';
        });
      }
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await SiteSession.instance.saveReport({
        'mission_id': missionId,
        'video': '1',
        'videoTeacherId': _teacher?.id,
        'videoNumber': widget.videoOrder,
        'videoSourceIndex': _source?.index,
        'videoSourceQbId': _source?.qbId,
        'videoSourceName': _source?.name,
        'studentNotes': _note.text,
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is SiteException ? error.message : 'Rapor kaydedilemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final konu = widget.subject.isEmpty ? widget.videoName ?? 'Görev' : widget.subject;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Neler yaptın?', style: DbText.style(size: 22, weight: FontWeight.w900))),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _showAll = !_showAll);
                          _load();
                        },
                  child: Text(
                    _showAll ? 'Atananlar' : 'Tümü',
                    style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.navy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.lesson.isEmpty ? konu : '${widget.lesson} > $konu',
              style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted),
            ),
            if (widget.missionId == null) ...[
              const SizedBox(height: 16),
              Text(
                'Bu kayıt sunucudaki göreve bağlı değil.',
                style: DbText.style(size: 15, weight: FontWeight.w800),
              ),
            ] else if (_loading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator(color: DbColors.navy)),
              const SizedBox(height: 28),
            ] else ...[
              if (_past.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Geçmiş raporlar', style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted)),
                for (final line in _past)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(line, style: DbText.style(size: 13, weight: FontWeight.w700)),
                  ),
              ],
              const SizedBox(height: 14),
              Container(
                height: 42,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: DbColors.mist, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    _tab('Soru Çözdüm', !_videoTab, () => setState(() => _videoTab = false)),
                    _tab('Video İzledim', _videoTab, () => setState(() => _videoTab = true)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!_videoTab) ...[
                if (_banks.isEmpty)
                  Text('Atanmış kaynak yok.', style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted))
                else
                  _bankRow(_banks),
                if (_showAll && _otherBanks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _othersOpen = !_othersOpen),
                    child: Text(
                      'Diğer kaynaklar (${_otherBanks.length})',
                      style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.navy),
                    ),
                  ),
                  if (_othersOpen) _bankRow(_otherBanks),
                ],
                const SizedBox(height: 12),
                Text(konu, style: DbText.style(size: 15, weight: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _num('Soru', _soru),
                    const SizedBox(width: 8),
                    _num('Doğru', _dogru),
                    const SizedBox(width: 8),
                    _num('Yanlış', _yanlis),
                    const SizedBox(width: 8),
                    _num('Boş', _bos),
                  ],
                ),
              ] else ...[
                if (_sources.length > 1) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final source in _sources)
                        GestureDetector(
                          onTap: () => setState(() => _source = source),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _source?.index == source.index ? DbColors.navy : DbColors.mist,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              source.name,
                              style: DbText.style(
                                size: 13,
                                weight: FontWeight.w800,
                                color: _source?.index == source.index ? Colors.white : DbColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if ((_source?.videos ?? const <_PackVideo>[]).isEmpty && widget.videoName == null)
                  Text('Bu kaynakta video yok.', style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted))
                else
                  for (final video in _source?.videos ?? const <_PackVideo>[])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_fill_rounded, color: DbColors.navy),
                      title: Text(video.name, style: DbText.style(size: 14, weight: FontWeight.w800)),
                      subtitle: Text(
                        '${video.order}. video${video.teacherName == null ? '' : ' · ${video.teacherName}'}',
                        style: DbText.style(size: 12, weight: FontWeight.w700, color: DbColors.muted),
                      ),
                      onTap: () {
                        setState(() {
                          if (video.teacherId == null) return;
                          _Teacher? match;
                          for (final item in _teachers) {
                            if (item.id == video.teacherId) match = item;
                          }
                          _teacher = match ?? _Teacher(video.teacherId!, video.teacherName ?? 'Anlatıcı');
                        });
                      },
                    ),
                if ((_source?.videos.isEmpty ?? true) && widget.videoName != null)
                  Text(
                    '${widget.videoOrder != null ? '${widget.videoOrder}. ' : ''}${widget.videoName}',
                    style: DbText.style(size: 16, weight: FontWeight.w900),
                  ),
                if (_teachers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final teacher in _teachers)
                        GestureDetector(
                          onTap: () => setState(() => _teacher = teacher),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _teacher?.id == teacher.id ? DbColors.navy : DbColors.mist,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              teacher.name,
                              style: DbText.style(
                                size: 13,
                                weight: FontWeight.w800,
                                color: _teacher?.id == teacher.id ? Colors.white : DbColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                style: DbText.style(size: 15, weight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'Açıklama',
                  filled: true,
                  fillColor: DbColors.mist,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.red)),
              ],
              if (_saved != null) ...[
                const SizedBox(height: 10),
                Text(_saved!, style: DbText.style(size: 14, weight: FontWeight.w800, color: DbColors.navy)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: DbColors.navy,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _saving ? 'Kaydediliyor' : 'Kaydet',
                  style: DbText.style(size: 16, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bankRow(List<_Bank> banks) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: banks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final bank = banks[index];
          final selected = _bank?.id == bank.id;
          return GestureDetector(
            onTap: () => setState(() => _bank = bank),
            child: Container(
              width: 148,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE8EEF8) : DbColors.mist,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? DbColors.navy : Colors.transparent, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bank.image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        bank.image!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.menu_book_rounded, color: DbColors.navy),
                      ),
                    )
                  else
                    const Icon(Icons.menu_book_rounded, color: DbColors.navy),
                  const Spacer(),
                  Text(
                    bank.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DbText.style(size: 12, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        },
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
}

int? _asInt(dynamic value) {
  if (value == null || value == false) return null;
  if (value is int) return value == 0 ? null : value;
  final parsed = int.tryParse(value.toString());
  if (parsed == null || parsed == 0) return null;
  return parsed;
}

class _Bank {
  const _Bank(this.id, this.name, this.image, this.assigned);

  final int id;
  final String name;
  final String? image;
  final bool assigned;
}

class _Teacher {
  const _Teacher(this.id, this.name);

  final int id;
  final String name;
}

class _PackVideo {
  const _PackVideo({required this.name, required this.order, this.url, this.teacherId, this.teacherName});

  final String name;
  final String? url;
  final int order;
  final int? teacherId;
  final String? teacherName;
}

class _VideoSource {
  const _VideoSource(this.index, this.name, this.qbId, this.videos);

  final int index;
  final String name;
  final int? qbId;
  final List<_PackVideo> videos;
}
