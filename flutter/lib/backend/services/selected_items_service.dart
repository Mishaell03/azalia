import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class SelectedItemsService {
  static const String _selectedItemsKey = 'selected_cart_items';

  /// Получить список выбранных ID товаров
  static Future<List<int>> getSelectedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_selectedItemsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<int>();
    } catch (e) {
      debugPrint('Ошибка загрузки выбранных товаров: $e');
      return [];
    }
  }

  /// Сохранить список выбранных ID товаров
  static Future<void> saveSelectedItems(List<int> itemIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(itemIds);
      await prefs.setString(_selectedItemsKey, jsonString);
    } catch (e) {
      debugPrint('Ошибка сохранения выбранных товаров: $e');
    }
  }

  /// Добавить товар в выбранные
  static Future<void> addSelectedItem(int itemId) async {
    try {
      final selectedItems = await getSelectedItems();
      if (!selectedItems.contains(itemId)) {
        selectedItems.add(itemId);
        await saveSelectedItems(selectedItems);
      }
    } catch (e) {
      debugPrint('Ошибка добавления товара в выбранные: $e');
    }
  }

  /// Удалить товар из выбранных
  static Future<void> removeSelectedItem(int itemId) async {
    try {
      final selectedItems = await getSelectedItems();
      selectedItems.removeWhere((id) => id == itemId);
      await saveSelectedItems(selectedItems);
    } catch (e) {
      debugPrint('Ошибка удаления товара из выбранных: $e');
    }
  }

  /// Очистить все выбранные товары
  static Future<void> clearSelectedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_selectedItemsKey);
    } catch (e) {
      debugPrint('Ошибка очистки выбранных товаров: $e');
    }
  }

  /// Проверить, выбран ли товар
  static Future<bool> isItemSelected(int itemId) async {
    final selectedItems = await getSelectedItems();
    return selectedItems.contains(itemId);
  }
}
