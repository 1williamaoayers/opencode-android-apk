import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';

class ResourceCache {
  static final Dio _dio = Dio();
  static String? _cachePath;

  /// 初始化缓存目录
  static Future<void> init() async {
    if (_cachePath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _cachePath = '${dir.path}/web_cache';
    await Directory(_cachePath!).create(recursive: true);
  }

  /// 判断是否为可缓存的静态资源
  static bool isCacheable(Uri uri) {
    final path = uri.path.toLowerCase();
    // 忽略 API 请求、根路径等
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    
    // 常见的静态资源后缀
    final extensions = [
      '.js', '.css', '.png', '.jpg', '.jpeg', '.gif', '.svg', 
      '.woff', '.woff2', '.ttf', '.eot', '.ico', '.json'
    ];
    
    return extensions.any((ext) => path.endsWith(ext));
  }

  /// 获取缓存文件可以使用的本地路径 (如果存在)
  static File _getLocalFile(Uri uri) {
    // 将 URL 转换为合法的文件名 (替换特殊字符)
    // 例如: http://host:port/assets/index-abc.js -> host_port_assets_index-abc.js
    // 但为了避免文件名过长和冲突，建议保留目录结构或使用 Hash。
    // 这里简单起见，使用 path 的最后一段加上 query 做区分，
    // 或者更安全点：对整个 URL 做 MD5？
    // 考虑到 OpenCode 的文件名已有 Hash (index-temHw60R.js)，直接用 URL path 部分即可。
    // 但是不同服务器可能有同名文件... 还是带上 host 吧。
    
    final safeName = uri.toString()
      .replaceAll('://', '_')
      .replaceAll('/', '_')
      .replaceAll(':', '_')
      .replaceAll('?', '_');
      
    // 截断过长的文件名 (Android 限制 255 字符)
    final fileName = safeName.length > 200 
        ? safeName.substring(safeName.length - 200) 
        : safeName;
        
    return File('$_cachePath/$fileName');
  }

  /// 尝试获取缓存数据
  /// 返回: 缓存文件的字节数据，如果无缓存或读取失败返回 null
  static Future<Uint8List?> load(Uri uri) async {
    if (_cachePath == null) await init();
    
    final file = _getLocalFile(uri);
    if (await file.exists()) {
      try {
        debugPrint('CACHE_HIT: $uri');
        return await file.readAsBytes();
      } catch (e) {
        debugPrint('CACHE_READ_ERR: $e');
      }
    }
    return null;
  }

  /// 下载并缓存资源 (后台运行，不阻塞当前请求)
  static Future<Uint8List?> downloadAndCache(Uri uri) async {
    if (_cachePath == null) await init();
    
    try {
      debugPrint('CACHE_DOWNLOAD: $uri');
      final response = await _dio.getUri(
        uri,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Uint8List;
        final file = _getLocalFile(uri);
        // 异步写入，不等待
        file.writeAsBytes(data).catchError((e) {
          debugPrint('CACHE_WRITE_ERR: $e');
          return file;
        });
        return data;
      }
    } catch (e) {
      debugPrint('CACHE_DOWNLOAD_ERR: $e');
    }
    return null;
  }
}
