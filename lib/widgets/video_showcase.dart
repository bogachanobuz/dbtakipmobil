import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/program/did_what_sheet.dart';
import '../theme/db_theme.dart';

class VideoTileData {
  const VideoTileData({
    required this.title,
    this.subject = '',
    this.url,
    this.order,
    this.teacher,
    this.done = false,
    this.onDone,
    this.onReport,
    this.missionId,
    this.subjectId,
    this.lesson = '',
  });

  final String title;
  final String subject;
  final String? url;
  final int? order;
  final String? teacher;
  final bool done;
  final VoidCallback? onDone;
  final VoidCallback? onReport;
  final int? missionId;
  final int? subjectId;
  final String lesson;

  String? get thumb => youtubeThumb(url);

  String get konu => subject.isEmpty ? title : subject;
}

String? youtubeThumb(String? url) {
  if (url == null || url.isEmpty) return null;
  final match = RegExp(
    r'(?:youtu\.be/|youtube\.com/(?:watch\?v=|embed/|shorts/|live/)|[?&]v=)([A-Za-z0-9_-]{11})',
  ).firstMatch(url);
  final id = match?.group(1);
  if (id == null) return null;
  return 'https://img.youtube.com/vi/$id/mqdefault.jpg';
}

class VideoShowcase extends StatelessWidget {
  const VideoShowcase({super.key, required this.videos, this.actions = true});

  final List<VideoTileData> videos;
  final bool actions;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return Text(
        'Bu kaynakta video yok.',
        style: DbText.style(size: 15, weight: FontWeight.w700, color: DbColors.muted),
      );
    }
    return Column(
      children: [
        for (final video in videos) ...[
          VideoCard(video: video, actions: actions),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class VideoCard extends StatefulWidget {
  const VideoCard({super.key, required this.video, required this.actions});

  final VideoTileData video;
  final bool actions;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late bool _done;

  @override
  void initState() {
    super.initState();
    _done = widget.video.done;
  }

  Future<void> _open() async {
    final url = widget.video.url;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final thumb = video.thumb;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: video.url == null ? null : _open,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 112,
                      height: 64,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumb != null)
                            Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              cacheWidth: 336,
                              cacheHeight: 192,
                              errorBuilder: (_, _, _) => const _ThumbFallback(),
                            )
                          else
                            const _ThumbFallback(),
                          if (video.url != null)
                            const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                            ),
                          if (video.order != null)
                            Positioned(
                              left: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${video.order}',
                                  style: DbText.style(size: 11, weight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(video.konu, style: DbText.style(size: 16, weight: FontWeight.w900, height: 1.15)),
                      if (video.title.isNotEmpty && video.title != video.konu) ...[
                        const SizedBox(height: 2),
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.muted, height: 1.2),
                        ),
                      ],
                      if (video.teacher != null && video.teacher!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          video.teacher!,
                          style: DbText.style(size: 12, weight: FontWeight.w700, color: DbColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (widget.actions) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _action('Ne yaptın?', () {
                  final report = widget.video.onReport;
                  if (report != null) {
                    report();
                    return;
                  }
                  showDidWhat(
                    context,
                    missionId: widget.video.missionId,
                    subjectId: widget.video.subjectId,
                    lesson: widget.video.lesson,
                    subject: widget.video.konu,
                    videoName: widget.video.title,
                    videoUrl: widget.video.url,
                    videoOrder: widget.video.order,
                    teacherName: widget.video.teacher,
                  );
                }, filled: false),
                const SizedBox(width: 8),
                _action('MEB', () => _meb(context), filled: false),
                const SizedBox(width: 8),
                _action(_done ? 'Geri al' : 'Tamamladım', () {
                  setState(() => _done = !_done);
                  video.onDone?.call();
                }, filled: true),
              ],
            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap, {required bool filled}) {
    return Expanded(
      child: Material(
        color: filled ? DbColors.navy : DbColors.mist,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: DbText.style(
                size: 13,
                weight: FontWeight.w800,
                color: filled ? Colors.white : DbColors.navy,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _meb(BuildContext context) {
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
              Text(widget.video.konu, style: DbText.style(size: 14, weight: FontWeight.w700, color: DbColors.muted)),
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
                        child: Center(child: Text(kind, style: DbText.style(size: 15, weight: FontWeight.w800))),
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

}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1A2845),
      child: Center(child: Icon(Icons.smart_display_rounded, color: Colors.white, size: 26)),
    );
  }
}

