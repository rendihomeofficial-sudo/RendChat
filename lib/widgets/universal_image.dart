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

  const UniversalImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        if (commaIdx != -1) {
          final b64 = imageUrl.substring(commaIdx + 1);
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) =>
                errorWidget ?? const Icon(Icons.broken_image, color: Colors.grey),
          );
        }
      } catch (e) {
        debugPrint('UniversalImage decode base64 error: $e');
      }
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
