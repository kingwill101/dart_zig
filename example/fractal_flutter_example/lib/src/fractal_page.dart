import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dart_zig/dart_zig.dart';
import 'package:flutter/material.dart';

import 'generated/api.g.dart';
import 'generated/runtime_bindings.g.dart' show createSession;

enum _Scene {
  overview('Overview', -0.5, 0, 3.2),
  seahorse('Seahorse Valley', -0.7435, 0.1314, 0.012),
  spiral('Spiral', -0.7453, 0.1127, 0.025);

  const _Scene(this.label, this.x, this.y, this.span);
  final String label;
  final double x;
  final double y;
  final double span;
}

enum _Resolution {
  small('640 × 420', 640, 420),
  medium('960 × 630', 960, 630),
  large('1280 × 840', 1280, 840);

  const _Resolution(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;
}

class FractalPage extends StatefulWidget {
  const FractalPage({super.key});

  @override
  State<FractalPage> createState() => _FractalPageState();
}

class _FractalPageState extends State<FractalPage> {
  NativeSession? _session;
  ZigApi? _api;
  ui.Image? _image;
  _Scene _scene = _Scene.overview;
  _Resolution _resolution = _Resolution.medium;
  double _centerX = _Scene.overview.x;
  double _centerY = _Scene.overview.y;
  double _span = _Scene.overview.span;
  int _zoomSteps = 0;
  int _iterations = 800;
  int _rowsReady = 0;
  int _stepsReady = 0;
  bool _busy = false;
  _Resolution? _displayedResolution;
  int? _displayedIterations;
  int? _displayedSteps;
  int? _displayedZoomSteps;
  Duration? _renderTime;
  Duration? _decodeTime;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final session = createSession(workers: 4);
        _session = session;
        _api = ZigApi(session);
        unawaited(_render());
      } catch (error) {
        setState(() => _error = '$error');
      }
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    final session = _session;
    if (session != null) unawaited(session.close());
    super.dispose();
  }

  Future<void> _render() async {
    final api = _api;
    if (api == null || _busy) return;
    final resolution = _resolution;
    final pixels = Uint8List(resolution.width * resolution.height * 4);
    final iterations = _iterations;
    final centerX = _centerX;
    final centerY = _centerY;
    final pixelScale = _span / resolution.width;
    final zoomSteps = _zoomSteps;
    setState(() {
      _busy = true;
      _rowsReady = 0;
      _stepsReady = 0;
      _error = null;
    });

    final renderWatch = Stopwatch()..start();
    try {
      Future<void> renderStripe(int firstRow, int lastRow) async {
        var nextRow = firstRow;
        await for (final tile in api.render((
          width: resolution.width,
          height: resolution.height,
          firstRow: firstRow,
          lastRow: lastRow,
          maxIterations: iterations,
          centerX: centerX,
          centerY: centerY,
          pixelScale: pixelScale,
        ))) {
          final rows = (lastRow - tile.row).clamp(0, 16);
          final expected = rows * resolution.width * 4;
          if (tile.rgba.length != expected || tile.row != nextRow) {
            throw StateError('Native renderer returned an invalid tile');
          }
          final offset = tile.row * resolution.width * 4;
          pixels.setRange(offset, offset + expected, tile.rgba);
          nextRow += rows;
          if (mounted) {
            setState(() {
              _rowsReady += rows;
              _stepsReady += tile.steps;
            });
          }
        }
        if (nextRow != lastRow) {
          throw StateError(
            'Native renderer ended before its stripe was complete',
          );
        }
      }

      await Future.wait([
        for (var stripe = 0; stripe < 4; stripe++)
          renderStripe(
            stripe * resolution.height ~/ 4,
            (stripe + 1) * resolution.height ~/ 4,
          ),
      ]);
      renderWatch.stop();
      if (_rowsReady != resolution.height) {
        throw StateError('Native renderer ended before the image was complete');
      }

      final decodeWatch = Stopwatch()..start();
      final image = await _decode(pixels, resolution.width, resolution.height);
      decodeWatch.stop();
      if (!mounted) {
        image.dispose();
        return;
      }
      final oldImage = _image;
      setState(() {
        _image = image;
        _displayedResolution = resolution;
        _displayedIterations = iterations;
        _displayedSteps = _stepsReady;
        _displayedZoomSteps = zoomSteps;
        _renderTime = renderWatch.elapsed;
        _decodeTime = decodeWatch.elapsed;
        _busy = false;
      });
      if (oldImage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => oldImage.dispose());
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<ui.Image> _decode(Uint8List pixels, int width, int height) {
    final result = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      result.complete,
    );
    return result.future;
  }

  void _selectScene(_Scene scene) {
    setState(() {
      _scene = scene;
      _centerX = scene.x;
      _centerY = scene.y;
      _span = scene.span;
      _zoomSteps = 0;
    });
    unawaited(_render());
  }

  void _zoom(double factor) {
    setState(() {
      _span *= factor;
      _zoomSteps -= 1;
    });
    unawaited(_render());
  }

  void _zoomAt(TapUpDetails details, Size size) {
    if (_busy || _api == null) return;
    if (_span * 0.5 / _resolution.width < 1e-15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reached the f64 coordinate precision limit. Zoom out to continue.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _centerX += (details.localPosition.dx / size.width - 0.5) * _span;
      _centerY +=
          (details.localPosition.dy / size.height - 0.5) *
          _span *
          _resolution.height /
          _resolution.width;
      _span *= 0.5;
      _zoomSteps += 1;
    });
    unawaited(_render());
  }

  void _resetView() => _selectScene(_scene);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DART + ZIG / NATIVE COMPUTE',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Fractal Lab', style: theme.textTheme.displayMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Explore the Mandelbrot set. Four Zig workers compute RGBA tiles while Flutter keeps the controls and progress responsive.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _canvas(theme)),
                            const SizedBox(width: 20),
                            SizedBox(width: 300, child: _controls(theme)),
                          ],
                        )
                      else ...[
                        _canvas(theme),
                        const SizedBox(height: 20),
                        _controls(theme),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _canvas(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: _resolution.width / _resolution.height,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapUp: (details) => _zoomAt(
                  details,
                  Size(constraints.maxWidth, constraints.maxHeight),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: const Color(0xff070e18),
                      child: _image == null
                          ? const Center(child: Icon(Icons.blur_on, size: 96))
                          : RawImage(image: _image, fit: BoxFit.fill),
                    ),
                    if (_busy)
                      ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: Text(
                            'Rendering new view · ${(_rowsReady * 100 / _resolution.height).round()}%',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ),
                    if (_busy)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          value: _rowsReady / _resolution.height,
                          minHeight: 6,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _busy
                      ? 'Rendering $_rowsReady / ${_resolution.height} rows${_image == null ? '' : ' · previous image shown'}'
                      : 'Tap the image to zoom into a point',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (_displayedResolution != null)
                      _stat(
                        'Image',
                        '${(_displayedResolution!.width * _displayedResolution!.height / 1e6).toStringAsFixed(2)} MP',
                      ),
                    if (_displayedIterations != null)
                      _stat('Image iterations', '${_displayedIterations!} max'),
                    if (_displayedZoomSteps != null)
                      _stat('Zoom', '2^${_displayedZoomSteps!} from preset'),
                    if (_displayedSteps != null)
                      _stat(
                        'Work',
                        '${(_displayedSteps! / 1e6).toStringAsFixed(1)} M iterations',
                      ),
                    if (_renderTime != null)
                      _stat(
                        'Native stream',
                        '${_renderTime!.inMilliseconds} ms',
                      ),
                    if (_renderTime != null)
                      _stat(
                        'Pixel rate',
                        '${(_displayedResolution!.width * _displayedResolution!.height / (_renderTime!.inMicroseconds == 0 ? 1 : _renderTime!.inMicroseconds)).toStringAsFixed(2)} MP/s',
                      ),
                    if (_renderTime != null && _displayedSteps != null)
                      _stat(
                        'Iteration rate',
                        '${(_displayedSteps! / (_renderTime!.inMicroseconds == 0 ? 1 : _renderTime!.inMicroseconds)).toStringAsFixed(1)} M/s',
                      ),
                    if (_decodeTime != null)
                      _stat(
                        'Image decode',
                        '${_decodeTime!.inMilliseconds} ms',
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) =>
      Chip(label: Text('$label · $value'));

  Widget _controls(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Workload', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Scene', style: theme.textTheme.labelLarge),
            DropdownButton<_Scene>(
              value: _scene,
              isExpanded: true,
              onChanged: _busy
                  ? null
                  : (scene) {
                      if (scene != null) _selectScene(scene);
                    },
              items: [
                for (final scene in _Scene.values)
                  DropdownMenuItem(value: scene, child: Text(scene.label)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Resolution', style: theme.textTheme.labelLarge),
            DropdownButton<_Resolution>(
              value: _resolution,
              isExpanded: true,
              onChanged: _busy
                  ? null
                  : (resolution) {
                      if (resolution != null) {
                        setState(() => _resolution = resolution);
                        unawaited(_render());
                      }
                    },
              items: [
                for (final resolution in _Resolution.values)
                  DropdownMenuItem(
                    value: resolution,
                    child: Text(resolution.label),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Maximum iterations · $_iterations',
              style: theme.textTheme.labelLarge,
            ),
            Slider(
              value: _iterations.toDouble(),
              min: 200,
              max: 2000,
              divisions: 9,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() => _iterations = value.round());
                    },
              onChangeEnd: _busy ? null : (_) => unawaited(_render()),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || _api == null
                  ? null
                  : () => unawaited(_render()),
              icon: const Icon(Icons.play_arrow),
              label: Text(_busy ? 'Rendering…' : 'Render in Zig'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy || _api == null ? null : () => _zoom(2),
              icon: const Icon(Icons.zoom_out),
              label: const Text('Zoom out'),
            ),
            TextButton.icon(
              onPressed: _busy || _api == null ? null : _resetView,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset to preset'),
            ),
            const SizedBox(height: 16),
            Text(
              'Each tile is computed after Dart grants stream credit. The displayed native stream time includes FFI delivery and Dart tile copies; image decode is shown separately.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
