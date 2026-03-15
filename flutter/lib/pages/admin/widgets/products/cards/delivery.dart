import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/services/procurement.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:flutter/material.dart';

class AdminProductsCartDelivery extends StatefulWidget {
  const AdminProductsCartDelivery({super.key});

  @override
  State<AdminProductsCartDelivery> createState() =>
      _AdminProductsCartDeliveryState();
}

class _AdminProductsCartDeliveryState extends State<AdminProductsCartDelivery> {
  final ProcurementService _service = ProcurementService(ApiClient());

  bool _isLoading = true;
  String? _error;
  int? _selectedStoreId;
  List<_StoreHistoryItem> _stores = const [];
  List<_SupplyOrder> _orders = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({int? storeId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.getHistory(storeId: storeId, limit: 300);
      final storesRaw = data['stores'] as List? ?? const [];
      final itemsRaw = data['items'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _stores = storesRaw
            .whereType<Map<String, dynamic>>()
            .map(_StoreHistoryItem.fromJson)
            .toList();
        _orders = itemsRaw
            .whereType<Map<String, dynamic>>()
            .map(_SupplyOrder.fromJson)
            .toList();
        _selectedStoreId = storeId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки поставок: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _statusColor(String code) {
    switch (code.trim().toLowerCase()) {
      case 'received':
        return AppColors.success;
      case 'partially_received':
        return AppColors.brown;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  String _formatDate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '-';
    final dt = DateTime.tryParse(text);
    if (dt == null) return text;
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  Widget _buildItemCard(_SupplyItem item) {
    final image = ApiConfig.imageUrl(item.imageUrl).trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.grey_light),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image.isEmpty
                ? Container(width: 58, height: 58, color: AppColors.grey_light)
                : Image.network(
                    image,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Container(
                      width: 58,
                      height: 58,
                      color: AppColors.grey_light,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppText.medium_14.copyWith(color: AppColors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  'Заказали: ${item.orderedQuantity} шт.',
                  style: AppText.medium_12.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
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
              onRefresh: () => _loadHistory(storeId: _selectedStoreId),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'История поставок',
                    style: AppText.bold_18.copyWith(color: AppColors.black),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _selectedStoreId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Магазин',
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
                    onChanged: (value) => _loadHistory(storeId: value),
                  ),
                  const SizedBox(height: 16),
                  if (_orders.isEmpty)
                    Text(
                      'Поставок пока нет',
                      style: AppText.medium_14.copyWith(color: AppColors.grey),
                    )
                  else
                    ..._orders.map(
                      (order) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey_light),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Поставка №${order.purchaseNumber}',
                                  style: AppText.bold_15.copyWith(
                                    color: AppColors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(order.statusCode).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    order.status,
                                    style: AppText.medium_14.copyWith(
                                      color: _statusColor(order.statusCode),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10,),
                                Text(
                                  '${order.storeName}, ${order.storeAddress}\n${_formatDate(order.orderedAt)}',
                                  style: AppText.medium_12.copyWith(
                                    color: AppColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          children: order.items.map(_buildItemCard).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StoreHistoryItem {
  final int id;
  final String name;
  final String address;

  const _StoreHistoryItem({
    required this.id,
    required this.name,
    required this.address,
  });

  factory _StoreHistoryItem.fromJson(Map<String, dynamic> json) {
    return _StoreHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class _SupplyOrder {
  final int id;
  final String purchaseNumber;
  final String status;
  final String statusCode;
  final String storeName;
  final String storeAddress;
  final String? orderedAt;
  final List<_SupplyItem> items;

  const _SupplyOrder({
    required this.id,
    required this.purchaseNumber,
    required this.status,
    required this.statusCode,
    required this.storeName,
    required this.storeAddress,
    required this.orderedAt,
    required this.items,
  });

  factory _SupplyOrder.fromJson(Map<String, dynamic> json) {
    final store = json['store'] as Map<String, dynamic>? ?? const {};
    return _SupplyOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      purchaseNumber: json['purchase_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusCode: json['status_code']?.toString() ?? '',
      storeName: store['name']?.toString() ?? '',
      storeAddress: store['address']?.toString() ?? '',
      orderedAt: json['ordered_at']?.toString(),
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_SupplyItem.fromJson)
          .toList(),
    );
  }
}

class _SupplyItem {
  final int id;
  final int orderedQuantity;
  final String name;
  final String imageUrl;

  const _SupplyItem({
    required this.id,
    required this.orderedQuantity,
    required this.name,
    required this.imageUrl,
  });

  factory _SupplyItem.fromJson(Map<String, dynamic> json) {
    return _SupplyItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderedQuantity: (json['ordered_quantity'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}
