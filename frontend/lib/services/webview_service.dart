import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/product_info.dart';
import '../models/variant_option.dart'; // Added import
import '../utils/debug_utils.dart';

class WebViewService {
  final WebViewController controller = WebViewController();
  final Function(bool) onLoadingStateChanged;
  final Function(ProductInfo) onProductInfoChanged;
  final Function(String) onUrlChanged;

  // Add a property to store the last detected product info
  ProductInfo? _lastProductInfo;

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
              // Reset the last product info
              _lastProductInfo = null;
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
      // Debug the raw message first
      debugPrint('[PD][DEBUG] Raw message length: ${message.message.length}');

      // For large messages, just show beginning and end
      if (message.message.length > 1000) {
        debugPrint(
            '[PD][DEBUG] Raw message start: ${message.message.substring(0, 100)}...');
        debugPrint(
            '[PD][DEBUG] Raw message end: ${message.message.substring(message.message.length - 100)}');
      } else {
        debugPrint('[PD][DEBUG] Raw message: ${message.message}');
      }

      final data = jsonDecode(message.message);
      debugPrint(
          '[PD][DEBUG] Received message from JS with keys: ${data.keys.join(", ")}');

      // Check if this is an enhanced variants message from our custom Zara script
      if (data.containsKey('type') && data['type'] == 'enhanced_variants') {
        debugPrint('[PD][DEBUG] Received enhanced variants data');

        // Process enhanced variants only if we have a last product info
        if (_lastProductInfo != null && data.containsKey('variants')) {
          _processEnhancedVariants(data['variants']);
        }
        return;
      }

      // Check if this is a Zara product by URL or brand
      bool isZaraProduct = false;
      String? url = data['url'] as String?;
      String? brand = data['brand'] as String?;
      if (url != null && url.toLowerCase().contains('zara.com')) {
        isZaraProduct = true;
      } else if (brand != null && brand.toLowerCase() == 'zara') {
        isZaraProduct = true;
      }

      // Debug variants structure immediately after JSON decode
      if (data.containsKey('variants')) {
        final variants = data['variants'];
        debugPrint('[PD][DEBUG] Variants keys: ${variants.keys.join(", ")}');

        // Debug each variant type in detail
        if (variants.containsKey('colors')) {
          final colors = variants['colors'];
          debugPrint(
              '[PD][DEBUG] Raw colors: ${colors.runtimeType}, count: ${colors.length}');

          // Dump the entire colors array for inspection
          debugPrint('[PD][DEBUG] Raw colors JSON: ${jsonEncode(colors)}');

          // Log first two colors to check structure
          if (colors is List && colors.length > 0) {
            for (int i = 0; i < min(colors.length, 2); i++) {
              debugPrint('[PD][DEBUG] Color $i: ${jsonEncode(colors[i])}');
            }
          }
        }

        if (variants.containsKey('sizes')) {
          final sizes = variants['sizes'];
          debugPrint(
              '[PD][DEBUG] Raw sizes: ${sizes.runtimeType}, count: ${sizes.length}');

          // Dump the entire sizes array for inspection
          debugPrint('[PD][DEBUG] Raw sizes JSON: ${jsonEncode(sizes)}');

          // Log first few sizes to check structure
          if (sizes is List && sizes.length > 0) {
            for (int i = 0; i < min(sizes.length, 3); i++) {
              debugPrint('[PD][DEBUG] Size $i: ${jsonEncode(sizes[i])}');
            }
          }
        }
      }

      // Process product information for Zara products
      if (data['isProductPage'] == true) {
        debugPrint('[PD][DEBUG] Processing Zara product variants');

        // Create a properly typed copy of the original data
        final Map<String, dynamic> productData = {};

        // Copy all the top-level fields
        data.forEach((key, value) {
          if (key is String) {
            productData[key] = value;
          }
        });

        // Special debugging for variants
        if (data.containsKey('variants') && data['variants'] is Map) {
          final originalVariants = data['variants'] as Map;
          final Map<String, dynamic> variantsMap = {};

          // Debug the original structure first
          if (originalVariants.containsKey('colors')) {
            final colors = originalVariants['colors'];
            debugPrint(
                '[PD][DEBUG] Found ${colors.length} colors in Zara product');
          }

          if (originalVariants.containsKey('sizes')) {
            final sizes = originalVariants['sizes'];
            debugPrint(
                '[PD][DEBUG] Found ${sizes.length} sizes in Zara product');
          }

          // Copy variant data with proper typing
          originalVariants.forEach((key, value) {
            if (key is String) {
              debugPrint('[PD][DEBUG] Processing variant type: $key');
              // For arrays of variants (colors, sizes, etc.)
              if (value is List) {
                debugPrint(
                    '[PD][DEBUG] Found ${value.length} items in $key list');
                List<Map<String, dynamic>> convertedList = [];

                // Process each item in the list, ensuring it's a properly typed Map
                for (var i = 0; i < value.length; i++) {
                  var item = value[i];
                  debugPrint(
                      '[PD][DEBUG] Processing item $i in $key: ${item.runtimeType}');

                  if (item is Map) {
                    Map<String, dynamic> convertedItem = {};

                    // Copy with proper typing
                    item.forEach((itemKey, itemValue) {
                      if (itemKey is String) {
                        convertedItem[itemKey] = itemValue;
                      }
                    });

                    if (convertedItem.containsKey('text')) {
                      convertedList.add(convertedItem);
                      debugPrint(
                          '[PD][DEBUG] Added item: ${convertedItem['text']}');
                    } else {
                      debugPrint(
                          '[PD][DEBUG] Skipped item - missing text field');
                    }
                  } else {
                    debugPrint(
                        '[PD][DEBUG] Item is not a Map: ${item.runtimeType}');
                  }
                }

                variantsMap[key] = convertedList;
                debugPrint(
                    '[PD][DEBUG] Converted ${convertedList.length} items in ${key}');

                // Check the entire list to make sure
                for (var i = 0; i < convertedList.length; i++) {
                  debugPrint(
                      '[PD][DEBUG] Converted $key $i: ${convertedList[i]['text']}');
                }
              } else {
                variantsMap[key] = value;
              }
            }
          });

          // Store the properly typed variants map
          productData['variants'] = variantsMap;

          // Validate final variants map
          if (variantsMap.containsKey('colors')) {
            debugPrint(
                '[PD][DEBUG] Final colors count: ${variantsMap['colors'].length}');
          }

          if (variantsMap.containsKey('sizes')) {
            debugPrint(
                '[PD][DEBUG] Final sizes count: ${variantsMap['sizes'].length}');
          }
        }

        // Create product info from our properly copied data
        final newProductInfo = ProductInfo.fromJson(productData);

        // Debug log the result
        if (newProductInfo.variants != null) {
          debugPrint('[PD][DEBUG] Final ProductInfo variants:');
          if (newProductInfo.variants!.containsKey('colors')) {
            debugPrint(
                '[PD][DEBUG] - Colors: ${newProductInfo.variants!["colors"]?.length}');
            // Log each color
            newProductInfo.variants!["colors"]?.forEach((color) {
              debugPrint('[PD][DEBUG] - Color: ${color.text}');
            });
          }
          if (newProductInfo.variants!.containsKey('sizes')) {
            debugPrint(
                '[PD][DEBUG] - Sizes: ${newProductInfo.variants!["sizes"]?.length}');
            // Log each size
            newProductInfo.variants!["sizes"]?.forEach((size) {
              debugPrint('[PD][DEBUG] - Size: ${size.text}');
            });
          }
        }

        // Store this product info for potential enhancement later
        _lastProductInfo = newProductInfo;

        // Only notify if we have valid product data
        if (newProductInfo.success) {
          onProductInfoChanged(newProductInfo);
        }

        // If it's a Zara product, try to get more complete color and size data
        if (isZaraProduct) {
          // Let's request an updated set of colors and sizes for Zara products
          // This is the temporary fix to get around the structured data extraction limitation
          controller.runJavaScript('''
            try {
              // Function to fetch and report all Zara variants
              function fetchZaraVariants() {
                const results = { colors: [], sizes: [] };
                
                // Find color variants - specifically for Zara's structure
                try {
                  const colorContainer = document.querySelector(".product-detail-color-selector__colors");
                  if (colorContainer) {
                    const colorItems = colorContainer.querySelectorAll(
                      ".product-detail-color-selector__color"
                    );
                    
                    for (const colorItem of colorItems) {
                      // Check if this color is selected
                      const isSelected = !!colorItem.querySelector(
                        ".product-detail-color-selector__color-button--is-selected"
                      );
                      
                      // Get color area to extract the RGB value
                      const colorArea = colorItem.querySelector(
                        ".product-detail-color-selector__color-area"
                      );
                      if (!colorArea) continue;
                      
                      // Try to get color name from screen reader text
                      const screenReaderText = colorItem.querySelector(".screen-reader-text");
                      let colorName = screenReaderText
                        ? screenReaderText.textContent.trim()
                        : "";
                      
                      // If no name found, try button aria-label
                      if (!colorName) {
                        const colorButton = colorItem.querySelector("button");
                        if (colorButton) {
                          colorName = colorButton.getAttribute("aria-label") || "";
                        }
                      }
                      
                      // Extract RGB color from style
                      let colorValue = "";
                      const styleAttr = colorArea.getAttribute("style");
                      if (styleAttr) {
                        const rgbMatch = styleAttr.match(/background-color:\\s*([^;]+)/);
                        if (rgbMatch && rgbMatch[1]) {
                          colorValue = rgbMatch[1].trim();
                        }
                      }
                      
                      // Add to results if we have name
                      if (colorName) {
                        results.colors.push({
                          text: colorName,
                          selected: isSelected,
                          value: colorValue || colorName,
                        });
                      }
                    }
                  }
                } catch(e) {
                  console.error("Error getting Zara colors:", e);
                }
                
                // Find size variants - specifically for Zara's structure
                try {
                  const sizeContainer = document.querySelector(".size-selector-sizes");
                  if (sizeContainer) {
                    const sizeItems = sizeContainer.querySelectorAll(
                      ".size-selector-sizes__size"
                    );
                    
                    for (const sizeItem of sizeItems) {
                      // Check if enabled (in stock)
                      const isEnabled = !sizeItem.classList.contains(
                        "size-selector-sizes-size--disabled"
                      );
                      
                      // Get size label
                      const sizeLabel = sizeItem.querySelector(
                        ".size-selector-sizes-size__label"
                      );
                      if (!sizeLabel) continue;
                      
                      const sizeText = sizeLabel.textContent.trim();
                      if (!sizeText) continue;
                      
                      // Check if selected
                      const isSelected =
                        sizeItem.classList.contains("selected") ||
                        sizeItem.classList.contains("size-selector-sizes-size--selected") ||
                        !!sizeItem.querySelector('[aria-selected="true"]');
                      
                      // Create value object with inStock info
                      const valueObj = {
                        size: sizeText,
                        inStock: isEnabled,
                      };
                      
                      // Add to results
                      results.sizes.push({
                        text: sizeText,
                        selected: isSelected,
                        value: JSON.stringify(valueObj),
                      });
                    }
                  }
                } catch(e) {
                  console.error("Error getting Zara sizes:", e);
                }
                
                return results;
              }
              
              // Get Zara-specific variants
              const zaraVariants = fetchZaraVariants();
              
              // Log results for debugging
              console.log("[PD][DEBUG] Zara variants retrieved:", 
                zaraVariants.colors.length + " colors, " + 
                zaraVariants.sizes.length + " sizes");
                
              // If we found more variants than what's currently in the message,
              // send the enhanced data
              if (zaraVariants.colors.length > 0 || zaraVariants.sizes.length > 0) {
                // Create message with enhanced variants
                const enhancedMessage = {
                  type: "enhanced_variants",
                  variants: zaraVariants
                };
                
                // Send to Flutter
                FlutterChannel.postMessage(JSON.stringify(enhancedMessage));
              }
            } catch(e) {
              console.error("[PD][DEBUG] Error getting enhanced Zara variants:", e);
            }
          ''');
        }
      } else {
        // For non-product pages
        debugPrint('[PD][DEBUG] Not a product page');
      }

      // Handle URL change notification if present
      if (data.containsKey('navigated') &&
          data['navigated'] == true &&
          data.containsKey('url') &&
          data['url'] != null) {
        onUrlChanged(data['url']);
      }
    } catch (e, stackTrace) {
      debugPrint('[PD][DEBUG] Error parsing product data: $e');
      debugPrint('[PD][DEBUG] Stack trace: $stackTrace');

      // Fallback parsing for simple format (price|title)
      try {
        final data = message.message.split('|');
        if (data.length >= 2) {
          final price = double.tryParse(data[0]);
          if (price != null) {
            final newProductInfo = ProductInfo(
              isProductPage: true,
              title: data[1],
              price: price,
              url: controller.currentUrl().toString(),
              success: true,
            );
            _lastProductInfo = newProductInfo;
            onProductInfoChanged(newProductInfo);
          }
        }
      } catch (e) {
        debugPrint('[PD][DEBUG] Error with fallback parsing: $e');
      }
    }
  }

  // Process enhanced variants from Zara
  void _processEnhancedVariants(Map<String, dynamic> enhancedVariants) {
    if (_lastProductInfo == null) {
      debugPrint('[PD][DEBUG] No product info to enhance');
      return;
    }

    // Create a deep copy of the last product info
    final productData = {
      'isProductPage': _lastProductInfo!.isProductPage,
      'title': _lastProductInfo!.title,
      'price': _lastProductInfo!.price,
      'originalPrice': _lastProductInfo!.originalPrice,
      'currency': _lastProductInfo!.currency,
      'imageUrl': _lastProductInfo!.imageUrl,
      'description': _lastProductInfo!.description,
      'sku': _lastProductInfo!.sku,
      'availability': _lastProductInfo!.availability,
      'brand': _lastProductInfo!.brand,
      'extractionMethod': _lastProductInfo!.extractionMethod,
      'url': _lastProductInfo!.url,
      'success': _lastProductInfo!.success,
      'variants': <String, dynamic>{},
    };

    // Process enhanced variants
    final Map<String, dynamic> newVariants = {};

    // Process colors
    if (enhancedVariants.containsKey('colors') &&
        enhancedVariants['colors'] is List) {
      final List<dynamic> colors = enhancedVariants['colors'];
      final List<Map<String, dynamic>> convertedColors = [];

      debugPrint('[PD][DEBUG] Processing ${colors.length} enhanced colors');

      for (final color in colors) {
        if (color is Map) {
          final Map<String, dynamic> convertedColor = {};

          // Convert keys
          color.forEach((key, value) {
            if (key is String) {
              convertedColor[key] = value;
            }
          });

          if (convertedColor.containsKey('text')) {
            convertedColors.add(convertedColor);
            debugPrint(
                '[PD][DEBUG] Added enhanced color: ${convertedColor['text']}');
          }
        }
      }

      if (convertedColors.isNotEmpty) {
        newVariants['colors'] = convertedColors;
      }
    }

    // Process sizes
    if (enhancedVariants.containsKey('sizes') &&
        enhancedVariants['sizes'] is List) {
      final List<dynamic> sizes = enhancedVariants['sizes'];
      final List<Map<String, dynamic>> convertedSizes = [];

      debugPrint('[PD][DEBUG] Processing ${sizes.length} enhanced sizes');

      for (final size in sizes) {
        if (size is Map) {
          final Map<String, dynamic> convertedSize = {};

          // Convert keys
          size.forEach((key, value) {
            if (key is String) {
              convertedSize[key] = value;
            }
          });

          if (convertedSize.containsKey('text')) {
            convertedSizes.add(convertedSize);
            debugPrint(
                '[PD][DEBUG] Added enhanced size: ${convertedSize['text']}');
          }
        }
      }

      if (convertedSizes.isNotEmpty) {
        newVariants['sizes'] = convertedSizes;
      }
    }

    // Preserve other options from original product info
    if (_lastProductInfo!.variants != null &&
        _lastProductInfo!.variants!.containsKey('otherOptions')) {
      newVariants['otherOptions'] = [];

      for (final option in _lastProductInfo!.variants!['otherOptions']!) {
        final Map<String, dynamic> convertedOption = {
          'text': option.text,
          'selected': option.selected,
          'value': option.value
        };

        (newVariants['otherOptions'] as List).add(convertedOption);
      }
    } else {
      newVariants['otherOptions'] = [];
    }

    // Update variants in the product data
    productData['variants'] = newVariants;

    // Create enhanced product info
    final enhancedProductInfo = ProductInfo.fromJson(productData);

    // Debug the enhanced product
    debugPrint('[PD][DEBUG] Created enhanced product info');
    if (enhancedProductInfo.variants != null) {
      debugPrint('[PD][DEBUG] Enhanced variants:');
      if (enhancedProductInfo.variants!.containsKey('colors')) {
        debugPrint(
            '[PD][DEBUG] - Colors: ${enhancedProductInfo.variants!["colors"]?.length}');
        enhancedProductInfo.variants!["colors"]?.forEach((color) {
          debugPrint('[PD][DEBUG] - Enhanced color: ${color.text}');
        });
      }
      if (enhancedProductInfo.variants!.containsKey('sizes')) {
        debugPrint(
            '[PD][DEBUG] - Sizes: ${enhancedProductInfo.variants!["sizes"]?.length}');
        enhancedProductInfo.variants!["sizes"]?.forEach((size) {
          debugPrint('[PD][DEBUG] - Enhanced size: ${size.text}');
        });
      }
    }

    // Store and notify
    _lastProductInfo = enhancedProductInfo;
    onProductInfoChanged(enhancedProductInfo);
    debugPrint('[PD][DEBUG] Enhanced product info sent to UI');
  }

  void _handlePageStarted(String url) {
    DebugLog.i('Page started loading: $url', category: DebugLog.WEBVIEW);
    onLoadingStateChanged(true);
    onUrlChanged(url);
    _lastProductInfo = null; // Reset last product info on page change
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
    _lastProductInfo = null; // Reset product info when loading a new URL
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
    _lastProductInfo = null; // Reset product info on reload
    await controller.reload();
  }
}
