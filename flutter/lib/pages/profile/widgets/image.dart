import 'dart:io';
import 'dart:convert';
import 'package:azalia/backend/api_config.dart';
import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';

class AppProfileImage extends StatelessWidget {
  final File? selectedImageFile;
  final String? avatarBase64;
  final VoidCallback onTap;
  final double size;
  final double cameraIconSize;
  final bool showCameraIcon;

  const AppProfileImage({
    super.key,
    this.selectedImageFile,
    this.avatarBase64,
    required this.onTap,
    this.size = 80,
    this.cameraIconSize = 24,
    this.showCameraIcon = true,
  });

  Widget? _buildImage() {
    if (selectedImageFile != null) {
      return Image.file(
        selectedImageFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }
    
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      final avatarValue = avatarBase64!.trim();

      if (_looksLikeImagePath(avatarValue)) {
        return Image.network(
          ApiConfig.imageUrl(avatarValue),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }

      try {
        String cleanBase64 = avatarValue;
        
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last.trim();
        }
        
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
        
        if (cleanBase64.isEmpty) {
          return _buildPlaceholder();
        }
        
        final imageBytes = base64Decode(cleanBase64);
        
        if (imageBytes.isEmpty) {
          return _buildPlaceholder();
        }
        
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      } catch (e) {
        return _buildPlaceholder();
      }
    }
    
    return null;
  }

  Widget _buildPlaceholder() {
    return Icon(
      Icons.person,
      size: size * 0.5,
      color: AppColors.brown,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = selectedImageFile != null || 
                    (avatarBase64 != null && avatarBase64!.isNotEmpty && avatarBase64!.trim().isNotEmpty);
    
    final imageWidget = hasImage ? _buildImage() : null;
    
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brown.withOpacity(0.1),
            ),
            child: ClipOval(
              child: imageWidget ?? _buildPlaceholder(),
            ),
          ),
          if (showCameraIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: cameraIconSize,
                height: cameraIconSize,
                decoration: BoxDecoration(
                  color: AppColors.brown,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: cameraIconSize * 0.5,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _looksLikeImagePath(String value) {
    return value.startsWith('http') ||
        value.startsWith('/') ||
        value.startsWith('img/') ||
        value.startsWith('api/');
  }
}
