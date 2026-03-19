import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/services/calendar.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class CorporateCalendarPage extends StatefulWidget {
  const CorporateCalendarPage({super.key});

  @override
  State<CorporateCalendarPage> createState() => _CorporateCalendarPageState();
}

class _CorporateCalendarPageState extends State<CorporateCalendarPage> {
  bool _ready = false;
  bool _loading = true;
  String? _error;
  bool _canUseCorporate = false;
  List<OrganizationDto> _organizations = const [];
  Map<int, List<CompanyCalendarEventDto>> _eventsByOrg = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await initializeDateFormatting('ru');
    if (!mounted) return;
    setState(() => _ready = true);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orgs = await CalendarService.getOrganizations();
      final map = <int, List<CompanyCalendarEventDto>>{};
      for (final org in orgs.items) {
        map[org.companyId] = await CalendarService.getCompanyEvents(org.companyId);
      }
      if (!mounted) return;
      setState(() {
        _canUseCorporate = orgs.canUseCorporate;
        _organizations = orgs.items;
        _eventsByOrg = map;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить корпоративный календарь: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showUpgrade(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Недоступно', style: AppText.bold_18.copyWith(color: AppColors.error)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/profile/subscriptions');
            },
            child: Text('Подписки', style: AppText.medium_14.copyWith(color: AppColors.brown)),
          ),
        ],
      ),
    );
  }

  Future<void> _addEvent(OrganizationDto org) async {
    final titleCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    DateTime date = DateTime.now();
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Событие: ${org.companyName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 8),
                TextField(controller: commentCtrl, decoration: const InputDecoration(labelText: 'Комментарий')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('dd.MM.yyyy').format(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setLocal(() => date = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      await CalendarService.createCompanyEvent(
        companyId: org.companyId,
        title: titleCtrl.text.trim(),
        date: date,
        comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
      );
      await _load();
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        await _showUpgrade(e.message);
        return;
      }
      rethrow;
    }
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Вы точно хотите удалить эту дату?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Удалить')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _editEvent(OrganizationDto org, CompanyCalendarEventDto event) async {
    final titleCtrl = TextEditingController(text: event.title);
    final commentCtrl = TextEditingController(text: event.comment ?? '');
    DateTime date = event.eventDate;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Редактировать: ${org.companyName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 8),
                TextField(controller: commentCtrl, decoration: const InputDecoration(labelText: 'Комментарий')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('dd.MM.yyyy').format(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setLocal(() => date = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (save != true) return;
    await CalendarService.updateCompanyEvent(
      id: event.id,
      title: titleCtrl.text.trim(),
      date: date,
      comment: commentCtrl.text.trim(),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        title: Text('Корпоративный календарь', style: AppText.bold_20),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: AppText.medium_14.copyWith(color: AppColors.error)))
                  : _organizations.isEmpty
                      ? Center(child: Text('Вы не состоите в организациях', style: AppText.medium_14))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (!_canUseCorporate)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.error.withValues(alpha: 0.08),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  'Добавление событий доступно только на расширенной подписке.',
                                  style: AppText.medium_12.copyWith(color: AppColors.error),
                                ),
                              ),
                            for (int i = 0; i < _organizations.length; i++) ...[
                              if (i > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Дополнительный: ${_organizations[i].companyName}',
                                    style: AppText.medium_14.copyWith(color: AppColors.grey),
                                  ),
                                ),
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.grey_light),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(_organizations[i].companyName, style: AppText.bold_18),
                                        ),
                                        IconButton(
                                          onPressed: _canUseCorporate ? () => _addEvent(_organizations[i]) : null,
                                          icon: const Icon(Icons.add_circle_outline, color: AppColors.brown),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ...(_eventsByOrg[_organizations[i].companyId] ?? const [])
                                        .map((e) => ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(e.title),
                                              subtitle: Text(
                                                '${DateFormat('dd.MM.yyyy').format(e.eventDate)} • ${(e.comment ?? '').isEmpty ? 'Без комментария' : e.comment!}',
                                              ),
                                              trailing: _canUseCorporate
                                                  ? Wrap(
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.edit_outlined, color: AppColors.brown),
                                                          onPressed: () => _editEvent(_organizations[i], e),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                                          onPressed: () async {
                                                            final ok = await _confirmDelete();
                                                            if (!ok) return;
                                                            await CalendarService.deleteCompanyEvent(e.id);
                                                            await _load();
                                                          },
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                            )),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
    );
  }
}
