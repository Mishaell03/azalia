import 'dart:io';
import 'package:azalia/components/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageEdit extends StatefulWidget {
  final String fullImageUrl;

  const ImageEdit({super.key, required this.fullImageUrl});

  @override
  State<ImageEdit> createState() => _ImageEdit();
}

class _ImageEdit extends State<ImageEdit> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _currentImageFile;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 88,
        maxWidth: 113,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _currentImageFile = File(image.path);
        });
      }
    } catch (e) {
      _showErrorDialog('Ошибка при выборе изображения');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: 113,
          height: 88,
          child: Image(
            image: _currentImageFile != null
                ? FileImage(_currentImageFile!)
                : NetworkImage(widget.fullImageUrl) as ImageProvider,
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: InkWell(
            onTap: () => _pickImage(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brown,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit, color: AppColors.white, size: 17,),
            ),
          ),
        ),
      ],
    );
  }
}
