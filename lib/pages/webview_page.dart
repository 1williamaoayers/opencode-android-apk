import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String? username;
  final String? password;

  const WebViewPage({
    super.key,
    required this.url,
    this.username,
    this.password,
  });

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
  bool _isDesktopMode = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: const Color(0xFF007ACC)),
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

  Map<String, String>? _buildHeaders() {
    if (widget.username != null && widget.username!.isNotEmpty &&
        widget.password != null && widget.password!.isNotEmpty) {
      final credentials = '${widget.username}:${widget.password}';
      final basicAuth = base64Encode(utf8.encode(credentials));
      return {'Authorization': 'Basic $basicAuth'};
    }
    return null;
  }

  Future<void> _applyViewport() async {
    final controller = _controller;
    if (controller == null) return;

    final viewportContent = _isDesktopMode
        ? 'width=1200, initial-scale=0.45, minimum-scale=0.2, maximum-scale=5.0, user-scalable=yes, viewport-fit=cover'
        : 'width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=5.0, user-scalable=yes, viewport-fit=cover';

    await controller.evaluateJavascript(source: """
      (function() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          document.head.appendChild(meta);
        }
        meta.content = '$viewportContent';

        if (!document.getElementById('opencode-mobile-tweaks')) {
          var style = document.createElement('style');
          style.id = 'opencode-mobile-tweaks';
          style.innerHTML = `
            * { -webkit-tap-highlight-color: transparent !important; }
            ::-webkit-scrollbar { display: none !important; width: 0 !important; height: 0 !important; }
            body, * {
              -webkit-font-smoothing: antialiased !important;
              text-rendering: optimizeLegibility !important;
            }
          `;
          document.head.appendChild(style);
        }
      })();
    """);
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isDesktopMode = !_isDesktopMode);
    await _applyViewport();
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
              // ─── Full-screen WebView ──────────────────────────────────────
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(widget.url),
                  headers: _buildHeaders(),
                ),
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
                  builtInZoomControls: true,
                  displayZoomControls: false,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                ),
                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                },
                onReceivedHttpAuthRequest: (controller, challenge) async {
                  if (widget.username != null && widget.username!.isNotEmpty &&
                      widget.password != null && widget.password!.isNotEmpty) {
                    return HttpAuthResponse(
                      username: widget.username!,
                      password: widget.password!,
                      action: HttpAuthResponseAction.PROCEED,
                    );
                  }
                  return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
                },
                onLoadStop: (controller, url) async {
                  await _applyViewport();
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
                  if (request.isForMainFrame == true) {
                    if (mounted) setState(() => _errorMessage = error.description);
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  debugPrint('HTTP Error: ${errorResponse.statusCode}');
                },
              ),

              // ─── Progress bar ─────────────────────────────────────────────
              if (_loading)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    color: const Color(0xFF007ACC),
                    minHeight: 2,
                  ),
                ),

              // ─── Toggle: left-edge center, transparent ghost circle ──────
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: _toggleViewMode,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        _isDesktopMode ? Icons.smartphone_rounded : Icons.desktop_windows_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Error card ───────────────────────────────────────────────
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
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
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
