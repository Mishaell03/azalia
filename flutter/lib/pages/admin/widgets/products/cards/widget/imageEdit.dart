import 'dart:io';

import 'package:azalia/components/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageEdit extends StatefulWidget {
  final String fullImageUrl;
  final File? imageFile;
  final ValueChanged<File> onImageSelected;

  const ImageEdit({
    super.key,
    required this.fullImageUrl,
    required this.imageFile,
    required this.onImageSelected,
  });

  @override
  State<ImageEdit> createState() => _ImageEditState();
}

class _ImageEditState extends State<ImageEdit> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 88,
        maxWidth: 113,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        widget.onImageSelected(File(image.path));
      }
    } catch (_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ошибка'),
          content: const Text('Ошибка при выборе изображения'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = widget.fullImageUrl.trim();
    final ImageProvider<Object>? imageProvider = widget.imageFile != null
        ? FileImage(widget.imageFile!)
        : (resolvedUrl.isNotEmpty ? NetworkImage(resolvedUrl) : null);

    return Stack(
      children: [
        SizedBox(
          width: 113,
          height: 88,
          child: imageProvider == null
              ? Container(color: AppColors.grey_light)
              : Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: AppColors.grey_light),
                ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: InkWell(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.brown,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: AppColors.white, size: 17),
            ),
          ),
        ),
      ],
    );
  }
}
