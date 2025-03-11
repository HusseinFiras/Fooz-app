// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import '../models/product_info.dart';
import '../widgets/product_card.dart';
import '../services/favorites_service.dart';
import '../services/data_service.dart';
import 'webview_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late FavoritesService _favoritesService;
  List<ProductInfo> _favoriteItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
    _loadFavoriteItems();
  }

  Future<void> _loadFavoriteItems() async {
    setState(() {
      _isLoading = true;
    });
    
    final items = await _favoritesService.getFavoriteItems();
    
    setState(() {
      _favoriteItems = items;
      _isLoading = false;
    });
  }
  
  Future<void> _removeFromFavorites(ProductInfo product) async {
    await _favoritesService.removeFromFavorites(product);
    await _loadFavoriteItems();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Item removed from favorites'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await _favoritesService.addToFavorites(product);
            await _loadFavoriteItems();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          if (_favoriteItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Favorites'),
                    content: const Text('Are you sure you want to clear all favorites?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await _favoritesService.clearFavorites();
                  await _loadFavoriteItems();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Favorites cleared'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your favorites list is empty',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add items by tapping the heart icon when viewing products',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _favoriteItems.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final product = _favoriteItems[index];
                    return Dismissible(
                      key: Key(product.url),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        _removeFromFavorites(product);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ProductCard(
                          productInfo: product,
                          onTap: () {
                            // Find store index to open correct webview
                            final url = product.url;
                            // Extract domain from URL to find matching retailer
                            final uri = Uri.parse(url);
                            final domain = uri.host;
                            
                            // Find index of store with matching domain
                            final dataService = DataService();
                            int storeIndex = 0;
                            
                            for (int i = 0; i < dataService.retailSites.length; i++) {
                              final siteUrl = dataService.retailSites[i]['url'] ?? '';
                              if (siteUrl.contains(domain)) {
                                storeIndex = i;
                                break;
                              }
                            }
                            
                            // Navigate to WebView with product URL
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WebViewScreen(
                                  initialSiteIndex: storeIndex,
                                  initialUrl: url,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}