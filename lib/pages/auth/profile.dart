import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:azalia/backend/models/auth.dart';
import 'package:azalia/components/widgets/footer.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    
    String cleaned = text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length > 11) {
      cleaned = cleaned.substring(0, 11);
    }
    
    String formatted = '';
    if (cleaned.isNotEmpty) {
      formatted = '+7';
      if (cleaned.length > 1) formatted += ' (${cleaned.substring(1, cleaned.length > 4 ? 4 : cleaned.length)}';
      if (cleaned.length > 4) formatted += ') ${cleaned.substring(4, cleaned.length > 7 ? 7 : cleaned.length)}';
      if (cleaned.length > 7) formatted += '-${cleaned.substring(7, cleaned.length > 9 ? 9 : cleaned.length)}';
      if (cleaned.length > 9) formatted += '-${cleaned.substring(9)}';
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

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
  final ImagePicker _imagePicker = ImagePicker();
  
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
      _nameController.text = user.name;
      _phoneController.text = _formatPhoneNumber(user.phone);
    }
  }

  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return '';
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length > 11) cleaned = cleaned.substring(0, 11);
    
    String formatted = '';
    if (cleaned.isNotEmpty) {
      formatted = '+7';
      if (cleaned.length > 1) formatted += ' (${cleaned.substring(1, cleaned.length > 4 ? 4 : cleaned.length)}';
      if (cleaned.length > 4) formatted += ') ${cleaned.substring(4, cleaned.length > 7 ? 7 : cleaned.length)}';
      if (cleaned.length > 7) formatted += '-${cleaned.substring(7, cleaned.length > 9 ? 9 : cleaned.length)}';
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
          _selectedImageFile = File(image.path);
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
          _selectedImageFile = File(image.path);
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

  void _showEditProfileDialog() {
    final FocusNode nameFocusNode = FocusNode();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameFocusNode.requestFocus();
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              'Редактировать профиль',
              style: AppText.bold_18.copyWith(color: AppColors.black),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.brown.withOpacity(0.1),
                            image: _selectedImageFile != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _selectedImageFile == null
                              ? Icon(Icons.person, size: 40, color: AppColors.brown)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.brown,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera_alt, size: 16, color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    focusNode: nameFocusNode,
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
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneNumberFormatter()],
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
                onPressed: () {
                  if (_nameController.text.trim().isEmpty) {
                    _showErrorDialog('Пожалуйста, введите имя');
                    return;
                  }
                  
                  String phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
                  if (phoneDigits.length != 11) {
                    _showErrorDialog('Пожалуйста, введите корректный номер телефона');
                    return;
                  }
                  
                  Navigator.of(context).pop();
                  _updateUserProfile();
                },
                child: Text(
                  'Сохранить',
                  style: AppText.medium_16.copyWith(color: AppColors.brown),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      nameFocusNode.dispose();
    });
  }

  Future<void> _updateUserProfile() async {
    try {
      // отправка данных
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
      
    } catch (e) {
      _showErrorDialog('Не удалось обновить данные');
    }
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
    final user = _sessionService.currentUser;
    final isEmployee = _sessionService.isEmployee;
    final position = _sessionService.currentPosition;

    return Scaffold(
      body: user == null
          ? _buildNotLoggedIn()
          : _buildProfileWithCollapsingHeader(user, isEmployee, position),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Widget _buildProfileWithCollapsingHeader(User user, bool isEmployee, Position? position) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: IconButton(
              onPressed: () {
                context.goNamed('home');
              },
              icon: SvgPicture.asset('assets/icons/Back.svg'),
            ),
          ),
          leadingWidth: 80,
          title: _showExpandedHeader
              ? null
              : Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brown.withOpacity(0.1),
                        image: _selectedImageFile != null
                            ? DecorationImage(
                                image: FileImage(_selectedImageFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImageFile == null
                          ? Icon(Icons.person, size: 16, color: AppColors.brown)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text,
                            style: AppText.bold_20.copyWith(color: AppColors.black),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isEmployee && position != null)
                            Text(
                              position.title,
                              style: AppText.medium_12.copyWith(color: AppColors.brown),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
          backgroundColor: AppColors.white,
          elevation: _showExpandedHeader ? 0 : 1,
          shadowColor: AppColors.grey_light.withOpacity(0.3),
          pinned: true,
          expandedHeight: 220.0,
          actions: [
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.brown),
              onPressed: _showEditProfileDialog,
            ),
            const SizedBox(width: 16),
          ],
          flexibleSpace: _showExpandedHeader
              ? FlexibleSpaceBar(
                  background: Container(
                    color: AppColors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.brown.withOpacity(0.1),
                                  image: _selectedImageFile != null
                                      ? DecorationImage(
                                          image: FileImage(_selectedImageFile!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _selectedImageFile == null
                                    ? Icon(Icons.person, size: 40, color: AppColors.brown)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.brown,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.camera_alt, size: 12, color: AppColors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _nameController.text,
                          style: AppText.bold_23.copyWith(color: AppColors.black),
                        ),
                        const SizedBox(height: 8),
                        if (isEmployee && position != null)
                          Text(
                            position.title,
                            style: AppText.medium_16.copyWith(color: AppColors.brown),
                          ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                )
              : null,
        ),
        SliverToBoxAdapter(
          child: _buildProfileContent(user, isEmployee, position),
        ),
      ],
    );
  }

  Widget _buildProfileContent(User user, bool isEmployee, Position? position) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildInfoRow('Имя', _nameController.text),
                  const SizedBox(height: 16),
                  _buildInfoRow('Телефон', _phoneController.text),
                  const SizedBox(height: 16),
                  _buildInfoRow('Telegram ID', user.telegramId?.toString() ?? 'Не указан'),
                  const SizedBox(height: 16),
                  _buildInfoRow('Статус', isEmployee ? 'Сотрудник' : 'Клиент'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          if (isEmployee) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Информация сотрудника',
                      style: AppText.bold_18.copyWith(color: AppColors.black),
                    ),
                    const SizedBox(height: 16),
                    if (position != null)
                      _buildInfoRow('Должность', position.title),
                    const SizedBox(height: 16),
                    _buildInfoRow('ID сотрудника', user.id.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  icon: Icons.settings,
                  title: 'Настройки',
                  onTap: () => _showSettings(context),
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.help,
                  title: 'Помощь',
                  onTap: () => _showHelp(context),
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.info,
                  title: 'О приложении',
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          Center(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Выйти',
                  style: AppText.medium_16.copyWith(color: AppColors.error),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.medium_16.copyWith(color: AppColors.grey)),
        Text(value, style: AppText.medium_16.copyWith(color: AppColors.black)),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.brown),
      title: Text(
        title,
        style: AppText.medium_16.copyWith(color: AppColors.black),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppColors.grey_light),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: AppColors.grey),
          const SizedBox(height: 20),
          Text(
            'Вы не авторизованы',
            style: AppText.medium_18.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              onPressed: () => context.go('/auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brown,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Войти',
                style: AppText.medium_16.copyWith(color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
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
                'Телефон поддержки: +7 (800) 555-35-35',
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
      builder: (context) => AlertDialog(
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
}