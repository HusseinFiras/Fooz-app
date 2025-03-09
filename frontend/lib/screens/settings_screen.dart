// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  String _selectedCurrency = 'TRY';
  bool _enableNotifications = true;
  final List<String> _supportedCurrencies = ['TRY', 'USD', 'EUR', 'GBP'];
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _selectedCurrency = prefs.getString('currency') ?? 'TRY';
      _enableNotifications = prefs.getBool('enableNotifications') ?? true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // App Preferences Section
          _buildSectionHeader('App Preferences'),
          
          // Dark Mode
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme throughout the app'),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
              _saveSetting('darkMode', value);
              
              // Show message that theme change will apply on restart
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Theme change will apply on app restart'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          
          const Divider(),
          
          // Currency Selection
          ListTile(
            title: const Text('Currency'),
            subtitle: Text('Display prices in $_selectedCurrency'),
            trailing: DropdownButton<String>(
              value: _selectedCurrency,
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCurrency = newValue;
                  });
                  _saveSetting('currency', newValue);
                }
              },
              items: _supportedCurrencies.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          
          const Divider(),
          
          // Notifications
          SwitchListTile(
            title: const Text('Price Drop Notifications'),
            subtitle: const Text('Get notified when products in your favorites drop in price'),
            value: _enableNotifications,
            onChanged: (value) {
              setState(() {
                _enableNotifications = value;
              });
              _saveSetting('enableNotifications', value);
            },
          ),
          
          const Divider(),
          
          // Account Section
          _buildSectionHeader('Account'),
          
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Sign In'),
            subtitle: const Text('Sign in to sync your favorites and cart'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sign in functionality coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          
          // About Section
          _buildSectionHeader('About'),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About App'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Luxury Price Checker',
                applicationVersion: '1.0.0',
                applicationIcon: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                children: const [
                  Text(
                    'Compare prices across luxury retail websites and track product details easily.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    '© 2025 Luxury Price Checker',
                  ),
                ],
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy policy page coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          
          // Data Management
          _buildSectionHeader('Data Management'),
          
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear App Data'),
            subtitle: const Text('Clear saved preferences and cached data'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear App Data'),
                  content: const Text('Are you sure you want to clear all app data? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('CLEAR'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                
                // Reload settings
                await _loadSettings();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('App data cleared successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}