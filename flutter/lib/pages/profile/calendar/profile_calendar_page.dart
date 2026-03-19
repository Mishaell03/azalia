import 'package:azalia/backend/services/calendar.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class ProfileCalendarPage extends StatefulWidget {
  const ProfileCalendarPage({super.key});

  @override
  State<ProfileCalendarPage> createState() => _ProfileCalendarPageState();
}

class _ProfileCalendarPageState extends State<ProfileCalendarPage> {
  bool _loading = true;
  String? _error;
  List<OrganizationDto> _organizations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orgs = await CalendarService.getOrganizations();
      if (!mounted) return;
      setState(() {
        _organizations = orgs.items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить разделы календаря: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _card({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.grey_light),
          gradient: LinearGradient(
            colors: [AppColors.white, AppColors.brown.withValues(alpha: 0.12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grey_light),
              ),
              child: Icon(icon, color: AppColors.brown),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.bold_18.copyWith(color: AppColors.black)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppText.medium_12.copyWith(color: AppColors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 260.ms).slideX(begin: 0.08, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        title: Text('Календарь событий', style: AppText.bold_20),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!, style: AppText.medium_14.copyWith(color: AppColors.error)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _card(
                        title: 'Памятные даты и праздники',
                        subtitle: 'Ежегодные важные даты и комментарии',
                        icon: Icons.celebration_outlined,
                        onTap: () => context.push('/profile/calendar/important'),
                      ),
                      const SizedBox(height: 12),
                      _card(
                        title: 'Уход за растениями',
                        subtitle: 'Полив, пересадка, подрезание, удобрение',
                        icon: Icons.local_florist_outlined,
                        onTap: () => context.push('/profile/calendar/care'),
                      ),
                      if (_organizations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _card(
                          title: 'Корпоративный календарь',
                          subtitle: _organizations.length > 1
                              ? 'Основной + дополнительный ниже'
                              : 'Доступ для вашей организации',
                          icon: Icons.groups_2_outlined,
                          onTap: () => context.push('/profile/calendar/corporate'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
