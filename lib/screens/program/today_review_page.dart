import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/error_book.dart';
import '../../data/site_session.dart';
import '../../theme/db_theme.dart';

class TodayReviewPage extends StatefulWidget {
  const TodayReviewPage({super.key, required this.questions});

  final List<ErrorQuestion> questions;

  @override
  State<TodayReviewPage> createState() => _TodayReviewPageState();
}

class _TodayReviewPageState extends State<TodayReviewPage> {
  final _player = AudioPlayer();
  var _index = 0;
  var _busy = false;
  var _correctCount = 0;
  String? _picked;
  bool? _right;
  var _finished = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  ErrorQuestion? get _question {
    if (_index < 0 || _index >= widget.questions.length) return null;
    return widget.questions[_index];
  }

  Future<void> _tone(List<double> freqs, int ms) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(_wav(freqs, ms, 0.35), mimeType: 'audio/wav'));
    } catch (_) {}
  }

  Future<void> _pick(String letter) async {
    final question = _question;
    if (question == null || _busy || _picked != null) return;
    setState(() => _busy = true);
    try {
      final data = await SiteSession.instance.checkErrorAnswer(question.id, letter);
      question.studentAnswer = letter;
      question.applyReview(data);
      final right = data['is_correct'] == true;
      if (!mounted) return;
      if (right) {
        _correctCount += 1;
        HapticFeedback.mediumImpact();
        _tone([523, 659, 784], 280);
      } else {
        HapticFeedback.heavyImpact();
        _tone([196, 165], 220);
      }
      setState(() {
        _picked = letter;
        _right = right;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final message = error is SiteException ? error.message : 'Cevap gönderilemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _next() {
    if (_index >= widget.questions.length - 1) {
      setState(() => _finished = true);
      _tone([392, 523, 659], 320);
      return;
    }
    setState(() {
      _index += 1;
      _picked = null;
      _right = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    final progress = total == 0 ? 0.0 : (_finished ? 1.0 : _index / total);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: total == 0
            ? Center(
                child: Text(
                  'Bugün bekleyen tekrar yok.',
                  style: DbText.style(size: 16, weight: FontWeight.w800),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: DbColors.muted),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress),
                              duration: const Duration(milliseconds: 280),
                              builder: (context, value, _) {
                                return LinearProgressIndicator(
                                  value: value,
                                  minHeight: 14,
                                  backgroundColor: const Color(0xFFE6E6E6),
                                  color: DbColors.navy,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _finished ? _doneView() : _questionView()),
                ],
              ),
      ),
    );
  }

  Widget _questionView() {
    final question = _question!;
    final image = SiteSession.storageUrl(question.imagePath);
    final checked = _picked != null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Image.asset('assets/dungeon/dungeon_robot.png', height: 92, fit: BoxFit.contain),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Text('Doğru şık hangisi?', style: DbText.style(size: 16, weight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    image,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                )
              else
                Text(question.preview, style: DbText.style(size: 20, weight: FontWeight.w900, height: 1.3)),
              const SizedBox(height: 8),
              Text(
                question.subjectName ?? (question.lessonKey == '__other__' ? 'Diğer' : question.lessonKey),
                style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted),
              ),
              const SizedBox(height: 14),
              for (final letter in question.options) _choice(letter, checked),
            ],
          ),
        ),
        if (checked) _feedback(),
      ],
    );
  }

  Widget _choice(String letter, bool checked) {
    final picked = _picked == letter;
    final good = picked && _right == true;
    final bad = picked && _right == false;
    final border = good
        ? DbColors.navy
        : bad
            ? DbColors.red
            : DbColors.line;
    final fill = good
        ? DbColors.mist
        : bad
            ? const Color(0xFFFFF1F0)
            : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: checked || _busy ? null : () => _pick(letter),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 2),
            ),
            child: Text(letter, style: DbText.style(size: 18, weight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }

  Widget _feedback() {
    final good = _right == true;
    final color = good ? DbColors.navy : DbColors.red;
    final wash = good ? DbColors.mist : const Color(0xFFFFF1F0);
    return Container(
      width: double.infinity,
      color: wash,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            good ? 'Harika!' : 'Olmadı',
            style: DbText.style(size: 22, weight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Devam', style: DbText.style(size: 16, weight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneView() {
    final total = widget.questions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          const Spacer(),
          Image.asset('assets/dungeon/dungeon_robot.png', height: 200, fit: BoxFit.contain),
          const SizedBox(height: 12),
          Text('Tekrar bitti', style: DbText.style(size: 28, weight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            '$_correctCount / $total doğru',
            style: DbText.style(size: 18, weight: FontWeight.w800, color: DbColors.navy),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: DbColors.navy,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Bitti', style: DbText.style(size: 16, weight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

Uint8List _wav(List<double> freqs, int ms, double volume) {
  const rate = 22050;
  final count = rate * ms ~/ 1000;
  final data = ByteData(44 + count * 2);
  final samples = <int>[];
  for (var i = 0; i < count; i++) {
    final env = 1 - (i / count);
    var mix = 0.0;
    for (final freq in freqs) {
      mix += math.sin(2 * math.pi * freq * i / rate);
    }
    mix = mix / freqs.length * volume * env;
    samples.add((mix * 32767).clamp(-32767, 32767).toInt());
  }
  void writeString(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeString(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}
