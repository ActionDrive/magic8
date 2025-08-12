import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// URL прокси прокидывается из Codemagic: --dart-define=AI_BASE_URL=...
const _aiBaseUrl = String.fromEnvironment('AI_BASE_URL', defaultValue: '');

void main() => runApp(const Magic8App());

class Magic8App extends StatelessWidget {
  const Magic8App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Волшебный шар',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const Magic8Screen(),
    );
  }
}

class Magic8Screen extends StatefulWidget {
  const Magic8Screen({super.key});
  @override
  State<Magic8Screen> createState() => _Magic8ScreenState();
}

class _Magic8ScreenState extends State<Magic8Screen>
    with TickerProviderStateMixin {
  final _q = TextEditingController();
  final _fallback = const [
    'Да', 'Нет', 'Сомневаюсь', 'Спроси позже', 'Определённо да', 'Определённо нет'
  ];

  // анимация появления треугольника/жидкости
  late final AnimationController _reveal;
  late final Animation<double> _rise;   // поднимаем «жидкость»
  late final Animation<double> _alpha;  // прозрачность ответа

  // голос
  late final stt.SpeechToText _stt;
  bool _sttReady = false;
  bool _isListening = false;

  // shake
  StreamSubscription? _accSub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  bool _loading = false;
  String _answer = '';

  @override
  void initState() {
    super.initState();

    _reveal = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _rise  = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic);
    _alpha = CurvedAnimation(parent: _reveal, curve: const Interval(0.4, 1, curve: Curves.easeOut));

    _initSpeech();
    _initShake();
  }

  Future<void> _initSpeech() async {
    _stt = stt.SpeechToText();
    _sttReady = await _stt.initialize();
    setState(() {});
  }

  void _initShake() {
    // простая детекция тряски по резким скачкам ускорения
    const threshold = 16.0; // чувствительность
    const cooldown  = Duration(milliseconds: 800);

    _accSub = accelerometerEvents.listen((e) {
      final g = sqrt(e.x * e.x + e.y * e.y + e.z * e.z); // приблизительно
      if (g > threshold) {
        final now = DateTime.now();
        if (now.difference(_lastShake) > cooldown) {
          _lastShake = now;
          _onAsk();
        }
      }
    });
  }

  @override
  void dispose() {
    _accSub?.cancel();
    _stt.stop();
    _q.dispose();
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _onAsk() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _answer = ''; });
    _reveal.reset();

    final question = _q.text.trim().isEmpty
        ? 'Ответь как волшебный шар: коротко и по делу (да/нет/сомневаюсь/позже).'
        : _q.text.trim();

    final ai = await _askAI(question);
    setState(() {
      _answer = ai ?? _fallback[Random().nextInt(_fallback.length)];
      _loading = false;
    });
    _reveal.forward(); // показать треугольник
  }

  /// ИИ через твой прокси. Вернёт короткую фразу или null.
  Future<String?> _askAI(String q) async {
    if (_aiBaseUrl.isEmpty) return null;

    final base = _aiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final endpoints = <Uri>[
      Uri.parse('$base/v1/chat/completions'),
      Uri.parse('$base/chat'),
      Uri.parse('$base/'),
    ];

    final bodyOpenAI = {
      "model": "gpt-4o-mini",
      "temperature": 0.7,
      "max_tokens": 40,
      "messages": [
        {"role":"system","content":"Отвечай как Magic 8 Ball. Коротко: да/нет/сомневаюсь/позже и т.п."},
        {"role":"user","content": q}
      ]
    };
    final bodyChat = {
      "model":"gpt-4o-mini","prompt": q,"max_tokens": 40,"temperature": 0.7
    };

    for (final uri in endpoints) {
      try {
        final isOpen = uri.path.contains('/v1/chat/completions');
        final r = await http.post(
          uri,
          headers: const {'Content-Type':'application/json'},
          body: jsonEncode(isOpen ? bodyOpenAI : bodyChat),
        ).timeout(const Duration(seconds: 20));

        if (r.statusCode >= 200 && r.statusCode < 300) {
          final j = jsonDecode(r.body);
          final open = () {
            try { return (j['choices'][0]['message']['content'] as String?)?.trim(); } catch(_){ return null; }
          }();
          final chat = () {
            try { return (j['text'] as String?)?.trim(); } catch(_){ return null; }
          }();
          final txt = (open ?? chat);
          if (txt != null && txt.isNotEmpty) {
            return txt.split('\n').first;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _toggleListen() async {
    if (!_sttReady) {
      _sttReady = await _stt.initialize();
      if (!_sttReady) return;
    }
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    _q.clear();
    await _stt.listen(
      onResult: (res) {
        setState(() => _q.text = res.recognizedWords);
      },
      localeId: 'ru_RU',
      listenMode: stt.ListenMode.dictation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _q,
                maxLines: 1,
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _onAsk(),
                decoration: InputDecoration(
                  hintText: 'Сформулируй вопрос…',
                  hintStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Mic
            _iconBtn(
              context,
              icon: _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
              onTap: _toggleListen,
              tint: _isListening ? Colors.redAccent : null,
            ),
            const SizedBox(width: 8),
            // Send
            _iconBtn(
              context,
              icon: Icons.send_rounded,
              onTap: _loading ? null : _onAsk,
              busy: _loading,
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      appBar: AppBar(title: const Text('Волшебный шар')),
      body: Column(
        children: [
          top,
          Expanded(
            child: Center(
              child: SizedBox(
                width: 320, height: 320,
                child: CustomPaint(
                  painter: _BallPainter(), // сам шар (чёткий)
                  child: _TriangleAnswer( // треугольник с «жидкостью»
                    progress: _rise.value,  // 0→1 – поднимаем
                    opacity: _alpha.value,  // прозрачность
                    text: _answer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(BuildContext c,
      {required IconData icon, VoidCallback? onTap, bool busy=false, Color? tint}) {
    final color = tint ?? Theme.of(c).colorScheme.primary;
    return Material(
      color: color, borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: busy
              ? const SizedBox(width:18, height:18,
                  child: CircularProgressIndicator(strokeWidth:2, color: Colors.white))
              : Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

/// Рисуем шар (векторно): внешний градиент, внутреннее «окно», блик.
class _BallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) / 2;

    // внешний шар
    final outer = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF20252E), const Color(0xFF0B0E12)],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, outer);

    // внутреннее окно (где ответ) – чуть светлее, с виньеткой
    final innerR = r * 0.72;
    final inner = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1A1F27), const Color(0xFF0B0E12)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: innerR));
    canvas.drawCircle(c, innerR, inner);

    // бликаем сверху
    final highlight = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.18), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c.translate(-innerR*0.3, -innerR*0.6), radius: innerR*0.65));
    canvas.drawCircle(c.translate(-innerR*0.3, -innerR*0.6), innerR*0.65, highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Треугольник-«пирамидка» с анимацией подъёма жидкости и текстом.
class _TriangleAnswer extends StatelessWidget {
  final double progress; // 0..1 – уровень
  final double opacity;  // 0..1 – текст/плашка
  final String text;
  const _TriangleAnswer({required this.progress, required this.opacity, required this.text});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth; final h = c.maxHeight;
      final center = Offset(w/2, h/2);
      final radius = min(w, h) * 0.72 / 2;

      // Треугольник внутри круга
      final triSize = radius * 1.15;
      final p1 = center.translate(0, -triSize*0.55);
      final p2 = center.translate(-triSize*0.65, triSize*0.55);
      final p3 = center.translate(triSize*0.65, triSize*0.55);

      final path = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..lineTo(p3.dx, p3.dy)..close();

      // уровень жидкости: от низа треугольника вверх
      final minY = min(p1.dy, min(p2.dy, p3.dy));
      final maxY = max(p1.dy, max(p2.dy, p3.dy));
      final levelY = maxY - (maxY - minY) * progress.clamp(0, 1);

      return Stack(children: [
        // жидкость в треугольнике
        ClipPath(
          clipper: _PathClipper(path),
          child: CustomPaint(
            painter: _LiquidPainter(levelY: levelY),
            child: const SizedBox.expand(),
          ),
        ),
        // текст внутри треугольника
        if (text.isNotEmpty)
          Opacity(
            opacity: opacity,
            child: Center(
              child: SizedBox(
                width: triSize * 1.1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white,
                        height: 1.15, letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _LiquidPainter extends CustomPainter {
  final double levelY;
  _LiquidPainter({required this.levelY});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // фон жидкости (глубокий синий → светлее наверху)
    final paint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF0D3C6E), Color(0xFF2A73E8)],
        begin: Alignment.bottomCenter, end: Alignment.topCenter,
      ).createShader(rect);

    // прямоугольник от уровня до низа
    final path = Path()
      ..addRect(Rect.fromLTRB(0, levelY, size.width, size.height));
    canvas.drawPath(path, paint);

    // немного блика
    final gloss = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.08), Colors.transparent],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawPath(path, gloss);
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter old) => old.levelY != levelY;
}

class _PathClipper extends CustomClipper<Path> {
  final Path path;
  _PathClipper(this.path);
  @override
  Path getClip(Size size) => path;
  @override
  bool shouldReclip(covariant _PathClipper oldClipper) => false;
}
