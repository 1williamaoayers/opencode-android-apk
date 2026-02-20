// OpenCode Mobile WebView
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({super.key, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  double _progress = 0;
  bool _loading = true;
  DateTime? _lastBackPressTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: const Color(0xFF007ACC),
      ),
      onRefresh: () async {
        await _controller?.reload();
        _pullToRefreshController?.endRefreshing();
      },
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          controller.goBack();
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('再次按返回键断开连接'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: '刷新',
                  onPressed: () => controller?.reload(),
                  textColor: const Color(0xFF007ACC),
                ),
              ),
            );
          }
        } else {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  clearCache: true,
                  safeBrowsingEnabled: false,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useHybridComposition: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  supportZoom: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  disablesWebViewContextMenu: false,
                ),
                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onProgressChanged: (controller, progress) {
                  if (mounted) {
                    setState(() {
                      _progress = progress / 100.0;
                      _loading = progress < 100;
                      _errorMessage = null;
                    });
                  }
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('WebView Error: ${error.description}');
                  if (mounted) {
                    setState(() {
                      _errorMessage = error.description;
                    });
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  debugPrint('HTTP Error: ${errorResponse.statusCode} - ${errorResponse.reasonPhrase}');
                },
              ),
              
              // 进度条
              if (_loading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    color: const Color(0xFF007ACC),
                    minHeight: 2,
                  ),
                ),
              
              // 错误显示
              if (_errorMessage != null && !_loading)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.red.shade900,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '加载失败',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                    _loading = true;
                                  });
                                  _controller?.reload();
                                },
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
