import 'dart:io';
import 'package:flutter/material.dart';
import '../services/image_cache_service.dart';

class CachedImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder; // Use Flutter's proper type
  final ImageLoadingBuilder? loadingBuilder; // Use Flutter's proper type

  const CachedImageWidget({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  }) : super(key: key);

  @override
  State<CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<CachedImageWidget> {
  bool _isLoading = true;
  String? _localPath;
  Object? _error;

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

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
    if (_isLoading) {
      return widget.loadingBuilder != null
          ? widget.loadingBuilder!(context,
              Container(width: widget.width, height: widget.height), null)
          : Center(child: CircularProgressIndicator());
    }

    if (_error != null || _localPath == null) {
      return widget.errorBuilder != null
          ? widget.errorBuilder!(context,
              _error ?? Exception('Failed to load image'), StackTrace.current)
          : Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[300],
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.white),
              ),
            );
    }

    return Image.file(
      File(_localPath!),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: widget.errorBuilder,
      // Remove loadingBuilder from here since the file is already loaded
    );
  }
}
