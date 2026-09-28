import 'dart:convert';
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
  var _closing = false;
  var _canLeave = false;
  String? _serverPath;
  Size _board = Size.zero;

  @override
  void initState() {
    super.initState();
    _serverPath = widget.sketchPath;
    _restore();
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

  Future<Directory> _folder() async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/sketch_${widget.questionId}');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    return folder;
  }

  Future<void> _restore() async {
    final folder = await _folder();
    final cleared = File('${folder.path}/cleared').existsSync();
    final file = File('${folder.path}/board.json');
    if (file.existsSync()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          final strokes = <_Stroke>[];
          final rows = raw['strokes'];
          if (rows is List) {
            for (final row in rows) {
              if (row is! Map) continue;
              final stroke = _Stroke(
                color: Color((row['c'] as num?)?.toInt() ?? 0xFF111827),
                width: (row['w'] as num?)?.toDouble() ?? 3,
                erase: row['e'] == true,
              );
              final points = row['p'];
              if (points is List) {
                for (final point in points) {
                  if (point is List && point.length >= 2) {
                    stroke.points.add(Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()));
                  }
                }
              }
              if (stroke.points.isNotEmpty) strokes.add(stroke);
            }
          }
          final photos = <_PlacedPhoto>[];
          final photoRows = raw['photos'];
          if (photoRows is List) {
            for (final row in photoRows) {
              if (row is! Map) continue;
              final name = row['file']?.toString();
              if (name == null) continue;
              final bytesFile = File('${folder.path}/$name');
              if (!bytesFile.existsSync()) continue;
              final image = await decodeImageFromList(await bytesFile.readAsBytes());
              photos.add(
                _PlacedPhoto(
                  image: image,
                  offset: Offset((row['x'] as num?)?.toDouble() ?? 0, (row['y'] as num?)?.toDouble() ?? 0),
                  scale: (row['s'] as num?)?.toDouble() ?? 1,
                ),
              );
            }
          }
          if (!mounted) return;
          setState(() {
            _strokes.addAll(strokes);
            _photos.addAll(photos);
          });
          return;
        }
      } catch (_) {}
    }
    if (cleared || !mounted) return;
    await _loadSaved();
  }

  Future<void> _persist() async {
    final folder = await _folder();
    final clearedMark = File('${folder.path}/cleared');
    if (_strokes.isEmpty && _photos.isEmpty) {
      final board = File('${folder.path}/board.json');
      if (board.existsSync()) board.deleteSync();
      return;
    }
    if (clearedMark.existsSync()) clearedMark.deleteSync();
    final photoJson = <Map<String, Object>>[];
    for (var i = 0; i < _photos.length; i++) {
      final photo = _photos[i];
      final name = 'p$i.png';
      final data = await photo.image.toByteData(format: ui.ImageByteFormat.png);
      if (data != null) {
        await File('${folder.path}/$name').writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      photoJson.add({'file': name, 'x': photo.offset.dx, 'y': photo.offset.dy, 's': photo.scale});
    }
    final payload = {
      'strokes': [
        for (final stroke in _strokes)
          {
            'c': stroke.color.toARGB32(),
            'w': stroke.width,
            'e': stroke.erase,
            'p': [
              for (final point in stroke.points) [point.dx, point.dy],
            ],
          },
      ],
      'photos': photoJson,
    };
    await File('${folder.path}/board.json').writeAsString(jsonEncode(payload), flush: true);
  }

  Future<void> _markCleared() async {
    final folder = await _folder();
    final board = File('${folder.path}/board.json');
    if (board.existsSync()) board.deleteSync();
    await File('${folder.path}/cleared').writeAsString('1');
  }

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
    _persist();
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
              _markCleared();
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
      await _persist();
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw SiteException('Çizim hazırlanamadı.');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sketch_${widget.questionId}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      final path = await SiteSession.instance.saveErrorSketch(widget.questionId, file.path);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverPath = path;
      });
      _toast('Çözüm karalaması kaydedildi.');
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

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _persist();
    if (!mounted) return;
    setState(() => _canLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(_serverPath);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: DbColors.ink,
        leading: IconButton(onPressed: _close, icon: const Icon(Icons.arrow_back_rounded)),
        title: Text('Karalama Defteri', style: DbText.style(size: 18, weight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    _toolButton(Icons.edit_rounded, _tool == _SketchTool.pen, () => setState(() => _tool = _SketchTool.pen)),
                    _toolButton(Icons.open_with_rounded, _tool == _SketchTool.move, () => setState(() => _tool = _SketchTool.move)),
                    _toolButton(Icons.auto_fix_normal_rounded, _tool == _SketchTool.eraser, () => setState(() => _tool = _SketchTool.eraser)),
                    for (final color in _colors)
                      GestureDetector(
                        onTap: () => setState(() => _color = color),
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: _color == color ? DbColors.ink : Colors.white, width: 2),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Slider(
                        value: _width,
                        min: 1,
                        max: 24,
                        activeColor: DbColors.navy,
                        onChanged: (value) => setState(() => _width = value),
                      ),
                    ),
                    Text('${_width.round()}', style: DbText.style(size: 12, weight: FontWeight.w800, color: DbColors.muted)),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('Soruyu ekle', style: DbText.style(size: 13, weight: FontWeight.w800, color: DbColors.navy)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    IconButton(
                      onPressed: _addGallery,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.image_outlined, color: DbColors.navy, size: 20),
                    ),
                    IconButton(
                      onPressed: _clear,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Tüm sayfayı sil',
                      icon: const Icon(Icons.delete_outline_rounded, color: DbColors.navy, size: 20),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: DbColors.navy,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: Icon(_saving ? Icons.hourglass_top_rounded : Icons.save_outlined, size: 16),
                      label: Text(
                        _saving ? 'Kaydediliyor' : 'Çözüm olarak kaydet',
                        style: DbText.style(size: 12, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
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
                    onPanEnd: (_) => _persist(),
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
    ),
    );
  }

  Widget _toolButton(IconData icon, bool on, VoidCallback tap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: on ? DbColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 34, height: 34, child: Icon(icon, color: on ? Colors.white : DbColors.ink, size: 18)),
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
