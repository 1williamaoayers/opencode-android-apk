import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({super.key, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _loading = true;
  String _currentUrl = '';
  String _pageTitle = '';
  final List<String> _logs = [];
  bool _showDebug = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _loading = true;
                _currentUrl = url;
              });
              _addLog('PAGE_START: $url');
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() => _loading = false);
              _addLog('PAGE_FINISH: $url');

              // 获取页面标题
              final title = await _controller.getTitle();
              if (mounted && title != null) {
                setState(() => _pageTitle = title);
                _addLog('TITLE: $title');
              }

              // 注入 JS 来捕获控制台输出和检查页面状态
              _controller.runJavaScript('''
                // 捕获 console
                var _origLog = console.log;
                var _origErr = console.error;
                var _origWarn = console.warn;
                console.log = function() {
                  _origLog.apply(console, arguments);
                  try { OC_Debug.postMessage('LOG: ' + Array.from(arguments).join(' ')); } catch(e) {}
                };
                console.error = function() {
                  _origErr.apply(console, arguments);
                  try { OC_Debug.postMessage('ERR: ' + Array.from(arguments).join(' ')); } catch(e) {}
                };
                console.warn = function() {
                  _origWarn.apply(console, arguments);
                  try { OC_Debug.postMessage('WARN: ' + Array.from(arguments).join(' ')); } catch(e) {}
                };

                // 捕获未处理的错误
                window.addEventListener('error', function(e) {
                  try { OC_Debug.postMessage('JS_ERR: ' + e.message + ' at ' + e.filename + ':' + e.lineno); } catch(ex) {}
                });

                // 捕获未处理的 Promise 拒绝
                window.addEventListener('unhandledrejection', function(e) {
                  try { OC_Debug.postMessage('PROMISE_ERR: ' + e.reason); } catch(ex) {}
                });

                // 报告页面状态
                setTimeout(function() {
                  var root = document.getElementById('root');
                  var body = document.body;
                  var info = 'BODY_CHILDREN: ' + body.children.length +
                    ' ROOT_CHILDREN: ' + (root ? root.children.length : 'null') +
                    ' ROOT_HTML_LEN: ' + (root ? root.innerHTML.length : 'null') +
                    ' BODY_BG: ' + getComputedStyle(body).backgroundColor +
                    ' DOC_TITLE: ' + document.title +
                    ' SCRIPTS: ' + document.querySelectorAll('script').length;
                  try { OC_Debug.postMessage(info); } catch(ex) {}
                }, 3000);
              ''');
            }
          },
          onWebResourceError: (error) {
            _addLog('RES_ERR: ${error.description} (${error.errorCode}) url=${error.url ?? "?"}');
          },
          onHttpError: (error) {
            _addLog('HTTP_ERR: ${error.response?.statusCode} url=${error.request?.uri}');
          },
          onNavigationRequest: (request) {
            _addLog('NAV: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'OC_Debug',
        onMessageReceived: (message) {
          _addLog(message.message);
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _addLog(String msg) {
    if (!mounted) return;
    final ts = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$ts] $msg');
      if (_logs.length > 100) _logs.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),

              // 顶部加载进度条
              if (_loading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress / 100.0,
                    backgroundColor: Colors.transparent,
                    color: const Color(0xFF007ACC),
                    minHeight: 3,
                  ),
                ),

              // 顶部工具条
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Debug 按钮
                    _miniButton(
                      icon: Icons.bug_report,
                      color: _showDebug ? Colors.amber : Colors.white70,
                      onTap: () => setState(() => _showDebug = !_showDebug),
                    ),
                    const SizedBox(width: 4),
                    // 刷新
                    _miniButton(
                      icon: Icons.refresh,
                      onTap: () => _controller.reload(),
                    ),
                    const SizedBox(width: 4),
                    // 断开
                    _miniButton(
                      icon: Icons.close,
                      label: '断开',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Debug 面板
              if (_showDebug)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Container(
                    color: Colors.black.withOpacity(0.9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 状态栏
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: const Color(0xFF333333),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('URL: $_currentUrl',
                                  style: _debugStyle(Colors.cyan)),
                              Text('Title: $_pageTitle',
                                  style: _debugStyle(Colors.green)),
                              Text(
                                  'Progress: $_progress% | Loading: $_loading',
                                  style: _debugStyle(Colors.yellow)),
                            ],
                          ),
                        ),
                        // 日志列表
                        Expanded(
                          child: ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(4),
                            itemCount: _logs.length,
                            itemBuilder: (ctx, i) {
                              final log = _logs[_logs.length - 1 - i];
                              Color c = Colors.white70;
                              if (log.contains('ERR'))
                                c = Colors.red;
                              else if (log.contains('WARN'))
                                c = Colors.orange;
                              else if (log.contains('PAGE_'))
                                c = Colors.cyan;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 1),
                                child: Text(log,
                                    style: _debugStyle(c)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniButton({
    required IconData icon,
    String? label,
    Color color = Colors.white70,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(fontSize: 11, color: color)),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _debugStyle(Color c) =>
      TextStyle(fontFamily: 'monospace', fontSize: 11, color: c);
}
