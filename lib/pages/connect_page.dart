import 'package:flutter/material.dart';
import '../utils/storage.dart';
import 'webview_page.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _urlController = TextEditingController();
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final lastUrl = await Storage.getLastUrl();
    final history = await Storage.getHistory();
    if (mounted) {
      setState(() {
        if (lastUrl != null) _urlController.text = lastUrl;
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
    // 移除末尾斜杠
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<void> _connect([String? urlOverride]) async {
    final url = _normalizeUrl(urlOverride ?? _urlController.text);
    if (url.isEmpty) {
      _showError('请输入服务器地址');
      return;
    }

    // 保存到历史
    await Storage.addToHistory(url);

    if (mounted) {
      // 直接跳转 WebView，不做健康检查（WebView 自带加载进度条）
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebViewPage(url: url),
        ),
      );
      // 返回后刷新历史
      _loadData();
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
                  // Logo
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

                  // URL Input
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://192.168.1.x:3306',
                      prefixIcon: Icon(Icons.dns_outlined, size: 20),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _connect(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '输入 OpenCode 服务器地址，包含端口号',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Connect Button
                  ElevatedButton(
                    onPressed: () => _connect(),
                    child: const Text('Connect'),
                  ),
                  const SizedBox(height: 32),

                  // History
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
                      final url = _history[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _connect(url),
                            onLongPress: () => _deleteHistory(url),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.computer,
                                      size: 16, color: Color(0xFF007ACC)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      url,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
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
                    'v1.0.0',
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
