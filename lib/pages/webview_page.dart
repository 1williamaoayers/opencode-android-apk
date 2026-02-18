import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mime/mime.dart';
import '../utils/resource_cache.dart';

class WebViewPage extends StatefulWidget {
  final String url;

  const WebViewPage({super.key, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    // 全屏沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ResourceCache.init();
  }

  @override
  void dispose() {
    // 恢复系统 UI
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

        // 双击退出逻辑
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
        backgroundColor: const Color(0xFF1E1E1E), // 避免闪白
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialSettings: InAppWebViewSettings(
                  useShouldInterceptRequest: true, // 启用请求拦截
                  transparentBackground: true,
                  safeBrowsingEnabled: false,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useHybridComposition: true, // 改善键盘输入
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onProgressChanged: (controller, progress) {
                  if (mounted) {
                    setState(() {
                      _progress = progress / 100.0;
                      _loading = progress < 100;
                    });
                  }
                },
                shouldInterceptRequest: (controller, request) async {
                  final uri = request.url;
                  
                  // 仅拦截 HTTP/HTTPS 的静态资源
                  if (ResourceCache.isCacheable(uri)) {
                    // 1. 尝试从缓存读取
                    final cachedData = await ResourceCache.load(uri);
                    if (cachedData != null) {
                      return WebResourceResponse(
                        data: cachedData,
                        contentType: lookupMimeType(uri.path) ?? 'application/octet-stream',
                        contentEncoding: 'binary',
                        headers: {
                          'Access-Control-Allow-Origin': '*',
                          'Cache-Control': 'max-age=31536000', // 强制长效缓存
                        },
                      );
                    }
                    
                    // 2. 缓存未命中：下载并缓存 (然后返回数据给 WebView)
                    final downloadedData = await ResourceCache.downloadAndCache(uri);
                    if (downloadedData != null) {
                      return WebResourceResponse(
                        data: downloadedData,
                        contentType: lookupMimeType(uri.path) ?? 'application/octet-stream',
                        contentEncoding: 'binary',
                        headers: {
                          'Access-Control-Allow-Origin': '*',
                        },
                      );
                    }
                  }
                  
                  // 3. 非静态资源或下载失败，让 WebView 自己加载
                  return null;
                },
                onReceivedError: (controller, request, error) {
                  // 忽略一些无关紧要的错误
                  debugPrint('WebView Error: ${error.description}');
                },
              ),
              
              // 极简进度条 (仅 2px 高)
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
            ],
          ),
        ),
      ),
    );
  }
}
