import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mime/mime.dart';
import '../utils/resource_cache.dart';
import 'package:dio/dio.dart';

class FileItem {
  final String path;
  final String name;
  final bool isDirectory;
  
  FileItem({
    required this.path,
    required this.name,
    required this.isDirectory,
  });
}

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
  
  // 侧边栏状态
  bool _showSidebar = false;
  List<FileItem> _currentFiles = [];
  String? _selectedFilePath;
  String? _selectedFileContent;
  bool _loadingContent = false;
  String? _errorMessage;
  
  // 服务器基础 URL
  late String _baseUrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ResourceCache.init();
    _baseUrl = widget.url.endsWith('/') ? widget.url.substring(0, widget.url.length - 1) : widget.url;
    
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: const Color(0xFF007ACC),
        backgroundColor: const Color(0xFF1E1E1E),
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

  Future<void> _loadFileContent(String filePath) async {
    setState(() {
      _selectedFilePath = filePath;
      _loadingContent = true;
      _errorMessage = null;
    });
    
    try {
      final response = await Dio().get(
        '$_baseUrl/api/file/content',
        queryParameters: {'path': filePath},
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      // 解析响应
      final data = response.data;
      String content;
      if (data is Map) {
        content = data['content']?.toString() ?? data.toString();
      } else {
        content = data.toString();
      }
      
      setState(() {
        _selectedFileContent = content;
        _loadingContent = false;
      });
    } on DioException catch (e) {
      setState(() {
        _errorMessage = '加载失败: ${e.message}';
        _loadingContent = false;
        _selectedFileContent = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '错误: $e';
        _loadingContent = false;
        _selectedFileContent = null;
      });
    }
  }

  Future<void> _setupClickListener(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: '''
      (function() {
        // 全局点击监听器
        document.addEventListener('click', function(e) {
          var target = e.target;
          
          // 向上查找按钮元素（文件树节点是 button）
          var button = target.closest('button');
          
          if (button) {
            // 尝试获取文件路径
            var path = null;
            var name = null;
            
            // 方法1: 从 data 属性获取
            path = button.getAttribute('data-path') || 
                   button.getAttribute('data-file-path') ||
                   button.getAttribute('data-name');
            
            // 方法2: 从 textContent 提取路径（文件树显示的文本）
            if (!path && button.textContent) {
              // 文件树中的文件通常有图标和文件名
              var text = button.textContent.trim();
              // 尝试从附近获取路径信息
            }
            
            // 方法3: 检查是否是文件树节点（通过 class 或结构）
            var isFileNode = button.classList.contains('filetree') || 
                            button.closest('[data-component="filetree"]');
            
            // 检查是否有文件图标
            var hasFileIcon = button.querySelector('[data-component="file-icon"]') !== null ||
                            button.querySelector('.filetree-icon') !== null;
            
            // 检查是否是目录（通常有 chevron 图标）
            var hasChevron = button.querySelector('[data-icon-name="chevron-down"]') !== null ||
                            button.querySelector('[data-icon-name="chevron-right"]') !== null;
            
            if (hasFileIcon && !hasChevron) {
              // 这很可能是一个文件节点
              // 尝试从 title 或 aria-label 获取路径
              path = button.getAttribute('title') || 
                     button.getAttribute('aria-label') ||
                     path;
              
              // 发送点击事件给 Flutter
              window.flutter_inappwebview.callHandler('onFileTreeClick', JSON.stringify({
                hasFileIcon: hasFileIcon,
                isDirectory: hasChevron,
                textContent: button.textContent?.trim().substring(0, 100)
              }));
            }
          }
        }, true);
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (_showSidebar) {
          setState(() => _showSidebar = false);
          return;
        }
        
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
              // 主体 WebView
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                right: _showSidebar ? 0 : 0,
                child: Container(
                  margin: EdgeInsets.only(right: _showSidebar ? screenWidth * 0.4 : 0),
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      useShouldInterceptRequest: true,
                      transparentBackground: true,
                      safeBrowsingEnabled: false,
                      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      useHybridComposition: true,
                      allowFileAccess: true,
                      allowContentAccess: true,
                      supportZoom: true,
                      mediaPlaybackRequiresUserGesture: false,
                      loadWithOverviewMode: true,
                      allowsInlineMediaPlayback: true,
                      preferredContentMode: UserPreferredContentMode.RECOMMENDED,
                    ),
                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (controller) async {
                  _controller = controller;
                  
                  // 监听 URL 变化来捕获文件点击
                  controller.addJavaScriptHandler(
                    handlerName: 'onUrlChange',
                    callback: (args) {
                      if (args.isNotEmpty) {
                        final url = args.first.toString();
                        // 检查是否是 file:// URL
                        if (url.startsWith('file://')) {
                          final path = Uri.parse(url).path;
                          if (path.isNotEmpty && path != '/') {
                            setState(() {
                              _showSidebar = true;
                            });
                            _loadFileContent(path);
                          }
                        }
                      }
                    },
                  );
                  
                  controller.addJavaScriptHandler(
                    handlerName: 'onFileTreeClick',
                    callback: (args) {
                      debugPrint('File tree click: ${args}');
                    },
                  );
                  
                  await _setupClickListener(controller);
                },
                    onLoadStop: (controller, url) async {
                      await controller.evaluateJavascript(source: '''
                        (function() {
                          var meta = document.querySelector('meta[name="viewport"]');
                          if (!meta) {
                            meta = document.createElement('meta');
                            meta.name = "viewport";
                            document.head.appendChild(meta);
                          }
                          meta.content = "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no";
                          
                          // 监听 popstate 事件（URL 变化）
                          window.addEventListener('popstate', function(e) {
                            var url = window.location.href;
                            window.flutter_inappwebview.callHandler('onUrlChange', url);
                          });
                          
                          // 监听 hashchange
                          window.addEventListener('hashchange', function(e) {
                            var url = window.location.href;
                            window.flutter_inappwebview.callHandler('onUrlChange', url);
                          });
                          
                          // 覆盖 pushState 来监听 SPA 导航
                          var originalPushState = history.pushState;
                          history.pushState = function() {
                            originalPushState.apply(this, arguments);
                            window.flutter_inappwebview.callHandler('onUrlChange', window.location.href);
                          };
                          
                          // 覆盖 replaceState
                          var originalReplaceState = history.replaceState;
                          history.replaceState = function() {
                            originalReplaceState.apply(this, arguments);
                            window.flutter_inappwebview.callHandler('onUrlChange', window.location.href);
                          };
                        })();
                      ''');
                      await _setupClickListener(controller);
                    },
                    onProgressChanged: (controller, progress) {
                      if (mounted) {
                        setState(() {
                          _progress = progress / 100.0;
                          _loading = progress < 100;
                        });
                      }
                    },
                    onUpdateVisitedHistory: (controller, url, isReload) {
                      // 监听 URL 变化
                      final urlStr = url.toString();
                      if (urlStr.startsWith('file://')) {
                        final path = Uri.parse(urlStr).path;
                        if (path.isNotEmpty && path != '/') {
                          setState(() {
                            _showSidebar = true;
                          });
                          _loadFileContent(path);
                        }
                      }
                    },
                    shouldInterceptRequest: (controller, request) async {
                      final uri = request.url;
                      
                      if (ResourceCache.isCacheable(uri)) {
                        final cachedData = await ResourceCache.load(uri);
                        if (cachedData != null) {
                          return WebResourceResponse(
                            data: cachedData,
                            contentType: lookupMimeType(uri.path) ?? 'application/octet-stream',
                            contentEncoding: 'binary',
                            headers: {
                              'Access-Control-Allow-Origin': '*',
                              'Cache-Control': 'max-age=31536000',
                            },
                          );
                        }
                        
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
                      
                      return null;
                    },
                    onReceivedError: (controller, request, error) {
                      debugPrint('WebView Error: ${error.description}');
                    },
                  ),
                ),
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
              
              // 右侧文件预览面板
              if (_showSidebar)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: screenWidth * 0.4,
                  child: _buildFilePreviewPanel(),
                ),
              
              // 切换侧边栏按钮
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  onPressed: () {
                    setState(() {
                      _showSidebar = !_showSidebar;
                    });
                  },
                  backgroundColor: const Color(0xFF007ACC),
                  child: Icon(
                    _showSidebar ? Icons.chevron_right : Icons.chevron_left,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreviewPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(
          left: BorderSide(color: Color(0xFF3E3E3E), width: 1),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              border: Border(
                bottom: BorderSide(color: Color(0xFF3E3E3E), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.code,
                  size: 18,
                  color: Color(0xFF007ACC),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFilePath?.split('/').last ?? '文件预览',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.white54,
                  onPressed: () {
                    setState(() => _showSidebar = false);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          // 文件路径
          if (_selectedFilePath != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF252525),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF3E3E3E), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _selectedFilePath!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          // 内容区
          Expanded(
            child: _buildContentArea(),
          ),
          
          // 底部操作栏
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              border: Border(
                top: BorderSide(color: Color(0xFF3E3E3E), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _selectedFileContent != null
                      ? () {
                          Clipboard.setData(ClipboardData(text: _selectedFileContent!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已复制到剪贴板'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF007ACC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    if (_loadingContent) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF007ACC),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    if (_selectedFileContent == null) {
      return const Center(
        child: Text(
          '点击文件树中的文件查看内容',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    
    // 简单语法高亮
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          _selectedFileContent!,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFFD4D4D4),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
