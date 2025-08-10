import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'services/answer_engine.dart';
import 'settings.dart';
import 'l10n.dart';

void main() {
  runApp(const ProviderScope(child: Magic8App()));
}

class Magic8App extends ConsumerWidget {
  const Magic8App({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings?.themeMode ?? ThemeMode.system;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Magic 8',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      themeMode: themeMode,
      home: settings == null ? const Scaffold(body: Center(child: CircularProgressIndicator())) : const HomeScreen(),
    );
  }
}

final speechProvider = Provider<stt.SpeechToText>((ref) => stt.SpeechToText());
final ttsProvider = Provider<FlutterTts>((ref) => FlutterTts());

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _accelSub;
  double _shakeThreshold = 18;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  final _controller = TextEditingController();
  bool _listening = false;
  String? _lastAnswer;
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _accelSub = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShake).inMilliseconds > 1200) {
          _lastShake = now;
          _onAsk();
        }
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _controller.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _onAsk() async {
    HapticFeedback.lightImpact();
    final engine = ref.read(engineProvider);
    final tts = ref.read(ttsProvider);
    final settings = ref.read(settingsProvider)!;
    final text = _controller.text.trim();
    final question = text.isEmpty ? null : text;
    setState(() => _lastAnswer = "…");
    _anim.forward(from: 0);
    final answer = await engine.answer(question: question, settings: settings);
    setState(() => _lastAnswer = answer);
    try {
      await tts.setLanguage(settings.locale.startsWith('ru') ? 'ru-RU' : 'en-US');
      await tts.speak(answer);
    } catch (_) {}
  }

  Future<void> _toggleVoice() async {
    final speech = ref.read(speechProvider);
    if (!_listening) {
      bool available = await speech.initialize();
      if (available) {
        setState(() => _listening = true);
        final localeId = ref.read(settingsProvider)!.locale.startsWith('ru') ? 'ru_RU' : 'en_US';
        speech.listen(localeId: localeId, onResult: (res) => _controller.text = res.recognizedWords);
      }
    } else {
      speech.stop();
      setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (settings == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final l10n = L10n(settings.locale);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('app_title')), actions: [
        IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings)),
      ]),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _onAsk(),
                decoration: InputDecoration(
                  hintText: l10n.t('hint'),
                  prefixIcon: IconButton(onPressed: _toggleVoice, icon: Icon(_listening ? Icons.mic : Icons.mic_none)),
                  suffixIcon: IconButton(onPressed: _onAsk, icon: const Icon(Icons.send)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(300),
                      child: Image.asset('assets/ball.jpg', width: 260, height: 260, fit: BoxFit.cover),
                    ),
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.66), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                        alignment: Alignment.center, padding: const EdgeInsets.all(16),
                        child: Text(_lastAnswer ?? l10n.t('shake'), key: ValueKey(_lastAnswer), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.t('tap_or_shake'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider)!;
    final c = ref.read(settingsProvider.notifier);
    final l10n = L10n(s.locale);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.t('theme'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (set) => c.update(s.copyWith(themeMode: set.first)),
          ),
          const SizedBox(height: 24),
          SwitchListTile(title: Text(l10n.t('ai_on')), value: s.aiOn, onChanged: (v) => c.update(s.copyWith(aiOn: v))),
          TextField(decoration: InputDecoration(labelText: l10n.t('base_url'), hintText: 'https://your-proxy.workers.dev'), controller: TextEditingController(text: s.baseUrl), onSubmitted: (v) => c.update(s.copyWith(baseUrl: v))),
          TextField(decoration: InputDecoration(labelText: l10n.t('api_key'), hintText: 'proxy-key (если нужен)'), controller: TextEditingController(text: s.apiKey), obscureText: true, onSubmitted: (v) => c.update(s.copyWith(apiKey: v))),
          TextField(decoration: InputDecoration(labelText: l10n.t('model'), hintText: 'gpt-4o-mini'), controller: TextEditingController(text: s.model), onSubmitted: (v) => c.update(s.copyWith(model: v))),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: s.locale, decoration: const InputDecoration(labelText: 'Language'),
            items: const [
              DropdownMenuItem(value: 'ru', child: Text('Русский')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (v) => c.update(s.copyWith(locale: v)),
          ),
        ],
      ),
    );
  }
}
