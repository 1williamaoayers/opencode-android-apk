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
  List<ServerConfig> _history = [];
  bool _connecting = false;
  final _dio = Dio();

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

    if (url.isEmpty) {
      _showError('请输入服务器地址');
      return;
    }

    setState(() => _connecting = true);

    try {
      _dio.options.headers = {};
      _dio.options.connectTimeout = const Duration(seconds: 5);
      _dio.options.receiveTimeout = const Duration(seconds: 5);
      _dio.options.validateStatus = (status) => true; // Handle all statuses

      final response = await _dio.get(url);

      if (!mounted) return;

      if (response.statusCode == 401) {
        _showError('认证失败：用户名或密码错误');
        setState(() => _connecting = false);
        return;
      } else if (response.statusCode == null || response.statusCode! >= 500) {
        _showError('无法连接到服务器 (${response.statusCode ?? '网络异常'})');
        setState(() => _connecting = false);
        return;
      }

      // Success, save history and navigate
      final finalConfig = ServerConfig(
        url: url,
      );

      await Storage.addToHistory(finalConfig);

      setState(() => _connecting = false);
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebViewPage(
            url: url,
          ),
        ),
      );
      
      _loadData();

    } catch (e) {
      debugPrint('Connection error: $e');
      if (mounted) {
        _showError('连接超时或无法访问该地址');
        setState(() => _connecting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteHistory(String url) async {
    await Storage.removeFromHistory(url);
    _loadData();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'OpenCode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF007ACC),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Remote Development Client',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 48),

                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://192.168.1.x:3000',
                      prefixIcon: Icon(Icons.dns_outlined, size: 20),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _connect(),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _connecting ? null : () => _connect(),
                    child: _connecting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Connect'),
                  ),
                  const SizedBox(height: 32),

                  if (_history.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.history,
                            size: 14,
                            color: Colors.white.withOpacity(0.3)),
                        const SizedBox(width: 6),
                        Text(
                          'RECENT SERVERS',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            color: Colors.white.withOpacity(0.3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_history.length, (i) {
                      final config = _history[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _connect(config),
                            onLongPress: () => _deleteHistory(config.url),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.computer,
                                      size: 16, color: Color(0xFF007ACC)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          config.url,
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (config.username != null)
                                          Text(
                                            'User: ${config.username}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white.withOpacity(0.4),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.2)),
                                ],
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
                    'v1.1.0',
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
      ),
    );
  }
}

