import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../utils/storage.dart';
import 'webview_page.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _pwdController = TextEditingController();
  List<ServerConfig> _history = [];
  bool _connecting = false;
  final _dio = Dio();

  // 是否在 UI 中配置了账号密码（由历史记录或上次配置决定）
  bool _requireAuth = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final lastConfig = await Storage.getLastConfig();
    final history = await Storage.getHistory();
    if (mounted) {
      setState(() {
        if (lastConfig != null) {
          _urlController.text = lastConfig.url;
          _userController.text = lastConfig.username ?? '';
          _pwdController.text = lastConfig.password ?? '';
          _requireAuth = (lastConfig.username != null && lastConfig.username!.isNotEmpty);
        }
        _history = history;
      });
    }
  }

  String _normalizeUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<void> _connect([ServerConfig? configOverride]) async {
    final url = _normalizeUrl(configOverride?.url ?? _urlController.text);

    // 仅当 configOverride 带了 username，或本地 UI 配置了 _requireAuth 时才读账号密码
    final String user;
    final String pwd;
    if (configOverride != null) {
      user = configOverride.username ?? '';
      pwd = configOverride.password ?? '';
    } else if (_requireAuth) {
      user = _userController.text.trim();
      pwd = _pwdController.text.trim();
    } else {
      user = '';
      pwd = '';
    }

    if (url.isEmpty) {
      _showError('请输入服务器地址');
      return;
    }

    // 若需要验证但账号密码为空，提示
    if (_requireAuth && (user.isEmpty || pwd.isEmpty)) {
      _showError('请输入账号和密码');
      return;
    }

    setState(() => _connecting = true);

    try {
      final String? basicAuth = (user.isNotEmpty && pwd.isNotEmpty)
          ? 'Basic ${base64Encode(utf8.encode('$user:$pwd'))}'
          : null;

      _dio.options
        ..connectTimeout = const Duration(seconds: 8)
        ..receiveTimeout = const Duration(seconds: 8);

      if (basicAuth != null) {
        _dio.options.headers['Authorization'] = basicAuth;
      } else {
        _dio.options.headers.remove('Authorization');
      }

      await _dio.get(url);

      final config = ServerConfig(
        url: url,
        username: user.isNotEmpty ? user : null,
        password: pwd.isNotEmpty ? pwd : null,
      );
      await Storage.addToHistory(config);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WebViewPage(
              url: url,
              username: user.isNotEmpty ? user : null,
              password: pwd.isNotEmpty ? pwd : null,
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _connecting = false);
        _showError(e.toString().replaceAll('DioException [', '').split(']:').first);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteHistory(String url) async {
    await Storage.removeFromHistory(url);
    final history = await Storage.getHistory();
    if (mounted) setState(() => _history = history);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / Title
                const Icon(
                  Icons.terminal_rounded,
                  size: 56,
                  color: Color(0xFF007ACC),
                ),
                const SizedBox(height: 16),
                const Text(
                  'OpenCode',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '连接到你的服务器',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 40),

                // URL 输入框
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'http://192.168.1.1:3000',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // 账号密码区域：仅当 _requireAuth 时显示
                if (_requireAuth) ...
                [
                  TextField(
                    controller: _userController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '账号',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pwdController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 切换是否需要账号密码
                Row(
                  children: [
                    Checkbox(
                      value: _requireAuth,
                      activeColor: const Color(0xFF007ACC),
                      onChanged: (v) {
                        setState(() {
                          _requireAuth = v ?? false;
                          if (!_requireAuth) {
                            _userController.clear();
                            _pwdController.clear();
                          }
                        });
                      },
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _requireAuth = !_requireAuth;
                        if (!_requireAuth) {
                          _userController.clear();
                          _pwdController.clear();
                        }
                      }),
                      child: Text(
                        '需要账号密码登录',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 连接按钮
                ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  child: _connecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('连接'),
                ),

                // 历史记录
                if (_history.isNotEmpty) ...
                [
                  const SizedBox(height: 32),
                  Text(
                    '最近连接',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._history.map((cfg) {
                    final hasAuth = cfg.username != null && cfg.username!.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onLongPress: () => _deleteHistory(cfg.url),
                        child: Material(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _connect(cfg),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    hasAuth
                                        ? Icons.lock_rounded
                                        : Icons.lock_open_rounded,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cfg.url,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (hasAuth)
                                    Text(
                                      cfg.username!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 11,
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.2)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Text(
                    '长按删除记录',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
                Text(
                  'v1.2.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
