import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool aiOn;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String locale;
  const AppSettings({
    required this.themeMode,
    required this.aiOn,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.locale,
  });
  AppSettings copyWith({
    ThemeMode? themeMode, bool? aiOn, String? baseUrl, String? apiKey, String? model, String? locale,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    aiOn: aiOn ?? this.aiOn,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    locale: locale ?? this.locale,
  );
}

class SettingsRepo {
  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: ThemeMode.values[p.getInt('themeMode') ?? 0],
      aiOn: p.getBool('aiOn') ?? false,
      baseUrl: p.getString('baseUrl') ?? const String.fromEnvironment('AI_BASE_URL', defaultValue: ''),
      apiKey: p.getString('apiKey') ?? const String.fromEnvironment('AI_KEY', defaultValue: ''),
      model: p.getString('model') ?? const String.fromEnvironment('AI_MODEL', defaultValue: 'gpt-4o-mini'),
      locale: p.getString('locale') ?? 'ru',
    );
  }
  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('themeMode', s.themeMode.index);
    await p.setBool('aiOn', s.aiOn);
    await p.setString('baseUrl', s.baseUrl);
    await p.setString('apiKey', s.apiKey);
    await p.setString('model', s.model);
    await p.setString('locale', s.locale);
  }
}
final settingsRepoProvider = Provider((_) => SettingsRepo());
final settingsProvider = StateNotifierProvider<SettingsController, AppSettings?>((ref) => SettingsController(ref));
class SettingsController extends StateNotifier<AppSettings?> {
  final Ref ref;
  SettingsController(this.ref) : super(null) { _init(); }
  Future<void> _init() async { state = await ref.read(settingsRepoProvider).load(); }
  void update(AppSettings s) { state = s; ref.read(settingsRepoProvider).save(s); }
}
