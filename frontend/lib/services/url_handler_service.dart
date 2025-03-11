// lib/services/url_handler_service.dart
import 'package:flutter/material.dart';
import 'data_service.dart';

class UrlHandlerService {
  final DataService _dataService = DataService();

  /// Parses and validates a URL string, returning detailed information for navigation
  /// Returns a map containing:
  /// - isValid: whether the URL is valid and from a supported retailer
  /// - normalizedUrl: the URL with proper http/https prefix
  /// - retailerIndex: index of the matching retail site (-1 if no match)
  /// - retailerName: name of the matching retailer (empty if no match)
  /// - errorMessage: error message (if any)
  /// - isProductPage: best guess if this might be a product page based on URL pattern
  Map<String, dynamic> processUrl(String urlString) {
    // Default result with invalid state
    Map<String, dynamic> result = {
      'isValid': false,
      'normalizedUrl': urlString,
      'retailerIndex': -1,
      'retailerName': '',
      'errorMessage': '',
      'isProductPage': false,
    };

    // Check if URL is empty
    if (urlString.trim().isEmpty) {
      result['errorMessage'] = 'Please enter a product URL';
      return result;
    }

    // Ensure the URL has http/https prefix
    String normalizedUrl = urlString.trim();
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }
    result['normalizedUrl'] = normalizedUrl;

    // Try to parse the URL (handle invalid format efficiently)
    Uri? uri;
    try {
      uri = Uri.parse(normalizedUrl);
      
      // Quick check if the URL is valid at a basic level
      if (!uri.hasAuthority || uri.host.isEmpty) {
        result['errorMessage'] = 'Invalid URL format';
        return result;
      }
    } catch (e) {
      result['errorMessage'] = 'Invalid URL format';
      return result;
    }

    // Extract the domain
    final domain = uri.host;

    // Check if the URL appears to be a product page
    if (_looksLikeProductPage(normalizedUrl)) {
      result['isProductPage'] = true;
    }

    // Find the matching retailer for this domain
    final retailerInfo = _findMatchingRetailer(domain);
    
    if (retailerInfo['index'] == -1) {
      result['errorMessage'] = 'This site is not supported. Please use one of the listed retailers.';
      return result;
    }

    // URL is valid and from a supported retailer
    result['isValid'] = true;
    result['retailerIndex'] = retailerInfo['index'];
    result['retailerName'] = retailerInfo['name'];
    return result;
  }

  /// Finds the matching retailer for a given domain
  Map<String, dynamic> _findMatchingRetailer(String domain) {
    // Loop through all retail sites to find a matching domain
    for (int i = 0; i < _dataService.retailSites.length; i++) {
      final siteUrl = _dataService.retailSites[i]['url'] ?? '';
      final siteName = _dataService.retailSites[i]['name'] ?? '';
      
      try {
        final siteUri = Uri.parse(siteUrl);
        final siteDomain = siteUri.host;
        
        // Check for exact match or subdomain
        if (_domainsMatch(domain, siteDomain)) {
          return {
            'index': i,
            'name': siteName,
            'domain': siteDomain
          };
        }
      } catch (e) {
        debugPrint('Error parsing URL for site ${_dataService.retailSites[i]['name']}: $e');
        continue;
      }
    }
    
    return {'index': -1, 'name': '', 'domain': ''};
  }

  /// Comprehensive domain matching
  bool _domainsMatch(String domain1, String domain2) {
    // Normalize domains by removing www. prefix
    String normDomain1 = domain1.startsWith('www.') ? domain1.substring(4) : domain1;
    String normDomain2 = domain2.startsWith('www.') ? domain2.substring(4) : domain2;
    
    // Check for exact match after normalization
    if (normDomain1 == normDomain2) {
      return true;
    }
    
    // Check for subdomain relationship
    if (domain1.endsWith('.$normDomain2') || domain2.endsWith('.$normDomain1')) {
      return true;
    }
    
    // Check for regional variants (e.g., gucci.com vs gucci.com.tr)
    List<String> parts1 = normDomain1.split('.');
    List<String> parts2 = normDomain2.split('.');
    
    if (parts1.length >= 2 && parts2.length >= 2) {
      // Compare the main domain name (e.g., "gucci" in gucci.com)
      if (parts1[parts1.length - 2] == parts2[parts2.length - 2]) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if URL looks like a product page based on common patterns
  bool _looksLikeProductPage(String url) {
    final productPatterns = [
      r'/p/', r'/product/', r'/products/', r'/item/', r'/items/', 
      r'/pd/', r'/urun/', r'/detay/', r'/product-detail/', 
      r'/ProductDetails', r'/productdetail', r'/goods/',
      r'/shop\/products\/', r'/product-p/'
    ];
    
    for (final pattern in productPatterns) {
      if (RegExp(pattern).hasMatch(url)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Generate search URL for a specific retailer
  String generateSearchUrl(int retailerIndex, String query) {
    if (retailerIndex < 0 || retailerIndex >= _dataService.retailSites.length) {
      return '';
    }
    
    final retailer = _dataService.retailSites[retailerIndex];
    final baseUrl = retailer['url']!;
    final encodedQuery = Uri.encodeComponent(query);
    
    final String domain = Uri.parse(baseUrl).host;
    
    // Map specific domains to their search URL formats
    switch (domain) {
      case 'www.gucci.com':
        return '$baseUrl/search?query=$encodedQuery';
      case 'www.zara.com':
        return '$baseUrl/search?q=$encodedQuery';
      case 'www.stradivarius.com':
        return '$baseUrl/search?term=$encodedQuery';
      case 'www.cartier.com':
        return '$baseUrl/search?q=$encodedQuery';
      case 'www.swarovski.com':
        return '$baseUrl/search/?q=$encodedQuery';
      case 'www.guess.eu':
        return '$baseUrl/search?q=$encodedQuery';
      case 'shop.mango.com':
        return '$baseUrl/search?kw=$encodedQuery';
      case 'www.bershka.com':
        return '$baseUrl/search?q=$encodedQuery';
      case 'www.massimodutti.com':
        return '$baseUrl/search?term=$encodedQuery';
      case 'www.deepatelier.co':
        return '$baseUrl/search?q=$encodedQuery';
      case 'tr.pandora.net':
        return '$baseUrl/search?q=$encodedQuery';
      case 'www.miumiu.com':
        return '$baseUrl/search?q=$encodedQuery';
      case 'www.victoriassecret.com.tr':
        return '$baseUrl/search?q=$encodedQuery';
      case 'www.nocturne.com.tr':
        return '$baseUrl/arama?q=$encodedQuery';
      case 'www.beymen.com':
        return '$baseUrl/search?q=$encodedQuery';
      case 'www.bluediamond.com.tr':
        return '$baseUrl/arama?q=$encodedQuery';
      case 'www.lacoste.com.tr':
        return '$baseUrl/arama?search=$encodedQuery';
      case 'tr.mancofficial.com':
        return '$baseUrl/search?type=product&q=$encodedQuery';
      case 'www.ipekyol.com.tr':
        return '$baseUrl/arama?q=$encodedQuery';
      case 'www.sandro.com.tr':
        return '$baseUrl/search?q=$encodedQuery';
      default:
        // Fallback to a common search pattern
        return '$baseUrl/search?q=$encodedQuery';
    }
  }
}