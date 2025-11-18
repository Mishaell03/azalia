import 'dart:io';
import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';

class AppProfileImage extends StatelessWidget {
  final File? selectedImageFile;
  final VoidCallback onTap;
  final double size;
  final double cameraIconSize;

  const AppProfileImage({
    super.key,
    required this.selectedImageFile,
    required this.onTap,
    this.size = 80,
    this.cameraIconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
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
              image: selectedImageFile != null
                  ? DecorationImage(
                      image: FileImage(selectedImageFile!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: selectedImageFile == null
                ? Icon(
                    Icons.person,
                    size: size * 0.5,
                    color: AppColors.brown,
                  )
                : null,
          ),
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
}