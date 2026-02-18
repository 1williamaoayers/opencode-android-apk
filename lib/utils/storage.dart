import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static const _historyKey = 'server_history';
  static const _lastUrlKey = 'last_url';
  static const _maxHistory = 10;

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  static Future<void> addToHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.remove(url);
    history.insert(0, url);
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    await prefs.setStringList(_historyKey, history);
    await prefs.setString(_lastUrlKey, url);
  }

  static Future<void> removeFromHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.remove(url);
    await prefs.setStringList(_historyKey, history);
  }

  static Future<String?> getLastUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUrlKey);
  }
}
