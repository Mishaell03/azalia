import 'package:azalia/backend/models/payment/order_history.dart';
import 'package:azalia/backend/services/order_history.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/order_payment_status_config.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/error/loading_error.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  bool _isLoading = true;
  String? _error;
  List<OrderHistorySummary> _orders = const [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await OrderHistoryService.getOrders();
      if (!mounted) return;
      setState(() {
        _orders = response.items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatPrice(double value) {
    return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} ₽';
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final value = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (value == null) return raw;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }

  Widget _buildStatusChip(String label, String status, {required bool isPayment}) {
    final color = isPayment
        ? OrderPaymentStatusConfig.paymentColor(status)
        : OrderPaymentStatusConfig.orderColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppText.medium_12.copyWith(color: color),
      ),
    );
  }

  Widget _buildOrderCard(OrderHistorySummary order) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/profile/orders/${order.orderId}'),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey_light.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: AppText.bold_18.copyWith(color: AppColors.black),
                    ),
                  ),
                  Text(
                    _formatPrice(order.totalPrice),
                    style: AppText.semibold_15.copyWith(color: AppColors.brown),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusChip(
                    OrderPaymentStatusConfig.orderLabel(
                      order.statusCode.isNotEmpty ? order.statusCode : order.status,
                    ),
                    order.statusCode.isNotEmpty ? order.statusCode : order.status,
                    isPayment: false,
                  ),
                  _buildStatusChip(
                    OrderPaymentStatusConfig.paymentLabel(
                      order.paymentStatusCode.isNotEmpty
                          ? order.paymentStatusCode
                          : order.paymentStatus,
                    ),
                    order.paymentStatusCode.isNotEmpty
                        ? order.paymentStatusCode
                        : order.paymentStatus,
                    isPayment: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Товаров: ${order.itemsCount}',
                style: AppText.medium_14.copyWith(color: AppColors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                'Создан: ${_formatDate(order.createdAt)}',
                style: AppText.medium_14.copyWith(color: AppColors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 18,
                    color: AppColors.black_transparent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.orderTypeLabel.isNotEmpty
                        ? order.orderTypeLabel
                        : (order.orderType == 'pickup' ? 'Без доставки' : 'С доставкой'),
                    style: AppText.medium_14.copyWith(
                      color: AppColors.black_transparent,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Подробнее',
                    style: AppText.medium_14.copyWith(color: AppColors.brown),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'История заказов',
          style: AppText.bold_18.copyWith(color: AppColors.black),
        ),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error != null
          ? GenericErrorWidget(onRetry: _loadOrders)
          : RefreshIndicator(
              color: AppColors.brown,
              onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 100),
                        Icon(
                          Icons.history,
                          size: 56,
                          color: AppColors.grey_light,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'У вас пока нет заказов',
                          textAlign: TextAlign.center,
                          style: AppText.medium_18.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Когда появятся покупки, они будут отображаться здесь',
                          textAlign: TextAlign.center,
                          style: AppText.medium_14.copyWith(
                            color: AppColors.black_transparent,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemBuilder: (context, index) =>
                          _buildOrderCard(_orders[index]),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemCount: _orders.length,
                    ),
            ),
    );
  }
}
