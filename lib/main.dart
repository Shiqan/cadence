import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CadenceApp());
}

class CadenceApp extends StatefulWidget {
  const CadenceApp({Key? key}) : super(key: key);

  @override
  State<CadenceApp> createState() => _CadenceAppState();
}

class _CadenceAppState extends State<CadenceApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    final light = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F6B45),
        surface: const Color(0xFFF6F0E6),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    final dark = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.tealAccent,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Cadence',
      theme: light,
      darkTheme: dark,
      themeMode: _themeMode,
      home: HomePage(
        onToggleTheme: () => setState(() => _themeMode =
            _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomePage({Key? key, required this.onToggleTheme}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Use ValueNotifiers so the UI can react without calling setState directly.
  final ValueNotifier<double> _bpm = ValueNotifier<double>(160); // default
  final ValueNotifier<bool> _running = ValueNotifier<bool>(false);
  Timer? _timer;
  late AnimationController _pulseController;
  late AudioPlayer _audioPlayer;
  // Counter used to play audio at half speed (one click every 2 visual beats).
  int _audioTickCounter = 0;
  final _notification = _NotificationService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Prepare a short click sound. Loading may fail if the asset isn't present;
    // that's non-fatal — the app will continue without sound.
    _audioPlayer = AudioPlayer();
    _audioPlayer.setAsset('assets/click.wav').catchError((e) {
      debugPrint('Failed to load click asset: $e');
      return null;
    });
    _notification.onNotificationTap = (payload) {
      // If user taps the notification while playing, stop playback.
      // Use the notifier to control state rather than calling setState here.
      if (_running.value) {
        _stop();
      }
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioPlayer.dispose();
    _bpm.dispose();
    _running.dispose();
    super.dispose();
  }

  void _start() {
    _running.value = true;
    _audioTickCounter = 0;
    _scheduleTimer();
    _notification.showPlaying(_bpm.value.toInt());
  }

  void _stop() {
    _running.value = false;
    _timer?.cancel();
    _notification.cancel();

    // reset audio counter so next start begins with the first audio tick
    _audioTickCounter = 0;

    // Reset the pulse animation so the UI returns to the idle state when stopped.
    if (_pulseController.isAnimating || _pulseController.value != 0.0) {
      _pulseController.reset();
    }

    // Stop any playing click immediately.
    _audioPlayer.stop();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    final intervalMs = (60000 / _bpm.value).round();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _tick());
  }

  void _tick() {
    // beat pulse: only trigger visual pulse on the same ticks we play audio
    // so the visual indicator matches the audible half-speed cadence.
    if (_audioTickCounter % 2 == 0) {
      _pulseController.forward(from: 0);
    }

    try {
      // Play audio only on every other tick so the perceived metronome
      // click is at half the displayed BPM (one click per two visual beats).
      if (_audioTickCounter % 2 == 0) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
      }
      _audioTickCounter = (_audioTickCounter + 1) % 2;
    } catch (e) {
      // ignore audio errors
    }

    if (_running.value) {
      _notification.updatePlaying(_bpm.value.toInt());
    }
  }

  void _onBpmChanged(double value) {
    _bpm.value = value.toDouble();

    if (_running.value) {
      _scheduleTimer();
      _notification.updatePlaying(_bpm.value.toInt());
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle theme',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    const baseAlpha = 0.12;
                    final ripple = baseAlpha +
                        Curves.easeOut.transform(1 - _pulseController.value) *
                            0.5;
                    return SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: color.withAlpha((ripple * 255).round()),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Center(
                            child: ValueListenableBuilder<double>(
                              valueListenable: _bpm,
                              builder: (context, bpm, _) => Text(
                                '${bpm.toInt()}',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(color: color),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('BPM', style: Theme.of(context).textTheme.titleMedium),
            ValueListenableBuilder<double>(
              valueListenable: _bpm,
              builder: (context, bpm, _) => Slider(
                value: bpm,
                min: 120,
                max: 200,
                divisions: 40,
                label: bpm.toInt().toString(),
                onChanged: _onBpmChanged,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _running,
                  builder: (context, running, _) => ElevatedButton.icon(
                    onPressed: running ? _stop : _start,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(running ? 'Stop' : 'Start'),
                  ),
                ),
                Text('Range 120 - 200',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _NotificationService {
  // No-op singleton used while notifications are removed.
  static final _NotificationService _singleton =
      _NotificationService._internal();
  factory _NotificationService() => _singleton;
  _NotificationService._internal();

  void Function(String? payload)? onNotificationTap;

  Future<void> init() async {
    // intentionally no-op
  }

  Future<void> showPlaying(int bpm) async {
    // intentionally no-op
  }

  Future<void> updatePlaying(int bpm) async {
    // intentionally no-op
  }

  Future<void> cancel() async {
    // intentionally no-op
  }
}
