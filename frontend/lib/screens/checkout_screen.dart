// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme_constants.dart';
import '../models/product_info.dart';
import '../services/cart_service.dart';

class CheckoutScreen extends StatefulWidget {
  final List<ProductInfo>? cartItems;

  const CheckoutScreen({
    Key? key,
    this.cartItems,
  }) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // Cart service for retrieving cart items if not provided
  final CartService _cartService = CartService();
  
  // State variables
  late List<ProductInfo> _cartItems;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  
  // Validation patterns
  final RegExp _emailRegex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
  final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
  
  // List of common cities in Iraq (can be expanded)
  final List<String> _iraqCities = [
    'Baghdad', 'Basra', 'Mosul', 'Erbil', 'Sulaymaniyah', 
    'Najaf', 'Karbala', 'Kirkuk', 'Ramadi', 'Fallujah',
    'Nasiriyah', 'Kut', 'Amarah', 'Diwaniyah', 'Samawah', 'Hillah'
  ];
  
  @override
  void initState() {
    super.initState();
    
    // If cart items are provided via constructor, use them
    // Otherwise, load them from the cart service
    if (widget.cartItems != null) {
      _cartItems = widget.cartItems!;
      _isLoading = false;
    } else {
      _loadCartItems();
    }
  }
  
  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
    });
    
    final items = await _cartService.getCartItems();
    
    setState(() {
      _cartItems = items;
      _isLoading = false;
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  // Format phone number as user types
  String _formatPhoneNumber(String text) {
    // Remove all non-digit characters
    String digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    
    // Format based on length
    if (digitsOnly.length <= 3) {
      return digitsOnly;
    } else if (digitsOnly.length <= 6) {
      return '${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3)}';
    } else if (digitsOnly.length <= 10) {
      return '${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3, 6)} ${digitsOnly.substring(6)}';
    } else {
      return '${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3, 6)} ${digitsOnly.substring(6, 9)} ${digitsOnly.substring(9)}';
    }
  }
  
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      
      // Show processing state
      setState(() {
        _isProcessingPayment = true;
      });
      
      // Simulate payment processing
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
          });
          
          // Show success dialog
          _showSuccessDialog();
        }
      });
    } else {
      // Show error message and provide haptic feedback
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check your information'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Order Placed Successfully!',
          style: TextStyle(
            fontFamily: 'DM Serif Display',
            color: LuxuryTheme.textCharcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LuxuryTheme.rosegoldGradient,
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: 50,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Thank you for your order, ${_nameController.text}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: LuxuryTheme.textCharcoal,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We\'ve sent a confirmation to ${_emailController.text}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You\'ll receive delivery updates at ${_phoneController.text}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Clear cart and return to home
              _cartService.clearCart().then((_) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            },
            child: Text(
              'Continue Shopping',
              style: TextStyle(
                color: LuxuryTheme.primaryRosegold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Calculate total price of items in cart
  String _calculateTotal() {
    double total = 0;
    String? currency;
    
    for (final item in _cartItems) {
      if (item.price != null) {
        total += item.price!;
        // Get the currency from the first valid item
        if (currency == null && item.currency != null) {
          currency = item.currency;
        }
      }
    }
    
    // Format with the appropriate currency symbol
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
    
    return '${total.toStringAsFixed(2)} $symbol';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Checkout',
          style: TextStyle(
            fontFamily: 'DM Serif Display',
            color: LuxuryTheme.textCharcoal,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: LuxuryTheme.textCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  LuxuryTheme.primaryRosegold,
                ),
              ),
            )
          : _cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Your cart is empty',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          fontFamily: 'Lato',
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add items to your cart to checkout',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                          fontFamily: 'Lato',
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LuxuryTheme.primaryRosegold,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text('Continue Shopping'),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Form fields
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order summary section
                              _buildSectionHeader('Order Summary'),
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Items:',
                                          style: TextStyle(
                                            fontFamily: 'Lato',
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${_cartItems.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total:',
                                          style: TextStyle(
                                            fontFamily: 'Lato',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _calculateTotal(),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: LuxuryTheme.textCharcoal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              
                              // Contact information
                              _buildSectionHeader('Contact Information'),
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Name field
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: _inputDecoration(
                                        labelText: 'Full Name',
                                        hintText: 'Enter your full name',
                                        icon: Icons.person_outline,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your name';
                                        }
                                        if (value.trim().length < 3) {
                                          return 'Name is too short';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // Email field with validation
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: _inputDecoration(
                                        labelText: 'Email',
                                        hintText: 'Enter your email address',
                                        icon: Icons.email_outlined,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter an email address';
                                        }
                                        if (!_emailRegex.hasMatch(value)) {
                                          return 'Please enter a valid email';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // Phone number field with validation
                                    TextFormField(
                                      controller: _phoneController,
                                      decoration: _inputDecoration(
                                        labelText: 'Phone Number',
                                        hintText: 'Enter your phone number',
                                        icon: Icons.phone_outlined,
                                      ),
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\s+]')),
                                      ],
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your phone number';
                                        }
                                        // Strip non-digits for validation
                                        final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                                        if (digitsOnly.length < 10) {
                                          return 'Phone number is too short';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        // Format the phone number as the user types
                                        final formatted = _formatPhoneNumber(value);
                                        if (formatted != value) {
                                          _phoneController.value = TextEditingValue(
                                            text: formatted,
                                            selection: TextSelection.collapsed(offset: formatted.length),
                                          );
                                        }
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              
                              // Simplified shipping information with landmark
                              _buildSectionHeader('Shipping Address'),
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // City dropdown with common Iraqi cities
                                    DropdownButtonFormField<String>(
                                      decoration: _inputDecoration(
                                        labelText: 'City',
                                        hintText: 'Select your city',
                                        icon: Icons.location_city_outlined,
                                      ),
                                      items: _iraqCities.map((city) {
                                        return DropdownMenuItem(
                                          value: city,
                                          child: Text(city),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _cityController.text = value;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select your city';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // District/Area field
                                    TextFormField(
                                      controller: _streetController,
                                      decoration: _inputDecoration(
                                        labelText: 'District/Area',
                                        hintText: 'Enter your district or area name',
                                        icon: Icons.map_outlined,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter your district or area';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // Closest landmark field
                                    TextFormField(
                                      controller: _landmarkController,
                                      decoration: _inputDecoration(
                                        labelText: 'Closest Landmark',
                                        hintText: 'Nearby shop, mosque, or known building',
                                        icon: Icons.place_outlined,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter a nearby landmark';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                    SizedBox(height: 16),
                                    
                                    // Notes field (optional)
                                    TextFormField(
                                      controller: _notesController,
                                      decoration: _inputDecoration(
                                        labelText: 'Delivery Instructions (Optional)',
                                        hintText: 'Additional directions or instructions for delivery',
                                        icon: Icons.note_outlined,
                                      ),
                                      maxLines: 2,
                                      // No validator since this field is optional
                                      textInputAction: TextInputAction.done,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Space at the bottom to ensure all content is visible
                              SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                      
                      // Checkout button fixed at the bottom
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isProcessingPayment ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LuxuryTheme.primaryRosegold,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: _isProcessingPayment
                                  ? CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 3,
                                    )
                                  : Text(
                                      'PLACE ORDER',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
  
  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'DM Serif Display',
              fontSize: 18,
              color: LuxuryTheme.textCharcoal,
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
    );
  }
  
  // Helper method for consistent input decoration
  InputDecoration _inputDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(
        icon,
        color: LuxuryTheme.primaryRosegold,
      ),
      prefixIconColor: LuxuryTheme.primaryRosegold,
      labelStyle: TextStyle(
        color: LuxuryTheme.textCharcoal.withOpacity(0.8),
        fontFamily: 'Lato',
      ),
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontFamily: 'Lato',
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: LuxuryTheme.primaryRosegold,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.red,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }
}