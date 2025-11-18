import 'dart:io';
import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/profile/widgets/phone.dart';
import 'package:azalia/pages/profile/widgets/image.dart';

class AppEditProfile extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final File? selectedImageFile;
  final Function() onPickImage;
  final Function() onTakePhoto;
  final Function() onUpdateProfile;

  const AppEditProfile({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.selectedImageFile,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onUpdateProfile,
  });

  @override
  State<AppEditProfile> createState() => _AppEditProfile();
}

class _AppEditProfile extends State<AppEditProfile> {
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    super.dispose();
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
                widget.onPickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.brown),
              title: Text('Камера'),
              onTap: () {
                Navigator.of(context).pop();
                widget.onTakePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() {
    if (widget.nameController.text.trim().isEmpty) {
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
              selectedImageFile: widget.selectedImageFile,
              onTap: _showImageSourceDialog,
              size: 100,
              cameraIconSize: 32,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: widget.nameController,
              focusNode: _nameFocusNode,
              autofocus: true,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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