// lib/widgets/brandscreenwidgets/url_search_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/url_handler_service.dart';
import '../../constants/theme_constants.dart';
import '../../screens/webview_screen.dart';
import 'dart:async';

class UrlSearchWidget extends StatefulWidget {
  const UrlSearchWidget({Key? key}) : super(key: key);

  @override
  _UrlSearchWidgetState createState() => _UrlSearchWidgetState();
}

class _UrlSearchWidgetState extends State<UrlSearchWidget> with SingleTickerProviderStateMixin {
  final UrlHandlerService _urlHandlerService = UrlHandlerService();
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  
  // Animation controller for validation feedback
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;
  
  // Debouncer for URL validation
  Timer? _debounceTimer;
  
  bool _isAddingProduct = false;
  
  // URL validation states
  bool _isValidatingUrl = false;
  bool _isUrlValid = false;
  String _urlValidationMessage = '';
  String _detectedBrandName = '';
  String _detectedProductType = '';
  
  @override
  void initState() {
    super.initState();
    
    // Add listener for real-time URL validation
    _urlController.addListener(_onTextChanged);
    
    // Initialize animation controller for validation feedback
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Create shake animation for invalid URLs
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_animationController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        }
      });
  }
  
  @override
  void dispose() {
    _urlController.removeListener(_onTextChanged);
    _urlController.dispose();
    _urlFocusNode.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Handle text changes with debouncing
  void _onTextChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    
    final text = _urlController.text.trim();
    
    // Reset validation state if field is cleared
    if (text.isEmpty) {
      setState(() {
        _isValidatingUrl = false;
        _isUrlValid = false;
        _urlValidationMessage = '';
        _detectedBrandName = '';
        _detectedProductType = '';
      });
      return;
    }
    
    // Set validating state immediately for UI feedback
    setState(() {
      _isValidatingUrl = true;
    });
    
    // Debounce actual validation to avoid excessive processing
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _validateUrlInput();
    });
  }

  // Validate the URL input
  void _validateUrlInput() {
    if (!mounted) return;
    
    final url = _urlController.text.trim();
    
    // Process the URL using the URL handler service
    final result = _urlHandlerService.processUrl(url);
    
    setState(() {
      _isValidatingUrl = false;
      _isUrlValid = result['isValid'];
      
      if (result['isValid']) {
        _urlValidationMessage = 'Valid product URL';
        _detectedBrandName = result['retailerName'];
        
        // Determine if it's likely a product page based on URL pattern
        if (result['isProductPage'] == true) {
          _detectedProductType = 'Product Page';
        } else {
          _detectedProductType = 'Store Page';
        }
      } else {
        if (url.contains('/product/') || url.contains('/p/') || url.contains('/item/')) {
          _urlValidationMessage = 'Product URL from unsupported retailer';
        } else if (url.startsWith('http') || url.contains('.com') || url.contains('.net') || url.contains('.org')) {
          _urlValidationMessage = 'Link not recognized as a product';
        } else {
          _urlValidationMessage = 'Invalid URL format';
        }
        _detectedBrandName = '';
        _detectedProductType = '';
        
        // Shake animation for invalid URL
        _animationController.forward(from: 0.0);
      }
    });
  }

  // Process the URL for navigation
  void _processUrl() {
    // If URL is already validated and valid, proceed directly
    if (_isUrlValid) {
      setState(() {
        _isAddingProduct = true;
      });
      
      final url = _urlController.text.trim();
      final result = _urlHandlerService.processUrl(url);
      
      // Clear the text field
      _urlController.clear();
      
      // Navigate to the product page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewScreen(
            initialSiteIndex: result['retailerIndex'],
            initialUrl: result['normalizedUrl'],
          ),
        ),
      ).then((_) {
        setState(() {
          _isAddingProduct = false;
        });
      });
    } else {
      // URL is not valid, show shake animation
      _animationController.forward(from: 0.0);
      
      // Provide haptic feedback to indicate error
      HapticFeedback.vibrate();
      
      // Focus the field
      _urlFocusNode.requestFocus();
    }
  }

  // Handle paste from clipboard
  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      _urlController.text = data.text!.trim();
      // Move cursor to the end
      _urlController.selection = TextSelection.fromPosition(
        TextPosition(offset: _urlController.text.length),
      );
      // Validate immediately
      _validateUrlInput();
    }
  }

  // Clear the text field
  void _clearTextField() {
    setState(() {
      _urlController.clear();
      _isUrlValid = false;
      _urlValidationMessage = '';
      _detectedBrandName = '';
      _detectedProductType = '';
    });
    _urlFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Search Product by link',
                style: TextStyle(
                  fontFamily: 'DM Serif Display',
                  color: LuxuryTheme.textCharcoal,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: LuxuryTheme.primaryRosegold.withOpacity(0.3),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // URL input with enhanced visual feedback
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value * (_animationController.value <= 0.5 ? 1 : -1), 0),
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(LuxuryTheme.buttonRadius),
                border: Border.all(
                  color: _urlController.text.isEmpty
                      ? Colors.grey.withOpacity(0.3)
                      : _isValidatingUrl
                          ? Colors.amber.withOpacity(0.5)
                          : _isUrlValid
                              ? Colors.green.withOpacity(0.5)
                              : Colors.red.withOpacity(0.5),
                  width: _urlController.text.isEmpty ? 1.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Paste button
                      IconButton(
                        icon: Icon(
                          Icons.content_paste_rounded,
                          color: LuxuryTheme.primaryRosegold.withOpacity(0.7),
                          size: 20,
                        ),
                        onPressed: _pasteFromClipboard,
                        splashRadius: 20,
                        tooltip: 'Paste from clipboard',
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      
                      // Text field
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          focusNode: _urlFocusNode,
                          style: TextStyle(
                            color: LuxuryTheme.textCharcoal,
                            fontFamily: 'Lato',
                          ),
                          decoration: InputDecoration(
                            hintText: _urlController.text.isEmpty
                                ? 'Paste product URL here'
                                : _isValidatingUrl
                                    ? 'Validating URL...'
                                    : _isUrlValid
                                        ? 'Valid URL detected'
                                        : 'Not a valid product URL',
                            hintStyle: TextStyle(
                              color: _urlController.text.isEmpty
                                  ? Colors.grey
                                  : _isValidatingUrl
                                      ? Colors.amber
                                      : _isUrlValid
                                          ? Colors.green
                                          : Colors.red.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(right: 16),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _isUrlValid ? _processUrl() : null,
                        ),
                      ),
                      
                      // Status icon/action button
                      _urlController.text.isEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.link,
                                color: LuxuryTheme.primaryRosegold,
                                size: 20,
                              ),
                              onPressed: null,
                              splashRadius: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            )
                          : _isValidatingUrl
                              ? Container(
                                  width: 40,
                                  height: 40,
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.amber,
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    _isUrlValid ? Icons.check_circle : Icons.close,
                                    color: _isUrlValid ? Colors.green : Colors.red.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  onPressed: _clearTextField,
                                  tooltip: 'Clear',
                                  splashRadius: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                    ],
                  ),
                  
                  // Show detected brand and product type when URL is valid
                  if (_isUrlValid && _detectedBrandName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline, 
                            size: 12, 
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _detectedBrandName,
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _detectedProductType,
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Show validation message when URL is invalid
                  if (_urlController.text.isNotEmpty && !_isUrlValid && !_isValidatingUrl)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline, 
                            size: 12, 
                            color: Colors.red.withOpacity(0.7),
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _urlValidationMessage,
                              style: TextStyle(
                                color: Colors.red.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Action button - Add Product
          InkWell(
            onTap: _isAddingProduct || !_isUrlValid ? null : _processUrl,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _isUrlValid 
                    ? LuxuryTheme.rosegoldGradient 
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.withOpacity(0.5),
                          Colors.grey.withOpacity(0.4),
                        ],
                      ),
                borderRadius: BorderRadius.circular(LuxuryTheme.buttonRadius),
                boxShadow: _isUrlValid ? LuxuryTheme.softShadow : [],
              ),
              child: Center(
                child: _isAddingProduct 
                    ? SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isUrlValid ? Icons.shopping_bag : Icons.link_off,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            _isUrlValid ? 'View Product' : 'Enter Valid URL',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ],
                      ),
              ),
                      ),
                          ),
                        ],
                      ),
                    );
            }
          }