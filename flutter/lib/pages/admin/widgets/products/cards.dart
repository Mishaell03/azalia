import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminProductsCards extends StatelessWidget {
  const AdminProductsCards({super.key});

  static const List<Map<String, dynamic>> _carts = [
    {
      "name": "Товары в закупках",
      "pic": Icons.add_shopping_cart,
      "heading": "Ожидают заказа",
      "description": "Планируемые позиции для заказа у поставщиков. Формирование новых поставок.",
      "route": "procurement"
    },
    {
      "name": "Товары на складах",
      "pic": Icons.warehouse_outlined,
      "heading": "Доступные растения",
      "description": "Горшечные цветы в наличии на складе. Готовы к сборке для заказов или продаже в зале.",
      "route": "warehouse"
    },
    {
      "name": "Товары в доставке",
      "pic": Icons.local_shipping_outlined,
      "heading": "Поступление товаров",
      "description": "Новая партия растений в пути от поставщика. Ожидается пополнение ассортимента.",
      "route": "delivery"
    },
    {
      "name": "Клиентские заказы",
      "pic": Icons.inventory_2_outlined,
      "heading": "Текущие заказы",
      "description": "Активные заявки от клиентов, которые требуют сборки, упаковки или подготовки к выдаче.",
      "route": "orders"
    },
    {
      "name": "Прием поставок",
      "pic": Icons.conveyor_belt,
      "heading": "Поступления на склад",
      "description": "Регистрация и проверка поступивших товаров от поставщиков.",
      "route": "receipts"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _carts.map((cart) {
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: 44,
                right: 24,
                top: 25,
                bottom: 5,
              ),
              child: Row(
                children: [
                  Icon(cart['pic']),
                  SizedBox(width: 10),
                  Text(cart['name']!, style: AppText.bold_18),
                ],
              ),
            ),
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 160,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cart['heading']!, style: AppText.medium_18),
                          IconButton(
                            onPressed: () {
                              context.go('/admin/products/${cart['route']}');
                            },
                            icon: Icon(Icons.arrow_circle_right_outlined),
                            iconSize: 30,
                            color: AppColors.grey,
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        cart['description']!,
                        style: AppText.medium_14.copyWith(
                          color: AppColors.black_transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
