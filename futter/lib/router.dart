import 'package:azalia/pages/admin/pages/analytics.dart';
import 'package:azalia/pages/admin/pages/flowers.dart';
import 'package:azalia/pages/admin/pages/settings.dart';
import 'package:azalia/pages/admin/pages/user.dart';
import 'package:azalia/pages/admin/widgets/products/cards/delivery.dart';
import 'package:azalia/pages/admin/widgets/products/cards/orders.dart';
import 'package:azalia/pages/admin/widgets/products/cards/procurement.dart';
import 'package:azalia/pages/admin/widgets/products/cards/warehouse.dart';
import 'package:azalia/pages/payment/payment_webview.dart';
import 'package:azalia/pages/payment/paymentpage.dart';
import 'package:azalia/pages/start/startpage.dart';
import 'package:azalia/pages/wishlist/wishlistpage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import 'package:azalia/pages/home/homepage.dart';
import 'package:azalia/pages/error/error_page.dart';
import 'package:azalia/pages/auth/authpage.dart';
import 'package:azalia/pages/profile/profilepage.dart';
import 'package:azalia/pages/cart/cartpage.dart';

class AppRouter {
  AppRouter();

  late final GoRouter router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        name: 'start',
        builder: (context, state) => const AppStartPage(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/love',
        name: 'love',
        builder: (context, state) => const WishlistPage(),
      ),
      GoRoute(
        path: '/cart',
        name: 'cart',
        builder: (context, state) => const CartPage(),
      ),
      GoRoute(
        path: '/payment',
        name: 'payment',
        builder: (context, state) {
          try {
            final args = state.extra as PaymentRouteArgs?;
            if (args == null) {
              throw Exception('PaymentRouteArgs is null');
            }
            return PaymentPage(args: args);
          } catch (e) {
            debugPrint('Payment route error: $e');
            return Scaffold(
              appBar: AppBar(title: const Text('Ошибка')),
              body: Center(child: Text('Ошибка при загрузке: $e')),
            );
          }
        },
      ),
      GoRoute(
        path: '/payment/webview',
        name: 'payment_webview',
        builder: (context, state) {
          final args = state.extra as PaymentRouteArgs;
          return PaymentWebViewPage(
            paymentUrl: args.paymentUrl,
            paymentLinkId: args.paymentLinkId,
          );
        },
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPageAnalytics(),
        routes: [
          GoRoute(
            path: 'products',
            name: 'adminProducts',
            builder: (context, state) => const AdminPageProducts(),
            routes: [
              GoRoute(
                path: 'procurement',
                name: 'adminProductsProcurement',
                builder: (context, state) => const AdminProductsCartProcurement(),
              ),
              GoRoute(
                path: 'warehouse',
                name: 'adminProductsWarehouse',
                builder: (context, state) => const AdminProductsCartWarehouse(),
              ),
              GoRoute(
                path: 'delivery',
                name: 'adminProductsDelivery',
                builder: (context, state) => const AdminProductsCartDelivery(),
              ),GoRoute(
                path: 'orders',
                name: 'adminProductsOrders',
                builder: (context, state) => const AdminProductsCartOrders(),
              ),
            ],
          ),
          GoRoute(
            path: 'users',
            name: 'adminUsers',
            builder: (context, state) => const AdminPageUser(),
          ),
          GoRoute(
            path: 'settings',
            name: 'adminSettings',
            builder: (context, state) => const AdminPageSettings(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorPage(),
  );
}

class PaymentRouteArgs {
  final int paymentLinkId;
  final int orderId;
  final String paymentUrl;
  final double totalPrice;
  final String? address;
  final String paymentMethod;
  final List<PaymentItemArgs> items;

  PaymentRouteArgs({
    required this.paymentLinkId,
    required this.orderId,
    required this.paymentUrl,
    required this.totalPrice,
    this.address,
    required this.paymentMethod,
    required this.items,
  });
}

class PaymentItemArgs {
  final String plantName;
  final int quantity;
  final double plantPrice;
  final double potPrice;
  final double itemTotal;

  PaymentItemArgs({
    required this.plantName,
    required this.quantity,
    required this.plantPrice,
    required this.potPrice,
    required this.itemTotal,
  });
}
