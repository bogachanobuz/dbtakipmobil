import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/error_book.dart';
import '../../data/site_session.dart';
import '../../theme/db_theme.dart';

class ErrorSolutionPanel extends StatefulWidget {
  const ErrorSolutionPanel({super.key, required this.question});

  final ErrorQuestion question;

  @override
  State<ErrorSolutionPanel> createState() => _ErrorSolutionPanelState();
}

class _ErrorSolutionPanelState extends State<ErrorSolutionPanel> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _youtube = TextEditingController();
  MediaQuota _quota = const MediaQuota(photoRemaining: 100, photoLimit: 100, videoRemaining: 20, videoLimit: 20);
  var _recording = false;
  var _busy = false;
  String? _notice;

  ErrorQuestion get question => widget.question;

  @override
  void initState() {
    super.initState();
    _youtube.text = question.solutionVideoUrl ?? '';
    _loadQuota();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _youtube.dispose();
    super.dispose();
  }

  Future<void> _loadQuota() async {
    try {
      final quota = await SiteSession.instance.mediaQuota();
      if (mounted) setState(() => _quota = quota);
    } catch (_) {}
  }

  void _say(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
  }

  Future<void> _upload(String type, String path, String filename) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final size = await file.length();
    if (type == 'audio' && size > 20 * 1024 * 1024) {
      _say('Ses dosyası 20 MB sınırını aşıyor.');
      return;
    }
    if (type == 'video' && size > 100 * 1024 * 1024) {
      _say('Video dosyası 100 MB sınırını aşıyor.');
      return;
    }
    if (type == 'photo' && _quota.photoRemaining <= 0) {
      _say('Bu ay fotoğraf hakkın doldu (${_quota.photoLimit}/ay). Silmek hakkı geri getirmez.');
      return;
    }
    if (type == 'video' && _quota.videoRemaining <= 0) {
      _say('Bu ay video hakkın doldu (${_quota.videoLimit}/ay). Silmek hakkı geri getirmez.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await SiteSession.instance.uploadSolutionMedia(question.id, type, path, filename);
      if (type == 'audio') question.solutionAudioPath = result.path;
      if (type == 'video') question.solutionVideoPath = result.path;
      if (type == 'photo') question.solutionPhotoPath = result.path;
      if (!mounted) return;
      setState(() {
        _quota = result.quota;
        _busy = false;
        _notice = result.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _say(error is SiteException ? error.message : 'Çözüm yüklenemedi.');
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) await _upload('audio', path, 'solution.m4a');
      return;
    }
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      _say('Mikrofon izni gerekli.');
      return;
    }
    final dir = await getTemporaryDirectory();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: '${dir.path}/solution_${question.id}.m4a',
    );
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _pickAudio() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'aac', '3gp', 'amr']);
    if (picked.isEmpty) return;
    final file = picked.single;
    final path = file.path;
    if (path == null) return;
    await _upload('audio', path, file.name);
  }

  Future<void> _pickVideo() async {
    if (_quota.videoRemaining <= 0) {
      _say('Bu ay video hakkın doldu (${_quota.videoLimit}/ay). Silmek hakkı geri getirmez.');
      return;
    }
    final picked = await FilePicker.pickFiles(type: FileType.video);
    if (picked.isEmpty) return;
    final file = picked.single;
    final path = file.path;
    if (path == null) return;
    await _upload('video', path, file.name);
  }

  Future<void> _pickPhoto() async {
    if (_quota.photoRemaining <= 0) {
      _say('Bu ay fotoğraf hakkın doldu (${_quota.photoLimit}/ay). Silmek hakkı geri getirmez.');
      return;
    }
    final shot = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 2048, maxHeight: 2048);
    if (shot == null) return;
    await _upload('photo', shot.path, 'solution.jpg');
  }

  Future<void> _remove(String type) async {
    setState(() => _busy = true);
    try {
      final message = await SiteSession.instance.deleteSolutionMedia(question.id, type);
      if (type == 'audio') question.solutionAudioPath = null;
      if (type == 'video') question.solutionVideoPath = null;
      if (type == 'photo') question.solutionPhotoPath = null;
      if (type == 'audio') await _player.stop();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice = message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _say(error is SiteException ? error.message : 'Medya silinemedi.');
    }
  }

  Future<void> _saveYoutube() async {
    final raw = _youtube.text.trim();
    if (raw.isEmpty) return;
    setState(() => _busy = true);
    try {
      final saved = await SiteSession.instance.saveSolutionVideoUrl(question.id, raw);
      question.solutionVideoUrl = saved;
      if (!mounted) return;
      setState(() {
        _youtube.text = saved;
        _busy = false;
        _notice = 'YouTube linki kaydedildi.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _say(error is SiteException ? error.message : 'Sadece YouTube linki kabul edilir (youtube.com / youtu.be).');
    }
  }

  Future<void> _removeYoutube() async {
    setState(() => _busy = true);
    try {
      await SiteSession.instance.deleteSolutionVideoUrl(question.id);
      question.solutionVideoUrl = null;
      if (!mounted) return;
      setState(() {
        _youtube.clear();
        _busy = false;
        _notice = 'Link silindi.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _say(error is SiteException ? error.message : 'Link silinemedi.');
    }
  }

  Future<void> _open(String? raw) async {
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _listen() async {
    final url = SiteSession.storageUrl(question.solutionAudioPath);
    if (url == null) return;
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  @override
  Widget build(BuildContext context) {
    final audio = question.solutionAudioPath;
    final video = question.solutionVideoPath;
    final photo = SiteSession.storageUrl(question.solutionPhotoPath);
    final youtube = question.solutionVideoUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bu sorunun çözümleri', style: DbText.style(size: 16, weight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          'Foto kalan: ${_quota.photoRemaining}/${_quota.photoLimit} · Video kalan: ${_quota.videoRemaining}/${_quota.videoLimit} · Ses: sınırsız',
          style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.navy),
        ),
        const SizedBox(height: 10),
        _card(
          icon: Icons.mic_none_rounded,
          title: 'Ses',
          actions: [
            IconButton(
              onPressed: _busy ? null : _toggleRecord,
              tooltip: 'Ses kaydet',
              icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, color: DbColors.navy),
            ),
            IconButton(onPressed: _busy ? null : _pickAudio, tooltip: 'Ses dosyası yükle', icon: const Icon(Icons.upload_rounded, color: DbColors.navy)),
            if (audio != null)
              IconButton(onPressed: _busy ? null : () => _remove('audio'), tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded, color: DbColors.red)),
          ],
          child: audio == null
              ? Text(
                  _recording ? 'Kaydediliyor...' : 'Ses kaydı yok — mikrofona basarak kaydedebilirsin',
                  style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.navy),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: _listen, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Dinle')),
                ),
        ),
        const SizedBox(height: 10),
        _card(
          icon: Icons.videocam_outlined,
          title: 'Çözüm videosu',
          actions: [
            IconButton(
              onPressed: _busy || _quota.videoRemaining <= 0 ? null : _pickVideo,
              tooltip: _quota.videoRemaining <= 0 ? 'Bu ay video hakkın doldu' : 'Video yükle',
              icon: const Icon(Icons.upload_rounded, color: DbColors.navy),
            ),
            if (video != null)
              IconButton(onPressed: _busy ? null : () => _remove('video'), tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded, color: DbColors.red)),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (video == null)
                Text('Video dosyası yok', style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.navy))
              else
                TextButton.icon(
                  onPressed: () => _open(SiteSession.storageUrl(video)),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Oynat'),
                ),
              const SizedBox(height: 8),
              Text('Çözüm videosu linki (yalnızca YouTube)', style: DbText.style(size: 13, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _youtube,
                      decoration: _field('https://www.youtube.com/watch?v=...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _busy ? null : _saveYoutube, child: const Text('Kaydet')),
                  if (youtube != null)
                    IconButton(onPressed: _busy ? null : _removeYoutube, icon: const Icon(Icons.delete_outline_rounded, color: DbColors.red)),
                ],
              ),
              if (youtube != null)
                TextButton.icon(
                  onPressed: () => _open(youtube),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('YouTube’da aç'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          icon: Icons.photo_camera_outlined,
          title: 'Çözüm foto',
          actions: [
            IconButton(
              onPressed: _busy || _quota.photoRemaining <= 0 ? null : _pickPhoto,
              tooltip: _quota.photoRemaining <= 0 ? 'Bu ay fotoğraf hakkın doldu' : 'Foto yükle',
              icon: const Icon(Icons.upload_rounded, color: DbColors.navy),
            ),
            if (question.solutionPhotoPath != null)
              IconButton(onPressed: _busy ? null : () => _remove('photo'), tooltip: 'Sil', icon: const Icon(Icons.delete_outline_rounded, color: DbColors.red)),
          ],
          child: photo == null
              ? Text('Foto yok', style: DbText.style(size: 13, weight: FontWeight.w700, color: DbColors.navy))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(photo, height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
        ),
        if (_notice != null) ...[
          const SizedBox(height: 8),
          Text(_notice!, style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.navy)),
        ],
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required List<Widget> actions,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: DbColors.navy),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: DbText.style(size: 15, weight: FontWeight.w900))),
              ...actions,
            ],
          ),
          child,
        ],
      ),
    );
  }

  InputDecoration _field(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF6F3EE),
      hintStyle: DbText.style(size: 12, weight: FontWeight.w700, color: DbColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
