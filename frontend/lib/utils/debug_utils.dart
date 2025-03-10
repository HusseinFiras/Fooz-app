// lib/utils/debug_utils.dart

import 'package:flutter/foundation.dart';

/// A cleaner debug logging system that filters out unwanted noise
class DebugLog {
  /// Main logging levels
  static const int NONE = 0;
  static const int ERROR = 1;
  static const int WARN = 2;
  static const int INFO = 3;
  static const int DEBUG = 4;
  static const int VERBOSE = 5;

  /// Log categories to filter and organize logs
  static const String PRODUCT = "Product";
  static const String WEBVIEW = "WebView";
  static const String NETWORK = "Network";
  static const String UI = "UI";
  static const String GENERAL = "General";

  /// Configure logging level and filters
  static int _logLevel = kReleaseMode ? ERROR : INFO;
  static final Set<String> _enabledCategories = {PRODUCT, WEBVIEW, NETWORK};
  static bool _filterWebViewLogs = true;
  static bool _showTimestamps = true;

  /// Maximum length for log messages (longer will be truncated)
  static int _maxLogLength = 500;

  /// Filter patterns to exclude from logging
  static final List<String> _filterPatterns = [
    "Running with",
    "Syncing files",
    "Reloaded",
    "Connected to",
    "Setting up hot",
    "Performing hot",
    "The following",
    "_RenderProxy",
    "Instance of",
    "WebKit",
    "Unsupported class version",
    "WebViewController",
    "PlatformView"
  ];

  /// Set the logging level
  static void setLogLevel(int level) {
    _logLevel = level;
    print("📋 Log level set to: ${_getLevelName(level)}");
  }

  /// Enable or disable a specific category
  static void toggleCategory(String category, bool enabled) {
    if (enabled) {
      _enabledCategories.add(category);
    } else {
      _enabledCategories.remove(category);
    }
    print(
        "📋 Category '$category' is now: ${enabled ? 'ENABLED' : 'DISABLED'}");
  }

  /// Enable or disable WebView-specific logs filtering
  static void setFilterWebViewLogs(bool filter) {
    _filterWebViewLogs = filter;
    print("📋 WebView filtering is now: ${filter ? 'ENABLED' : 'DISABLED'}");
  }

  /// Include/exclude timestamps in logs
  static void setShowTimestamps(bool show) {
    _showTimestamps = show;
  }

  /// Set maximum log length (for truncation)
  static void setMaxLogLength(int length) {
    _maxLogLength = length;
  }

  /// Log an error message
  static void e(String message, {String category = GENERAL, Object? details}) {
    _log(ERROR, category, message, details);
  }

  /// Log a warning message
  static void w(String message, {String category = GENERAL, Object? details}) {
    _log(WARN, category, message, details);
  }

  /// Log an info message
  static void i(String message, {String category = GENERAL, Object? details}) {
    _log(INFO, category, message, details);
  }

  /// Log a debug message
  static void d(String message, {String category = GENERAL, Object? details}) {
    _log(DEBUG, category, message, details);
  }

  /// Log a verbose message
  static void v(String message, {String category = GENERAL, Object? details}) {
    _log(VERBOSE, category, message, details);
  }

  /// Main logging implementation
  static void _log(
      int level, String category, String message, Object? details) {
    // Skip if logging is disabled for this level
    if (level > _logLevel) return;

    // Skip if category is disabled
    if (!_enabledCategories.contains(category)) return;

    // Check for filtered patterns
    if (_shouldFilterLog(message)) return;

    // Prepare log prefix with level and category
    final levelName = _getLevelName(level);
    final timestamp = _showTimestamps
        ? "${DateTime.now().toIso8601String().substring(11, 19)} "
        : "";
    final prefix = "$timestamp[$levelName][$category]";

    // Maybe truncate message
    String logMessage = message;
    if (logMessage.length > _maxLogLength) {
      logMessage = "${logMessage.substring(0, _maxLogLength)}... (truncated)";
    }

    // Log message with or without details
    if (details != null) {
      // Custom version of debugPrint that avoids some Flutter logging issues
      _safePrint("$prefix $logMessage");
      _safePrint("    └─ Details: $details");
    } else {
      _safePrint("$prefix $logMessage");
    }
  }

  /// Determine if a log should be filtered out
  static bool _shouldFilterLog(String message) {
    // Apply WebView filtering if enabled
    if (_filterWebViewLogs) {
      for (final pattern in _filterPatterns) {
        if (message.contains(pattern)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Convert log level to string name
  static String _getLevelName(int level) {
    switch (level) {
      case ERROR:
        return "ERROR";
      case WARN:
        return "WARN";
      case INFO:
        return "INFO";
      case DEBUG:
        return "DEBUG";
      case VERBOSE:
        return "VERBOSE";
      default:
        return "UNKNOWN";
    }
  }

  /// Safely print message avoiding some Flutter debug print limitations
  static void _safePrint(String message) {
    // Using debugPrintThrottled to avoid log dropping in Flutter
    debugPrintThrottled(message);
  }

  /// Clear current console (may not work in all environments)
  static void clearConsole() {
    // ANSI escape code to clear console - works in some environments
    print('\x1B[2J\x1B[0;0H');
    print('Console cleared at ${DateTime.now()}');
  }
}
