import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({
    super.key,
    required this.url,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  double _progress = 0;
  bool _loading = true;
  DateTime? _lastBackPressTime;
  String? _errorMessage;
  bool _isDesktopMode = true;
  bool _isReconnecting = false;
  DateTime? _pausedAt;

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

    WidgetsBinding.instance.addObserver(this);

    // Keep screen and CPU alive so Android never kills our WebSocket
    WakelockPlus.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final controller = _controller;
    if (controller == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _pausedAt = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        controller.resume();
        final pauseDuration = _pausedAt != null
            ? DateTime.now().difference(_pausedAt!)
            : Duration.zero;
        _pausedAt = null;
        // Check connection more aggressively (e.g., if away for more than 1 second)
        // since Android aggressively caches active sockets, leading to silent drops.
        if (pauseDuration.inSeconds > 1) {
          _smartReconnect();
        }
        break;
      default:
        break;
    }
  }

  /// Silently checks if the server is still reachable.
  /// If dead, shows a brief dark overlay and reloads seamlessly.
  /// If alive, does nothing — user sees zero interruption.
  Future<void> _smartReconnect() async {
    final controller = _controller;
    if (controller == null) return;

    // Give WebView engine a moment to resume
    await Future.delayed(const Duration(milliseconds: 300));

    // Ask JS to check if the connection is still alive,
    // and simultaneously fire a visibilitychange event to wake up JS SDK internal watchdogs
    final result = await controller.evaluateJavascript(source: """
      (async function() {
        try {
          document.dispatchEvent(new Event('visibilitychange'));
          var resp = await fetch(window.location.href, {method: 'HEAD', cache: 'no-store'});
          return resp.ok ? 'alive' : 'dead';
        } catch(e) {
          return 'dead';
        }
      })();
    """);

    // result is a JSON-encoded string, e.g. '"alive"' or '"dead"'
    final isAlive = result != null && result.toString().contains('alive');

    if (!isAlive && mounted) {
      // Show a dark overlay to mask any white flash during reload
      setState(() => _isReconnecting = true);
      await Future.delayed(const Duration(milliseconds: 100));
      await controller.reload();
      // The overlay will be removed when onLoadStop fires
    }
  }

  /// Inject a JS heartbeat that pings the server every 15 seconds.
  /// This keeps WebSocket connections alive by preventing Android
  /// from considering the network idle.
  Future<void> _injectHeartbeat() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.evaluateJavascript(source: """
      (function() {
        if (window.__0CODE_HEARTBEAT__) return; // Already injected
        window.__0CODE_HEARTBEAT__ = setInterval(function() {
          fetch(window.location.origin + '/', {method: 'HEAD', cache: 'no-store'}).catch(function(){});
        }, 15000);
      })();
    """);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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
                onLoadStop: (controller, url) async {
                  await _applyViewport();
                  await _injectHeartbeat();
                  if (mounted && _isReconnecting) {
                    setState(() => _isReconnecting = false);
                  }
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

              // ─── Manual Refresh Toggle: left-edge upper-third ─────────────
              Align(
                alignment: const Alignment(-1.0, -0.33),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () async {
                      if (mounted) setState(() => _isReconnecting = true);
                      await Future.delayed(const Duration(milliseconds: 100));
                      await _controller?.reload();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 20,
                      ),
                    ),
                  ),
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

              // ─── Reconnecting overlay (masks any reload flash) ─────────
              if (_isReconnecting)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF1E1E1E),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF007ACC),
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
