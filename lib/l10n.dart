class L10n {
  final String locale;
  L10n(this.locale);
  static const _ru = {
    'app_title': 'Волшебный шар',
    'hint': 'Сформулируй вопрос… затем встряхни телефон',
    'shake': 'Встряхни!',
    'tap_or_shake': 'Встряхни телефон или нажми «отправить».',
    'settings': 'Настройки',
    'theme': 'Тема',
    'theme_system': 'Системная',
    'theme_dark': 'Тёмная',
    'theme_light': 'Светлая',
    'ai_engine': 'ИИ-движок',
    'ai_on': 'Включить ИИ',
    'base_url': 'Базовый URL',
    'model': 'Модель',
    'api_key': 'API ключ',
  };
  static const _en = {
    'app_title': 'Magic 8',
    'hint': 'Ask a question… then shake the phone',
    'shake': 'Shake!',
    'tap_or_shake': 'Shake the phone or press “send”.',
    'settings': 'Settings',
    'theme': 'Theme',
    'theme_system': 'System',
    'theme_dark': 'Dark',
    'theme_light': 'Light',
    'ai_engine': 'AI engine',
    'ai_on': 'Enable AI',
    'base_url': 'Base URL',
    'model': 'Model',
    'api_key': 'API key',
  };
  String t(String key) => (locale.startsWith('ru') ? _ru : _en)[key] ?? key;
}
