import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:azalia/backend/services/device_id.dart';
import 'package:azalia/backend/services/auth.dart';
import 'package:azalia/backend/models/auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String _errorText = '';
  bool _allFieldsFilled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupControllerListeners();
  }

  void _setupControllerListeners() {
    for (final controller in _controllers) {
      controller.addListener(_updateButtonState);
    }
  }

  void _updateButtonState() {
    final allFilled = _controllers.every(
      (controller) => controller.text.isNotEmpty,
    );
    if (allFilled != _allFieldsFilled) {
      setState(() {
        _allFieldsFilled = allFilled;
      });
    }
  }

  void _onDigitChanged(String value, int index) {
    if (value.isNotEmpty && !RegExp(r'^\d$').hasMatch(value)) {
      _controllers[index].clear();
      return;
    }

    if (_errorText.isNotEmpty) {
      setState(() {
        _errorText = '';
      });
    }

    if (value.isNotEmpty && index < 3) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }

    if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }

    _updateButtonState();
  }

  bool _isAllFieldsFilled() {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  String _getEnteredCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyCode() async {
    if (_isLoading) return;

    final code = _getEnteredCode();

    if (!AuthService.validateCodeFormat(code)) {
      setState(() {
        _errorText = 'Код должен состоять из 4 цифр';
      });
      _clearAllFields();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      final authResponse = await AuthService.verifyCode(code);

      if (authResponse.success) {
        _showSuccessDialog(authResponse);
      } else {
        setState(() {
          _errorText = authResponse.message;
        });
        _clearAllFields();
      }
    } on AuthException catch (e) {
      setState(() {
        debugPrint(e.toString());
        _errorText = e.message;
      });
      _clearAllFields();
    } catch (e) {
      setState(() {
        debugPrint('Unexpected error: $e');
        _errorText = 'Неизвестная ошибка';
      });
      _clearAllFields();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearAllFields() {
    for (final controller in _controllers) {
      controller.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes[0]);
    setState(() {
      _allFieldsFilled = false;
    });
  }

  void _showSuccessDialog(AuthResponse authResponse) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Успешно!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Добро пожаловать, ${authResponse.user.name}!'),
            if (authResponse.isEmployee) ...[
              const SizedBox(height: 8),
              Text('Должность: ${authResponse.position?.title ?? 'Сотрудник'}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.goNamed('profile');
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTelegram() async {
    try {
      final success = await DeviceService.launchTelegram();

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Telegram')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при открытии Telegram')),
        );
      }
    }
  }

  void _handleFieldSubmit(int index) {
    if (index < 3 && _controllers[index].text.isNotEmpty) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (index == 3 && _isAllFieldsFilled()) {
      _verifyCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/auth.jpg',
              height: screenHeight,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              onPressed: () {
                context.goNamed('home');
              },
              icon: SvgPicture.asset('assets/icons/Back.svg'),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.7,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white_transparent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25),

                    Text(
                      'Вход через Telegram',
                      style: AppText.bold_23.copyWith(color: AppColors.black),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Для авторизации получите код в нашем Telegram боте',
                      style: AppText.medium_16.copyWith(color: AppColors.grey),
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _openTelegram,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.brown, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppColors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.telegram,
                              color: AppColors.brown,
                              size: 30,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Открыть Telegram',
                              style: AppText.medium_20.copyWith(
                                color: AppColors.brown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.grey_light,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'введите полученый код',
                            style: AppText.medium_16.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.grey_light,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (index) {
                        return SizedBox(
                          width: 64,
                          height: 64,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: AppText.medium_24,
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _errorText.isNotEmpty
                                      ? AppColors.error
                                      : AppColors.grey_light,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.brown,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.error,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) => _onDigitChanged(value, index),
                            onSubmitted: (_) => _handleFieldSubmit(index),
                          ),
                        );
                      }),
                    ),

                    if (_errorText.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorText,
                        style: AppText.medium_14.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _allFieldsFilled && !_isLoading
                            ? _verifyCode
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brown,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Подтвердить',
                                style: AppText.medium_20.copyWith(
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_updateButtonState);
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}
