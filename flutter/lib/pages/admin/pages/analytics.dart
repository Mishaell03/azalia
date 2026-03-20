import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/services/admin_analytics.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminPageAnalytics extends StatefulWidget {
  const AdminPageAnalytics({super.key});

  @override
  State<AdminPageAnalytics> createState() => _AdminPageAnalyticsState();
}

class _AdminPageAnalyticsState extends State<AdminPageAnalytics> {
  final AdminAnalyticsService _service = AdminAnalyticsService(ApiClient());
  static const List<int> _periodOptions = [7, 30, 90];

  bool _isLoading = true;
  String? _error;
  int? _selectedStoreId;
  int _selectedDays = 30;
  List<_StoreOption> _stores = const [];
  List<_DailySeriesPoint> _series = const [];
  List<_PopularPlantPoint> _popularPlants = const [];
  List<_SubscriptionSeriesPoint> _subscriptionSeries = const [];
  List<_RegistrationsSeriesPoint> _registrationsSeries = const [];
  List<_PopularSubscriptionPoint> _popularSubscriptions = const [];
  int _ordersCount = 0;
  double _revenue = 0;
  double _averageOrderValue = 0;
  int _soldSubscriptionsCount = 0;
  double _subscriptionRevenue = 0;
  double _averageSubscriptionCheck = 0;
  int _newUsersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics({int? storeId, int? days}) async {
    final targetDays = days ?? _selectedDays;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.getAnalytics(
        storeId: storeId,
        days: targetDays,
        top: 7,
      );
      final storesRaw = data['stores'] as List? ?? const [];
      final seriesRaw = data['series'] as List? ?? const [];
      final popularRaw = data['popular_plants'] as List? ?? const [];
      final subscriptionSeriesRaw =
          data['subscription_series'] as List? ?? const [];
      final registrationsSeriesRaw =
          data['registrations_series'] as List? ?? const [];
      final popularSubscriptionsRaw =
          data['popular_subscriptions'] as List? ?? const [];
      final summary = data['summary'] as Map<String, dynamic>? ?? const {};
      final subscriptionSummary =
          data['subscription_summary'] as Map<String, dynamic>? ?? const {};
      if (!mounted) return;
      setState(() {
        _stores = storesRaw
            .whereType<Map<String, dynamic>>()
            .map(_StoreOption.fromJson)
            .toList();
        _series = seriesRaw
            .whereType<Map<String, dynamic>>()
            .map(_DailySeriesPoint.fromJson)
            .toList();
        _popularPlants = popularRaw
            .whereType<Map<String, dynamic>>()
            .map(_PopularPlantPoint.fromJson)
            .toList();
        _subscriptionSeries = subscriptionSeriesRaw
            .whereType<Map<String, dynamic>>()
            .map(_SubscriptionSeriesPoint.fromJson)
            .toList();
        _registrationsSeries = registrationsSeriesRaw
            .whereType<Map<String, dynamic>>()
            .map(_RegistrationsSeriesPoint.fromJson)
            .toList();
        _popularSubscriptions = popularSubscriptionsRaw
            .whereType<Map<String, dynamic>>()
            .map(_PopularSubscriptionPoint.fromJson)
            .toList();
        _ordersCount = (summary['orders_count'] as num?)?.toInt() ?? 0;
        _revenue = (summary['revenue'] as num?)?.toDouble() ?? 0;
        _averageOrderValue =
            (summary['average_order_value'] as num?)?.toDouble() ?? 0;
        _newUsersCount = (summary['new_users_count'] as num?)?.toInt() ?? 0;
        _soldSubscriptionsCount =
            (subscriptionSummary['sold_subscriptions_count'] as num?)
                ?.toInt() ??
            0;
        _subscriptionRevenue =
            (subscriptionSummary['revenue'] as num?)?.toDouble() ?? 0;
        _averageSubscriptionCheck =
            (subscriptionSummary['average_subscription_check'] as num?)
                ?.toDouble() ??
            0;
        _selectedStoreId = storeId;
        _selectedDays = targetDays;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки аналитики: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _money(double value) {
    final f = NumberFormat('#,##0.##', 'ru_RU');
    return '${f.format(value)} ₽';
  }

  String _shortDate(String dateIso) {
    final dt = DateTime.tryParse(dateIso);
    if (dt == null) return dateIso;
    return DateFormat('dd.MM').format(dt);
  }

  Widget _summaryCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey_light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.medium_12.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 6),
          Text(value, style: AppText.bold_18.copyWith(color: AppColors.black)),
        ],
      ),
    );
  }

  Widget _summaryCardsSection() {
    final cards = <Widget>[
      _summaryCard(title: 'Количество заказов', value: '$_ordersCount'),
      _summaryCard(title: 'Выручка', value: _money(_revenue)),
      _summaryCard(title: 'Средний чек', value: _money(_averageOrderValue)),
      _summaryCard(
        title: 'Продано подписок',
        value: '$_soldSubscriptionsCount',
      ),
      _summaryCard(
        title: 'Выручка по подпискам',
        value: _money(_subscriptionRevenue),
      ),
      _summaryCard(
        title: 'Средний чек подписки',
        value: _money(_averageSubscriptionCheck),
      ),
      _summaryCard(title: 'Новые пользователи', value: '$_newUsersCount'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const minCardWidth = 280.0;
        final showTwoColumns =
            constraints.maxWidth >= (minCardWidth * 2 + spacing);
        final cardWidth = showTwoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _chartContainer({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey_light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.bold_18.copyWith(color: AppColors.black)),
          const SizedBox(height: 10),
          SizedBox(height: 220, child: child),
        ],
      ),
    );
  }

  Widget _ordersChart() {
    if (_series.isEmpty) {
      return Center(
        child: Text(
          'Нет данных',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
      );
    }
    final maxY = _series
        .map((e) => e.ordersCount)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final labelStep = (_series.length / 6).ceil().clamp(1, 10);

    return BarChart(
      BarChartData(
        maxY: (maxY + 1).toDouble(),
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.grey,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(10),
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${_shortDate(_series[group.x.toInt()].date)}\n${rod.toY.toInt()} заказов',
              AppText.medium_14.copyWith(color: AppColors.white),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: ((maxY + 1) / 4).clamp(1, 9999).toDouble(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _series.length || idx % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _shortDate(_series[idx].date),
                  style: AppText.medium_8.copyWith(color: AppColors.grey),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          _series.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _series[i].ordersCount.toDouble(),
                color: AppColors.brown,
                width: 7,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _revenueChart() {
    if (_series.isEmpty) {
      return Center(
        child: Text(
          'Нет данных',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
      );
    }
    final maxY = _series
        .map((e) => e.revenue)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final labelStep = (_series.length / 6).ceil().clamp(1, 10);
    final interval = maxY <= 0 ? 1 : (maxY / 4);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_series.length - 1).toDouble(),
        clipData: const FlClipData.all(),
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.1,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.grey,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(10),
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    '${_shortDate(_series[spot.x.toInt()].date)}\n${_money(spot.y)}',
                    AppText.medium_14.copyWith(color: AppColors.white),
                  ),
                )
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: interval <= 0 ? 1 : interval.toDouble(),
              getTitlesWidget: (value, meta) => Text(
                NumberFormat.compact(locale: 'ru_RU').format(value),
                style: AppText.medium_8.copyWith(color: AppColors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _series.length || idx % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _shortDate(_series[idx].date),
                  style: AppText.medium_8.copyWith(color: AppColors.grey),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              _series.length,
              (i) => FlSpot(i.toDouble(), _series[i].revenue),
            ),
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.success,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.success.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _popularPlantsChart() {
    if (_popularPlants.isEmpty) {
      return Center(
        child: Text(
          'Нет данных',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
      );
    }
    final maxY = _popularPlants
        .map((e) => e.totalSold)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: (maxY + 1).toDouble(),
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.grey,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipPadding: const EdgeInsets.all(10),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        '${_popularPlants[group.x.toInt()].name}\n${rod.toY.toInt()} шт.',
                        AppText.medium_14.copyWith(color: AppColors.white),
                      ),
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: ((maxY + 1) / 4).clamp(1, 9999).toDouble(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt() + 1}',
                      style: AppText.medium_12.copyWith(color: AppColors.grey),
                    ),
                  ),
                ),
              ),
              barGroups: List.generate(
                _popularPlants.length,
                (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _popularPlants[i].totalSold.toDouble(),
                      color: AppColors.brown,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._popularPlants.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  '${entry.key + 1}. ',
                  style: AppText.medium_12.copyWith(color: AppColors.grey),
                ),
                Expanded(
                  child: Text(
                    entry.value.name,
                    style: AppText.medium_12.copyWith(color: AppColors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.totalSold} шт.',
                  style: AppText.medium_12.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _subscriptionsChart() {
    if (_subscriptionSeries.isEmpty) {
      return Center(
        child: Text(
          'Нет данных',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
      );
    }
    final maxY = _subscriptionSeries
        .map((e) => e.soldCount)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final labelStep = (_subscriptionSeries.length / 6).ceil().clamp(1, 10);
    return BarChart(
      BarChartData(
        maxY: (maxY + 1).toDouble(),
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.grey,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(10),
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${_shortDate(_subscriptionSeries[group.x.toInt()].date)}\n${rod.toY.toInt()} подписок',
              AppText.medium_14.copyWith(color: AppColors.white),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: ((maxY + 1) / 4).clamp(1, 9999).toDouble(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 ||
                    idx >= _subscriptionSeries.length ||
                    idx % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _shortDate(_subscriptionSeries[idx].date),
                  style: AppText.medium_8.copyWith(color: AppColors.grey),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          _subscriptionSeries.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _subscriptionSeries[i].soldCount.toDouble(),
                color: AppColors.brown,
                width: 7,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _registrationsChart() {
    if (_registrationsSeries.isEmpty) {
      return Center(
        child: Text(
          'Нет данных',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
      );
    }
    final maxY = _registrationsSeries
        .map((e) => e.usersCount)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final labelStep = (_registrationsSeries.length / 6).ceil().clamp(1, 10);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_registrationsSeries.length - 1).toDouble(),
        minY: 0,
        maxY: (maxY <= 0 ? 1 : maxY * 1.1).toDouble(),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.grey,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(10),
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    '${_shortDate(_registrationsSeries[spot.x.toInt()].date)}\n${spot.y.toInt()} пользователей',
                    AppText.medium_14.copyWith(color: AppColors.white),
                  ),
                )
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: ((maxY + 1) / 4).clamp(1, 9999).toDouble(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 ||
                    idx >= _registrationsSeries.length ||
                    idx % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _shortDate(_registrationsSeries[idx].date),
                  style: AppText.medium_8.copyWith(color: AppColors.grey),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              _registrationsSeries.length,
              (i) => FlSpot(
                i.toDouble(),
                _registrationsSeries[i].usersCount.toDouble(),
              ),
            ),
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.success,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.success.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _popularSubscriptionsChart() {
    if (_popularSubscriptions.isEmpty) {
      return Center(
        child: Text(
          'Нет данных',
          style: AppText.medium_14.copyWith(color: AppColors.grey),
        ),
      );
    }
    final maxY = _popularSubscriptions
        .map((e) => e.soldCount)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: (maxY + 1).toDouble(),
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.grey,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipPadding: const EdgeInsets.all(10),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        '${_popularSubscriptions[group.x.toInt()].name}\n${rod.toY.toInt()} шт.',
                        AppText.medium_14.copyWith(color: AppColors.white),
                      ),
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: ((maxY + 1) / 4).clamp(1, 9999).toDouble(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt() + 1}',
                      style: AppText.medium_12.copyWith(color: AppColors.grey),
                    ),
                  ),
                ),
              ),
              barGroups: List.generate(
                _popularSubscriptions.length,
                (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _popularSubscriptions[i].soldCount.toDouble(),
                      color: AppColors.brown,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._popularSubscriptions.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  '${entry.key + 1}. ',
                  style: AppText.medium_12.copyWith(color: AppColors.grey),
                ),
                Expanded(
                  child: Text(
                    entry.value.name,
                    style: AppText.medium_12.copyWith(color: AppColors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.soldCount} шт.',
                  style: AppText.medium_12.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminHeaderItems),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: AppText.medium_14.copyWith(color: AppColors.error),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadAnalytics(storeId: _selectedStoreId),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Админ-аналитика',
                    style: AppText.bold_20.copyWith(color: AppColors.black),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _selectedStoreId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Фильтр по магазину',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Все магазины'),
                      ),
                      ..._stores.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text('${s.name} • ${s.address}'),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        _loadAnalytics(storeId: value, days: _selectedDays),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _periodOptions
                        .map(
                          (days) => ChoiceChip(
                            label: Text('$days дней'),
                            selected: _selectedDays == days,
                            selectedColor: AppColors.brown,
                            labelStyle: AppText.medium_12.copyWith(
                              color: _selectedDays == days
                                  ? AppColors.white
                                  : AppColors.black,
                            ),
                            side: const BorderSide(color: AppColors.brown),
                            onSelected: _isLoading
                                ? null
                                : (_) => _loadAnalytics(
                                    storeId: _selectedStoreId,
                                    days: days,
                                  ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _summaryCardsSection(),
                  _chartContainer(
                    title: 'График заказов',
                    child: _ordersChart(),
                  ),
                  _chartContainer(
                    title: 'График выручки',
                    child: _revenueChart(),
                  ),
                  _chartContainer(
                    title: 'Популярные растения',
                    child: _popularPlantsChart(),
                  ),
                  _chartContainer(
                    title: 'Продажи подписок (по дням)',
                    child: _subscriptionsChart(),
                  ),
                  _chartContainer(
                    title: 'Регистрация пользователей (по дням)',
                    child: _registrationsChart(),
                  ),
                  _chartContainer(
                    title: 'Востребованные подписки',
                    child: _popularSubscriptionsChart(),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: AppFooter(items: adminFooterItems),
    );
  }
}

class _StoreOption {
  final int id;
  final String name;
  final String address;

  const _StoreOption({
    required this.id,
    required this.name,
    required this.address,
  });

  factory _StoreOption.fromJson(Map<String, dynamic> json) {
    return _StoreOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class _DailySeriesPoint {
  final String date;
  final int ordersCount;
  final double revenue;

  const _DailySeriesPoint({
    required this.date,
    required this.ordersCount,
    required this.revenue,
  });

  factory _DailySeriesPoint.fromJson(Map<String, dynamic> json) {
    return _DailySeriesPoint(
      date: json['date']?.toString() ?? '',
      ordersCount: (json['orders_count'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _PopularPlantPoint {
  final String name;
  final int totalSold;
  final double revenue;

  const _PopularPlantPoint({
    required this.name,
    required this.totalSold,
    required this.revenue,
  });

  factory _PopularPlantPoint.fromJson(Map<String, dynamic> json) {
    return _PopularPlantPoint(
      name: json['name']?.toString() ?? '',
      totalSold: (json['total_sold'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _SubscriptionSeriesPoint {
  final String date;
  final int soldCount;
  final double revenue;

  const _SubscriptionSeriesPoint({
    required this.date,
    required this.soldCount,
    required this.revenue,
  });

  factory _SubscriptionSeriesPoint.fromJson(Map<String, dynamic> json) {
    return _SubscriptionSeriesPoint(
      date: json['date']?.toString() ?? '',
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _RegistrationsSeriesPoint {
  final String date;
  final int usersCount;

  const _RegistrationsSeriesPoint({
    required this.date,
    required this.usersCount,
  });

  factory _RegistrationsSeriesPoint.fromJson(Map<String, dynamic> json) {
    return _RegistrationsSeriesPoint(
      date: json['date']?.toString() ?? '',
      usersCount: (json['users_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class _PopularSubscriptionPoint {
  final int planId;
  final String name;
  final int soldCount;
  final double revenue;

  const _PopularSubscriptionPoint({
    required this.planId,
    required this.name,
    required this.soldCount,
    required this.revenue,
  });

  factory _PopularSubscriptionPoint.fromJson(Map<String, dynamic> json) {
    return _PopularSubscriptionPoint(
      planId: (json['plan_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Тариф',
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}
