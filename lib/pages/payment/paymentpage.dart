import 'package:azalia/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaymentPage extends StatelessWidget {
  final PaymentRouteArgs args;

  const PaymentPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата')),
      body: Column(
        children: [
          Text('Заказ №${args.orderId}'),
          Text('Сумма к оплате'),
          ElevatedButton(
            onPressed: () async {
              final result = await context.pushNamed<bool>(
                'payment_webview',
                extra: args.paymentUrl,
              );
              // if (result == true){
              //   // успех
              // } else{
              //   // отмена
              // }
            },
            child: const Text('Перейти к оплате'),
          ),
        ],
      ),
    );
  }
}
