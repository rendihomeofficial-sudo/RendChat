import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/whatsapp_theme.dart';

class UniversalImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  // In-memory cache for base64 decoded bytes so images are not re-decoded on every widget rebuild
  static final Map<String, Uint8List> _base64Cache = {};
  static const int _maxCacheSize = 40;

  const UniversalImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  static Uint8List? _getDecodedBytes(String dataUri) {
    if (_base64Cache.containsKey(dataUri)) {
      return _base64Cache[dataUri];
    }
    try {
      final commaIdx = dataUri.indexOf(',');
      if (commaIdx != -1) {
        final b64 = dataUri.substring(commaIdx + 1).trim();
        final bytes = base64Decode(b64);
        if (_base64Cache.length >= _maxCacheSize) {
          _base64Cache.remove(_base64Cache.keys.first);
        }
        _base64Cache[dataUri] = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('UniversalImage decode base64 error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      final bytes = _getDecodedBytes(imageUrl);
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return placeholder ??
                Container(
                  width: width,
                  height: height,
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WhatsAppTheme.primaryTeal,
                    ),
                  ),
                );
          },
          errorBuilder: (_, __, ___) =>
              errorWidget ?? const Icon(Icons.broken_image, color: Colors.grey),
        );
      }
      return errorWidget ?? const Icon(Icons.broken_image, color: Colors.grey);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WhatsAppTheme.primaryTeal,
              ),
            ),
          ),
      errorWidget: (_, __, ___) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.black26,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
    );
  }
}
