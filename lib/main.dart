import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const Magic8App());

// Берём базовый URL прокси из --dart-define (Codemagic его уже пробрасывает)
const _aiBaseUrl = String.fromEnvironment('AI_BASE_URL', defaultValue: '');

class Magic8App extends StatelessWidget {
  const Magic8App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Волшебный шар',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
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
    with SingleTickerProviderStateMixin {
  final TextEditingController _questionCtrl = TextEditingController();
  final List<String> _fallbackAnswers = const [
    'Да', 'Нет', 'Скорее да', 'Скорее нет',
    'Спроси позже', 'Есть сомнения', 'Определённо да', 'Определённо нет'
  ];

  late final AnimationController _c;
  late final Animation<double> _rot;
  late final Animation<double> _scale;

  String _answer = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _rot = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.22), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 0.22, end: -0.18), weight: 22),
      TweenSequenceItem(tween: Tween(begin: -0.18, end: 0.10), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.10, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.92).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.92, end: 1.04).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 30),
    ]).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _shakeAndAnswer() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    _c.forward(from: 0);

    final q = _questionCtrl.text.trim().isEmpty
        ? 'Дай короткий ответ, как в волшебном шаре: да/нет/сомневаюсь и т.п.'
        : _questionCtrl.text.trim();

    final ai = await _askAI(q);
    setState(() {
      _answer = ai ?? _randomFallback();
      _loading = false;
    });
  }

  String _randomFallback() {
    final rnd = Random();
    return _fallbackAnswers[rnd.nextInt(_fallbackAnswers.length)];
  }

  /// Запрос к твоему прокси. Возвращает короткий ответ или null при ошибке.
  Future<String?> _askAI(String question) async {
    if (_aiBaseUrl.isEmpty) return null;

    // Варианты путей. Поставь первый рабочий в своём воркере и можно оставить один.
    final tryEndpoints = <Uri>[
      // 1) Классический роут под OpenAI совместимые прокси (chat completions):
      Uri.parse('${_aiBaseUrl.replaceAll(RegExp(r"/$"), "")}/v1/chat/completions'),
      // 2) Кастомный «/chat» (часто в Cloudflare Worker)
      Uri.parse('${_aiBaseUrl.replaceAll(RegExp(r"/$"), "")}/chat'),
      // 3) На случай, если прокси ожидает просто POST на корень
      Uri.parse(_aiBaseUrl),
    ];

    final bodyOpenAI = {
      "model": "gpt-4o-mini",
      "temperature": 0.7,
      "max_tokens": 60,
      "messages": [
        {"role": "system", "content": "Отвечай кратко как шар предсказаний (да/нет/сомневаюсь/переспрашивай позже и т.п.)."},
        {"role": "user", "content": question}
      ]
    };

    // Вариант для кастомного /chat
    final bodyChat = {
      "model": "gpt-4o-mini",
      "prompt": question,
      "max_tokens": 60,
      "temperature": 0.7
    };

    for (final uri in tryEndpoints) {
      try {
        final isOpenAI = uri.path.contains('/v1/chat/completions');
        final resp = await http
            .post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                // Ключ не нужен – он лежит на прокси. Если у тебя требуется заголовок – добавь его тут.
              },
              body: jsonEncode(isOpenAI ? bodyOpenAI : bodyChat),
            )
            .timeout(const Duration(seconds: 25));

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final json = jsonDecode(resp.body);

          // Разбираем оба формата.
          // OpenAI совместимый:
          final openAiText = () {
            try {
              return (json['choices'][0]['message']['content'] as String?)?.trim();
            } catch (_) {
              return null;
            }
          }();

          // Кастомный /chat:
          final chatText = () {
            try {
              return (json['text'] as String?)?.trim();
            } catch (_) {
              return null;
            }
          }();

          final text = openAiText ?? chatText;
          if (text != null && text.isNotEmpty) {
            // Оставим 1–2 предложения/короткую фразу
            return text.split('\n').first.replaceAll(RegExp(r'\s+'), ' ').trim();
          }
        }
      } catch (_) {/* пробуем следующий эндпоинт */}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final topBar = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _questionCtrl,
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _shakeAndAnswer(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Сформулируй вопрос… затем нажми ►',
                  hintStyle: const TextStyle(color: Colors.white70),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _loading
                  ? Colors.grey
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _loading ? null : _shakeAndAnswer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );

    final ball = GestureDetector(
      onTap: _loading ? null : _shakeAndAnswer,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rot.value,
            child: Transform.scale(scale: _scale.value, child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(blurRadius: 30, spreadRadius: 2, color: Colors.black.withOpacity(0.35))],
              ),
              child: ClipOval(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.08),
                    BlendMode.darken,
                  ),
                  child: Image.asset('assets/ball.jpg', fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final answerChip = AnimatedOpacity(
      opacity: _answer.isEmpty ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.45))],
        ),
        child: Stack(
          children: [
            Text(
              _answer,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = Colors.black.withOpacity(0.7),
              ),
            ),
            Text(
              _answer,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0C0F13),
      appBar: AppBar(title: const Text('Волшебный шар')),
      body: Column(
        children: [
          topBar,
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: Center(child: ball)),
                Positioned(top: 90, left: 0, right: 0, child: answerChip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
