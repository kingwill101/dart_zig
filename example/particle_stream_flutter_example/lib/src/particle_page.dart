import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:particle_stream_flutter_example/src/generated/generated.dart';

import 'process_rss_native.dart'
    if (dart.library.js_interop) 'process_rss_web.dart'
    as process_rss;

const _imageWidth = 160;
const _imageHeight = 90;
const _imageBytes = _imageWidth * _imageHeight * 4;

typedef _Frame = ({
  int sequence,
  int collisions,
  double meanSpeed,
  int liveNativeBytes,
  Uint8List rgba,
});

class ParticlePage extends StatefulWidget {
  const ParticlePage({super.key});

  @override
  State<ParticlePage> createState() => _ParticlePageState();
}

class _ParticlePageState extends State<ParticlePage> {
  NativeSession? _session;
  ZigApi? _api;
  StreamSubscription<_Frame>? _subscription;
  ui.Image? _image;
  final _clock = Stopwatch()..start();
  final _fpsHistory = <double>[];
  int _generation = 0;
  int _particleCount = 100000;
  int _activeCount = 100000;
  int _targetFps = 30;
  int _seed = 42;
  int _lastPresentedUs = 0;
  int _sequence = 0;
  int _collisions = 0;
  int _liveNativeBytes = 0;
  int _processRss = 0;
  double _meanSpeed = 0;
  double _fps = 0;
  bool _paused = false;
  bool _restarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final session = createSession(workers: 1);
        _session = session;
        _api = ZigApi(session);
        _start();
      } catch (error) {
        setState(() => _error = '$error');
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    _image?.dispose();
    unawaited(_shutdown());
    super.dispose();
  }

  Future<void> _shutdown() async {
    await _subscription?.cancel();
    await _session?.close();
  }

  void _start() {
    final api = _api;
    if (api == null || _subscription != null) return;
    final generation = ++_generation;
    final count = _particleCount;
    final seed = _seed++;
    try {
      late StreamSubscription<_Frame> subscription;
      subscription = api
          .simulate((particleCount: count, seed: seed))
          .listen(
            (frame) {
              // Pausing before the synchronous stream callback returns prevents
              // the session from granting another production credit.
              subscription.pause(_presentFrame(frame, generation));
            },
            onError: (Object error, StackTrace stack) => _reportError(error),
            onDone: () {
              if (mounted && generation == _generation) {
                setState(() => _subscription = null);
              }
            },
          );
      setState(() {
        _subscription = subscription;
        _activeCount = count;
        _paused = false;
        _error = null;
        _sequence = 0;
        _fps = 0;
        _lastPresentedUs = 0;
        _fpsHistory.clear();
      });
    } catch (error) {
      _reportError(error);
    }
  }

  Future<void> _presentFrame(_Frame frame, int generation) async {
    final work = Stopwatch()..start();
    try {
      if (frame.rgba.length != _imageBytes) {
        throw StateError('Zig stream returned an invalid heatmap');
      }
      final image = await _decode(frame.rgba);
      if (!mounted || generation != _generation) {
        image.dispose();
        return;
      }

      final nowUs = _clock.elapsedMicroseconds;
      final elapsedUs = nowUs - _lastPresentedUs;
      final instantFps = elapsedUs > 0 ? 1000000 / elapsedUs : 0.0;
      final previousImage = _image;
      setState(() {
        _image = image;
        _sequence = frame.sequence;
        _collisions = frame.collisions;
        _liveNativeBytes = frame.liveNativeBytes;
        if (frame.sequence % 30 == 1) {
          _processRss = process_rss.currentProcessRss();
        }
        _meanSpeed = frame.meanSpeed;
        if (_lastPresentedUs != 0) {
          _fps = _fps == 0 ? instantFps : _fps * 0.8 + instantFps * 0.2;
          _fpsHistory.add(_fps);
          if (_fpsHistory.length > 90) _fpsHistory.removeAt(0);
        }
        _lastPresentedUs = nowUs;
      });
      if (previousImage != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => previousImage.dispose(),
        );
      }

      final remainingUs = (1000000 ~/ _targetFps) - work.elapsedMicroseconds;
      if (remainingUs > 0) {
        await Future<void>.delayed(Duration(microseconds: remainingUs));
      }
    } catch (error) {
      _reportError(error);
    }
  }

  Future<ui.Image> _decode(Uint8List rgba) {
    final result = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      _imageWidth,
      _imageHeight,
      ui.PixelFormat.rgba8888,
      result.complete,
    );
    return result.future;
  }

  void _reportError(Object error) {
    if (!mounted) return;
    setState(() => _error = '$error');
    unawaited(_stop());
  }

  Future<void> _stop() async {
    final old = _subscription;
    _generation++;
    _subscription = null;
    if (mounted) setState(() => _paused = false);
    await old?.cancel();
  }

  Future<void> _restart() async {
    if (_restarting) return;
    setState(() => _restarting = true);
    await _stop();
    if (!mounted) return;
    setState(() => _restarting = false);
    _start();
  }

  void _togglePause() {
    final subscription = _subscription;
    if (subscription == null) return;
    if (_paused) {
      subscription.resume();
    } else {
      subscription.pause();
    }
    setState(() => _paused = !_paused);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 950;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1450),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DART + ZIG / CREDITED LIVE STREAM',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Particle Field',
                        style: theme.textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Zig tracks up to 250,000 moving particles. Flutter receives a 160 × 90 density frame and live counters, then grants credit for the next frame.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _visualization(theme)),
                            const SizedBox(width: 20),
                            SizedBox(width: 310, child: _controls(theme)),
                          ],
                        )
                      else ...[
                        _visualization(theme),
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

  Widget _visualization(ThemeData theme) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: _imageWidth / _imageHeight,
          child: ColoredBox(
            color: const Color(0xff05101b),
            child: _image == null
                ? const Center(child: CircularProgressIndicator())
                : RawImage(image: _image, fit: BoxFit.fill),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _paused ? Icons.pause_circle : Icons.circle,
                    color: _paused
                        ? Colors.amberAccent
                        : theme.colorScheme.primary,
                    size: 12,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _subscription == null
                        ? 'Stopped'
                        : _paused
                        ? 'Paused · Zig state retained'
                        : 'Live · frame $_sequence',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _stat(
                    'Tracked',
                    '${(_activeCount / 1000).toStringAsFixed(0)}k',
                  ),
                  _stat(
                    'Zig state',
                    '${(_liveNativeBytes / 1048576).toStringAsFixed(2)} MiB',
                  ),
                  if (_processRss > 0)
                    _stat(
                      'Process RSS',
                      '${(_processRss / 1048576).toStringAsFixed(0)} MiB',
                    ),
                  _stat('Actual rate', '${_fps.toStringAsFixed(1)} fps'),
                  _stat(
                    'Updates',
                    '${(_activeCount * _fps / 1e6).toStringAsFixed(1)} M/s',
                  ),
                  _stat(
                    'Transfer',
                    '${(_imageBytes * _fps / 1048576).toStringAsFixed(2)} MiB/s',
                  ),
                  _stat('Wall hits', '$_collisions / frame'),
                  _stat('Mean speed', _meanSpeed.toStringAsFixed(4)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              Text(
                'Delivered frames per second',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: CustomPaint(
                  painter: _RatePainter(
                    List.of(_fpsHistory),
                    _targetFps.toDouble(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _stat(String title, String value) =>
      Chip(label: Text('$title · $value'));

  Widget _controls(ThemeData theme) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Simulation', style: theme.textTheme.titleLarge),
          const SizedBox(height: 18),
          Text(
            'Zig particles · ${(_particleCount / 1000).round()}k',
            style: theme.textTheme.labelLarge,
          ),
          Slider(
            value: _particleCount.toDouble(),
            min: 25000,
            max: 250000,
            divisions: 9,
            onChanged: _restarting
                ? null
                : (value) => setState(() => _particleCount = value.round()),
            onChangeEnd: _restarting ? null : (_) => unawaited(_restart()),
          ),
          const SizedBox(height: 8),
          Text('Display cap', style: theme.textTheme.labelLarge),
          DropdownButton<int>(
            value: _targetFps,
            isExpanded: true,
            onChanged: (rate) {
              if (rate != null) setState(() => _targetFps = rate);
            },
            items: [
              for (final rate in [15, 30, 60])
                DropdownMenuItem(value: rate, child: Text('$rate fps')),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _restarting || _api == null
                ? null
                : _subscription == null
                ? _start
                : _togglePause,
            icon: Icon(
              _subscription == null || _paused ? Icons.play_arrow : Icons.pause,
            ),
            label: Text(
              _subscription == null
                  ? 'Start'
                  : _paused
                  ? 'Resume'
                  : 'Pause',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _restarting || _api == null
                ? null
                : () => unawaited(_restart()),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Restart simulation'),
          ),
          const SizedBox(height: 18),
          Text(
            'Particle positions and velocities stay in Zig. Only the heatmap and counters cross the transport. Pausing the Dart subscription withholds stream credit, so Zig does not work between frames.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Zig state counts live simulation buffers. On native platforms, process RSS also includes Flutter, Dart, libraries, and heap pages retained for reuse.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RatePainter extends CustomPainter {
  _RatePainter(this.values, this.target);

  final List<double> values;
  final double target;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = const Color(0xff425466)
      ..strokeWidth = 1;
    final guideY = size.height * (1 - target / 75);
    canvas.drawLine(Offset(0, guideY), Offset(size.width, guideY), guide);
    if (values.length < 2) return;
    final line = Paint()
      ..color = const Color(0xff56e4c9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = index * size.width / 89;
      final y = size.height * (1 - values[index].clamp(0, 75) / 75);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _RatePainter oldDelegate) => true;
}
