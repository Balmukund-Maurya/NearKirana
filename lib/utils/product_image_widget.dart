import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ProductImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    if (imageUrl!.startsWith('data:image')) {
      return _buildBase64Image();
    } else if (imageUrl!.startsWith('http')) {
      return _buildNetworkImage();
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildBase64Image() {
    try {
      // Expected format: data:image/jpeg;base64,...
      final parts = imageUrl!.split(',');
      if (parts.length != 2) return _buildPlaceholder();

      final base64Str = parts[1];
      final bytes = base64Decode(base64Str);

      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return _buildPlaceholder();
    }
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}
