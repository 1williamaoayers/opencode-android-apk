import 'dart:async';
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
  // Auto-hide toggle button
  double _buttonOpacity = 1.0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _resetHideTimer(); // Start the auto-hide countdown immediately

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
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _buttonOpacity = 1.0);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _buttonOpacity = 0.12);
    });
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

  /// Injects the correct viewport meta tag based on current mode.
  Future<void> _applyViewport() async {
    final controller = _controller;
    if (controller == null) return;

    final viewportContent = _isDesktopMode
        // Desktop: Forces 1200px width so all 3 panels render, initial 0.45 scale so it fits on screen
        ? 'width=1200, initial-scale=0.45, minimum-scale=0.2, maximum-scale=5.0, user-scalable=yes, viewport-fit=cover'
        // Mobile: Device-width so the web app enters its mobile-responsive layout, 100% zoom for comfortable typing
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

        // Inject base CSS tweaks (idempotent)
        if (!document.getElementById('opencode-mobile-tweaks')) {
          var style = document.createElement('style');
          style.id = 'opencode-mobile-tweaks';
          style.innerHTML = `
            * { -webkit-tap-highlight-color: transparent !important; }
            ::-webkit-scrollbar { display: none !important; width: 0 !important; height: 0 !important; }
            .pb-4 { padding-bottom: max(1rem, env(safe-area-inset-bottom)) !important; }
            /* Improve font sharpness in scaled-down desktop viewport */
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

  /// Toggle between desktop and mobile mode.
  Future<void> _toggleViewMode() async {
    setState(() {
      _isDesktopMode = !_isDesktopMode;
    });
    _resetHideTimer(); // Show the button again briefly after switching
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
                  // Apply the current viewport mode after the page loads
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
                    if (mounted) {
                      setState(() {
                        _errorMessage = error.description;
                      });
                    }
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  debugPrint('HTTP Error: ${errorResponse.statusCode} - ${errorResponse.reasonPhrase}');
                },
              ),

              // ─── Progress bar ───────────────────────────────────────────
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

              // ─── Toggle Button (auto-hides to 12% opacity after 3s) ───
              Positioned(
                bottom: 20,
                left: 16,
                child: AnimatedOpacity(
                  opacity: _buttonOpacity,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    onTap: () {
                      // If faded out, first tap just reveals, second tap toggles
                      if (_buttonOpacity < 0.5) {
                        _resetHideTimer();
                      } else {
                        _toggleViewMode();
                      }
                    },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isDesktopMode
                          ? const Color(0xFF007ACC).withOpacity(0.92)
                          : const Color(0xFF3C8A2E).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isDesktopMode ? Icons.desktop_windows_rounded : Icons.smartphone_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isDesktopMode ? '桌面视图' : '手机视图',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Error card ─────────────────────────────────────────────
              if (_errorMessage != null && !_loading)
                Positioned(
                  bottom: 70,
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
