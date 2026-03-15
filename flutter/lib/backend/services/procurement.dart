import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';

class ProcurementService {
  final ApiClient _api;

  ProcurementService(this._api);

  Future<List<Map<String, dynamic>>> getStores() async {
    final response = await _api.get(ApiConfig.procurementStores);
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getMissingProducts(int storeId) async {
    final response = await _api.get(ApiConfig.procurementMissingProducts(storeId));
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getCatalogProducts(int storeId) async {
    final response = await _api.get(ApiConfig.procurementCatalogProducts(storeId));
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getCartItems(int storeId) async {
    final response = await _api.get(ApiConfig.procurementCart(storeId));
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> upsertCartItem({
    required int storeId,
    required int productId,
    required int quantity,
  }) async {
    await _api.post(
      ApiConfig.procurementCartItems,
      body: {
        'store_id': storeId,
        'product_id': productId,
        'quantity': quantity,
      },
    );
  }

  Future<void> deleteCartItem(int cartItemId) async {
    await _api.delete(ApiConfig.procurementCartItemById(cartItemId));
  }

  Future<Map<String, dynamic>> checkout({
    required int storeId,
    required List<int> cartItemIds,
    String? comment,
  }) async {
    final response = await _api.post(
      ApiConfig.procurementCheckout,
      body: {
        'store_id': storeId,
        'cart_item_ids': cartItemIds,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
    return response['data'] as Map<String, dynamic>? ?? const {};
  }
}
