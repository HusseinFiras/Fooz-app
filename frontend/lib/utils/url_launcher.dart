import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter/services.dart';
import 'debug_utils.dart';

/// Utility class for launching URLs from the app
class UrlLauncher {
  /// Opens the given URL in the device's default browser
  static Future<void> openUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(
          uri,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      } else {
        // If we can't launch the URL, copy it to clipboard as fallback
        await Clipboard.setData(ClipboardData(text: url));
        throw Exception('Could not launch $url (copied to clipboard)');
      }
    } catch (e) {
      DebugLog.e('Error launching URL: $e');
      // Rethrow to let caller handle the error
      rethrow;
    }
  }
  
  /// Opens a URL in an external browser with a confirmation dialog
  static Future<void> openUrlWithConfirmation(
    BuildContext context, 
    String url,
    {String? title, String? message}
  ) async {
    final bool shouldOpen = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Open external link?'),
        content: Text(message ?? 'This will open $url in your browser.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open'),
          ),
        ],
      ),
    ) ?? false;
    
    if (shouldOpen) {
      await openUrl(url);
    }
  }
} 