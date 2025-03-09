// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_service.dart';
import 'search_results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DataService _dataService = DataService();
  List<String> _recentSearches = [];
  List<Map<String, String>> _popularRetailers = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadPopularRetailers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  void _loadPopularRetailers() {
    // Here we could load from analytics or just show a curated list
    // For now, we'll just take the first 5 retailers
    setState(() {
      _popularRetailers = _dataService.retailSites.sublist(0, 5);
    });
  }

  Future<void> _saveSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing searches
    List<String> searches = prefs.getStringList('recent_searches') ?? [];
    
    // Remove this search if it already exists (to avoid duplicates)
    searches.removeWhere((s) => s.toLowerCase() == query.toLowerCase());
    
    // Add this search to the beginning of the list
    searches.insert(0, query);
    
    // Keep only the last 10 searches
    if (searches.length > 10) {
      searches = searches.sublist(0, 10);
    }
    
    // Save updated list
    await prefs.setStringList('recent_searches', searches);
    
    // Update state
    setState(() {
      _recentSearches = searches;
    });
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    // Save this search
    _saveSearch(query);

    // Navigate to results screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          searchQuery: query.trim(),
        ),
      ),
    );
  }

  void _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    
    setState(() {
      _recentSearches = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
          decoration: InputDecoration(
            hintText: 'Search products...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[600]),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _isSearching = false;
                      });
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (value) {
            setState(() {
              _isSearching = value.trim().isNotEmpty;
            });
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text),
          ),
        ],
      ),
      body: _isSearching
          ? const Center(
              child: Text('Type to search...'),
            )
          : ListView(
              children: [
                // Recent searches section
                if (_recentSearches.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Searches',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _clearRecentSearches,
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentSearches.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(_recentSearches[index]),
                        onTap: () => _performSearch(_recentSearches[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () async {
                            List<String> searches = List.from(_recentSearches);
                            searches.removeAt(index);
                            
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setStringList('recent_searches', searches);
                            
                            setState(() {
                              _recentSearches = searches;
                            });
                          },
                        ),
                      );
                    },
                  ),
                  const Divider(),
                ],

                // Popular retailers section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                  child: Text(
                    'Popular Retailers',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _popularRetailers.length,
                  itemBuilder: (context, index) {
                    final retailer = _popularRetailers[index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchResultsScreen(
                              searchQuery: _searchController.text.trim().isEmpty 
                                  ? 'popular items' // Default search if no input
                                  : _searchController.text.trim(),
                              specificRetailerIndex: _dataService.retailSites.indexWhere(
                                (r) => r['name'] == retailer['name'],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                retailer['name']![0],
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            retailer['name']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Search suggestions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                  child: Text(
                    'Popular Searches',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Handbags',
                    'Shoes',
                    'Watches',
                    'Dresses',
                    'Jewelry',
                    'Sunglasses',
                    'Perfume',
                    'Sale',
                    'New Arrivals',
                  ].map((term) => Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: InkWell(
                      onTap: () => _performSearch(term),
                      child: Chip(
                        label: Text(term),
                        backgroundColor: Colors.grey[200],
                        onDeleted: null,
                        deleteIcon: null,
                        labelStyle: TextStyle(color: theme.colorScheme.primary),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
    );
  }
}