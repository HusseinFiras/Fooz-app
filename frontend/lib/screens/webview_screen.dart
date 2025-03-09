// lib/screens/webview_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/product_info.dart';
import '../services/data_service.dart';
import '../services/webview_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_details.dart';
import '../widgets/site_selector.dart';

class WebViewScreen extends StatefulWidget {
  final int initialSiteIndex;

  const WebViewScreen({
    Key? key,
    required this.initialSiteIndex,
  }) : super(key: key);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  bool isLoading = true;
  DateTime? _lastBackPressTime;
  Timer? _loadingTimer;
  bool _manuallyDismissedLoading = false;

  // Product info model
  ProductInfo? productInfo;
  bool isProductPage = false;
  String _currentUrl = '';
  int _currentSiteIndex = 0;

  // Services
  final DataService _dataService = DataService();
  late WebViewService _webViewService;

  @override
  void initState() {
    super.initState();
    _currentSiteIndex = widget.initialSiteIndex;
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize webview service
    _webViewService = WebViewService(
      onLoadingStateChanged: _handleLoadingStateChanged,
      onProductInfoChanged: _handleProductInfoChanged,
      onUrlChanged: _handleUrlChanged,
    );

    setState(() {
      _currentUrl = _dataService.getUrlForIndex(_currentSiteIndex);
    });

    // Initialize webview with current URL
    _webViewService.initializeWebView(_currentUrl);

    // Save last site index for next time
    _dataService.saveLastSiteIndex(_currentSiteIndex);
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _handleLoadingStateChanged(bool isLoading) {
    if (!mounted) return;

    setState(() {
      this.isLoading = isLoading;
      if (isLoading) {
        isProductPage = false;
        productInfo = null;
        _manuallyDismissedLoading = false;

        // Set a timer to auto-dismiss the loading indicator
        _loadingTimer?.cancel();
        _loadingTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && !_manuallyDismissedLoading) {
            setState(() {
              this.isLoading = false;
            });
          }
        });
      }
    });
  }

  void _handleProductInfoChanged(ProductInfo newProductInfo) {
    if (!mounted) return;

    setState(() {
      // Only show product info if we're on an actual product page
      if (newProductInfo.isProductPage && newProductInfo.success) {
        productInfo = newProductInfo;
        isProductPage = true;
        
        // Automatically hide loading indicator when product info is detected
        isLoading = false;
      } else {
        // If we're not on a product page, don't show product card
        productInfo = null;
        isProductPage = false;
      }
    });
  }

  void _handleUrlChanged(String url) {
    if (!mounted) return;

    setState(() {
      _currentUrl = url;
      
      // Reset product state when URL changes
      // This helps ensure we don't show product info on non-product pages
      if (!isLoading) {
        productInfo = null;
        isProductPage = false;
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (await _webViewService.canGoBack()) {
      _webViewService.goBack();
      return false;
    } else {
      return true; // Allow pop to return to grid view
    }
  }

  void _navigateToSite(int index) {
    if (index >= 0 && index < _dataService.retailSites.length) {
      setState(() {
        _currentSiteIndex = index;
        _currentUrl = _dataService.getUrlForIndex(index);
        productInfo = null;
        isProductPage = false;
      });
      _webViewService.loadUrl(_currentUrl);
      _dataService.saveLastSiteIndex(index);
    }
  }

  void _showSiteSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SiteSelectorBottomSheet(
        currentSiteIndex: _currentSiteIndex,
        onSiteSelected: _navigateToSite,
        dataService: _dataService,
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
      builder: (context) => ProductDetailsBottomSheet(
        productInfo: productInfo!,
      ),
    );
  }

  // Helper function to determine if we should show the product card
  bool _shouldShowProductCard() {
    return productInfo != null && 
           productInfo!.success == true && 
           isProductPage == true && 
           productInfo!.price != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'site_${_dataService.getNameForIndex(_currentSiteIndex)}',
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _dataService.getNameForIndex(_currentSiteIndex)[0],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _dataService.getNameForIndex(_currentSiteIndex),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            splashRadius: 24,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            // Web navigation controls
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    splashRadius: 24,
                    onPressed: () async {
                      if (await _webViewService.canGoBack()) {
                        _webViewService.goBack();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('No previous page'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );
                      }
                    },
                    tooltip: 'Go back',
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    splashRadius: 24,
                    onPressed: () async {
                      if (await _webViewService.canGoForward()) {
                        _webViewService.goForward();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('No next page'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );
                      }
                    },
                    tooltip: 'Go forward',
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    splashRadius: 24,
                    onPressed: () {
                      _webViewService.reload();
                    },
                    tooltip: 'Reload',
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    splashRadius: 24,
                    onPressed: _showSiteSelector,
                    tooltip: 'Change website',
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            // WebView
            AnimatedOpacity(
              opacity: isLoading ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: WebViewWidget(controller: _webViewService.controller),
            ),

            // Loading indicator
            if (isLoading)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Loading...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Dismiss loading button
            if (isLoading)
              Positioned(
                bottom: 20,
                right: 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Analyzing page...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    isLoading = false;
                                    _manuallyDismissedLoading = true;
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Product info card with animation - only show on actual product pages
            if (_shouldShowProductCard())
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: ProductCard(
                    productInfo: productInfo!,
                    onTap: _showProductDetails,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}