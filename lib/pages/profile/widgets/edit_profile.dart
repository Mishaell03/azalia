import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/profile/widgets/phone.dart';
import 'package:azalia/pages/profile/widgets/image.dart';

class AppEditProfile extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final File? selectedImageFile;
  final Function() onUpdateProfile;
  final Function(File?) onImageUpdated;

  const AppEditProfile({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.selectedImageFile,
    required this.onUpdateProfile,
    required this.onImageUpdated,
  });

  @override
  State<AppEditProfile> createState() => _AppEditProfile();
}

class _AppEditProfile extends State<AppEditProfile> {
  final FocusNode _nameFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  late File? _currentImageFile;

  @override
  void initState() {
    super.initState();
    _currentImageFile = widget.selectedImageFile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
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

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _currentImageFile = File(image.path);
        });
      }
    } catch (e) {
      _showErrorDialog('Ошибка при съемке фото');
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Выберите источник',
          style: AppText.bold_18.copyWith(color: AppColors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.brown),
              title: Text('Галерея'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.brown),
              title: Text('Камера'),
              onTap: () {
                Navigator.of(context).pop();
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() {
    final trimmedName = widget.nameController.text.trim();
    final finalName = trimmedName.length > 15
        ? trimmedName.substring(0, 15)
        : trimmedName;

    widget.nameController.text = finalName;

    if (finalName.isEmpty) {
      _showErrorDialog('Пожалуйста, введите имя');
      return;
    }

    String phoneDigits = widget.phoneController.text.replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    if (phoneDigits.length != 11) {
      _showErrorDialog('Пожалуйста, введите корректный номер телефона');
      return;
    }

    // Передаем обновленное фото обратно в ProfilePage
    widget.onImageUpdated(_currentImageFile);
    
    Navigator.of(context).pop();
    widget.onUpdateProfile();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Ошибка',
          style: AppText.bold_18.copyWith(color: AppColors.error),
        ),
        content: Text(
          message,
          style: AppText.medium_16.copyWith(color: AppColors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: AppText.medium_16.copyWith(color: AppColors.brown),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Редактировать профиль',
        style: AppText.bold_18.copyWith(color: AppColors.black),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppProfileImage(
              selectedImageFile: _currentImageFile,
              onTap: _showImageSourceDialog,
              size: 100,
              cameraIconSize: 32,
              showCameraIcon: true,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: widget.nameController,
              focusNode: _nameFocusNode,
              autofocus: true,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              maxLength: 15,
              decoration: InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
              onChanged: (value) {
                if (value.length > 15) {
                  widget.nameController.text = value.substring(0, 15);
                  widget.nameController.selection = TextSelection.collapsed(
                    offset: 15,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [AppProfilePhone()],
              decoration: InputDecoration(
                labelText: 'Телефон',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Отмена',
            style: AppText.medium_16.copyWith(color: AppColors.grey),
          ),
        ),
        TextButton(
          onPressed: _saveProfile,
          child: Text(
            'Сохранить',
            style: AppText.medium_16.copyWith(color: AppColors.brown),
          ),
        ),
      ],
    );
  }
}