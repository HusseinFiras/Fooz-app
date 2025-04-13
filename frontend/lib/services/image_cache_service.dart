import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';


class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Cache directory
  Directory? _cacheDir;
  final Map<String, String> _inMemoryCache = {};
  bool _initialized = false;

  // Initialize the cache
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _cacheDir = await getTemporaryDirectory();
      _initialized = true;
      debugPrint('[IMAGE_CACHE] Initialized at: ${_cacheDir?.path}');
    } catch (e) {
      debugPrint('[IMAGE_CACHE] Error initializing cache: $e');
    }
  }

  // Get file name from URL using MD5 hash
  String _getFileName(String url) {
    var bytes = utf8.encode(url);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  // Get cached image file path
  Future<String?> getCachedImagePath(String url) async {
    await initialize();
    
    // Check in-memory cache first for quick lookup
    if (_inMemoryCache.containsKey(url)) {
      return _inMemoryCache[url];
    }
    
    if (_cacheDir == null) return null;

    final fileName = _getFileName(url);
    final file = File('${_cacheDir!.path}/$fileName.png');
    
    // Check if file exists
    if (await file.exists()) {
      _inMemoryCache[url] = file.path;
      return file.path;
    }
    
    return null;
  }

  // Cache an image
  Future<String?> cacheImage(String url) async {
    await initialize();
    if (_cacheDir == null) return null;

    // Check if already in cache
    final cachedPath = await getCachedImagePath(url);
    if (cachedPath != null) {
      return cachedPath;
    }

    try {
      // Build custom request with browser-like headers
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.gucci.com/',
        'Origin': 'https://www.gucci.com',
        'Cache-Control': 'no-cache',
      });

      // Send the request
      final httpResponse = await http.Client().send(request);
      
      if (httpResponse.statusCode != 200) {
        debugPrint('[IMAGE_CACHE] Error downloading image: HTTP ${httpResponse.statusCode}');
        return null;
      }

      // Read response bytes
      final bytes = await httpResponse.stream.toBytes();
      if (bytes.isEmpty) {
        debugPrint('[IMAGE_CACHE] Downloaded empty image');
        return null;
      }
      
      // Save to file
      final fileName = _getFileName(url);
      final file = File('${_cacheDir!.path}/$fileName.png');
      await file.writeAsBytes(bytes);
      
      // Store in memory cache
      _inMemoryCache[url] = file.path;
      
      debugPrint('[IMAGE_CACHE] Image cached: $url -> ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('[IMAGE_CACHE] Error caching image: $e');
      return null;
    }
  }

  // Get or cache image in one call
  Future<String?> getOrCacheImage(String url) async {
    final cachedPath = await getCachedImagePath(url);
    if (cachedPath != null) {
      return cachedPath;
    }
    return await cacheImage(url);
  }

  // Clear all cached images
  Future<void> clearCache() async {
    await initialize();
    if (_cacheDir == null) return;
    
    try {
      final dir = Directory(_cacheDir!.path);
      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.png')) {
          await file.delete();
        }
      }
      _inMemoryCache.clear();
      debugPrint('[IMAGE_CACHE] Cache cleared');
    } catch (e) {
      debugPrint('[IMAGE_CACHE] Error clearing cache: $e');
    }
  }
}