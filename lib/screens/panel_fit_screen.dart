import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termopaneli_app/painting/facade_mask_clipper.dart';
import 'package:termopaneli_app/painting/facade_mask_stroke_painter.dart';
import 'package:termopaneli_app/painting/house_template_painter.dart';
import 'package:termopaneli_app/routes/routes.dart';

/// **§8 + §9 MVP**: фото или шаблон дома, текстура панели из каталога; **несколько**
/// замкнутых областей обводки (текстура внутри объединения контуров). Маски шаблонов
/// хранятся отдельно по индексу силуэта ([SharedPreferences] `panel_fit_tpl_mask_*`).
///
/// Камера, ИИ, серверные шаблоны — **§16** / **«На потом»**.
class PanelFitScreen extends StatefulWidget {
  const PanelFitScreen({
    super.key,
    this.initialTextureUrl,
    this.initialPanelTitle,
  });

  /// При открытии с карточки панели — сразу сохраняется в prefs.
  final String? initialTextureUrl;
  final String? initialPanelTitle;

  @override
  State<PanelFitScreen> createState() => _PanelFitScreenState();
}

class _PanelFitScreenState extends State<PanelFitScreen> {
  static const String _prefsKeyImage = 'panel_fit_last_image_path';
  static const String _prefsKeyTemplate = 'panel_fit_template_index';
  static const String _prefsKeyTextureUrl = 'panel_fit_texture_image_url';
  static const String _prefsKeyTextureLabel = 'panel_fit_texture_panel_title';
  static const String _prefsKeyMask = 'panel_fit_facade_mask_norm_v1';

  static String _prefsKeyTemplateMask(int variant) => 'panel_fit_tpl_mask_$variant';

  static const double _minPointDistPx = 3.5;
  static const int _maxMaskPoints = 1600;

  final ImagePicker _picker = ImagePicker();
  final GlobalKey _captureKey = GlobalKey();
  File? _imageFile;
  int? _templateIndex;
  double _overlayOpacity = 0.22;
  String? _textureUrl;
  String? _textureTitle;
  bool _exporting = false;

  /// Замкнутые области (норм. 0…1). Текущий жест — [_currentStroke], до «Замкнуть область» / «Готово».
  final List<List<Offset>> _maskPolygons = <List<Offset>>[];
  final List<Offset> _currentStroke = <Offset>[];
  bool _maskEditMode = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  bool get _hasBackground => _imageFile != null || _templateIndex != null;

  bool get _hasCatalogTexture =>
      _textureUrl != null && _textureUrl!.trim().isNotEmpty;

  bool get _hasFacadeMask =>
      _hasBackground && _maskPolygons.any((List<Offset> p) => p.length >= 3);

  int _totalMaskPoints() {
    int n = _currentStroke.length;
    for (final List<Offset> p in _maskPolygons) {
      n += p.length;
    }
    return n;
  }

  List<Offset> _offsetsFromJsonList(List<dynamic> list) {
    return list.map((dynamic e) {
      final Map<String, dynamic> m = e as Map<String, dynamic>;
      return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
    }).toList();
  }

  /// Legacy: плоский массив точек. Новый формат: `{ "v": 2, "polygons": [ [...], ... ] }`.
  List<List<Offset>> _decodeMaskPolygons(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <List<Offset>>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        final List<Offset> pts = _offsetsFromJsonList(decoded);
        if (pts.length >= 3) {
          return <List<Offset>>[pts];
        }
        return <List<Offset>>[];
      }
      if (decoded is Map<String, dynamic>) {
        final Map<String, dynamic> m = decoded;
        if (m['v'] == 2 && m['polygons'] is List<dynamic>) {
          final List<List<Offset>> out = <List<Offset>>[];
          for (final dynamic poly in m['polygons'] as List<dynamic>) {
            if (poly is! List<dynamic>) {
              continue;
            }
            final List<Offset> pts = _offsetsFromJsonList(poly);
            if (pts.length >= 3) {
              out.add(pts);
            }
          }
          return out;
        }
      }
    } catch (_) {
      return <List<Offset>>[];
    }
    return <List<Offset>>[];
  }

  String _encodeMaskPolygons(List<List<Offset>> polys) {
    final List<List<Map<String, double>>> encoded = polys
        .where((List<Offset> p) => p.length >= 3)
        .map(
          (List<Offset> p) =>
              p.map((Offset o) => <String, double>{'x': o.dx, 'y': o.dy}).toList(),
        )
        .toList();
    return jsonEncode(<String, Object>{'v': 2, 'polygons': encoded});
  }

  /// Для сохранения при смене шаблона / уходе на фото: завершённые + текущий контур, если уже ≥3 точек.
  List<List<Offset>> _polygonsSnapshotForPrefs() {
    final List<List<Offset>> out = _maskPolygons
        .where((List<Offset> p) => p.length >= 3)
        .map((List<Offset> p) => List<Offset>.from(p))
        .toList();
    if (_currentStroke.length >= 3) {
      out.add(List<Offset>.from(_currentStroke));
    }
    return out;
  }

  bool get _hasPersistableMask => _polygonsSnapshotForPrefs().isNotEmpty;

  Future<void> _persistMask() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<List<Offset>> toSave = _polygonsSnapshotForPrefs();
    if (toSave.isEmpty) {
      if (_imageFile != null) {
        await prefs.remove(_prefsKeyMask);
      }
      if (_templateIndex != null) {
        await prefs.remove(_prefsKeyTemplateMask(_templateIndex!));
      }
      return;
    }
    final String json = _encodeMaskPolygons(toSave);
    if (_imageFile != null) {
      await prefs.setString(_prefsKeyMask, json);
    }
    if (_templateIndex != null) {
      await prefs.setString(_prefsKeyTemplateMask(_templateIndex!), json);
    }
  }

  Future<void> _clearMaskInPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_imageFile != null) {
      await prefs.remove(_prefsKeyMask);
    }
    if (_templateIndex != null) {
      await prefs.remove(_prefsKeyTemplateMask(_templateIndex!));
    }
  }

  void _appendMaskPointPx(Offset px, Size box) {
    final double w = box.width <= 0 ? 1 : box.width;
    final double h = box.height <= 0 ? 1 : box.height;
    final Offset n = Offset(
      (px.dx / w).clamp(0.0, 1.0),
      (px.dy / h).clamp(0.0, 1.0),
    );
    if (_totalMaskPoints() >= _maxMaskPoints) {
      return;
    }
    if (_currentStroke.isEmpty) {
      setState(() => _currentStroke.add(n));
      return;
    }
    final Offset last = _currentStroke.last;
    final Offset lastPx = Offset(last.dx * w, last.dy * h);
    if ((lastPx - px).distance < _minPointDistPx) {
      return;
    }
    setState(() => _currentStroke.add(n));
  }

  void _onMaskPanStart(DragStartDetails d, Size box) {
    _appendMaskPointPx(d.localPosition, box);
  }

  void _onMaskPanUpdate(DragUpdateDetails d, Size box) {
    _appendMaskPointPx(d.localPosition, box);
  }

  Future<void> _bootstrap() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String? texUrl;
    String? texLabel;
    final String? init = widget.initialTextureUrl?.trim();
    if (init != null && init.isNotEmpty) {
      texUrl = init;
      final String? t = widget.initialPanelTitle?.trim();
      texLabel = (t != null && t.isNotEmpty) ? t : null;
      await prefs.setString(_prefsKeyTextureUrl, texUrl);
      if (texLabel != null) {
        await prefs.setString(_prefsKeyTextureLabel, texLabel);
      } else {
        await prefs.remove(_prefsKeyTextureLabel);
      }
    } else {
      texUrl = prefs.getString(_prefsKeyTextureUrl);
      if (texUrl != null && texUrl.trim().isEmpty) {
        texUrl = null;
      }
      texLabel = prefs.getString(_prefsKeyTextureLabel);
      if (texLabel != null && texLabel.trim().isEmpty) {
        texLabel = null;
      }
    }

    int? templateIndex;
    File? imageFile;
    List<List<Offset>> maskPolys = <List<Offset>>[];
    final int? tid = prefs.getInt(_prefsKeyTemplate);
    if (tid != null && tid >= 0 && tid < HouseTemplatePainter.variantCount) {
      templateIndex = tid;
      maskPolys = _decodeMaskPolygons(prefs.getString(_prefsKeyTemplateMask(tid)));
    } else {
      final String? path = prefs.getString(_prefsKeyImage);
      if (path != null && path.isNotEmpty) {
        final File f = File(path);
        if (await f.exists()) {
          imageFile = f;
          maskPolys = _decodeMaskPolygons(prefs.getString(_prefsKeyMask));
        } else {
          await prefs.remove(_prefsKeyImage);
          await prefs.remove(_prefsKeyMask);
        }
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _textureUrl = texUrl;
      _textureTitle = texLabel;
      _templateIndex = templateIndex;
      _imageFile = imageFile;
      _maskPolygons
        ..clear()
        ..addAll(maskPolys);
      _currentStroke.clear();
      _maskEditMode = false;
    });
  }

  Future<void> _clearTexture() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyTextureUrl);
    await prefs.remove(_prefsKeyTextureLabel);
    if (!mounted) {
      return;
    }
    setState(() {
      _textureUrl = null;
      _textureTitle = null;
    });
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? x = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 82,
      );
      if (x == null || !mounted) {
        return;
      }
      final Directory dir = await getApplicationDocumentsDirectory();
      final String destName = 'panel_fit_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File dest = File('${dir.path}/$destName');
      await File(x.path).copy(dest.path);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_templateIndex != null && _hasPersistableMask) {
        await prefs.setString(
          _prefsKeyTemplateMask(_templateIndex!),
          _encodeMaskPolygons(_polygonsSnapshotForPrefs()),
        );
      }
      await prefs.remove(_prefsKeyTemplate);
      await prefs.remove(_prefsKeyMask);
      final String? old = prefs.getString(_prefsKeyImage);
      if (old != null && old.isNotEmpty && old != dest.path) {
        final File oldFile = File(old);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }
      await prefs.setString(_prefsKeyImage, dest.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _imageFile = dest;
        _templateIndex = null;
        _maskPolygons.clear();
        _currentStroke.clear();
        _maskEditMode = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выбрать фото: $e')),
      );
    }
  }

  Future<void> _selectTemplate(int index) async {
    if (_templateIndex == index && _imageFile == null) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_templateIndex != null &&
        _hasPersistableMask &&
        _templateIndex != index) {
      await prefs.setString(
        _prefsKeyTemplateMask(_templateIndex!),
        _encodeMaskPolygons(_polygonsSnapshotForPrefs()),
      );
    }
    final String? path = prefs.getString(_prefsKeyImage);
    await prefs.remove(_prefsKeyImage);
    await prefs.remove(_prefsKeyMask);
    if (path != null && path.isNotEmpty) {
      final File f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
    await prefs.setInt(_prefsKeyTemplate, index);
    final List<List<Offset>> nextMask =
        _decodeMaskPolygons(prefs.getString(_prefsKeyTemplateMask(index)));
    if (!mounted) {
      return;
    }
    setState(() {
      _templateIndex = index;
      _imageFile = null;
      _maskPolygons
        ..clear()
        ..addAll(nextMask);
      _currentStroke.clear();
      _maskEditMode = false;
    });
  }

  Future<void> _clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? path = prefs.getString(_prefsKeyImage);
    await prefs.remove(_prefsKeyImage);
    await prefs.remove(_prefsKeyTemplate);
    await prefs.remove(_prefsKeyMask);
    for (int v = 0; v < HouseTemplatePainter.variantCount; v++) {
      await prefs.remove(_prefsKeyTemplateMask(v));
    }
    if (path != null && path.isNotEmpty) {
      final File f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _imageFile = null;
      _templateIndex = null;
      _maskPolygons.clear();
      _currentStroke.clear();
      _maskEditMode = false;
    });
  }

  void _closeCurrentArea() {
    if (_currentStroke.length < 3) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Для одной области нужно минимум три точки.'),
        ),
      );
      return;
    }
    setState(() {
      _maskPolygons.add(List<Offset>.from(_currentStroke));
      _currentStroke.clear();
    });
  }

  Future<void> _finishMaskEdit() async {
    if (_currentStroke.length >= 3) {
      setState(() {
        _maskPolygons.add(List<Offset>.from(_currentStroke));
        _currentStroke.clear();
      });
    } else {
      setState(() => _currentStroke.clear());
    }
    if (!_maskPolygons.any((List<Offset> p) => p.length >= 3)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Нужна хотя бы одна замкнутая область (≥3 точек). '
            'После каждой зоны нажимайте «Замкнуть область» или завершите последнюю через «Готово».',
          ),
        ),
      );
      return;
    }
    setState(() => _maskEditMode = false);
    await _persistMask();
  }

  Future<void> _eraseMask() async {
    await _clearMaskInPrefs();
    if (!mounted) {
      return;
    }
    setState(() {
      _maskPolygons.clear();
      _currentStroke.clear();
      _maskEditMode = false;
    });
  }

  Widget _buildPreview() {
    if (_imageFile != null) {
      return Image.file(
        _imageFile!,
        fit: BoxFit.cover,
      );
    }
    if (_templateIndex != null) {
      return CustomPaint(
        painter: HouseTemplatePainter(variant: _templateIndex!),
        child: const SizedBox.expand(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTextureOverlay() {
    if (_hasCatalogTexture) {
      return Image.network(
        _textureUrl!.trim(),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder:
            (BuildContext context, Widget child, ImageChunkEvent? progress) {
          if (progress == null) {
            return child;
          }
          return const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
          return Image.asset(
            'assets/icons/app_icon.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    }
    return Image.asset(
      'assets/icons/app_icon.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _textureLayer() {
    return IgnorePointer(
      child: Opacity(
        opacity: _overlayOpacity,
        child: _buildTextureOverlay(),
      ),
    );
  }

  /// Только фон + текстура (без контура обводки) — для снимка в галерею / шаринга.
  Widget _buildCompositedCapture() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildPreview(),
        Positioned.fill(
          child: _hasFacadeMask
              ? ClipPath(
                  clipper: FacadeMaskClipper(
                    _maskPolygons
                        .map((List<Offset> p) => List<Offset>.from(p))
                        .toList(),
                  ),
                  child: _textureLayer(),
                )
              : _textureLayer(),
        ),
      ],
    );
  }

  Future<Uint8List?> _capturePngBytes() async {
    if (!context.mounted) {
      return null;
    }
    final double dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!context.mounted) {
      return null;
    }
    final RenderObject? ro = _captureKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) {
      return null;
    }
    final RenderRepaintBoundary boundary = ro;
    final ui.Image image = await boundary.toImage(pixelRatio: dpr);
    try {
      final ByteData? bd = await image.toByteData(format: ui.ImageByteFormat.png);
      return bd?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _saveToGallery() async {
    if (_maskEditMode) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Завершите обводку: нажмите «Готово».'),
          ),
        );
      }
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final Uint8List? bytes = await _capturePngBytes();
      if (!context.mounted) {
        return;
      }
      if (bytes == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось сформировать изображение.')),
        );
        return;
      }
      bool access = await Gal.hasAccess(toAlbum: true);
      if (!access) {
        access = await Gal.requestAccess(toAlbum: true);
      }
      if (!context.mounted) {
        return;
      }
      if (!access) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Нет доступа к фото: разрешите сохранение в настройках.')),
        );
        return;
      }
      await Gal.putImageBytes(
        bytes,
        name: 'panel_fit_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Сохранено в галерею')),
      );
    } on GalException catch (e) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Галерея: ${e.type.message}')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      if (context.mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _shareImage() async {
    if (_maskEditMode) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Завершите обводку: нажмите «Готово».'),
          ),
        );
      }
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final Uint8List? bytes = await _capturePngBytes();
      if (!context.mounted) {
        return;
      }
      if (bytes == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось сформировать изображение.')),
        );
        return;
      }
      final Directory dir = await getTemporaryDirectory();
      if (!context.mounted) {
        return;
      }
      final File out = File(
        '${dir.path}/panel_fit_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await out.writeAsBytes(bytes);
      if (!context.mounted) {
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(out.path, mimeType: 'image/png')],
          text: 'Примерка фасада',
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось поделиться: $e')),
      );
    } finally {
      if (context.mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Widget _buildPreviewStack() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size box = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              key: _captureKey,
              child: _buildCompositedCapture(),
            ),
            if (_hasBackground &&
                (_maskPolygons.any((List<Offset> p) => p.length >= 2) ||
                    _currentStroke.length >= 2) &&
                !_maskEditMode)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: FacadeMaskStrokePainter(
                      polygons: _maskPolygons,
                      currentStroke: const <Offset>[],
                    ),
                  ),
                ),
              ),
            if (_hasBackground && _maskEditMode)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (DragStartDetails d) => _onMaskPanStart(d, box),
                  onPanUpdate: (DragUpdateDetails d) => _onMaskPanUpdate(d, box),
                  child: CustomPaint(
                    painter: FacadeMaskStrokePainter(
                      polygons: _maskPolygons,
                      currentStroke: _currentStroke,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Примерка (MVP)'),
        actions: [
          if (_hasCatalogTexture)
            IconButton(
              tooltip: 'Стандартная текстура',
              onPressed: _clearTexture,
              icon: const Icon(Icons.layers_clear_outlined),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Своё фото или шаблон; текстура панели из каталога. Можно обвести '
              'несколько областей: после каждой — «Замкнуть область», затем «Готово».',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5C5C5C),
                  ),
            ),
          ),
          if (_hasCatalogTexture)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Панель: ${_textureTitle ?? "из каталога"}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Откройте термопанель в каталоге и нажмите «Примерка на фасаде», '
                'чтобы подставить её рисунок.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6E6E6E),
                    ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.catalog),
              child: const Text('Открыть каталог'),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: HouseTemplatePainter.variantCount + 1,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int i) {
                if (i == 0) {
                  return _TemplateChip(
                    label: 'Фото',
                    selected: _imageFile != null,
                    onTap: _pickFromGallery,
                    child: const Icon(Icons.photo_library_outlined, size: 32),
                  );
                }
                final int t = i - 1;
                final bool selected = _templateIndex == t;
                return _TemplateChip(
                  label: HouseTemplatePainter.labelFor(t),
                  selected: selected,
                  onTap: () => _selectTemplate(t),
                  child: CustomPaint(
                    painter: HouseTemplatePainter(variant: t),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: !_hasBackground
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Выберите шаблон выше или загрузите фото',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Выбрать фото'),
                        ),
                      ],
                    ),
                  )
                : ClipRect(child: _buildPreviewStack()),
          ),
          if (_hasBackground) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (!_maskEditMode)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _maskEditMode = true),
                      icon: const Icon(Icons.gesture_rounded),
                      label: const Text('Обвести фасад'),
                    )
                  else ...<Widget>[
                    FilledButton(
                      onPressed: _finishMaskEdit,
                      child: const Text('Готово'),
                    ),
                    OutlinedButton(
                      onPressed: _closeCurrentArea,
                      child: const Text('Замкнуть область'),
                    ),
                    OutlinedButton(
                      onPressed: _eraseMask,
                      child: const Text('Стереть обводку'),
                    ),
                  ],
                ],
              ),
            ),
            if (_maskEditMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Обведите зону пальцем, «Замкнуть область» — следующая зона. '
                  '«Готово» сохраняет все области; у каждого шаблона дома свой набор.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6E6E6E),
                      ),
                ),
              ),
          ],
          if (_hasBackground && !_maskEditMode) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _saveToGallery,
                      icon: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_alt_outlined),
                      label: const Text('В галерею'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _shareImage,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Поделиться'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_hasBackground) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: <Widget>[
                  Text(_hasCatalogTexture ? 'Наложение' : 'Текстура'),
                  Expanded(
                    child: Slider(
                      value: _overlayOpacity,
                      min: 0.05,
                      max: 0.55,
                      onChanged: (double v) => setState(() => _overlayOpacity = v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clear,
                      child: const Text('Сбросить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _pickFromGallery,
                      child: const Text('Другое фото'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFFCCCCCC),
            width: selected ? 2.5 : 1,
          ),
          color: const Color(0xFFF2F2F2),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: <Widget>[
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child)),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
