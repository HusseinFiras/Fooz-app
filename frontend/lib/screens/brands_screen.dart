// lib/screens/brands_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data_service.dart';
import 'webview_screen.dart';

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({Key? key}) : super(key: key);

  @override
  _BrandsScreenState createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _fadeController;
  
  // Animations
  late Animation<double> _fadeAnimation;

  // State variables
  bool _isSearching = false;
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  
  // Categories
  final List<String> _categories = ['All Brands', 'Luxury', 'Fashion', 'Beauty', 'Sports'];
  
  // Brand categorization
  final List<String> _luxuryBrands = [
    'Gucci',
    'Cartier',
    'Swarovski',
    'Miu Miu',
    'Beymen',
    'Blue Diamond',
    'Lacoste',
    'Sandro',
    'Deep Atelier',
    'Mango'
  ];

  final List<String> _fashionBrands = [
    'Zara',
    'Stradivarius',
    'Guess',
    'Bershka',
    'Massimo Dutti',
    'Pandora',
    'Victoria\'s Secret',
    'Nocturne',
    'Ipekyol'
  ];

  final List<String> _beautyBrands = [
    'Sephora',
    'MAC',
    'Estee Lauder',
    'L\'Oreal',
    'Clinique'
  ];

  final List<String> _sportsBrands = [
    'Nike',
    'Adidas',
    'Puma',
    'Under Armour',
    'New Balance'
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    
    // Start animation
    _fadeController.forward();
    
    // Add search controller listener
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }
  
  void _navigateToSite(int index) {
    HapticFeedback.mediumImpact(); // Give tactile feedback

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          initialSiteIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter brands based on search query and category
    List<Map<String, String>> filteredBrands = _dataService.retailSites.where((site) {
      final name = site['name']?.toLowerCase() ?? '';
      
      // First filter by search query
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
        return false;
      }
      
      // Then filter by category
      if (_selectedCategoryIndex == 0) {
        return true; // All brands
      } else if (_selectedCategoryIndex == 1) {
        return _luxuryBrands.contains(site['name']);
      } else if (_selectedCategoryIndex == 2) {
        return _fashionBrands.contains(site['name']);
      } else if (_selectedCategoryIndex == 3) {
        return _beautyBrands.contains(site['name']);
      } else if (_selectedCategoryIndex == 4) {
        return _sportsBrands.contains(site['name']);
      }
      
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search brands...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
            )
          : const Text('Brands'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.clear : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Categories
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedCategoryIndex == index;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Grid of brands
          Expanded(
            child: filteredBrands.isEmpty
              ? const Center(
                  child: Text('No brands found'),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: filteredBrands.length,
                    itemBuilder: (context, index) {
                      final site = filteredBrands[index];
                      final name = site['name'] ?? '';
                      
                      // Determine category
                      String category = 'Other';
                      if (_luxuryBrands.contains(name)) {
                        category = 'Luxury';
                      } else if (_fashionBrands.contains(name)) {
                        category = 'Fashion';
                      } else if (_beautyBrands.contains(name)) {
                        category = 'Beauty';
                      } else if (_sportsBrands.contains(name)) {
                        category = 'Sports';
                      }
                      
                      return _buildBrandCard(name, category, index);
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBrandCard(String name, String category, int index) {
    // Generate a color based on category
    Color cardColor;
    switch (category) {
      case 'Luxury':
        cardColor = Colors.blueGrey[800]!;
        break;
      case 'Fashion':
        cardColor = Colors.indigo[700]!;
        break;
      case 'Beauty':
        cardColor = Colors.pink[700]!;
        break;
      case 'Sports':
        cardColor = Colors.green[700]!;
        break;
      default:
        cardColor = Colors.grey[700]!;
    }
    
    return GestureDetector(
      onTap: () => _navigateToSite(
        _dataService.retailSites.indexWhere((site) => site['name'] == name)
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background of card 
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cardColor,
                      cardColor.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brand circle with first letter
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        name.substring(0, 1),
                        style: TextStyle(
                          color: cardColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  
                  // Brand name
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Category tag
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}