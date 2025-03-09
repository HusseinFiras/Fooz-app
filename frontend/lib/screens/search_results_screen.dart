// lib/screens/search_results_screen.dart
import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../screens/webview_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;
  final int? specificRetailerIndex;

  const SearchResultsScreen({
    Key? key,
    required this.searchQuery,
    this.specificRetailerIndex,
  }) : super(key: key);

  @override
  _SearchResultsScreenState createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final DataService _dataService = DataService();
  List<Map<String, dynamic>> _retailers = [];
  
  @override
  void initState() {
    super.initState();
    _loadRetailers();
  }
  
  void _loadRetailers() {
    // If a specific retailer index is provided, only search that one
    if (widget.specificRetailerIndex != null) {
      final retailer = _dataService.retailSites[widget.specificRetailerIndex!];
      _retailers = [
        {
          ...retailer,
          'searchUrl': _generateSearchUrl(retailer, widget.searchQuery),
        }
      ];
    } else {
      // Otherwise, generate search URLs for all retailers
      _retailers = _dataService.retailSites.map((retailer) {
        return {
          ...retailer,
          'searchUrl': _generateSearchUrl(retailer, widget.searchQuery),
        };
      }).toList();
    }
  }
  
  String _generateSearchUrl(Map<String, String> retailer, String query) {
    final baseUrl = retailer['url']!;
    final encodedQuery = Uri.encodeComponent(query);
    
    // Different retailers have different search URL structures
    // We'll need to define these patterns for each supported retailer
    final String domain = Uri.parse(baseUrl).host;
    
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Results for "${widget.searchQuery}"'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _retailers.length,
        itemBuilder: (context, index) {
          final retailer = _retailers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(
                      initialSiteIndex: _dataService.retailSites.indexWhere(
                        (site) => site['name'] == retailer['name'],
                      ),
                      initialUrl: retailer['searchUrl'],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Retailer icon/logo
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          retailer['name']![0],
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Retailer info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            retailer['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search for "${widget.searchQuery}"',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action button
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}