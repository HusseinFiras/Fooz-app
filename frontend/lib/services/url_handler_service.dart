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
    debugPrint('Matching domain: $domain');
    
    // Extract core domain name without regional prefixes
    final coreDomain = _extractCoreDomain(domain);
    debugPrint('Core domain extracted: $coreDomain');
    
    // First pass - try to match with the core domain
    for (int i = 0; i < _dataService.retailSites.length; i++) {
      final siteUrl = _dataService.retailSites[i]['url'] ?? '';
      final siteName = _dataService.retailSites[i]['name'] ?? '';
      
      try {
        final siteUri = Uri.parse(siteUrl);
        final siteDomain = siteUri.host;
        final siteCoreDomain = _extractCoreDomain(siteDomain);
        
        debugPrint('Comparing with: $siteName - $siteDomain (core: $siteCoreDomain)');
        
        // If exact match with the site domain
        if (domain == siteDomain) {
          debugPrint('Exact match found!');
          return {
            'index': i,
            'name': siteName,
            'domain': siteDomain
          };
        }
        
        // If core domains match
        if (coreDomain == siteCoreDomain) {
          debugPrint('Core domain match found!');
          return {
            'index': i, 
            'name': siteName,
            'domain': siteDomain
          };
        }
      } catch (e) {
        debugPrint('Error parsing URL for site $siteName: $e');
        continue;
      }
    }
    
    // Second pass - try partial domain matching for hyphenated domains
    if (coreDomain.contains('-')) {
      final domainParts = coreDomain.split('-');
      
      for (int i = 0; i < _dataService.retailSites.length; i++) {
        final siteUrl = _dataService.retailSites[i]['url'] ?? '';
        final siteName = _dataService.retailSites[i]['name'] ?? '';
        
        try {
          final siteUri = Uri.parse(siteUrl);
          final siteDomain = siteUri.host;
          final siteCoreDomain = _extractCoreDomain(siteDomain);
          
          // Check if any part of the domain matches the retailer name
          bool nameMatch = siteName.toLowerCase().contains(domainParts[0].toLowerCase()) || 
                          (domainParts.length > 1 && siteName.toLowerCase().contains(domainParts[1].toLowerCase()));
          
          // Also check if any part of the site's core domain matches
          bool domainMatch = false;
          if (siteCoreDomain.contains('-')) {
            final siteDomainParts = siteCoreDomain.split('-');
            domainMatch = domainParts.any((part) => 
                siteDomainParts.any((sitePart) => 
                    sitePart.toLowerCase() == part.toLowerCase()));
          }
          
          if (nameMatch || domainMatch) {
            debugPrint('Partial match found for hyphenated domain with $siteName');
            return {
              'index': i,
              'name': siteName,
              'domain': siteDomain
            };
          }
        } catch (e) {
          debugPrint('Error during partial match for $siteName: $e');
          continue;
        }
      }
    }
    
    // Third pass - look for brand names in the domain
    for (int i = 0; i < _dataService.retailSites.length; i++) {
      final siteName = _dataService.retailSites[i]['name'] ?? '';
      
      // Clean up brand name for comparison (remove spaces, lowercase)
      final cleanBrandName = siteName.toLowerCase().replaceAll(' ', '').replaceAll("'", "");
      final cleanDomain = domain.toLowerCase();
      
      // Check if the domain contains the brand name
      if (cleanDomain.contains(cleanBrandName) && cleanBrandName.length > 3) {
        debugPrint('Brand name $cleanBrandName found in domain $cleanDomain');
        return {
          'index': i,
          'name': siteName,
          'domain': Uri.parse(_dataService.retailSites[i]['url'] ?? '').host
        };
      }
    }
    
    return {'index': -1, 'name': '', 'domain': ''};
  }
  
  /// Extracts the core domain name from a full domain
  /// Examples:
  /// - www.gucci.com -> gucci.com
  /// - eu.sandro-paris.com -> sandro-paris.com
  /// - shop.armani.com -> armani.com
  /// - us.louisvuitton.com -> louisvuitton.com
  String _extractCoreDomain(String domain) {
    // Remove www. prefix if present
    String result = domain.startsWith('www.') ? domain.substring(4) : domain;
    
    // Handle regional/functional prefixes
    List<String> parts = result.split('.');
    
    // If domain has enough parts and starts with a known prefix
    if (parts.length >= 3) {
      String prefix = parts[0].toLowerCase();
      
      // List of common regional or functional prefixes
      List<String> knownPrefixes = [
        'eu', 'us', 'uk', 'fr', 'it', 'de', 'es', 'au', 'ca', 'jp', 'cn', 'ru', 
        'tr', 'kr', 'br', 'mx', 'in', 'hk', 'sg', 'nl', 'be', 'ch', 'pl', 'se',
        'at', 'pt', 'no', 'fi', 'dk', 'gr', 'nz', 'za', 'ae', 'sa', 'qa', 'my',
        'th', 'id', 'ph', 'vn', 'cz', 'hu', 'ro', 'bg', 'hr', 'rs', 'si', 'sk',
        'ee', 'lv', 'lt', 'ua', 'by', 'md', 'am', 'az', 'ge', 'kz', 'uz', 'tm',
        'shop', 'store', 'online', 'mobile', 'app', 'api', 'm', 'web'
      ];
      
      if (knownPrefixes.contains(prefix)) {
        // Remove the prefix
        result = parts.sublist(1).join('.');
      }
    }
    
    return result;
  }
  
  /// Check if URL looks like a product page based on common patterns
  bool _looksLikeProductPage(String url) {
    final productPatterns = [
      r'/p/', r'/product/', r'/products/', r'/item/', r'/items/', 
      r'/pd/', r'/urun/', r'/detay/', r'/product-detail/', 
      r'/ProductDetails', r'/productdetail', r'/goods/',
      r'/shop\/products\/', r'/product-p/', r'/-p-', r'/dp/',
      r'/fp/', r'/skus/'
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
    
    // Use the normalized site URL as the base
    final Uri siteUri = Uri.parse(baseUrl);
    final String siteDomain = siteUri.host;
    
    // Extract core domain to identify retailer
    final coreDomain = _extractCoreDomain(siteDomain);
    
    // Common search patterns by retailer domain pattern
    if (coreDomain.contains('gucci')) {
      return '$baseUrl/search?query=$encodedQuery';
    } else if (coreDomain.contains('zara')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('stradivarius')) {
      return '$baseUrl/search?term=$encodedQuery';
    } else if (coreDomain.contains('cartier')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('swarovski')) {
      return '$baseUrl/search/?q=$encodedQuery';
    } else if (coreDomain.contains('guess')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('mango')) {
      return '$baseUrl/search?kw=$encodedQuery';
    } else if (coreDomain.contains('bershka')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('massimodutti')) {
      return '$baseUrl/search?term=$encodedQuery';
    } else if (coreDomain.contains('deepatelier')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('pandora')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('miumiu')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('victoriassecret')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('nocturne')) {
      return '$baseUrl/arama?q=$encodedQuery';
    } else if (coreDomain.contains('beymen')) {
      return '$baseUrl/search?q=$encodedQuery';
    } else if (coreDomain.contains('bluediamond')) {
      return '$baseUrl/arama?q=$encodedQuery';
    } else if (coreDomain.contains('lacoste')) {
      return '$baseUrl/arama?search=$encodedQuery';
    } else if (coreDomain.contains('mancofficial')) {
      return '$baseUrl/search?type=product&q=$encodedQuery';
    } else if (coreDomain.contains('ipekyol')) {
      return '$baseUrl/arama?q=$encodedQuery';
    } else if (coreDomain.contains('sandro-paris')) {
      return '$baseUrl/en/search?q=$encodedQuery';
    } else if (coreDomain.contains('sandro')) {
      return '$baseUrl/search?q=$encodedQuery';
    }
    
    // Turkish sites often use "arama" instead of "search"
    if (siteDomain.endsWith('.tr') || baseUrl.contains('/tr/')) {
      return '$baseUrl/arama?q=$encodedQuery';
    }
    
    // Fallback to common search pattern
    return '$baseUrl/search?q=$encodedQuery';
  }
}