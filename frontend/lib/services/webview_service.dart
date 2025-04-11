// Updated webview_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/product_info.dart';
import '../utils/debug_utils.dart';

class WebViewService {
  final WebViewController controller = WebViewController();
  final Function(bool) onLoadingStateChanged;
  final Function(ProductInfo) onProductInfoChanged;
  final Function(String) onUrlChanged;

  WebViewService({
    required this.onLoadingStateChanged,
    required this.onProductInfoChanged,
    required this.onUrlChanged,
  });

  void initializeWebView(String initialUrl) {
    DebugLog.i('Initializing WebView with URL: $initialUrl',
        category: DebugLog.WEBVIEW);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _handlePageStarted,
          onPageFinished: _handlePageFinished,
          onWebResourceError: (WebResourceError error) {
            // Only log errors that might be important, filter out noise
            if (error.errorType !=
                    WebResourceErrorType.webContentProcessTerminated &&
                error.errorType != WebResourceErrorType.unknown) {
              DebugLog.e('WebView error: ${error.description}',
                  category: DebugLog.WEBVIEW,
                  details: 'Type: ${error.errorType}');
            }
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              onUrlChanged(change.url!);
              // When URL changes, we should reset the loading state
              onLoadingStateChanged(true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));

    // Add custom JavaScript to filter console logs
    _injectConsoleFilter();
  }

  // Inject code to filter WebView console logs
  void _injectConsoleFilter() {
    const filterScript = '''
      // Override console methods to reduce noise
      (function() {
        const originalConsoleLog = console.log;
        const originalConsoleWarn = console.warn;
        const originalConsoleError = console.error;
        
        // Filter patterns we want to skip
        const filterPatterns = [
          'JQMIGRATE',
          'ResizeObserver',
          'localStorage',
          'sessionStorage',
          'Content Security Policy',
          'Synchronous XMLHttpRequest',
          'DevTools',
          'Failed to load resource',
          'The XDG_'
        ];
        
        // Check if a message should be filtered
        function shouldFilter(args) {
          const msg = args.join(' ');
          return filterPatterns.some(pattern => msg.includes(pattern));
        }
        
        // Override console.log
        console.log = function(...args) {
          if (!shouldFilter(args)) {
            originalConsoleLog.apply(console, args);
          }
        };
        
        // Override console.warn
        console.warn = function(...args) {
          if (!shouldFilter(args)) {
            originalConsoleWarn.apply(console, args);
          }
        };
        
        // Override console.error
        console.error = function(...args) {
          if (!shouldFilter(args)) {
            originalConsoleError.apply(console, args);
          }
        };
      })();
    ''';

    try {
      controller.runJavaScript(filterScript);
    } catch (e) {
      DebugLog.w('Could not inject console filter: $e',
          category: DebugLog.WEBVIEW);
    }
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);
      DebugLog.d('Received product data from JS',
          category: DebugLog.PRODUCT, details: data);

      // Check if we have a valid product message
      if (data['isProductPage'] == true) {
        // Create product info object from data
        final newProductInfo = ProductInfo.fromJson(data);

        // Only notify if we have valid product data (success = true indicates valid product)
        if (newProductInfo.success) {
          DebugLog.i('Successfully extracted product info',
              category: DebugLog.PRODUCT);
          onProductInfoChanged(newProductInfo);
        } else {
          DebugLog.w('Product page detected but extraction failed',
              category: DebugLog.PRODUCT);
        }
      }

      // Handle URL change notification if present
      if (data.containsKey('navigated') &&
          data['navigated'] == true &&
          data.containsKey('url') &&
          data['url'] != null) {
        onUrlChanged(data['url']);
      }
    } catch (e) {
      DebugLog.w('Error parsing product data JSON: $e',
          category: DebugLog.PRODUCT);

      try {
        // Fallback parsing for simple format (price|title)
        final data = message.message.split('|');
        if (data.length >= 2) {
          final price = double.tryParse(data[0]);
          if (price != null) {
            DebugLog.i('Using fallback parsing for product data',
                category: DebugLog.PRODUCT);
            final newProductInfo = ProductInfo(
              isProductPage: true,
              title: data[1],
              price: price,
              url: controller.currentUrl().toString(),
              success: true,
            );
            onProductInfoChanged(newProductInfo);
          }
        }
      } catch (e) {
        DebugLog.e('Error with fallback parsing: $e',
            category: DebugLog.PRODUCT);
      }
    }
  }

  void _handlePageStarted(String url) {
    DebugLog.i('Page started loading: $url', category: DebugLog.WEBVIEW);
    onLoadingStateChanged(true);
    onUrlChanged(url);
  }

  void _handlePageFinished(String url) {
    DebugLog.i('Page finished loading: $url', category: DebugLog.WEBVIEW);
    onLoadingStateChanged(false);
    _injectProductDetector();
  }

  Future<void> _injectProductDetector() async {
    try {
      DebugLog.d('Injecting product detector script',
          category: DebugLog.PRODUCT);

      // First inject the script from assets
      final script = await rootBundle.loadString('assets/product_detector.js');
      await controller.runJavaScript(script);

      // Then execute the init function with a delay to let the page fully render
      await Future.delayed(const Duration(milliseconds: 500));
      await controller.runJavaScript('''
        // Clear any existing timers
        if (window._productDetectionTimers) {
          window._productDetectionTimers.forEach(timer => clearTimeout(timer));
        }
        window._productDetectionTimers = [];
        
        // First attempt immediate detection
        detectAndReportProduct();
        
        // Then schedule additional detection attempts with increasing delays
        // This helps with sites that load content dynamically
        window._productDetectionTimers.push(setTimeout(() => detectAndReportProduct(), 1000));
        window._productDetectionTimers.push(setTimeout(() => detectAndReportProduct(), 2500));
        window._productDetectionTimers.push(setTimeout(() => detectAndReportProduct(), 5000));
      ''');

      DebugLog.i(
          'Product detector script injected and initialized successfully',
          category: DebugLog.PRODUCT);
    } catch (e) {
      DebugLog.e('Error injecting product detector script: $e',
          category: DebugLog.PRODUCT);
      _injectLegacyPriceExtractor();
    }
  }

  void _injectLegacyPriceExtractor() {
    final js = '''
      function extractProductInfo() {
        // This function will run multiple extraction methods to improve success rate
        
        // Method 1: Use common price selectors
        function tryCommonSelectors() {
          // Price selectors for different sites (optimized for Turkish e-commerce)
          const priceSelectors = [
            '.price', '[data-testid="price"]', '.product-price', 
            '.product-info__price', '.pricing', '.new-price',
            '.current-price', '.price-box', '.price-current',
            '.cost', '.actual-price', '.pdp-price', '.urun-fiyat',
            '.money', '.price-item', '.product-price-container',
            '.main-price', '.item-price', '.now', '.discount-price',
            '.current', '[itemprop="price"]', '[data-price]',
            // Turkish-specific selectors
            '.fiyat', '.urunDetayFiyat', '.satisFiyat', '.indirimliFiyat', 
            '.urun-fiyati', '.product-price-tr', '.aktuel-fiyat',
            '.urn_adetfiyat', '.prc-box-dscntd'
          ];

          // Product title selectors for different sites
          const titleSelectors = [
            'h1', '.product-title', '.product-name', 
            '.item-title', '.product-info__name', '.pdp-title',
            '.main-title', '.product-detail-name', '.product-single__title',
            '.product_title', '.title-container', '[itemprop="name"]',
            '.product-page__name', '.urun-adi', '.item-name',
            // Turkish-specific selectors
            '.urun-ismi', '.urunDetayBaslik', '.productName', '.productTitle',
            '.product-title-tr', '.urun-baslik', '.product-detail-title', 
            '.prdct-desc-cntnr-name', '.pro_header', '.prdct-title'
          ];

          // Try to find price using various selectors
          let priceElement = null;
          for (const selector of priceSelectors) {
            const elements = document.querySelectorAll(selector);
            for (const element of elements) {
              if (element && element.textContent.trim()) {
                // Check if the content matches a price pattern
                const text = element.textContent.trim();
                if (/[0-9]+[,.][0-9]+.*?(TL|\\u20BA|\$|€|£)/i.test(text)) {
                  priceElement = element;
                  break;
                }
              }
            }
            if (priceElement) break;
          }

          // Try to find title using various selectors
          let titleElement = null;
          for (const selector of titleSelectors) {
            const element = document.querySelector(selector);
            if (element && element.textContent.trim()) {
              titleElement = element;
              break;
            }
          }
          
          if (priceElement && titleElement) {
            return {
              price: priceElement.textContent.trim(),
              title: titleElement.textContent.trim()
            };
          }
          
          return null;
        }
        
        // Method 2: Look for structured data in meta tags
        function tryMetaTags() {
          // Try Open Graph, Twitter Cards, and other meta tags
          const priceMetaSelector = 'meta[property="product:price:amount"], meta[property="og:price:amount"], meta[name="twitter:data1"], meta[itemprop="price"]';
          const titleMetaSelector = 'meta[property="og:title"], meta[name="twitter:title"], meta[itemprop="name"]';
          
          const priceMetaTag = document.querySelector(priceMetaSelector);
          const titleMetaTag = document.querySelector(titleMetaSelector);
          
          if (priceMetaTag && titleMetaTag) {
            return {
              price: priceMetaTag.getAttribute('content'),
              title: titleMetaTag.getAttribute('content')
            };
          }
          
          return null;
        }
        
        // Method 3: Look for any text that matches price patterns in the page
        function scanForPricePatterns() {
          const priceRegex = /([0-9]+[.,][0-9]+)\\s*(?:TL|₺|\$|€|£)/i;
          const elements = document.querySelectorAll('div, span, p');
          
          let bestPriceElement = null;
          let bestPriceValue = null;
          
          // Get h1 as the title
          const titleElement = document.querySelector('h1') || document.querySelector('title');
          if (!titleElement) return null;
          
          // Look through all elements for price patterns
          for (const element of elements) {
            const text = element.textContent.trim();
            const match = text.match(priceRegex);
            
            if (match) {
              // If we find multiple price matches, use the one closest to the product info
              if (!bestPriceElement || 
                Math.abs(window.innerHeight/2 - element.getBoundingClientRect().top) < 
                Math.abs(window.innerHeight/2 - bestPriceElement.getBoundingClientRect().top)) {
                bestPriceElement = element;
                bestPriceValue = match[0];
              }
            }
          }
          
          if (bestPriceElement && titleElement) {
            return {
              price: bestPriceValue,
              title: titleElement.textContent.trim()
            };
          }
          
          return null;
        }
        
        // Try all methods in sequence
        const result = tryCommonSelectors() || tryMetaTags() || scanForPricePatterns();
        
        if (result) {
          // Format the price for better parsing
          let priceStr = result.price;
          
          // First check if it's already a clean number
          if (!isNaN(parseFloat(priceStr))) {
            // Format as JSON
            let productInfo = {
              isProductPage: true,
              title: result.title,
              price: parseFloat(priceStr),
              success: true,
              url: window.location.href
            };
            FlutterChannel.postMessage(JSON.stringify(productInfo));
            return;
          }
          
          // Extract numeric price from text
          let price = priceStr.replace(/[^0-9.,]/g, '');
          
          // Handle different currency format (1.234,56 TL -> 1234.56)
          if (price.includes(',') && price.includes('.')) {
            // Remove all periods (thousand separators in Turkish format)
            price = price.replace(/\\./g, '');
            // Replace comma with period (decimal separator)
            price = price.replace(',', '.');
          } else if (price.includes(',')) {
            // If only comma exists, it's likely a decimal separator
            price = price.replace(',', '.');
          }
          
          if (price && !isNaN(parseFloat(price))) {
            // Format as JSON
            let productInfo = {
              isProductPage: true,
              title: result.title,
              price: parseFloat(price),
              success: true,
              url: window.location.href
            };
            FlutterChannel.postMessage(JSON.stringify(productInfo));
          }
        }
      }
      
      // Try immediate extraction for static content
      setTimeout(extractProductInfo, 800);
      
      // Additional attempts to handle dynamic content loading
      setTimeout(extractProductInfo, 2000);
      setTimeout(extractProductInfo, 4000);
      
      // Observe DOM changes to detect dynamic content loading
      const observer = new MutationObserver(() => {
        setTimeout(extractProductInfo, 500);
      });
      
      observer.observe(document.body, { subtree: true, childList: true });
      
      // Also try extraction after all resources are loaded
      window.addEventListener('load', () => setTimeout(extractProductInfo, 1500));
    ''';

    controller.runJavaScript(js);
    DebugLog.i('Legacy price extractor injected as fallback',
        category: DebugLog.PRODUCT);
  }

  Future<void> loadUrl(String url) async {
    DebugLog.i('Loading URL: $url', category: DebugLog.WEBVIEW);
    controller.loadRequest(Uri.parse(url));
  }

  Future<bool> canGoBack() async {
    return controller.canGoBack();
  }

  Future<void> goBack() async {
    DebugLog.d('Navigating back', category: DebugLog.WEBVIEW);
    await controller.goBack();
  }

  Future<bool> canGoForward() async {
    return controller.canGoForward();
  }

  Future<void> goForward() async {
    DebugLog.d('Navigating forward', category: DebugLog.WEBVIEW);
    await controller.goForward();
  }

  Future<void> reload() async {
    DebugLog.d('Reloading page', category: DebugLog.WEBVIEW);
    await controller.reload();
  }
}
