import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/services/calendar.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class ImportantDatesPage extends StatefulWidget {
  const ImportantDatesPage({super.key});

  @override
  State<ImportantDatesPage> createState() => _ImportantDatesPageState();
}

class _ImportantDatesPageState extends State<ImportantDatesPage> {
  bool _ready = false;
  bool _loading = true;
  String? _error;
  DateTime _focusMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<ImportantDateDto> _items = const [];
  Map<int, List<ImportantDatePreferenceDto>> _prefsByDateId = const {};
  HolidayPreferenceOptionsResponse _options = HolidayPreferenceOptionsResponse(
    categories: const [],
    products: const [],
  );

  static const Map<String, (int month, int day, String title)> _fixedHolidays =
      {'new_year': (1, 1, 'Новый год'), 'march_8': (3, 8, '8 марта')};

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
      final items = await CalendarService.getImportantDates();
      final options = await CalendarService.getImportantDatePreferenceOptions();
      final prefsByDate = <int, List<ImportantDatePreferenceDto>>{};
      for (final item in items) {
        prefsByDate[item.id] =
            await CalendarService.getImportantDatePreferences(item.id);
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _prefsByDateId = prefsByDate;
        _options = options;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить даты: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  String _yearsWord(int years) {
    final mod10 = years % 10;
    final mod100 = years % 100;
    if (mod10 == 1 && mod100 != 11) return 'год';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'года';
    return 'лет';
  }

  String _yearsSinceText(ImportantDateDto event, DateTime selectedDay) {
    final years = (selectedDay.year - event.eventDate.year).clamp(0, 10000);
    return '$years ${_yearsWord(years)} с ${event.eventDate.year} года';
  }

  List<ImportantDateDto> _eventsForSelectedDay(DateTime day) {
    return _items.where((e) {
      final src = e.eventDate;
      if (day.year < src.year) return false;
      return day.month == src.month && day.day == src.day;
    }).toList();
  }

  Map<DateTime, int> _markersCountForMonth() {
    final map = <DateTime, int>{};
    for (final h in _fixedHolidays.values) {
      final key = DateTime(_focusMonth.year, h.$1, h.$2);
      map[key] = (map[key] ?? 0) + 1;
    }
    for (final e in _items) {
      if (_focusMonth.year >= e.eventDate.year) {
        final key = DateTime(
          _focusMonth.year,
          e.eventDate.month,
          e.eventDate.day,
        );
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Вы точно хотите удалить эту дату?'),
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

  Future<void> _addDatePreference(ImportantDateDto dateItem) async {
    String mode = 'category';
    String query = '';
    final categoryOptions = _options.categories;
    final productOptions = _options.products;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final source = mode == 'category' ? categoryOptions : productOptions;
          final filtered = source
              .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.55,
            maxChildSize: 0.94,
            builder: (_, controller) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey_light,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Любимый вариант для "${dateItem.title}"',
                    style: AppText.bold_18,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'category',
                        label: Text('Категория'),
                      ),
                      ButtonSegment(value: 'product', label: Text('Цветок')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => setLocal(() {
                      mode = v.first;
                      query = '';
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setLocal(() => query = v),
                    decoration: const InputDecoration(
                      hintText: 'Поиск...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Ничего не найдено',
                              style: AppText.medium_14.copyWith(
                                color: AppColors.grey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: controller,
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final option = filtered[i];
                              return InkWell(
                                onTap: () async {
                                  final navigator = Navigator.of(ctx);
                                  await CalendarService.createImportantDatePreference(
                                    importantDateId: dateItem.id,
                                    categoryId: mode == 'category'
                                        ? option.id
                                        : null,
                                    productId: mode == 'product'
                                        ? option.id
                                        : null,
                                  );
                                  if (!mounted) return;
                                  navigator.pop();
                                  await _load();
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.white_dark,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.grey_light,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        mode == 'category'
                                            ? Icons.category_outlined
                                            : Icons.local_florist_outlined,
                                        color: AppColors.brown,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          option.name,
                                          style: AppText.medium_14,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.add_circle_outline,
                                        color: AppColors.brown,
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _showUpgrade(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Нужна подписка',
          style: AppText.bold_18.copyWith(color: AppColors.error),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              side: BorderSide(color: AppColors.brown),
            ),
            child: Text(
              'Отмена',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/profile/subscriptions');
            },
            child: Text(
              'Подписки',
              style: AppText.medium_14.copyWith(color: AppColors.brown),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _pickPreferenceSheet({String? title}) async {
    String mode = 'category';
    String query = '';
    final categoryOptions = _options.categories;
    final productOptions = _options.products;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final source = mode == 'category' ? categoryOptions : productOptions;
          final filtered = source
              .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.55,
            maxChildSize: 0.94,
            builder: (_, controller) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey_light,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(title ?? 'Выбор предпочтения', style: AppText.bold_18),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'category',
                        label: Text('Категория'),
                      ),
                      ButtonSegment(value: 'product', label: Text('Цветок')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => setLocal(() {
                      mode = v.first;
                      query = '';
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setLocal(() => query = v),
                    decoration: const InputDecoration(
                      hintText: 'Поиск...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Ничего не найдено',
                              style: AppText.medium_14.copyWith(
                                color: AppColors.grey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: controller,
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final option = filtered[i];
                              return InkWell(
                                onTap: () {
                                  Navigator.of(ctx).pop(<String, dynamic>{
                                    'mode': mode,
                                    'id': option.id,
                                    'name': option.name,
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.white_dark,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.grey_light,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        mode == 'category'
                                            ? Icons.category_outlined
                                            : Icons.local_florist_outlined,
                                        color: AppColors.brown,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          option.name,
                                          style: AppText.medium_14,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.add_circle_outline,
                                        color: AppColors.brown,
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditDialog({
    ImportantDateDto? item,
    DateTime? selectedDay,
  }) async {
    final titleCtrl = TextEditingController(text: item?.title ?? '');
    final commentCtrl = TextEditingController(text: item?.comment ?? '');
    DateTime date = item?.eventDate ?? selectedDay ?? DateTime.now();
    Map<String, dynamic>? pendingPreference;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            item == null ? 'Новая памятная дата' : 'Редактировать дату',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Комментарий'),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.white_dark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.grey_light),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Предпочтение', style: AppText.medium_14),
                      const SizedBox(height: 6),
                      if (pendingPreference == null)
                        Text(
                          'Не выбрано',
                          style: AppText.medium_12.copyWith(
                            color: AppColors.grey,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              pendingPreference!['mode'] == 'category'
                                  ? Icons.category_outlined
                                  : Icons.local_florist_outlined,
                              color: AppColors.brown,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pendingPreference!['name']?.toString() ?? '',
                                style: AppText.medium_12,
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setLocal(() => pendingPreference = null),
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await _pickPreferenceSheet(
                            title: 'Предпочтение для этой даты',
                          );
                          if (selected == null) return;
                          setLocal(() => pendingPreference = selected);
                        },
                        icon: const Icon(
                          Icons.favorite_border,
                          color: AppColors.brown,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.brown),
                        ),
                        label: const Text('Добавить предпочтение'),
                      ),
                    ],
                  ),
                ),
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
    if (save != true) return;
    try {
      if (item == null) {
        final created = await CalendarService.createImportantDate(
          title: titleCtrl.text.trim(),
          date: date,
          comment: commentCtrl.text.trim().isEmpty
              ? null
              : commentCtrl.text.trim(),
        );
        if (pendingPreference != null) {
          await CalendarService.createImportantDatePreference(
            importantDateId: created.id,
            categoryId: pendingPreference!['mode'] == 'category'
                ? pendingPreference!['id'] as int?
                : null,
            productId: pendingPreference!['mode'] == 'product'
                ? pendingPreference!['id'] as int?
                : null,
          );
        }
      } else {
        await CalendarService.updateImportantDate(
          id: item.id,
          title: titleCtrl.text.trim(),
          date: date,
          comment: commentCtrl.text.trim(),
        );
        if (pendingPreference != null) {
          await CalendarService.createImportantDatePreference(
            importantDateId: item.id,
            categoryId: pendingPreference!['mode'] == 'category'
                ? pendingPreference!['id'] as int?
                : null,
            productId: pendingPreference!['mode'] == 'product'
                ? pendingPreference!['id'] as int?
                : null,
          );
        }
      }
      await _load();
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        await _showUpgrade(e.message);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: ${e.message}')));
      }
    }
  }

  Future<void> _showEventsBottomSheet(DateTime selected) async {
    final events = _eventsForSelectedDay(selected);
    (int, int, String)? holidayInfo;
    for (final h in _fixedHolidays.values) {
      if (selected.month == h.$1 && selected.day == h.$2) {
        holidayInfo = h;
        break;
      }
    }
    if (events.isEmpty && holidayInfo == null) return;
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
              DateFormat('dd MMMM yyyy', 'ru').format(selected),
              style: AppText.bold_18,
            ),
            const SizedBox(height: 10),
            if (holidayInfo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brown.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brown),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Праздник: ${holidayInfo.$3}',
                        style: AppText.medium_14.copyWith(
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ...events.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title),
                subtitle: Text(
                  '${_yearsSinceText(e, selected)}'
                  '${(e.comment ?? '').isEmpty ? '' : ' • ${e.comment!}'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.favorite_border,
                        color: AppColors.brown,
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _addDatePreference(e);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.brown,
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _openEditDialog(item: e);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        final ok = await _confirmDelete();
                        if (!ok) return;
                        await CalendarService.deleteImportantDate(e.id);
                        if (!mounted) return;
                        navigator.pop();
                        await _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brown,
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _openEditDialog(selectedDay: selected);
                },
                icon: const Icon(Icons.add, color: AppColors.white),
                label: Text(
                  'Добавить праздник',
                  style: AppText.medium_14.copyWith(color: AppColors.white),
                ),
              ),
            ),
            ...events.map((e) {
              final prefs =
                  _prefsByDateId[e.id] ?? const <ImportantDatePreferenceDto>[];
              if (prefs.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white_dark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Предпочтения для "${e.title}"',
                      style: AppText.medium_12,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: prefs
                          .map(
                            (p) => Chip(
                              label: Text(p.displayName),
                              backgroundColor: AppColors.white,
                              deleteIconColor: AppColors.error,
                              onDeleted: () async {
                                final navigator = Navigator.of(ctx);
                                final ok = await _confirmDelete();
                                if (!ok) return;
                                await CalendarService.deleteImportantDatePreference(
                                  p.id,
                                );
                                if (!mounted) return;
                                navigator.pop();
                                await _load();
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  side: const BorderSide(color: AppColors.brown),
                ),
                child: Text(
                  'Отмена',
                  style: AppText.medium_14.copyWith(color: AppColors.brown),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendar() {
    final markerCounts = _markersCountForMonth();
    final firstDay = DateTime(_focusMonth.year, _focusMonth.month, 1);
    final offset = (firstDay.weekday + 6) % 7;
    final start = firstDay.subtract(Duration(days: offset));
    final days = List.generate(42, (i) => start.add(Duration(days: i)));

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
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, i) {
              final day = days[i];
              final key = _dayKey(day);
              final count = markerCounts[key] ?? 0;
              final marked = count > 0;
              return GestureDetector(
                onTap: () async {
                  if (count > 0) {
                    await _showEventsBottomSheet(day);
                    return;
                  }
                  await _openEditDialog(selectedDay: day);
                },
                onLongPress: () => _openEditDialog(selectedDay: day),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: marked
                        ? Border.all(color: AppColors.brown, width: 1.8)
                        : Border.all(
                            color: AppColors.white_transparent,
                            width: 1.2,
                          ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
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
                      if (count > 1)
                        Positioned(
                          right: -6,
                          top: -6,
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
                              '$count',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        title: Text('Памятные даты', style: AppText.bold_20),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditDialog(),
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
                children: [_calendar()],
              ),
            ),
    );
  }
}
