import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnswerEngine {
  final List<String> classic = const [
    'Бесспорно','Предрешено','Никаких сомнений','Определённо да','Можешь быть уверен в этом',
    'Мне кажется — да','Вероятнее всего','Хорошие перспективы','Знаки говорят — да','Да',
    'Пока не ясно, попробуй снова','Спроси позже','Лучше не рассказывать','Сейчас нельзя предсказать','Сконцентрируйся и спроси опять',
    'Даже не думай','Мой ответ — нет','По моим данным — нет','Перспективы не очень хорошие','Весьма сомнительно'
  ];
  final _rng = Random();

  Future<String> answer({String? question, required AppSettings settings}) async {
    if (settings.aiOn && question != null && question.isNotEmpty && settings.baseUrl.isNotEmpty) {
      final ai = await _tryAI(question, settings);
      if (ai != null) return ai;
    }
    return classic[_rng.nextInt(classic.length)];
  }

  Future<String?> _tryAI(String question, AppSettings s) async {
    try {
      final uri = Uri.parse('${s.baseUrl.replaceAll(RegExp(r"/$"), "")}/v1/chat/completions');
      final body = {
        'model': s.model,
        'messages': [
          {'role':'system','content':'Ты отвечаешь кратко, как шар предсказаний. 3–10 слов, без пояснений.'},
          {'role':'user','content':question}
        ],
        'temperature': 0.9,
        'max_tokens': 32
      };
      final res = await http.post(uri, headers: {
        'Content-Type': 'application/json'
      }, body: jsonEncode(body));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String,dynamic>;
        final txt = (data['choices'] as List).first['message']['content'] as String;
        return txt.trim();
      }
    } catch (_) {}
    return null;
  }
}
final engineProvider = Provider<AnswerEngine>((ref) => AnswerEngine());
