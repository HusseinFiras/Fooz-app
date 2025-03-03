// lib/main.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turkish Retail Price Calculator',
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

class _HomePageState extends State<HomePage> {
  final WebViewController _controller = WebViewController();
  double markupPercentage = 30.0;
  bool isLoading = true;
  double? currentPrice;
  String? productTitle;
  int _currentSiteIndex = 0;
  String _currentUrl = '';

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
    {'name': 'Victoria\'s Secret', 'url': 'https://www.victoriassecret.com.tr/'},
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
    _loadSavedMarkup();
  }

  Future<void> _loadSavedMarkup() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      markupPercentage = prefs.getDouble('markup') ?? 30.0;
      _currentSiteIndex = prefs.getInt('lastSiteIndex') ?? 0;
    });
  }

  Future<void> _saveMarkup(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('markup', value);
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
          final data = message.message.split('|');
          if (data.length >= 2) {
            setState(() {
              currentPrice = double.tryParse(data[0]);
              productTitle = data[1];
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              currentPrice = null;
              productTitle = null;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            _injectPriceExtractor();
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  void _injectPriceExtractor() {
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

  void _navigateToSite(int index) {
    if (index >= 0 && index < _retailSites.length) {
      setState(() {
        _currentSiteIndex = index;
        _currentUrl = _retailSites[index]['url']!;
        currentPrice = null;
        productTitle = null;
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
                    subtitle: Text(site['url']!, overflow: TextOverflow.ellipsis),
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

  void _showCalculationDetails() {
    if (currentPrice == null) return;
    
    final double finalPrice = currentPrice! * (1 + markupPercentage / 100);
    final double markup = finalPrice - currentPrice!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(productTitle ?? 'Product Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original Price: ${currentPrice!.toStringAsFixed(2)} TL'),
            Text('Markup (${markupPercentage.round()}%): ${markup.toStringAsFixed(2)} TL'),
            const Divider(),
            Text('Final Price: ${finalPrice.toStringAsFixed(2)} TL',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Here you would typically integrate with a payment processor
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proceeding to checkout...')),
              );
              Navigator.pop(context);
            },
            child: const Text('Proceed to Checkout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_retailSites[_currentSiteIndex]['name'] ?? 'Price Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _showSiteSelector,
            tooltip: 'Change website',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showMarkupSettings(),
            tooltip: 'Set markup',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (currentPrice != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.black,
                ),
                onPressed: _showCalculationDetails,
                child: Text(
                  'Calculate Final Price: ${currentPrice!.toStringAsFixed(2)} TL',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Use this to go back in WebView navigation
          _controller.goBack();
        },
        child: const Icon(Icons.arrow_back),
        tooltip: 'Go back',
      ),
    );
  }

  void _showMarkupSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Markup Percentage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: markupPercentage,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${markupPercentage.round()}%',
              onChanged: (value) {
                setState(() {
                  markupPercentage = value;
                });
              },
            ),
            Text('Current Markup: ${markupPercentage.round()}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveMarkup(markupPercentage);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}