// lib/widgets/cached_image_widget.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/image_cache_service.dart';

class CachedImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final String? brandName;
  final String? productTitle;
  final String? colorName;

  const CachedImageWidget({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
    this.brandName,
    this.productTitle,
    this.colorName,
  }) : super(key: key);

  @override
  State<CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<CachedImageWidget> {
  bool _isLoading = true;
  String? _localPath;
  Object? _error;
  final String _debugTag = "[IMG_WIDGET]";

  // Map of brand names to their brand colors
  static final Map<String, Color> _brandColors = {
    'gucci': const Color(0xFF1F1F1F),
    'zara': const Color(0xFF212121),
    'stradivarius': const Color(0xFF7B6751),
    'cartier': const Color(0xFFB01119),
    'swarovski': const Color(0xFF0C1F3C),
    'guess': const Color(0xFF1A1A1A),
    'mango': const Color(0xFF2A2A2A),
    'bershka': const Color(0xFF333333),
    'massimo dutti': const Color(0xFF796F65),
    'deep atelier': const Color(0xFF000000),
    'pandora': const Color(0xFFA8A8A8),
    'miu miu': const Color(0xFFD3A97E),
    'victoria\'s secret': const Color(0xFFE1B4CE),
    'nocturne': const Color(0xFF000000),
    'beymen': const Color(0xFF000000),
    'blue diamond': const Color(0xFF304065),
    'lacoste': const Color(0xFF004234),
    'manc': const Color(0xFF022742),
    'ipekyol': const Color(0xFF241F20),
    'sandro': const Color(0xFF0D0A0B),
  };

  // Variant colors for common color names
  static final Map<String, Color> _variantColors = {
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red.shade800,
    'blue': Colors.blue.shade800,
    'green': Colors.green.shade800,
    'yellow': Colors.amber,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'grey': Colors.grey,
    'brown': const Color(0xFF795548),
    'navy': const Color(0xFF000080),
    'beige': const Color(0xFFF5F5DC),
    'gold': const Color(0xFFD4AF37),
    'silver': const Color(0xFFC0C0C0),
    'ivory': const Color(0xFFFFFFF0),
    'cream': const Color(0xFFFFFDD0),
    'tan': const Color(0xFFD2B48C),
    'natural': const Color(0xFFE8D4AD),
  };

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Color _getBrandColor() {
    if (widget.colorName != null) {
      // Check if the color name matches any known colors
      final lowerColorName = widget.colorName!.toLowerCase();
      for (final entry in _variantColors.entries) {
        if (lowerColorName.contains(entry.key)) {
          return entry.key == 'white' ? Colors.grey.shade300 : entry.value;
        }
      }
    }

    if (widget.brandName != null) {
      // Try to match the brand name to a known brand color
      final lowerBrandName = widget.brandName!.toLowerCase();
      for (final entry in _brandColors.entries) {
        if (lowerBrandName.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    // Extract brand from URL if needed
    if (widget.imageUrl.contains('gucci')) {
      return _brandColors['gucci']!;
    } else if (widget.imageUrl.contains('zara')) {
      return _brandColors['zara']!;
    }

    // Generate a color based on the product title or URL
    if (widget.productTitle != null) {
      return _generateColorFromString(widget.productTitle!);
    }

    // Default color - deep elegant gray
    return const Color(0xFF2A2A2A);
  }

  Color _generateColorFromString(String input) {
    // Hash the string and use it to generate a consistent color
    int hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = input.codeUnitAt(i) + ((hash << 5) - hash);
    }

    // Create a HSL color with controlled saturation and lightness for elegance
    final hue = (hash % 360).abs();

    // For luxury brands, we want more elegant, muted colors
    // Lower saturation and controlled lightness
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.35, 0.35).toColor();
  }

  Future<void> _loadImage() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final localPath =
          await ImageCacheService().getOrCacheImage(widget.imageUrl);

      if (mounted) {
        setState(() {
          _localPath = localPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Enhanced error logging for better debugging
      debugPrint('$_debugTag Error loading ${widget.imageUrl}: $e');

      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return widget.loadingBuilder != null
          ? widget.loadingBuilder!(context,
              Container(width: widget.width, height: widget.height), null)
          : Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey.shade200,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _getBrandColor().withOpacity(0.7)),
                  ),
                ),
              ),
            );
    }

    // Error state - show elegant branded placeholder
    if (_error != null || _localPath == null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context,
            _error ?? Exception('Failed to load image'), StackTrace.current);
      }

      final brandColor = _getBrandColor();
      final textColor = _isLightColor(brandColor) ? Colors.black : Colors.white;

      // Create a branded placeholder
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: brandColor,
          borderRadius: BorderRadius.circular(widget.colorName != null ? 4 : 8),
        ),
        child: widget.colorName != null
            // For color variants, just show a color block
            ? null
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.brandName != null) ...[
                      // Show first letter of brand in a circle
                      Container(
                        width: min(40, (widget.width ?? 100) * 0.3),
                        height: min(40, (widget.width ?? 100) * 0.3),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: textColor.withOpacity(0.5), width: 1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.brandName![0].toUpperCase(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: min(20, (widget.width ?? 100) * 0.15),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: min(8, (widget.height ?? 100) * 0.05)),
                    ],
                    if (widget.productTitle != null && (widget.width ?? 0) > 60)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          widget.productTitle!,
                          style: TextStyle(
                            color: textColor.withOpacity(0.9),
                            fontSize: min(14, (widget.width ?? 100) * 0.08),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
      );
    }

    // Success state - show cached image
    return Image.file(
      File(_localPath!),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('$_debugTag Error displaying cached image: $error');

        // If we have a custom error builder, use it
        if (widget.errorBuilder != null) {
          return widget.errorBuilder!(context, error, stackTrace);
        }

        // Otherwise use our branded fallback
        final brandColor = _getBrandColor();
        final textColor =
            _isLightColor(brandColor) ? Colors.black : Colors.white;

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: brandColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: textColor.withOpacity(0.7),
                  size: min(30, (widget.width ?? 100) * 0.2),
                ),
                if (widget.productTitle != null &&
                    (widget.width ?? 0) > 60) ...[
                  SizedBox(height: min(8, (widget.height ?? 100) * 0.05)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      widget.productTitle!,
                      style: TextStyle(
                        color: textColor.withOpacity(0.9),
                        fontSize: min(14, (widget.width ?? 100) * 0.08),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isLightColor(Color color) {
    // Calculate the perceived brightness using the formula
    // (299*R + 587*G + 114*B) / 1000
    final brightness =
        (299 * color.red + 587 * color.green + 114 * color.blue) / 1000;
    return brightness > 128;
  }
}
