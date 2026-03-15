import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:flutter/material.dart';

class AdminProductsCartWarehouse extends StatefulWidget {
  const AdminProductsCartWarehouse({super.key});

  @override
  State<AdminProductsCartWarehouse> createState() =>
      _AdminProductsCartWarehouseState();
}

class _AdminProductsCartWarehouseState
    extends State<AdminProductsCartWarehouse> {
  final ApiClient _api = ApiClient();

  bool _isLoading = true;
  bool _isAdjusting = false;
  String? _error;

  int? _selectedStoreId;
  List<_WarehouseStore> _stores = const [];
  List<_WarehouseProduct> _products = const [];

  @override
  void initState() {
    super.initState();
    _loadWarehouse();
  }

  Future<void> _loadWarehouse({int? storeId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final params = <String, String>{'include_inactive_products': 'true'};
      if (storeId != null) {
        params['store_id'] = storeId.toString();
      }

      final url = Uri.parse(
        ApiConfig.warehouseProducts,
      ).replace(queryParameters: params).toString();

      final response = await _api.get(url);
      if (response['success'] != true) {
        throw Exception('Не удалось загрузить склад');
      }

      final data = (response['data'] as Map<String, dynamic>? ?? const {});
      final selectedStore = data['selected_store'] as Map<String, dynamic>?;

      final stores = (data['stores_for_switch'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_WarehouseStore.fromJson)
          .toList();

      final products = (data['products'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_WarehouseProduct.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _stores = stores;
        _products = products;
        _selectedStoreId = (selectedStore?['id'] as num?)?.toInt();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки склада: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAdjustDialog(_WarehouseProduct product) async {
    final quantityController = TextEditingController(
      text: product.quantityAvailable.toString(),
    );
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Корректировка: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Текущий остаток: ${product.quantityAvailable} шт.'),
              const SizedBox(height: 10),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Новое количество (шт.)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Комментарий причины изменения',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                side: BorderSide(color: AppColors.brown),
              ),
              child: Text(
                'Отмена',
                style: AppText.medium_14.copyWith(color: AppColors.brown),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.brown
              ),
              child: Text(
                'Сохранить',
                style: AppText.medium_14.copyWith(color: AppColors.white_transparent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final newQuantity = int.tryParse(quantityController.text.trim());
    if (newQuantity == null || newQuantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Введите корректное количество (0 или больше)',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
      return;
    }

    final delta = newQuantity - product.quantityAvailable;
    if (delta == 0) {
      return;
    }
    final comment = commentController.text.trim();

    await _adjustProduct(
      productId: product.productId,
      delta: delta,
      comment: comment,
    );
  }

  Future<void> _adjustProduct({
    required int productId,
    required int delta,
    required String comment,
  }) async {
    if (_selectedStoreId == null) return;

    setState(() {
      _isAdjusting = true;
    });

    try {
      final response = await _api.patch(
        ApiConfig.warehouseAdjustProduct(productId),
        body: {
          'quantity_delta': delta,
          'comment': comment.isEmpty ? null : comment,
          'store_id': _selectedStoreId,
        },
      );

      if (response['success'] != true) {
        throw Exception('Не удалось обновить остаток');
      }

      final data = (response['data'] as Map<String, dynamic>? ?? const {});
      final updated = _WarehouseProduct.fromJson(data);

      if (!mounted) return;
      setState(() {
        _products = _products.map((item) {
          if (item.productId == updated.productId) return updated;
          return item;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Остаток обновлен',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.white,
          content: Text(
            'Ошибка корректировки: $e',
            style: AppText.medium_14.copyWith(color: AppColors.brown),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAdjusting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Склад / адрес точки',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedStoreId,
                  items: _stores
                      .map(
                        (store) => DropdownMenuItem<int>(
                          value: store.id,
                          child: Text('${store.name} • ${store.address}'),
                        ),
                      )
                      .toList(),
                  onChanged: (_isLoading || _isAdjusting)
                      ? null
                      : (value) {
                          if (value == null) return;
                          _loadWarehouse(storeId: value);
                        },
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null) {
                  return Center(child: Text(_error!));
                }
                if (_products.isEmpty) {
                  return const Center(
                    child: Text('На этом складе товаров нет'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _loadWarehouse(storeId: _selectedStoreId),
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final isDeleted =
                          product.deletedAt != null || !product.isActive;
                      final isZeroQty =
                          !isDeleted && product.quantityAvailable == 0;
                      final qtyLabel = isDeleted
                          ? 'Удален'
                          : '${product.quantityAvailable} шт.';

                      return InkWell(
                        onTap: _isAdjusting
                            ? null
                            : () => _showAdjustDialog(product),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                (() {
                                  final imageUrl =
                                      ApiConfig.imageUrl(product.imageUrl)
                                          .trim();
                                  final fallback = Container(
                                    width: 72,
                                    height: 72,
                                    color: AppColors.grey_light,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.image_not_supported),
                                  );
                                  if (imageUrl.isEmpty) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: fallback,
                                    );
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, error, stackTrace) => fallback,
                                    ),
                                  );
                                })(),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.medium_16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  qtyLabel,
                                  style: AppText.medium_14.copyWith(
                                    color: isDeleted || isZeroQty
                                        ? AppColors.error
                                        : AppColors.brown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseStore {
  final int id;
  final String name;
  final String address;

  const _WarehouseStore({
    required this.id,
    required this.name,
    required this.address,
  });

  factory _WarehouseStore.fromJson(Map<String, dynamic> json) {
    return _WarehouseStore(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class _WarehouseProduct {
  final int productId;
  final String name;
  final String? imageUrl;
  final int quantityAvailable;
  final bool isActive;
  final String? deletedAt;

  const _WarehouseProduct({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.quantityAvailable,
    required this.isActive,
    required this.deletedAt,
  });

  factory _WarehouseProduct.fromJson(Map<String, dynamic> json) {
    return _WarehouseProduct(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      quantityAvailable: (json['quantity_available'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
      deletedAt: json['deleted_at']?.toString(),
    );
  }
}
