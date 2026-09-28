import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/site_session.dart';
import '../../theme/db_theme.dart';

class ErrorSketchPage extends StatefulWidget {
  const ErrorSketchPage({
    super.key,
    required this.questionId,
    this.sketchPath,
    this.questionImagePath,
  });

  final int questionId;
  final String? sketchPath;
  final String? questionImagePath;

  @override
  State<ErrorSketchPage> createState() => _ErrorSketchPageState();
}

enum _SketchTool { pen, move, eraser }

class _Stroke {
  _Stroke({required this.color, required this.width, required this.erase});

  final Color color;
  final double width;
  final bool erase;
  final points = <Offset>[];
}

class _PlacedPhoto {
  _PlacedPhoto({required this.image, required this.offset, required this.scale});

  final ui.Image image;
  Offset offset;
  double scale;
}

class _ErrorSketchPageState extends State<ErrorSketchPage> {
  static const _colors = [Color(0xFF111827), Color(0xFF16A34A), Color(0xFF2563EB), Color(0xFFDC2626)];

  final _boardKey = GlobalKey();
  final _strokes = <_Stroke>[];
  final _photos = <_PlacedPhoto>[];
  ui.Image? _saved;
  _SketchTool _tool = _SketchTool.pen;
  Color _color = _colors.first;
  double _width = 3;
  _PlacedPhoto? _selected;
  var _saving = false;
  var _loadingSaved = false;
  Size _board = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _saved?.dispose();
    for (final photo in _photos) {
      photo.image.dispose();
    }
    super.dispose();
  }

  bool get _hasMarks => _strokes.isNotEmpty || _photos.isNotEmpty || _saved != null;

  Future<void> _loadSaved() async {
    final url = SiteSession.storageUrl(widget.sketchPath);
    if (url == null) return;
    setState(() => _loadingSaved = true);
    try {
      final image = await _imageFromUrl(url);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _saved = image;
        _loadingSaved = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<ui.Image> _imageFromUrl(String url) async {
    final res = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) throw SiteException('Görsel okunamadı.');
    return decodeImageFromList(Uint8List.fromList(bytes));
  }

  Future<void> _addQuestion() async {
    final url = SiteSession.storageUrl(widget.questionImagePath);
    if (url == null) {
      _toast('Bu kayıtta eklenecek soru görseli yok.');
      return;
    }
    try {
      final image = await _imageFromUrl(url);
      if (!mounted) return;
      _place(image);
    } catch (_) {
      _toast('Soru görseli tahtaya yüklenemedi.');
    }
  }

  Future<void> _addGallery() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (shot == null) return;
    final image = await decodeImageFromList(await shot.readAsBytes());
    if (!mounted) return;
    _place(image);
  }

  void _place(ui.Image image) {
    final board = _board == Size.zero ? const Size(320, 420) : _board;
    final scale = math.min(board.width * 0.9 / image.width, board.height * 0.9 / image.height);
    final safe = scale.isFinite && scale > 0 ? scale : 1.0;
    final photo = _PlacedPhoto(
      image: image,
      offset: Offset((board.width - image.width * safe) / 2, (board.height - image.height * safe) / 2),
      scale: safe,
    );
    setState(() {
      _photos.add(photo);
      _selected = photo;
      _tool = _SketchTool.move;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clear() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Karalamayı temizle?', style: DbText.style(size: 18, weight: FontWeight.w900)),
        content: const Text('Çizim silinecek. Kayıtlı çözüm sunucuda kalır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _strokes.clear();
                for (final photo in _photos) {
                  photo.image.dispose();
                }
                _photos.clear();
                _selected = null;
                _saved?.dispose();
                _saved = null;
              });
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_strokes.isEmpty && _photos.isEmpty && _saved == null) {
      _toast('Önce bir şeyler karala.');
      return;
    }
    final boundary = _boardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _saving = true);
    try {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw SiteException('Çizim hazırlanamadı.');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sketch_${widget.questionId}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      final path = await SiteSession.instance.saveErrorSketch(widget.questionId, file.path);
      if (!mounted) return;
      Navigator.of(context).pop(path);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(error is SiteException ? error.message : 'Çözüm karalaması kaydedilemedi.');
    }
  }

  void _start(Offset point) {
    if (_tool == _SketchTool.move) {
      _selected = _hit(point);
      return;
    }
    setState(() {
      _strokes.add(_Stroke(color: _color, width: _width, erase: _tool == _SketchTool.eraser)..points.add(point));
    });
  }

  void _move(Offset point) {
    if (_tool == _SketchTool.move) {
      final photo = _selected;
      if (photo == null) return;
      setState(() => photo.offset += point);
      return;
    }
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.points.add(point));
  }

  _PlacedPhoto? _hit(Offset point) {
    for (final photo in _photos.reversed) {
      final rect = Rect.fromLTWH(
        photo.offset.dx,
        photo.offset.dy,
        photo.image.width * photo.scale,
        photo.image.height * photo.scale,
      );
      if (rect.contains(point)) return photo;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        title: Text('Karalama Defteri', style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _toolButton(Icons.edit_rounded, _tool == _SketchTool.pen, () => setState(() => _tool = _SketchTool.pen)),
                _toolButton(Icons.open_with_rounded, _tool == _SketchTool.move, () => setState(() => _tool = _SketchTool.move)),
                _toolButton(Icons.auto_fix_normal_rounded, _tool == _SketchTool.eraser, () => setState(() => _tool = _SketchTool.eraser)),
                const SizedBox(width: 8),
                for (final color in _colors)
                  GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 34),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == color ? DbColors.ink : Colors.white, width: 2),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _width,
                    min: 1,
                    max: 24,
                    activeColor: DbColors.navy,
                    onChanged: (value) => setState(() => _width = value),
                  ),
                ),
                TextButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add_rounded), label: const Text('Soruyu ekle')),
                IconButton(onPressed: _addGallery, icon: const Icon(Icons.image_outlined, color: DbColors.navy)),
                IconButton(onPressed: _clear, icon: const Icon(Icons.delete_outline_rounded, color: DbColors.navy)),
                TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Kaydediliyor' : 'Çözüm olarak kaydet')),
              ],
            ),
          ),
          if (_tool == _SketchTool.move && _selected != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _selected!.scale = math.max(0.08, _selected!.scale - 0.08)),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Text('Boyut', style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.muted)),
                IconButton(
                  onPressed: () => setState(() => _selected!.scale = math.min(6, _selected!.scale + 0.08)),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _board = Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onPanStart: (details) => _start(details.localPosition),
                    onPanUpdate: (details) => _move(_tool == _SketchTool.move ? details.delta : details.localPosition),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(
                            key: _boardKey,
                            child: CustomPaint(
                              painter: _SketchPainter(saved: _saved, photos: _photos, strokes: _strokes),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          if (_loadingSaved) const Center(child: CircularProgressIndicator(color: DbColors.navy)),
                          if (!_loadingSaved && !_hasMarks)
                            IgnorePointer(
                              child: Center(
                                child: Text(
                                  'Burada çöz / karala',
                                  style: DbText.style(size: 16, weight: FontWeight.w800, color: DbColors.muted),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, bool on, VoidCallback tap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 28),
      child: Material(
        color: on ? DbColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 40, height: 40, child: Icon(icon, color: on ? Colors.white : DbColors.ink, size: 20)),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({required this.saved, required this.photos, required this.strokes});

  final ui.Image? saved;
  final List<_PlacedPhoto> photos;
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final saved = this.saved;
    if (saved != null) {
      final scale = math.min(size.width / saved.width, size.height / saved.height);
      final w = saved.width * scale;
      final h = saved.height * scale;
      canvas.drawImageRect(
        saved,
        Rect.fromLTWH(0, 0, saved.width.toDouble(), saved.height.toDouble()),
        Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
        Paint(),
      );
    }
    for (final photo in photos) {
      canvas.drawImageRect(
        photo.image,
        Rect.fromLTWH(0, 0, photo.image.width.toDouble(), photo.image.height.toDouble()),
        Rect.fromLTWH(photo.offset.dx, photo.offset.dy, photo.image.width * photo.scale, photo.image.height * photo.scale),
        Paint(),
      );
    }
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final width = stroke.erase ? math.max(12, stroke.width * 4).toDouble() : stroke.width;
      final paint = Paint()
        ..color = stroke.erase ? Colors.white : stroke.color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, width / 2, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
