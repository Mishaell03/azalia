import 'dart:io';

import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/services/calendar.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class PlantCarePage extends StatefulWidget {
  const PlantCarePage({super.key});

  @override
  State<PlantCarePage> createState() => _PlantCarePageState();
}

enum _CalendarDayStatus { none, planned, overdue, partial, done }

class _PlantCarePageState extends State<PlantCarePage> {
  bool _ready = false;
  bool _loading = true;
  String? _error;
  DateTime _focusMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<PlantCareDateDto> _items = const [];
  List<UserPlantDto> _plants = const [];

  static const careLabels = <String, String>{
    'watering': 'Полив',
    'repotting': 'Пересадка',
    'pruning': 'Подрезание',
    'soil_change': 'Смена грунта',
    'fertilizing': 'Удобрение',
  };

  static const wateringOptions = <int, String>{
    1: 'Раз в день',
    2: 'Раз в 2 дня',
    3: 'Раз в 3 дня',
    4: 'Раз в 4 дня',
    5: 'Раз в 5 дней',
    7: 'Раз в неделю',
    10: 'Раз в 10 дней',
    14: 'Раз в 2 недели',
  };

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

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        CalendarService.getPlantCareDates(),
        CalendarService.getUserPlants(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<PlantCareDateDto>;
        _plants = results[1] as List<UserPlantDto>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить задачи: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Вы точно хотите удалить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              side: const BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Отмена',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text(
              'Удалить',
              style: AppText.medium_14.copyWith(
                color: AppColors.white_transparent,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _wateringLabel(int? days) {
    if (days == null) return 'Не указано';
    return wateringOptions[days] ?? 'Раз в $days дн.';
  }

  Future<void> _showErrorMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showUpgradeDialog(String? message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нужна подписка'),
        content: Text(
          message ??
              'Достигнут лимит по количеству цветов. Расширьте подписку, чтобы добавить ещё.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              side: const BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Позже',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/profile/subscriptions');
            },
            style: TextButton.styleFrom(backgroundColor: AppColors.brown),
            child: Text(
              'Открыть подписки',
              style: AppText.medium_14.copyWith(
                color: AppColors.white_transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddPlantFlow() async {
    try {
      final limits = await CalendarService.getUserPlantLimits();
      if (!limits.canAdd) {
        await _showUpgradeDialog(limits.message);
        return;
      }
      await _openAddPlantDialog();
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        await _showUpgradeDialog(e.message);
        return;
      }
      await _showErrorMessage('Ошибка: ${e.message}');
    } catch (e) {
      await _showErrorMessage('Ошибка: $e');
    }
  }

  _CalendarDayStatus _statusForDay(
    DateTime day,
    List<PlantCareDateDto> dayItems,
  ) {
    if (dayItems.isEmpty) return _CalendarDayStatus.none;

    final doneCount = dayItems.where((e) => e.isDone).length;
    final total = dayItems.length;
    if (doneCount == total) return _CalendarDayStatus.done;

    final today = _dayKey(DateTime.now());
    final isPast = _dayKey(day).isBefore(today);
    if (doneCount == 0) {
      return isPast ? _CalendarDayStatus.overdue : _CalendarDayStatus.planned;
    }
    return _CalendarDayStatus.partial;
  }

  Future<void> _showAddMenu() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey_light,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: AppColors.white_dark,
                leading: const Icon(
                  Icons.water_drop_outlined,
                  color: AppColors.brown,
                ),
                title: Text('Отметить полив', style: AppText.medium_14),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _openMarkWateringDialog();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: AppColors.white_dark,
                leading: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.brown,
                ),
                title: Text('Добавить цветок', style: AppText.medium_14),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _openAddPlantFlow();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMarkWateringDialog() async {
    if (_plants.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте хотя бы один цветок')),
      );
      return;
    }

    int selectedPlantId = _plants.first.id;
    DateTime selectedDate = DateTime.now();
    final notesCtrl = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Отметить полив'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPlantId,
                items: _plants
                    .map(
                      (p) => DropdownMenuItem<int>(
                        value: p.id,
                        child: Text(p.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setLocal(() => selectedPlantId = v);
                },
                decoration: const InputDecoration(labelText: 'Цветок'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('dd.MM.yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setLocal(() => selectedDate = picked);
                  }
                },
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                side: const BorderSide(color: AppColors.brown),
              ),
              child: Text(
                'Отмена',
                style: AppText.medium_14.copyWith(color: AppColors.brown),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(backgroundColor: AppColors.brown),
              child: Text(
                'Сохранить',
                style: AppText.medium_14.copyWith(
                  color: AppColors.white_transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (submit != true) return;

    try {
      await CalendarService.markUserPlantCare(
        id: selectedPlantId,
        careType: 'watering',
        careDate: selectedDate,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      await _load();
    } on ApiException catch (e) {
      await _showErrorMessage('Ошибка: ${e.message}');
    } catch (e) {
      await _showErrorMessage('Ошибка: $e');
    }
  }

  Future<void> _openAddPlantDialog() async {
    final displayNameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    DateTime? lastSoilChanged;
    File? photoFile;
    int selectedWateringDays = 3;

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Добавить цветок'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: displayNameCtrl,
                  decoration: const InputDecoration(labelText: 'Имя цветка'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: selectedWateringDays,
                  items: wateringOptions.entries
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() => selectedWateringDays = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Как часто поливать',
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    lastSoilChanged == null
                        ? 'Последний раз меняли грунт: не указан'
                        : 'Последний раз меняли грунт: ${DateFormat('dd.MM.yyyy').format(lastSoilChanged!)}',
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: lastSoilChanged ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setLocal(() => lastSoilChanged = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked == null) return;
                      setLocal(() => photoFile = File(picked.path));
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.brown),
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      photoFile == null ? 'Прикрепить фото' : 'Фото выбрано',
                    ),
                  ),
                ),
                TextField(
                  controller: notesCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Заметки'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                side: const BorderSide(color: AppColors.brown),
              ),
              child: Text(
                'Отмена',
                style: AppText.medium_14.copyWith(color: AppColors.brown),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(backgroundColor: AppColors.brown),
              child: Text(
                'Добавить',
                style: AppText.medium_14.copyWith(
                  color: AppColors.white_transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (submit != true) return;

    final displayName = displayNameCtrl.text.trim();
    if (displayName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Имя цветка обязательно')));
      return;
    }

    try {
      final created = await CalendarService.createUserPlant(
        plantName: displayName,
        customName: displayName,
        wateringRequirement: _wateringLabel(selectedWateringDays).toLowerCase(),
        wateringFrequencyDays: selectedWateringDays,
        lastSoilChangeAt: lastSoilChanged,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );

      if (photoFile != null) {
        await CalendarService.uploadUserPlantPhoto(
          id: created.id,
          file: photoFile!,
        );
      }

      await _load();
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        await _showUpgradeDialog(e.message);
        return;
      }
      await _showErrorMessage('Ошибка: ${e.message}');
    } catch (e) {
      await _showErrorMessage('Ошибка: $e');
    }
  }

  Future<void> _showPlantDetails(UserPlantDto plant) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey_light,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    ApiConfig.imageUrl(plant.photoUrl),
                    width: 66,
                    height: 66,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 66,
                      height: 66,
                      color: AppColors.white_dark,
                      child: const Icon(
                        Icons.local_florist_outlined,
                        color: AppColors.brown,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(plant.displayName, style: AppText.bold_18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(
              'Требование к поливу',
              _wateringLabel(plant.wateringFrequencyDays),
            ),
            _infoRow(
              'Последний раз меняли грунт',
              plant.lastSoilChangeAt == null
                  ? 'Не указано'
                  : DateFormat('dd.MM.yyyy').format(plant.lastSoilChangeAt!),
            ),
            _infoRow(
              'Следующий полив',
              plant.nextWateringAt == null
                  ? 'Не рассчитан'
                  : DateFormat('dd.MM.yyyy').format(plant.nextWateringAt!),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brown,
                    ),
                    onPressed: () async {
                      try {
                        Navigator.of(ctx).pop();
                        await CalendarService.markUserPlantCare(
                          id: plant.id,
                          careType: 'watering',
                          careDate: DateTime.now(),
                        );
                        await _load();
                      } on ApiException catch (e) {
                        await _showErrorMessage('Ошибка: ${e.message}');
                      } catch (e) {
                        await _showErrorMessage('Ошибка: $e');
                      }
                    },
                    icon: const Icon(
                      Icons.water_drop_outlined,
                      color: AppColors.white,
                    ),
                    label: Text(
                      'Отметить полив',
                      style: AppText.medium_12.copyWith(color: AppColors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        Navigator.of(ctx).pop();
                        await CalendarService.updateUserPlant(
                          id: plant.id,
                          wateringRequirement: 'не знаю',
                        );
                        await _load();
                      } on ApiException catch (e) {
                        await _showErrorMessage('Ошибка: ${e.message}');
                      } catch (e) {
                        await _showErrorMessage('Ошибка: $e');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.brown),
                    ),
                    child: const Text('Не знаю'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  try {
                    final navigator = Navigator.of(ctx);
                    final ok = await _confirmDelete();
                    if (!ok) return;
                    await CalendarService.deleteUserPlant(plant.id);
                    if (!mounted) return;
                    navigator.pop();
                    await _load();
                  } on ApiException catch (e) {
                    await _showErrorMessage('Ошибка: ${e.message}');
                  } catch (e) {
                    await _showErrorMessage('Ошибка: $e');
                  }
                },
                style: TextButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.error
                  )
                ),
                child: Text(
                  'Удалить цветок',
                  style: AppText.medium_12.copyWith(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white_dark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey_light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.medium_12.copyWith(color: AppColors.grey)),
          const SizedBox(height: 2),
          Text(value, style: AppText.medium_14),
        ],
      ),
    );
  }

  Future<void> _showDayTasks(
    DateTime day,
    List<PlantCareDateDto> dayItems,
  ) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMMM yyyy', 'ru').format(day),
              style: AppText.bold_18,
            ),
            const SizedBox(height: 8),
            if (dayItems.isEmpty)
              Text(
                'На этот день задач нет',
                style: AppText.medium_14.copyWith(color: AppColors.grey),
              ),
            ...dayItems.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ApiConfig.imageUrl(e.plantPhotoUrl),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 36,
                      height: 36,
                      color: AppColors.white_dark,
                      child: const Icon(Icons.local_florist_outlined, size: 18),
                    ),
                  ),
                ),
                title: Text(
                  '${e.plantName} • ${careLabels[e.careType] ?? e.careType}',
                ),
                subtitle: Text(
                  (e.comment ?? '').isEmpty ? 'Без комментария' : e.comment!,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        e.isDone
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        await CalendarService.updatePlantCareDate(
                          id: e.id,
                          isDone: true,
                        );
                        if (!mounted) return;
                        nav.pop();
                        await _load();
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        final ok = await _confirmDelete();
                        if (!ok) return;
                        await CalendarService.deletePlantCareDate(e.id);
                        if (!mounted) return;
                        nav.pop();
                        await _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.brown),
                ),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayBackground(_CalendarDayStatus status) {
    switch (status) {
      case _CalendarDayStatus.none:
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.white_dark, width: 1.2),
          ),
        );
      case _CalendarDayStatus.planned:
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.brown, width: 1.8),
          ),
        );
      case _CalendarDayStatus.overdue:
        return Container(
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error, width: 1.8),
          ),
        );
      case _CalendarDayStatus.done:
        return Container(
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success, width: 1.8),
          ),
        );
      case _CalendarDayStatus.partial:
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error, width: 1.8),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                heightFactor: 0.56,
                alignment: Alignment.topCenter,
                child: Container(
                  color: AppColors.error.withValues(alpha: 0.22),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 14,
                child: ClipPath(
                  clipper: _BottomWaveClipper(),
                  child: Container(
                    color: AppColors.success.withValues(alpha: 0.26),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _calendar() {
    final first = DateTime(_focusMonth.year, _focusMonth.month, 1);
    final offset = (first.weekday + 6) % 7;
    final start = first.subtract(Duration(days: offset));
    final days = List.generate(42, (i) => start.add(Duration(days: i)));
    final itemsByDay = <DateTime, List<PlantCareDateDto>>{};
    for (final item in _items) {
      itemsByDay.putIfAbsent(_dayKey(item.careDate), () => []).add(item);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grey_light),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _focusMonth = DateTime(
                    _focusMonth.year,
                    _focusMonth.month - 1,
                    1,
                  ),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('LLLL yyyy', 'ru').format(_focusMonth),
                    style: AppText.medium_16,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _focusMonth = DateTime(
                    _focusMonth.year,
                    _focusMonth.month + 1,
                    1,
                  ),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: const [
              'Пн',
              'Вт',
              'Ср',
              'Чт',
              'Пт',
              'Сб',
              'Вс',
            ].map((d) => Expanded(child: Center(child: Text(d)))).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            itemCount: 42,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, i) {
              final day = days[i];
              final dayItems =
                  itemsByDay[_dayKey(day)] ?? const <PlantCareDateDto>[];
              final status = _statusForDay(day, dayItems);
              final markedCount = dayItems.length;
              return GestureDetector(
                onTap: () async => _showDayTasks(day, dayItems),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: _dayBackground(status)),
                      Center(
                        child: Text(
                          '${day.day}',
                          style: AppText.medium_14.copyWith(
                            color: day.month == _focusMonth.month
                                ? AppColors.black
                                : AppColors.grey_light,
                          ),
                        ),
                      ),
                      if (markedCount > 1)
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brown,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$markedCount',
                              style: AppText.medium_8.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _plantsCards() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grey_light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ваши растения', style: AppText.bold_18),
          const SizedBox(height: 10),
          if (_plants.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.white_dark,
              ),
              child: Text(
                'Пока нет добавленных растений',
                style: AppText.medium_14.copyWith(color: AppColors.grey),
              ),
            )
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _plants.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final p = _plants[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showPlantDetails(p),
                    child: Container(
                      width: 216,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.white_dark,
                        border: Border.all(color: AppColors.grey_light),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                ApiConfig.imageUrl(p.photoUrl),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppColors.white,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.local_florist_outlined,
                                        color: AppColors.brown,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.medium_14,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Полив: ${_wateringLabel(p.wateringFrequencyDays)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.medium_12.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        title: Text('Уход за растениями', style: AppText.bold_20),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        backgroundColor: AppColors.brown,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: Text(
          'Добавить',
          style: AppText.medium_14.copyWith(color: AppColors.white),
        ),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: AppText.medium_14.copyWith(color: AppColors.error),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
                children: [
                  _calendar(),
                  const SizedBox(height: 12),
                  _plantsCards(),
                ],
              ),
            ),
    );
  }
}

class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..moveTo(0, size.height);
    p.lineTo(0, size.height * 0.35);
    p.quadraticBezierTo(
      size.width * 0.2,
      0,
      size.width * 0.4,
      size.height * 0.35,
    );
    p.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.7,
      size.width * 0.8,
      size.height * 0.35,
    );
    p.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.15,
      size.width,
      size.height * 0.35,
    );
    p.lineTo(size.width, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
