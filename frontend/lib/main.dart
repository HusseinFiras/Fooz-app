// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turkish Retail Price Checker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class ProductInfo {
  final bool isProductPage;
  final String? title;
  final double? price;
  final double? originalPrice;
  final String? currency;
  final String? imageUrl;
  final String? description;
  final String? sku;
  final String? availability;
  final String? brand;
  final String? extractionMethod;
  final String url;
  final bool success;
  final Map<String, List<VariantOption>>? variants;

  ProductInfo({
    required this.isProductPage,
    this.title,
    this.price,
    this.originalPrice,
    this.currency,
    this.imageUrl,
    this.description,
    this.sku,
    this.availability,
    this.brand,
    this.extractionMethod,
    required this.url,
    required this.success,
    this.variants,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    // Process variants
    Map<String, List<VariantOption>>? variantMap;
    if (json['variants'] != null) {
      variantMap = {};

      // Process colors
      if (json['variants']['colors'] != null) {
        variantMap['colors'] = List<VariantOption>.from(
            (json['variants']['colors'] as List)
                .map((variant) => VariantOption.fromJson(variant)));
      }

      // Process sizes
      if (json['variants']['sizes'] != null) {
        variantMap['sizes'] = List<VariantOption>.from(
            (json['variants']['sizes'] as List)
                .map((variant) => VariantOption.fromJson(variant)));
      }

      // Process other options
      if (json['variants']['otherOptions'] != null) {
        variantMap['otherOptions'] = List<VariantOption>.from(
            (json['variants']['otherOptions'] as List)
                .map((variant) => VariantOption.fromJson(variant)));
      }
    }

    return ProductInfo(
      isProductPage: json['isProductPage'] ?? false,
      title: json['title'],
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      originalPrice: json['originalPrice'] != null
          ? double.tryParse(json['originalPrice'].toString())
          : null,
      currency: json['currency'],
      imageUrl: json['imageUrl'],
      description: json['description'],
      sku: json['sku'],
      availability: json['availability'],
      brand: json['brand'],
      extractionMethod: json['extractionMethod'],
      url: json['url'] ?? '',
      success: json['success'] ?? false,
      variants: variantMap,
    );
  }

  String formatPrice(double? price, String? currency) {
    if (price == null) return '';

    final formatter = NumberFormat('#,##0.00', 'tr_TR');
    String symbol = '₺';

    switch (currency) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
      case 'TRY':
      default:
        symbol = '₺';
        break;
    }

    return '${formatter.format(price)} $symbol';
  }

  String get formattedPrice {
    return formatPrice(price, currency);
  }

  String get formattedOriginalPrice {
    return formatPrice(originalPrice, currency);
  }
}

class VariantOption {
  final String text;
  final bool selected;
  final String? value;

  VariantOption({
    required this.text,
    required this.selected,
    this.value,
  });

  factory VariantOption.fromJson(Map<String, dynamic> json) {
    return VariantOption(
      text: json['text'] ?? '',
      selected: json['selected'] ?? false,
      value: json['value'],
    );
  }
}

class _HomePageState extends State<HomePage> {
  final WebViewController _controller = WebViewController();
  bool isLoading = true;
  DateTime? _lastBackPressTime;
  Timer? _loadingTimer;
  bool _manuallyDismissedLoading = false;

  // Product info model
  ProductInfo? productInfo;
  bool isProductPage = false;
  String _currentUrl = '';
  int _currentSiteIndex = 0;

  // List of all retail websites
  final List<Map<String, String>> _retailSites = [
    {'name': 'Gucci', 'url': 'https://www.gucci.com/tr/en_gb/'},
    {'name': 'Zara', 'url': 'https://www.zara.com/tr/en/'},
    {'name': 'Stradivarius', 'url': 'https://www.stradivarius.com/tr/'},
    {'name': 'Cartier', 'url': 'https://www.cartier.com/en-tr/home'},
    {'name': 'Swarovski', 'url': 'https://www.swarovski.com/en-TR/'},
    {'name': 'Guess', 'url': 'https://www.guess.eu/tr-tr/'},
    {'name': 'Mango', 'url': 'https://shop.mango.com/tr/tr/h/kadin'},
    {'name': 'Bershka', 'url': 'https://www.bershka.com/tr/en/'},
    {'name': 'Massimo Dutti', 'url': 'https://www.massimodutti.com/tr/'},
    {'name': 'Deep Atelier', 'url': 'https://www.deepatelier.co/'},
    {'name': 'Pandora', 'url': 'https://tr.pandora.net/'},
    {'name': 'Miu Miu', 'url': 'https://www.miumiu.com/tr/tr.html'},
    {
      'name': 'Victoria\'s Secret',
      'url': 'https://www.victoriassecret.com.tr/'
    },
    {'name': 'Nocturne', 'url': 'https://www.nocturne.com.tr/'},
    {'name': 'Beymen', 'url': 'https://www.beymen.com/tr/kadin-10006'},
    {'name': 'Blue Diamond', 'url': 'https://www.bluediamond.com.tr/'},
    {'name': 'Lacoste', 'url': 'https://www.lacoste.com.tr/'},
    {'name': 'Manc', 'url': 'https://tr.mancofficial.com/'},
    {'name': 'Ipekyol', 'url': 'https://www.ipekyol.com.tr/'},
    {'name': 'Sandro', 'url': 'https://www.sandro.com.tr/'},
  ];

  @override
  void initState() {
    super.initState();
    _currentUrl = _retailSites[_currentSiteIndex]['url']!;
    _initializeWebView();
    _loadLastSiteIndex();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLastSiteIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSiteIndex = prefs.getInt('lastSiteIndex') ?? 0;
    });
  }

  Future<void> _saveLastSiteIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSiteIndex', index);
  }

  void _initializeWebView() {
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            final newProductInfo = ProductInfo.fromJson(data);

            setState(() {
              productInfo = newProductInfo;
              isProductPage = newProductInfo.isProductPage;

              // Handle navigated event from our script
              if (data.containsKey('navigated') && data['navigated'] == true) {
                // Clear product info on navigation
                _currentUrl = data['url'] ?? _currentUrl;
              }
            });

            // Show notification if product detected
            if (newProductInfo.success &&
                (productInfo == null || productInfo!.success == false)) {
              _showProductDetectedNotification();
            }
          } catch (e) {
            debugPrint('Error parsing product data: $e');

            // Fallback to old method for backward compatibility
            try {
              final data = message.message.split('|');
              if (data.length >= 2) {
                final price = double.tryParse(data[0]);
                if (price != null) {
                  setState(() {
                    productInfo = ProductInfo(
                      isProductPage: true,
                      title: data[1],
                      price: price,
                      url: _currentUrl,
                      success: true,
                    );
                    isProductPage = true;
                  });
                }
              }
            } catch (e) {
              debugPrint('Error with fallback parsing: $e');
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              isProductPage = false;
              productInfo = null;
              _currentUrl = url;
              _manuallyDismissedLoading = false;
            });

            // Set a timer to auto-dismiss the loading indicator after 10 seconds
            _loadingTimer?.cancel();
            _loadingTimer = Timer(const Duration(seconds: 10), () {
              if (mounted && !_manuallyDismissedLoading) {
                setState(() {
                  isLoading = false;
                });
              }
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            _injectProductDetector();
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    } else {
      final now = DateTime.now();
      if (_lastBackPressTime == null ||
          now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
        _lastBackPressTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }
      return true;
    }
  }

  void _injectProductDetector() async {
    try {
      final script = await rootBundle.loadString('assets/product_detector.js');
      _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('Error loading product detector script: $e');
      // Fallback to the old extraction method
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

          // Product title selectors for different sites (optimized for Turkish e-commerce)
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
                if (/[0-9]+[,.][0-9]+.*?(TL|\u20BA|\$|€|£)/i.test(text)) {
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
        
        // Method 2: Look for schema.org markup (many e-commerce sites use this)
        function trySchemaOrgMarkup() {
          // Try to find product structured data
          const jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
          for (const script of jsonLdScripts) {
            try {
              const data = JSON.parse(script.textContent);
              
              // Handle nested structures or arrays
              const findProduct = (obj) => {
                if (!obj) return null;
                
                if (obj['@type'] === 'Product') {
                  return obj;
                }
                
                if (Array.isArray(obj)) {
                  for (const item of obj) {
                    const result = findProduct(item);
                    if (result) return result;
                  }
                } else if (typeof obj === 'object') {
                  for (const key in obj) {
                    const result = findProduct(obj[key]);
                    if (result) return result;
                  }
                }
                
                return null;
              };
              
              const product = findProduct(data);
              
              if (product) {
                let price = null;
                let title = product.name;
                
                // Try to extract price
                if (product.offers) {
                  if (Array.isArray(product.offers)) {
                    if (product.offers.length > 0) {
                      price = product.offers[0].price || product.offers[0].lowPrice;
                    }
                  } else {
                    price = product.offers.price || product.offers.lowPrice;
                  }
                }
                
                if (price && title) {
                  return { price: price.toString(), title: title };
                }
              }
            } catch (e) {
              // JSON parsing error, continue to next script
            }
          }
          
          return null;
        }
        
        // Method 3: Look for meta tags
        function tryMetaTags() {
          const priceMetaTag = document.querySelector('meta[property="product:price:amount"], meta[property="og:price:amount"], meta[name="twitter:data1"]');
          const titleMetaTag = document.querySelector('meta[property="og:title"], meta[name="twitter:title"]');
          
          if (priceMetaTag && titleMetaTag) {
            return {
              price: priceMetaTag.getAttribute('content'),
              title: titleMetaTag.getAttribute('content')
            };
          }
          
          return null;
        }
        
        // Method 4: Look for any text that matches price patterns in the page
        function scanForPricePatterns() {
          const priceRegex = /([0-9]+[.,][0-9]+)\s*(?:TL|₺|\$|€|£)/i;
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
              // This is a simple heuristic - we get the element closest to the center of the page
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
        const result = tryCommonSelectors() || trySchemaOrgMarkup() || tryMetaTags() || scanForPricePatterns();
        
        if (result) {
          // Clean and format the price
          let priceStr = result.price;
          
          // First check if it's already a clean number
          if (!isNaN(parseFloat(priceStr))) {
            FlutterChannel.postMessage(priceStr + '|' + result.title);
            return;
          }
          
          // Extract numeric price from text (optimized for Turkish currency format)
          // Turkish prices typically use comma as decimal separator and period as thousands separator
          // Example: 1.299,99 TL -> should become 1299.99
          let price = priceStr.replace(/[^0-9.,]/g, '');
          
          // Handle Turkish currency format (1.234,56 TL) -> 1234.56
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
            FlutterChannel.postMessage(price + '|' + result.title);
          }
        }
      }
      
      // Try immediate extraction for static content
      setTimeout(extractProductInfo, 1000);
      
      // Observe DOM changes to detect dynamic content loading
      const observer = new MutationObserver(() => {
        setTimeout(extractProductInfo, 500);
      });
      
      observer.observe(document.body, { subtree: true, childList: true });
      
      // Also try extraction after all resources are loaded
      window.addEventListener('load', () => setTimeout(extractProductInfo, 2000));
      
      // And try again after a few seconds in case of lazy-loaded content
      setTimeout(extractProductInfo, 3000);
      setTimeout(extractProductInfo, 5000);
    ''';
    _controller.runJavaScript(js);
  }

  void _showProductDetectedNotification() {
    if (!mounted || productInfo == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product detected: ${productInfo?.title ?? 'Unknown'}'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View',
          onPressed: _showProductDetails,
        ),
      ),
    );
  }

  void _navigateToSite(int index) {
    if (index >= 0 && index < _retailSites.length) {
      setState(() {
        _currentSiteIndex = index;
        _currentUrl = _retailSites[index]['url']!;
        productInfo = null;
        isProductPage = false;
      });
      _controller.loadRequest(Uri.parse(_currentUrl));
      _saveLastSiteIndex(index);
    }
  }

  void _showSiteSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Retail Site',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _retailSites.length,
                itemBuilder: (context, index) {
                  final site = _retailSites[index];
                  return ListTile(
                    title: Text(site['name']!),
                    subtitle:
                        Text(site['url']!, overflow: TextOverflow.ellipsis),
                    selected: index == _currentSiteIndex,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSite(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetails() {
    if (productInfo == null || !productInfo!.success) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and close button
            Row(
              children: [
                Expanded(
                  child: Text(
                    productInfo!.title ?? 'Product Details',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Product details
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image with improved handling
                    if (productInfo!.imageUrl != null)
                      Container(
                        height: 240,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            productInfo!.imageUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Image error: $error');
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.broken_image, size: 50),
                                    const SizedBox(height: 8),
                                    Text('Image could not be loaded',
                                        style:
                                            TextStyle(color: Colors.grey[600])),
                                    Text(productInfo!.imageUrl ?? '',
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 10),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Price information
                    _buildInfoRow('Price:', productInfo!.formattedPrice,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    if (productInfo!.originalPrice != null)
                      _buildInfoRow('Original Price:',
                          productInfo!.formattedOriginalPrice,
                          style: const TextStyle(
                              decoration: TextDecoration.lineThrough)),
                    const SizedBox(height: 16),

                    // Color variants
                    if (productInfo!.variants != null &&
                        productInfo!.variants!.containsKey('colors') &&
                        productInfo!.variants!['colors']!.isNotEmpty)
                      _buildVariantSection(
                          'Colors', productInfo!.variants!['colors']!),

                    // Size variants
                    if (productInfo!.variants != null &&
                        productInfo!.variants!.containsKey('sizes') &&
                        productInfo!.variants!['sizes']!.isNotEmpty)
                      _buildVariantSection(
                          'Sizes', productInfo!.variants!['sizes']!),

                    // Other option variants
                    if (productInfo!.variants != null &&
                        productInfo!.variants!.containsKey('otherOptions') &&
                        productInfo!.variants!['otherOptions']!.isNotEmpty)
                      _buildVariantSection(
                          'Options', productInfo!.variants!['otherOptions']!),

                    if (productInfo!.variants == null ||
                        (productInfo!.variants!['colors']?.isEmpty ?? true) &&
                            (productInfo!.variants!['sizes']?.isEmpty ??
                                true) &&
                            (productInfo!.variants!['otherOptions']?.isEmpty ??
                                true))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No variants available for this product',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic),
                        ),
                      ),

                    const Divider(height: 24),

                    // Additional product details
                    if (productInfo!.brand != null)
                      _buildInfoRow('Brand:', productInfo!.brand!),
                    if (productInfo!.sku != null)
                      _buildInfoRow('SKU:', productInfo!.sku!),
                    if (productInfo!.availability != null)
                      _buildInfoRow(
                          'Availability:', productInfo!.availability!),

                    // Description
                    if (productInfo!.description != null) ...[
                      const SizedBox(height: 16),
                      const Text('Description:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(productInfo!.description!),
                    ],

                    // Technical info (for debugging)
                    const SizedBox(height: 16),
                    ExpansionTile(
                      title: const Text('Technical Information'),
                      initiallyExpanded: false,
                      children: [
                        _buildInfoRow('Extraction Method:',
                            productInfo!.extractionMethod ?? 'Unknown'),
                        _buildInfoRow('URL:', productInfo!.url,
                            textOverflow: TextOverflow.ellipsis),
                        // Add debugging info for image URL
                        _buildInfoRow(
                            'Image URL:', productInfo!.imageUrl ?? 'None',
                            textOverflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('Save'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Product saved to favorites')),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Add to Cart'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to cart')),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantSection(String title, List<VariantOption> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            // For colors, try to use the color value if it exists
            if (title == 'Colors' &&
                option.value != null &&
                option.value!.startsWith('rgb')) {
              // Try to parse the color
              Color? color;
              try {
                final rgbValues =
                    RegExp(r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)')
                        .firstMatch(option.value!);
                if (rgbValues != null) {
                  color = Color.fromRGBO(
                    int.parse(rgbValues.group(1)!),
                    int.parse(rgbValues.group(2)!),
                    int.parse(rgbValues.group(3)!),
                    1.0,
                  );
                }
              } catch (e) {
                debugPrint('Error parsing color: $e');
              }

              return InkWell(
                onTap: () {
                  // Handle color selection
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected color: ${option.text}')),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color ?? Colors.grey,
                    border: Border.all(
                      color: option.selected ? Colors.black : Colors.grey,
                      width: option.selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: option.selected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            } else if (title == 'Colors' &&
                option.value != null &&
                option.value!.startsWith('http')) {
              // If the color value is an image URL
              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected color: ${option.text}')),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: option.selected ? Colors.black : Colors.grey,
                      width: option.selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network(
                      option.value!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.grey[300]),
                    ),
                  ),
                ),
              );
            } else {
              // For other variants or when no color value exists
              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Selected ${title.toLowerCase().substring(0, title.length - 1)}: ${option.text}')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: option.selected ? Colors.black : Colors.grey[300]!,
                      width: option.selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: option.selected
                        ? Colors.black.withOpacity(0.05)
                        : Colors.white,
                  ),
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontWeight:
                          option.selected ? FontWeight.bold : FontWeight.normal,
                      color: option.selected ? Colors.black : Colors.black87,
                    ),
                  ),
                ),
              );
            }
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value,
      {TextStyle? style, TextOverflow textOverflow = TextOverflow.visible}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: style,
              overflow: textOverflow,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(_retailSites[_currentSiteIndex]['name'] ?? 'Price Checker'),
          actions: [
            // Navigation buttons
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _controller.canGoBack()) {
                  _controller.goBack();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No previous page')),
                  );
                }
              },
              tooltip: 'Go back',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () async {
                if (await _controller.canGoForward()) {
                  _controller.goForward();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No next page')),
                  );
                }
              },
              tooltip: 'Go forward',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _controller.reload();
              },
              tooltip: 'Reload',
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: _showSiteSelector,
              tooltip: 'Change website',
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isLoading)
              Stack(
                children: [
                  // Semi-transparent overlay
                  Container(
                    color: Colors.white.withOpacity(0.7),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  // Dismiss button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            isLoading = false;
                            _manuallyDismissedLoading = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (productInfo?.success == true)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: _showProductDetails,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Product thumbnail
                          if (productInfo!.imageUrl != null)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  productInfo!.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                        Icons.image_not_supported);
                                  },
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_bag, size: 30),
                            ),
                          const SizedBox(width: 12),

                          // Product info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  productInfo!.title ?? 'Product Detected',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      productInfo!.formattedPrice,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (productInfo!.originalPrice != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        productInfo!.formattedOriginalPrice,
                                        style: const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (productInfo!.variants != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (productInfo!.variants!['colors']
                                              ?.isNotEmpty ??
                                          false)
                                        _buildVariantIndicator(
                                          'Colors',
                                          productInfo!
                                              .variants!['colors']!.length,
                                          Colors.red[400]!,
                                        ),
                                      if (productInfo!
                                              .variants!['sizes']?.isNotEmpty ??
                                          false)
                                        _buildVariantIndicator(
                                          'Sizes',
                                          productInfo!
                                              .variants!['sizes']!.length,
                                          Colors.blue[400]!,
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // View details button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: const Text(
                              'View',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Removed the floating action button as navigation is now in the app bar
      ),
    );
  }

  Widget _buildVariantIndicator(String type, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'Colors' ? Icons.palette : Icons.straighten,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
