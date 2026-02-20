import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  final String url;
  final String? username;
  final String? password;

  ServerConfig({required this.url, this.username, this.password});

  Map<String, dynamic> toJson() => {
        'url': url,
        if (username != null) 'username': username,
        if (password != null) 'password': password,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      url: json['url'] as String,
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }
}

class Storage {
  static const _historyKey = 'server_configs_history';
  static const _lastConfigKey = 'last_server_config';
  static const _maxHistory = 10;

  static Future<List<ServerConfig>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    try {
      return historyJson
          .map((e) => ServerConfig.fromJson(jsonDecode(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addToHistory(ServerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await getHistory();
    
    // Remove if exists to update its position and credentials
    configs.removeWhere((c) => c.url == config.url);
    configs.insert(0, config);
    
    if (configs.length > _maxHistory) {
      configs.removeRange(_maxHistory, configs.length);
    }
    
    final encodedList = configs.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_historyKey, encodedList);
    await prefs.setString(_lastConfigKey, jsonEncode(config.toJson()));
  }

  static Future<void> removeFromHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await getHistory();
    configs.removeWhere((c) => c.url == url);
    
    final encodedList = configs.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_historyKey, encodedList);
  }

  static Future<ServerConfig?> getLastConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_lastConfigKey);
    if (jsonStr == null) return null;
    try {
      return ServerConfig.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return null;
    }
  }
}
