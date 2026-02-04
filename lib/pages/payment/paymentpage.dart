import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaymentPage extends StatefulWidget {
  final PaymentRouteArgs args;

  const PaymentPage({super.key, required this.args});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _formatPaymentMethod(String method) {
    return method == 'card' ? 'Карта' : 'Наличные';
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оформление заказа'),
        iconTheme: const IconThemeData(color: AppColors.black),
        titleTextStyle: AppText.bold_18.copyWith(color: AppColors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsGeometry.symmetric(horizontal: 20),
                child: Text(
                  'Заказ №${widget.args.orderId}',
                  style: AppText.bold_23.copyWith(color: AppColors.black),
                ),
              ),
              const SizedBox(height: 20),
              // карточка с деталями заказа
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white_transparent,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColors.brown, width: 1),
                ),
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Товары в заказе',
                      style: AppText.bold_15.copyWith(color: AppColors.grey),
                    ),
                    const SizedBox(height: 12),
                    ...widget.args.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.plantName,
                                        style: AppText.semibold_18.copyWith(
                                          color: AppColors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Кол-во: ${item.quantity} шт.',
                                        style: AppText.medium_14.copyWith(
                                          color: AppColors.grey,
                                        ),
                                      ),
                                      if (item.potPrice > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            'С горшком: ${_formatCurrency(item.potPrice)} ₽',
                                            style: AppText.medium_14.copyWith(
                                              color: AppColors.grey,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${_formatCurrency(item.itemTotal)} ₽',
                                      style: AppText.medium_16.copyWith(
                                        color: AppColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatCurrency(item.plantPrice)} ₽/шт.',
                                      style: AppText.medium_8.copyWith(
                                        color: AppColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (index < widget.args.items.length - 1)
                            Divider(
                              color: Colors.grey[300],
                              height: 1,
                              thickness: 1,
                            ),
                        ],
                      );
                    }).toList(),
                    const SizedBox(height: 12),
                    Divider(color: AppColors.brown, height: 1, thickness: 1),
                    const SizedBox(height: 12),

                    // Адрес доставки будет добавлен позже
                    Text(
                      'Адрес доставки',
                      style: AppText.bold_15.copyWith(color: AppColors.grey),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.args.address,
                      style: AppText.medium_16.copyWith(color: AppColors.grey),
                    ),
                    const SizedBox(height: 10),
                    // Метод оплаты
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Метод оплаты',
                          style: AppText.medium_14.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                        // будет добавлен выбор
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brown.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _formatPaymentMethod(widget.args.paymentMethod),
                            style: AppText.medium_12.copyWith(
                              color: AppColors.black_transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Итоговая сумма
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppColors.brown),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Итого к оплате',
                            style: AppText.medium_16.copyWith(
                              color: AppColors.black_transparent,
                            ),
                          ),
                          Text(
                            '${_formatCurrency(widget.args.totalPrice)} ₽',
                            style: AppText.bold_18.copyWith(
                              color: AppColors.black_transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Кнопка оплаты
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    debugPrint('PaymentPage: нажата кнопка "Оплатить"');
                    debugPrint(
                      'PaymentPage: платёжная ссылка: ${widget.args.paymentUrl}',
                    );

                    // диалог с предупреждением о VPN
                    final confirmed = await showDialog<bool>(
                      context: context,
                      barrierDismissible: true,
                      builder: (BuildContext context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 25,
                              color: AppColors.brown,
                            ),
                            SizedBox(width: 10,),
                            Text('Предупреждение', style: AppText.medium_20,),
                          ],
                        ),
                        content: Text(
                          'Если вы используете VPN, оплата может работать некорректно.\n\n'
                          'Рекомендуем временно отключить VPN для успешного завершения платежа.',
                          style: AppText.medium_14.copyWith(color: AppColors.grey),
                        ),
                        actions: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                side: BorderSide(color: AppColors.brown, width: 1.5),
                                backgroundColor: AppColors.brown
                              ),
                              child: Text(
                                'Продолжить',
                                style: AppText.semibold_18.copyWith(color: AppColors.white),
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                side: BorderSide(color: AppColors.brown, width: 1.5),
                              ),
                              child: Text(
                                'Отмена',
                                style: AppText.semibold_18.copyWith(color: AppColors.brown),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true || !mounted) return;

                    final result = await context.pushNamed<bool>(
                      'payment_webview',
                      extra: widget.args.paymentUrl,
                    );

                    debugPrint(
                      'PaymentPage: вернулись из payment_webview с результатом: $result',
                    );

                    if (result == true && mounted) {
                      // Успешная оплата
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Оплата прошла успешно!'),
                          backgroundColor: Colors.brown,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      // Переходим на главную
                      if (mounted) {
                        context.go('/');
                      }
                    } else if (result == false && mounted) {
                      // Отмена оплаты
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Платёж отменён'),
                          backgroundColor: AppColors.white_transparent,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Оплатить',
                    style: AppText.semibold_18.copyWith(color: AppColors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Кнопка отмены
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.go('/cart');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    side: BorderSide(color: AppColors.brown, width: 1.5),
                  ),
                  child: Text(
                    'Отмена',
                    style: AppText.semibold_18.copyWith(color: AppColors.brown),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
