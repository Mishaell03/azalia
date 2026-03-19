import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/backend/models/auth.dart';
import 'package:azalia/pages/profile/widgets/info.dart';
import 'package:azalia/pages/profile/widgets/setting.dart';
import 'package:go_router/go_router.dart';

class AppProfileContent extends StatelessWidget {
  final User user;
  final bool isEmployee;
  final Position? position;
  final String formattedName;
  final String formattedPhone;
  final VoidCallback onLogout;
  final VoidCallback onSettings;
  final VoidCallback onOrderHistory;
  final VoidCallback onSubscriptions;
  final VoidCallback onEventCalendar;
  final VoidCallback onHelp;
  final VoidCallback onAbout;

  const AppProfileContent({
    super.key,
    required this.user,
    required this.isEmployee,
    required this.position,
    required this.formattedName,
    required this.formattedPhone,
    required this.onLogout,
    required this.onSettings,
    required this.onOrderHistory,
    required this.onSubscriptions,
    required this.onEventCalendar,
    required this.onHelp,
    required this.onAbout,
  });

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppColors.grey_light),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  AppProfileInfo(
                    label: 'Имя',
                    value: formattedName.length > 15
                        ? '${formattedName.substring(0, 15)}...'
                        : formattedName,
                  ),
                  const SizedBox(height: 16),
                  AppProfileInfo(label: 'Телефон', value: formattedPhone),
                  const SizedBox(height: 16),
                  AppProfileInfo(
                    label: 'Telegram ID',
                    value: user.telegramId.toString(),
                  ),
                  const SizedBox(height: 16),
                  AppProfileInfo(
                    label: 'Статус',
                    value: isEmployee ? 'Сотрудник' : 'Клиент',
                  ),
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
                      AppProfileInfo(
                        label: 'Должность',
                        value: position!.title,
                      ),
                    const SizedBox(height: 16),
                    AppProfileInfo(
                      label: 'ID сотрудника',
                      value: user.id.toString(),
                    ),
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
                if (isEmployee) ...[
                  AppProfileSetting(
                    icon: Icons.admin_panel_settings,
                    title: 'Админ-панель',
                    onTap: (){
                      context.go('/admin');
                    },
                  ),
                  _buildDivider(),
                ],
                AppProfileSetting(
                  icon: Icons.history_rounded,
                  title: 'История заказов',
                  onTap: onOrderHistory,
                ),
                _buildDivider(),
                AppProfileSetting(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Подписки',
                  onTap: onSubscriptions,
                ),
                _buildDivider(),
                AppProfileSetting(
                  icon: Icons.event_note_outlined,
                  title: 'Календарь событий',
                  onTap: onEventCalendar,
                ),
                _buildDivider(),
                AppProfileSetting(
                  icon: Icons.settings,
                  title: 'Настройки',
                  onTap: onSettings,
                ),
                _buildDivider(),
                AppProfileSetting(
                  icon: Icons.help,
                  title: 'Помощь',
                  onTap: onHelp,
                ),
                _buildDivider(),
                AppProfileSetting(
                  icon: Icons.info,
                  title: 'О приложении',
                  onTap: onAbout,
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
                onPressed: onLogout,
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
}
