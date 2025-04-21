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
      // Debug the raw message only if it's exceptionally large
      if (message.message.length > 1000) {
        debugPrint('[PD] Raw message: ${message.message.substring(0, 100)}...');
      }

      final data = jsonDecode(message.message);
      
      // Check if this is an enhanced variants message from our custom script
      if (data.containsKey('type') && data['type'] == 'enhanced_variants') {
        debugPrint('[PD] Received enhanced variants data');

        // Process enhanced variants only if we have a last product info
        if (_lastProductInfo != null && data.containsKey('variants')) {
          _processEnhancedVariants(data['variants']);
        }
        return;
      }

      // Check if this is a Stradivarius product by URL or brand
      bool isStradivariusProduct = false;
      String? url = data['url'] as String?;
      String? brand = data['brand'] as String?;
      if (url != null && url.toLowerCase().contains('stradivarius.com')) {
        isStradivariusProduct = true;
        debugPrint('[PD] Stradivarius product detected by URL');
      } else if (brand != null && brand.toLowerCase() == 'stradivarius') {
        isStradivariusProduct = true;
        debugPrint('[PD] Stradivarius product detected by brand');
      }

      // Check if this is a Zara product by URL or brand
      bool isZaraProduct = false;
      if (url != null && url.toLowerCase().contains('zara.com')) {
        isZaraProduct = true;
      } else if (brand != null && brand.toLowerCase() == 'zara') {
        isZaraProduct = true;
      }
      
      // Check if this is a Guess product by URL or brand
      bool isGuessProduct = false;
      if (url != null && url.toLowerCase().contains('guess.eu')) {
        isGuessProduct = true;
        debugPrint('[PD] Guess product detected by URL');
      } else if (brand != null && brand.toLowerCase() == 'guess') {
        isGuessProduct = true;
        debugPrint('[PD] Guess product detected by brand');
      }

      // Check if this is a Bershka product by URL or brand
      bool isBershkaProduct = false;
      if (url != null && url.toLowerCase().contains('bershka.com')) {
        isBershkaProduct = true;
        debugPrint('[PD] Bershka product detected by URL');
      } else if (brand != null && brand.toLowerCase() == 'bershka') {
        isBershkaProduct = true;
        debugPrint('[PD] Bershka product detected by brand');
      }

      // Process product information for product pages
      if (data['isProductPage'] == true) {
        debugPrint('[PD] Processing product variants');

        // Create a properly typed copy of the original data
        final Map<String, dynamic> productData = {};

        // Copy all the top-level fields
        data.forEach((key, value) {
          if (key is String) {
            productData[key] = value;
          }
        });

        // Process variants data
        if (data.containsKey('variants') && data['variants'] is Map) {
          final originalVariants = data['variants'] as Map;
          final Map<String, dynamic> variantsMap = {};

          // Copy variant data with proper typing
          originalVariants.forEach((key, value) {
            if (key is String) {
              // For arrays of variants (colors, sizes, etc.)
              if (value is List) {
                List<Map<String, dynamic>> convertedList = [];

                // Process each item in the list, ensuring it's a properly typed Map
                for (var i = 0; i < value.length; i++) {
                  var item = value[i];

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
                    }
                  }
                }

                variantsMap[key] = convertedList;
              } else {
                variantsMap[key] = value;
              }
            }
          });

          // Store the properly typed variants map
          productData['variants'] = variantsMap;
        }

        // Create product info from our properly copied data
        final newProductInfo = ProductInfo.fromJson(productData);

        // Store this product info for potential enhancement later
        _lastProductInfo = newProductInfo;

        // Only notify if we have valid product data
        if (newProductInfo.success) {
          onProductInfoChanged(newProductInfo);
        }

        // If it's a Zara product, try to get more complete color and size data
        if (isZaraProduct) {
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
              
              console.log("[PD] Zara variants retrieved:", 
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
                console.error("[PD] Error getting enhanced Zara variants:", e);
              }
            ''');
        }
        
        // If it's a Stradivarius product, try to get the color variants
        if (isStradivariusProduct) {
          debugPrint('[PD] Extracting Stradivarius variants');
          controller.runJavaScript('''
            try {
              // Function to fetch Stradivarius color variants
              function fetchStradivariusVariants() {
                const results = { colors: [], sizes: [] };
                
                // Find color variants - specifically for Stradivarius structure
                try {
                  const colorContainer = document.querySelector(".color-selector.color-selector--preview");
                  
                  if (colorContainer) {
                    const colorItems = colorContainer.querySelectorAll("li");
                    
                    for (let i = 0; i < colorItems.length; i++) {
                      const colorItem = colorItems[i];
                      // Check if this color is selected
                      const isSelected = colorItem.querySelector(".line-selected") !== null;
                      
                      // Get the image that represents the color
                      const colorImage = colorItem.querySelector("img");
                      if (!colorImage) continue;
                      
                      // Get the image URL
                      const imageUrl = colorImage.getAttribute("src");
                      if (!imageUrl) continue;
                      
                      // Try to extract a color name from the URL
                      // URLs often contain color information in the filename (like 19257570102 where last digits might be color code)
                      let colorName = "Color " + (i + 1);
                      
                      try {
                        // Try to extract the product/color code from the URL
                        const matches = imageUrl.match(/([0-9]+)-m/);
                        if (matches && matches[1]) {
                          // For Stradivarius, typically the last 2-3 digits in the product ID represent the color code
                          const productId = matches[1];
                          const colorCode = productId.slice(-2);
                          
                          // We don't have color names, so we'll use a generic naming with the code
                          colorName = "Color " + colorCode;
                        }
                      } catch(e) {}
                      
                      // Add to results
                      results.colors.push({
                        text: colorName,
                        selected: isSelected,
                        value: imageUrl,  // Store the image URL as the value
                      });
                    }
                  }
                } catch(e) {
                  console.error("Error getting Stradivarius colors:", e);
                }
                
                // Extract sizes from Stradivarius products
                try {
                  const sizesContainer = document.querySelector(".sizes-lists .sizes-list");
                  
                  if (sizesContainer) {
                    const sizeItems = sizesContainer.querySelectorAll(".size-item");
                    
                    for (let i = 0; i < sizeItems.length; i++) {
                      const sizeItem = sizeItems[i];
                      
                      // Check if this size is selected (Stradivarius adds 'selected' class to selected size)
                      const isSelected = sizeItem.classList.contains("selected");
                      
                      // Get stock info - by default assume it's in stock unless explicitly marked otherwise
                      const stockInfo = sizeItem.querySelector(".stock-description");
                      let isInStock = true;
                      
                      if (stockInfo && stockInfo.textContent) {
                        // If there's any text in the stock description, it's usually "out of stock" or similar
                        if (stockInfo.textContent.toLowerCase().includes("out of stock") ||
                            stockInfo.textContent.toLowerCase().includes("notify me") ||
                            stockInfo.textContent.toLowerCase().includes("back soon")) {
                          isInStock = false;
                        }
                      }
                      
                      // Get the size name
                      const sizeNameElement = sizeItem.querySelector(".size-name");
                      if (!sizeNameElement) continue;
                      
                      const sizeName = sizeNameElement.textContent.trim();
                      
                      // Add to results
                      results.sizes.push({
                        text: sizeName,
                        selected: isSelected,
                        value: JSON.stringify({ size: sizeName, inStock: isInStock }),
                      });
                    }
                  }
                } catch(e) {
                  console.error("Error getting Stradivarius sizes:", e);
                }
                
                // Extract product description
                try {
                  const descriptionElement = document.querySelector(".description #descriptionId");
                  if (descriptionElement) {
                    // Send the description along with the variants
                    results.description = descriptionElement.textContent.trim();
                  }
                } catch(e) {
                  console.error("Error getting Stradivarius description:", e);
                }
                
                return results;
              }
              
              // Get Stradivarius-specific variants
              const stradivariusVariants = fetchStradivariusVariants();
              
              // If we found colors or sizes, send the enhanced data
              if (stradivariusVariants.colors.length > 0 || stradivariusVariants.sizes.length > 0) {
                // Create message with enhanced variants
                const enhancedMessage = {
                  type: "enhanced_variants",
                  variants: stradivariusVariants
                };
                
                // Send to Flutter
                FlutterChannel.postMessage(JSON.stringify(enhancedMessage));
              }
            } catch(e) {
              console.error("Error getting enhanced Stradivarius variants:", e);
            }
          ''');
        }
        
        // If it's a Guess product, try to get more accurate color and size data
        if (isGuessProduct) {
          debugPrint('[PD] Extracting Guess variants');
          controller.runJavaScript('''
            try {
              // Function to fetch Guess variants with more accuracy
              function fetchGuessVariants() {
                const results = { colors: [], sizes: [] };
                
                // Extract colors
                try {
                  const colorContainer = document.querySelector(".swatches-wrapper, .color-swatches");
                  if (colorContainer) {
                    const colorButtons = colorContainer.querySelectorAll("button.color-attribute");
                    
                    for (let i = 0; i < colorButtons.length; i++) {
                      const button = colorButtons[i];
                      const colorSwatch = button.querySelector(".color-value");
                      
                      if (colorSwatch) {
                        // Get color code
                        const colorCode = colorSwatch.getAttribute("data-attr-value");
                        
                        // Get color name
                        const colorName = colorSwatch.getAttribute("data-attr-name");
                        
                        // Get image URL if available
                        let imageUrl = "";
                        const style = colorSwatch.getAttribute("style");
                        if (style && style.includes("background-image")) {
                          const match = style.match(/background-image\\s*:\\s*url\\(['"]?(.*?)['"]?\\)/i);
                          if (match && match[1]) {
                            imageUrl = match[1];
                          }
                        }
                        
                        // Check if selected
                        const isSelected = button.classList.contains("attribute__value-wrapper--selected");
                        
                        // Check for selected text
                        const selectedText = button.querySelector(".selected-assistive-text");
                        const hasSelectedText = selectedText && selectedText.textContent.trim() === "selected";
                        
                        if (colorName) {
                          results.colors.push({
                            text: colorName,
                            selected: isSelected || hasSelectedText || colorSwatch.classList.contains("selected"),
                            value: imageUrl || colorCode
                          });
                          
                          console.log("Added Guess color: " + colorName);
                        }
                      }
                    }
                  }
                } catch(e) {
                  console.error("Error getting Guess colors:", e);
                }
                
                // Extract sizes
                try {
                  const sizeContainer = document.querySelector(".variation.single-size, .size-container");
                  if (sizeContainer) {
                    // First try wrappers
                    const sizeWrappers = sizeContainer.querySelectorAll(".attribute__value-wrapper");
                    
                    if (sizeWrappers && sizeWrappers.length > 0) {
                      console.log("Found " + sizeWrappers.length + " size wrappers");
                      
                      for (let i = 0; i < sizeWrappers.length; i++) {
                        const wrapper = sizeWrappers[i];
                        
                        // Check if wrapper is hidden (out of stock or unavailable)
                        const isHidden = wrapper.classList.contains("d-none");
                        
                        // Get the size button inside the wrapper
                        const sizeButton = wrapper.querySelector(".attribute__btn");
                        if (!sizeButton) continue;
                        
                        // Get size value
                        const sizeValue = sizeButton.getAttribute("data-attr-value") || sizeButton.textContent.trim();
                        if (!sizeValue) continue;
                        
                        // Check if available
                        const isAvailable = !isHidden && sizeButton.classList.contains("selectable") && 
                                           !sizeButton.classList.contains("unselectable");
                        
                        // Check if selected
                        const isSelected = sizeButton.classList.contains("selected") || 
                                          sizeButton.getAttribute("aria-selected") === "true";
                        
                        // Create JSON value with inStock info
                        const valueObj = { 
                          size: sizeValue, 
                          inStock: isAvailable 
                        };
                        
                        results.sizes.push({
                          text: sizeValue,
                          selected: isSelected,
                          value: JSON.stringify(valueObj)
                        });
                        
                        console.log("Added Guess size: " + sizeValue + (isSelected ? " (selected)" : "") + 
                                   (isAvailable ? "" : " (out of stock)"));
                      }
                    } else {
                      // Fallback to direct buttons
                      const sizeButtons = sizeContainer.querySelectorAll(".attribute__btn");
                      
                      console.log("Found " + sizeButtons.length + " size buttons");
                      
                      for (let i = 0; i < sizeButtons.length; i++) {
                        const button = sizeButtons[i];
                        
                        // Get size value
                        const sizeValue = button.getAttribute("data-attr-value") || button.textContent.trim();
                        if (!sizeValue) continue;
                        
                        // Check if available
                        const isAvailable = button.classList.contains("selectable") && 
                                          !button.classList.contains("unselectable");
                        
                        // Check if selected
                        const isSelected = button.classList.contains("selected") || 
                                          button.getAttribute("aria-selected") === "true";
                        
                        // Create JSON value with inStock info
                        const valueObj = { 
                          size: sizeValue, 
                          inStock: isAvailable 
                        };
                        
                        results.sizes.push({
                          text: sizeValue,
                          selected: isSelected,
                          value: JSON.stringify(valueObj)
                        });
                        
                        console.log("Added Guess size: " + sizeValue + (isSelected ? " (selected)" : "") + 
                                   (isAvailable ? "" : " (out of stock)"));
                      }
                    }
                  }
                } catch(e) {
                  console.error("Error getting Guess sizes:", e);
                }
                
                return results;
              }
                    
              // Get Guess-specific variants
              const guessVariants = fetchGuessVariants();
              
              // Log what we found
              console.log("Guess variants retrieved: " + 
                         guessVariants.colors.length + " colors, " + 
                         guessVariants.sizes.length + " sizes");
              
              // If we found any variants, send them to Flutter
              if (guessVariants.colors.length > 0 || guessVariants.sizes.length > 0) {
                // Create message with enhanced variants
                const enhancedMessage = {
                  type: "enhanced_variants",
                  variants: guessVariants
                };
                
                // Send to Flutter
                FlutterChannel.postMessage(JSON.stringify(enhancedMessage));
              }
            } catch(e) {
              console.error("Error getting enhanced Guess variants:", e);
            }
          ''');
        }
        
        // If it's a Bershka product, try to get complete color data
        if (isBershkaProduct) {
          controller.runJavaScript('''
            try {
              // Function to fetch and report all Bershka variants
              function fetchBershkaVariants() {
                const results = { colors: [], sizes: [] };
                
                // Find all colors using various methods
                try {
                  // STRATEGY 1: Try to get colors from the expanded colors panel
                  const colorsBarDialog = document.querySelector('.colors-bar__dialog, .colors-bar--mobile');
                  if (colorsBarDialog) {
                    const colorItems = colorsBarDialog.querySelectorAll('.colors-bar__color-item, .colors-bar__link');
                    console.log("Found " + colorItems.length + " color options in Bershka colors dialog");
                    
                    for (const colorItem of colorItems) {
                      // Extract color id
                      const colorId = colorItem.id ? colorItem.id.replace('color-', '') : '';
                      
                      // Check if selected
                      const isSelected = 
                        colorItem.classList.contains('colors-bar__color-item--selected') ||
                        colorItem.getAttribute('aria-selected') === 'true';
                      
                      // Get color name from various sources
                      let colorName = '';
                      
                      // Try color-name element
                      const colorNameElement = colorItem.querySelector('.colors-bar__color-name');
                      if (colorNameElement) {
                        colorName = colorNameElement.textContent.trim();
                      }
                      
                      // Try aria label
                      if (!colorName) {
                        const colorLink = colorItem.querySelector('.colors-bar__link') || colorItem;
                        if (colorLink) {
                          colorName = colorLink.getAttribute('aria-label') || colorLink.getAttribute('aria-describedby');
                        }
                      }
                      
                      // Try tooltip
                      if (!colorName) {
                        const tooltip = document.querySelector('#' + colorItem.getAttribute('aria-describedby'));
                        if (tooltip) {
                          const tooltipText = tooltip.querySelector('.colors-bar__color-name');
                          if (tooltipText) {
                            colorName = tooltipText.textContent.trim();
                          }
                        }
                      }
                      
                      // Try image alt
                      if (!colorName) {
                        const img = colorItem.querySelector('img');
                        if (img) {
                          colorName = img.getAttribute('alt');
                        }
                      }
                      
                      // Color mappings for Bershka color IDs
                      if (!colorName && colorId) {
                        const colorIdMap = {
                          '091': 'Gold',
                          '050': 'Pink',
                          '100': 'Brown',
                          '712': 'Orange',
                          '800': 'Silver',
                          '040': 'Blue',
                          '250': 'Green',
                          '251': 'Dark Green',
                          '500': 'Black',
                          '251': 'White',
                          '600': 'Yellow',
                        };
                        
                        colorName = colorIdMap[colorId] || 'Color ' + colorId;
                      }
                      
                      if (!colorName) continue;
                      
                      // Get image URL
                      let imageUrl = '';
                      const img = colorItem.querySelector('img');
                      if (img) {
                        imageUrl = img.getAttribute('src');
                        if (imageUrl && imageUrl.startsWith('//')) {
                          imageUrl = 'https:' + imageUrl;
                        }
                      }
                      
                      // Add to results if not already present
                      if (!results.colors.some(c => c.text === colorName)) {
                        results.colors.push({
                          text: colorName,
                          selected: isSelected,
                          value: imageUrl || colorName
                        });
                        
                        console.log("Added Bershka color: " + colorName + (isSelected ? " (selected)" : ""));
                      }
                    }
                  }
                  
                  // STRATEGY 2: If no colors found, try the compact selector
                  if (results.colors.length === 0) {
                    const colorSelector = document.querySelector('.color-selector');
                    if (colorSelector) {
                      // Get visible colors
                      const visibleColors = colorSelector.querySelectorAll('.color-selector__color:not(.color-selector__color--more)');
                      console.log("Found " + visibleColors.length + " visible Bershka color options");
                      
                      for (const color of visibleColors) {
                        const isSelected = color.classList.contains('selected');
                        const img = color.querySelector('img');
                        
                        let colorName = '';
                        let imageUrl = '';
                        
                        if (img) {
                          colorName = img.getAttribute('alt');
                          imageUrl = img.getAttribute('src');
                          if (imageUrl && imageUrl.startsWith('//')) {
                            imageUrl = 'https:' + imageUrl;
                          }
                        }
                        
                        if (!colorName) continue;
                        
                        results.colors.push({
                          text: colorName,
                          selected: isSelected,
                          value: imageUrl || colorName
                        });
                        
                        console.log("Added Bershka visible color: " + colorName + (isSelected ? " (selected)" : ""));
                      }
                      
                      // Check for hidden colors
                      const moreColorElement = colorSelector.querySelector('.color-selector__color--more');
                      if (moreColorElement) {
                        const moreText = moreColorElement.textContent.trim();
                        const moreMatch = moreText.match(/\\+(\\d+)/);
                        
                        if (moreMatch) {
                          console.log("Bershka has " + moreMatch[1] + " more hidden colors");
                          
                          // Look for color links in the page source
                          const colorLinks = document.querySelectorAll('a[href*="colorId="]');
                          for (const link of colorLinks) {
                            const href = link.getAttribute('href');
                            const colorIdMatch = href.match(/colorId=(\\d+)/);
                            
                            if (colorIdMatch && colorIdMatch[1]) {
                              const colorId = colorIdMatch[1];
                              
                              // Check if we already have this color
                              const alreadyExists = results.colors.some(c => 
                                c.text.includes(colorId) || (c.value && c.value.includes(colorId)));
                              
                              if (!alreadyExists) {
                                // Try to get from image
                                const img = link.querySelector('img');
                                let colorName = '';
                                let imageUrl = '';
                                
                                if (img) {
                                  colorName = img.getAttribute('alt');
                                  imageUrl = img.getAttribute('src');
                                  if (imageUrl && imageUrl.startsWith('//')) {
                                    imageUrl = 'https:' + imageUrl;
                                  }
                                }
                                
                                // Try from color mapping
                                if (!colorName) {
                                  const colorIdMap = {
                                    '091': 'Gold',
                                    '050': 'Pink',
                                    '100': 'Brown',
                                    '712': 'Orange',
                                    '800': 'Silver',
                                    '040': 'Blue',
                                    '250': 'Green',
                                    '251': 'Dark Green',
                                    '500': 'Black',
                                    '251': 'White',
                                    '600': 'Yellow',
                                  };
                                  
                                  colorName = colorIdMap[colorId] || 'Color ' + colorId;
                                }
                                
                                results.colors.push({
                                  text: colorName,
                                  selected: false,
                                  value: imageUrl || colorName
                                });
                                
                                console.log("Added Bershka hidden color: " + colorName);
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                  
                  // STRATEGY 3: Search the entire DOM for images with color names
                  if (results.colors.length < 3) {
                    const allImagesWithAlt = document.querySelectorAll('.colors-bar img[alt], .color-selector img[alt]');
                    const knownColors = results.colors.map(c => c.text.toLowerCase());
                    
                    for (const img of allImagesWithAlt) {
                      const altText = img.getAttribute('alt');
                      if (altText && !knownColors.includes(altText.toLowerCase())) {
                        // This might be a color we don't have yet
                        const imageUrl = img.getAttribute('src');
                        const fixedUrl = imageUrl && imageUrl.startsWith('//') ? 'https:' + imageUrl : imageUrl;
                        
                        results.colors.push({
                          text: altText,
                          selected: false,
                          value: fixedUrl || altText
                        });
                        
                        console.log("Added Bershka color from image search: " + altText);
                      }
                    }
                  }
                  
                } catch(e) {
                  console.error("Error getting Bershka colors:", e);
                }
                
                // Find size variants - specifically for Bershka's structure
                try {
                  const sizeSelectors = [
                    '.sizes-list li',
                    '.size-selector__size',
                    '[aria-labelledby="a11y-size-selector-pdp-title"] [role="option"]'
                  ];
                  
                  for (const selector of sizeSelectors) {
                    const sizeElements = document.querySelectorAll(selector);
                    if (sizeElements && sizeElements.length > 0) {
                      console.log("Found " + sizeElements.length + " Bershka size options with " + selector);
                      
                      for (const element of sizeElements) {
                        // Check if selected
                        const isSelected = 
                          element.classList.contains('selected') || 
                          element.getAttribute('aria-selected') === 'true';
                        
                        // Check if out of stock
                        const isOutOfStock = 
                          element.classList.contains('unavailable') || 
                          element.classList.contains('disabled') ||
                          element.getAttribute('aria-disabled') === 'true';
                        
                        // Get size text
                        let sizeText = element.textContent.trim();
                        
                        // If no text, try aria-label
                        if (!sizeText) {
                          sizeText = element.getAttribute('aria-label');
                        }
                        
                        if (!sizeText) continue;
                        
                        // Create value object with inStock info
                        const valueObj = { 
                          size: sizeText, 
                          inStock: !isOutOfStock 
                        };
                        
                        results.sizes.push({
                          text: sizeText,
                          selected: isSelected,
                          value: JSON.stringify(valueObj)
                        });
                        
                        console.log("Added Bershka size: " + sizeText + (isSelected ? " (selected)" : "") + 
                                   (isOutOfStock ? " (out of stock)" : ""));
                      }
                      
                      break; // Stop after finding sizes with one selector
                    }
                  }
                } catch(e) {
                  console.error("Error getting Bershka sizes:", e);
                }
                
                return results;
              }
              
              // Get Bershka-specific variants
              const bershkaVariants = fetchBershkaVariants();
              
              // Log what we found
              console.log("Bershka variants retrieved: " + 
                         bershkaVariants.colors.length + " colors, " + 
                         bershkaVariants.sizes.length + " sizes");
              
              // If we found any variants, send them to Flutter
              if (bershkaVariants.colors.length > 0 || bershkaVariants.sizes.length > 0) {
                // Create message with enhanced variants
                const enhancedMessage = {
                  type: "enhanced_variants",
                  variants: bershkaVariants
                };
                
                // Send to Flutter
                FlutterChannel.postMessage(JSON.stringify(enhancedMessage));
              }
            } catch(e) {
              console.error("Error getting enhanced Bershka variants:", e);
            }
          ''');
        }
      } else {
        // For non-product pages
        debugPrint('[PD] Not a product page');
      }

      // Handle URL change notification if present
      if (data.containsKey('navigated') &&
          data['navigated'] == true &&
          data.containsKey('url') &&
          data['url'] != null) {
        onUrlChanged(data['url']);
      }
    } catch (e, stackTrace) {
      debugPrint('[PD] Error parsing product data: $e');
      debugPrint('[PD] Stack trace: $stackTrace');

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
        debugPrint('[PD] Error with fallback parsing: $e');
      }
    }
  }

  // Process enhanced variants from Zara or Stradivarius
  void _processEnhancedVariants(Map<String, dynamic> enhancedVariants) {
    if (_lastProductInfo == null) {
      debugPrint('[PD] No product info to enhance');
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

    // Update description if it's provided in the enhanced variants
    if (enhancedVariants.containsKey('description') && 
        enhancedVariants['description'] != null && 
        (productData['description'] == null || productData['description'].toString().isEmpty)) {
      debugPrint('[PD] Using enhanced description');
      productData['description'] = enhancedVariants['description'];
    }

    // Process enhanced variants
    final Map<String, dynamic> newVariants = {};

    // Process colors
    if (enhancedVariants.containsKey('colors') &&
        enhancedVariants['colors'] is List) {
      final List<dynamic> colors = enhancedVariants['colors'];
      final List<Map<String, dynamic>> convertedColors = [];

      debugPrint('[PD] Processing ${colors.length} enhanced colors');

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

      debugPrint('[PD] Processing ${sizes.length} enhanced sizes');

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
    debugPrint('[PD] Created enhanced product info');
    if (enhancedProductInfo.variants != null) {
      if (enhancedProductInfo.variants!.containsKey('colors')) {
        debugPrint('[PD] Enhanced colors: ${enhancedProductInfo.variants!["colors"]?.length}');
      }
      if (enhancedProductInfo.variants!.containsKey('sizes')) {
        debugPrint('[PD] Enhanced sizes: ${enhancedProductInfo.variants!["sizes"]?.length}');
      }
    }

    // Store and notify
    _lastProductInfo = enhancedProductInfo;
    onProductInfoChanged(enhancedProductInfo);
    debugPrint('[PD] Enhanced product info sent to UI');
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

