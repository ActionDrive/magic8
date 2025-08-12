import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(Magic8BallApp());
}

class Magic8BallApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Magic8BallScreen(),
    );
  }
}

class Magic8BallScreen extends StatefulWidget {
  @override
  _Magic8BallScreenState createState() => _Magic8BallScreenState();
}

class _Magic8BallScreenState extends State<Magic8BallScreen> {
  final TextEditingController _controller = TextEditingController();
  late stt.SpeechToText _speech;
  String _answer = "";
  bool _listening = false;
  double _shakeThreshold = 15.0;
  DateTime _lastShakeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    accelerometerEvents.listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    double gX = event.x;
    double gY = event.y;
    double gZ = event.z;
    double gForce =
        sqrt(gX * gX + gY * gY + gZ * gZ) - 9.8; // remove gravity offset

    if (gForce > _shakeThreshold &&
        DateTime.now().difference(_lastShakeTime).inMilliseconds > 1000) {
      _lastShakeTime = DateTime.now();
      if (_controller.text.isNotEmpty) {
        _getAnswer(_controller.text);
      }
    }
  }

  Future<void> _getAnswer(String question) async {
    setState(() => _answer = "...");
    _controller.clear();

    try {
      final uri = Uri.parse(
          "${const String.fromEnvironment('AI_BASE_URL')}/ask?question=${Uri.encodeComponent(question)}");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        setState(() => _answer = json.decode(res.body)['answer'] ?? "Ошибка");
      } else {
        setState(() => _answer = "Ошибка: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _answer = "Ошибка подключения");
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _listening = true);
      _speech.listen(onResult: (val) {
        setState(() {
          _controller.text = val.recognizedWords;
        });
      });
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset("assets/ball.jpg", fit: BoxFit.cover),
                    CustomPaint(
                      size: Size(200, 200),
                      painter: TrianglePainter(_answer),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Задай вопрос...",
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_listening) {
                        _stopListening();
                      } else {
                        _startListening();
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        _getAnswer(_controller.text);
                      }
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final String text;
  TrianglePainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    Paint trianglePaint = Paint()..color = Colors.blue[800]!;
    Path trianglePath = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(trianglePath, trianglePaint);

    TextSpan span = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width * 0.8);
    tp.paint(canvas,
        Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
