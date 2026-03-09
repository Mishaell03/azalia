import 'dart:io';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:azalia/backend/models/auth.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/backend/services/profile.dart';
import 'package:azalia/backend/services/auth.dart';
import 'package:azalia/pages/profile/widgets/edit_profile.dart';
import 'package:azalia/pages/profile/widgets/content.dart';
import 'package:azalia/pages/profile/widgets/header.dart';
import 'package:azalia/components/widgets/logged.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SessionService _sessionService = SessionService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _showExpandedHeader = true;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initializeUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeUserData() {
    final user = _sessionService.currentUser;
    if (user != null) {
      _nameController.text = user.name.length > 15
          ? user.name.substring(0, 15)
          : user.name;
      _phoneController.text = _formatPhoneNumber(user.phone);
    }
  }

  Future<void> _refreshProfile() async {
    try {
      // тянем актуальную роль с сервера
      await AuthService.fetchMe();
      await _sessionService.initialize();
      _initializeUserData();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Не удалось обновить профиль');
      }
    }
  }

  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return '';
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length > 11) cleaned = cleaned.substring(0, 11);

    String formatted = '';
    if (cleaned.isNotEmpty) {
      formatted = '+7';
      if (cleaned.length > 1)
        formatted +=
        ' (${cleaned.substring(1, cleaned.length > 4 ? 4 : cleaned.length)}';
      if (cleaned.length > 4)
        formatted +=
        ') ${cleaned.substring(4, cleaned.length > 7 ? 7 : cleaned.length)}';
      if (cleaned.length > 7)
        formatted +=
        '-${cleaned.substring(7, cleaned.length > 9 ? 9 : cleaned.length)}';
      if (cleaned.length > 9) formatted += '-${cleaned.substring(9)}';
    }
    return formatted;
  }

  void _scrollListener() {
    final double scrollOffset = _scrollController.offset;
    final bool shouldShowExpanded = scrollOffset < 100;

    if (_showExpandedHeader != shouldShowExpanded) {
      setState(() {
        _showExpandedHeader = shouldShowExpanded;
      });
    }
  }


  void _showEditProfileDialog() {
    final user = _sessionService.currentUser;
    showDialog(
      context: context,
      builder: (context) =>
          AppEditProfile(
            nameController: _nameController,
            phoneController: _phoneController,
            selectedImageFile: _selectedImageFile,
            avatarBase64: user?.avatar,
            onUpdateProfile: _updateUserProfile,
            onImageUpdated: (File? newImage) {
              setState(() {
                _selectedImageFile = newImage;
              });
            },
          ),
    );
  }

  Future<void> _updateUserProfile() async {
    try {
      final token = await _sessionService.getToken();

      // Загружаем аватарку, если она выбрана
      String? newAvatarBase64;
      if (_selectedImageFile != null) {
        try {
          final avatarResponse = await ProfileService.uploadAvatar(
              _selectedImageFile!);
          if (avatarResponse.success && avatarResponse.avatar != null) {
            newAvatarBase64 = avatarResponse.avatar;
          }
        } catch (e) {
          _showErrorDialog('Не удалось загрузить аватарку');
          return;
        }
      }

      // Обновляем профиль
      final response = await ProfileService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (response.success) {
        // Обновляем пользователя с новой аватаркой
        final updatedUser = User(
          id: response.user.id,
          telegramId: response.user.telegramId,
          name: response.user.name,
          phone: response.user.phone,
          sessionToken: response.user.sessionToken,
          avatar: newAvatarBase64 ?? response.user.avatar,
        );

        await _sessionService.saveSession(
          user: updatedUser,
          token: token ?? response.user.sessionToken ?? '',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          isEmployee: _sessionService.isEmployee,
          position: _sessionService.currentPosition,
          avatar: newAvatarBase64 ?? updatedUser.avatar,
        );

        _nameController.text = updatedUser.name;
        _phoneController.text = _formatPhoneNumber(updatedUser.phone);

        // Очищаем выбранный файл после успешной загрузки
        _selectedImageFile = null;

        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: Text(
                  'Успешно',
                  style: AppText.bold_18.copyWith(color: AppColors.black),
                ),
                content: Text(
                  'Данные профиля обновлены',
                  style: AppText.medium_16.copyWith(color: AppColors.grey),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {});
                    },
                    child: Text(
                      'OK',
                      style: AppText.medium_16.copyWith(color: AppColors.brown),
                    ),
                  ),
                ],
              ),
        );
      } else {
        _showErrorDialog('Не удалось обновить профиль');
      }
    } on ProfileException {
      _showErrorDialog('Не удалось обновить профиль');
    } catch (_) {
      _showErrorDialog('Не удалось обновить данные');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
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

  void _logout() async {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
              'Выход',
              style: AppText.bold_18.copyWith(color: AppColors.black),
            ),
            content: Text(
              'Вы уверены, что хотите выйти?',
              style: AppText.medium_16.copyWith(color: AppColors.grey),
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
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _sessionService.clearSession();
                  if (mounted) {
                    context.go('/auth');
                  }
                },
                child: Text(
                  'Выйти',
                  style: AppText.medium_16.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
              'Настройки',
              style: AppText.bold_18.copyWith(color: AppColors.black),
            ),
            content: Text(
              'Раздел настроек в разработке',
              style: AppText.medium_16.copyWith(color: AppColors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Закрыть',
                  style: AppText.medium_16.copyWith(color: AppColors.brown),
                ),
              ),
            ],
          ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
              'Помощь',
              style: AppText.bold_18.copyWith(color: AppColors.black),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Если у вас возникли проблемы:',
                    style: AppText.medium_16.copyWith(color: AppColors.grey),
                  ),
                  const SizedBox(height: 10),
                  _buildHelpItem('• Проверьте подключение к интернету'),
                  _buildHelpItem('• Перезапустите приложение'),
                  _buildHelpItem('• Обратитесь в службу поддержки'),
                  const SizedBox(height: 20),
                  Text(
                    'Телефон поддержки:\n +7 (800) 555-35-35',
                    style: AppText.medium_16.copyWith(color: AppColors.brown),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Закрыть',
                  style: AppText.medium_16.copyWith(color: AppColors.brown),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildHelpItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: AppText.medium_16.copyWith(color: AppColors.grey),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
              'О приложении',
              style: AppText.bold_18.copyWith(color: AppColors.black),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Azalia Flower Shop App',
                    style: AppText.bold_15.copyWith(color: AppColors.brown),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Версия 1.0.0',
                    style: AppText.medium_14.copyWith(color: AppColors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Приложение для заказа комнатных растений.',
                    style: AppText.medium_14.copyWith(color: AppColors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Закрыть',
                  style: AppText.medium_16.copyWith(color: AppColors.brown),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _sessionService.currentUser;
    final isEmployee = _sessionService.isEmployee;
    final position = _sessionService.currentPosition;

    return Scaffold(
      body: user == null
          ? const AppProfileLoggeg()
          : _buildProfileWithCollapsingHeader(user, isEmployee, position),
      bottomNavigationBar: const AppFooter(items: userFooterItems),
    );
  }

  Widget _buildProfileWithCollapsingHeader(User user,
      bool isEmployee,
      Position? position,) {
    return RefreshIndicator(
      onRefresh: _refreshProfile,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          AppProfileHeader(
            showExpandedHeader: _showExpandedHeader,
            userName: _nameController.text,
            positionTitle: position?.title,
            isEmployee: isEmployee,
            selectedImageFile: _selectedImageFile,
            avatarBase64: user.avatar,
            onEditPressed: _showEditProfileDialog,
            onImageTap: () {},
          ),
          SliverToBoxAdapter(
            child: AppProfileContent(
              user: user,
              isEmployee: isEmployee,
              position: position,
              formattedName: _nameController.text,
              formattedPhone: _phoneController.text,
              onLogout: _logout,
              onSettings: () => _showSettings(context),
              onHelp: () => _showHelp(context),
              onAbout: () => _showAbout(context),
            ),
          ),
        ],
      ),
    );
  }
}
