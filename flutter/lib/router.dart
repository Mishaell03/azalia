import 'package:azalia/pages/admin/pages/analytics.dart';
import 'package:azalia/pages/admin/pages/flowers.dart';
import 'package:azalia/pages/admin/pages/settings.dart';
import 'package:azalia/pages/admin/pages/user.dart';
import 'package:azalia/pages/admin/widgets/products/cards/delivery.dart';
import 'package:azalia/pages/admin/widgets/products/cards/orders.dart';
import 'package:azalia/pages/admin/widgets/products/cards/procurement.dart';
import 'package:azalia/pages/admin/widgets/products/cards/receipts.dart';
import 'package:azalia/pages/admin/widgets/products/cards/editor.dart';
import 'package:azalia/pages/admin/widgets/products/cards/subscriptions.dart';
import 'package:azalia/pages/admin/widgets/products/cards/warehouse.dart';
import 'package:azalia/pages/payment/payment_webview.dart';
import 'package:azalia/pages/payment/paymentpage.dart';
import 'package:azalia/pages/plant/plant_details_page.dart';
import 'package:azalia/pages/profile/orders/order_details_page.dart';
import 'package:azalia/pages/profile/orders/order_history_page.dart';
import 'package:azalia/pages/profile/calendar/corporate_calendar_page.dart';
import 'package:azalia/pages/profile/calendar/important_dates_page.dart';
import 'package:azalia/pages/profile/calendar/plant_care_page.dart';
import 'package:azalia/pages/profile/calendar/profile_calendar_page.dart';
import 'package:azalia/pages/profile/subscriptions/subscription_checkout_page.dart';
import 'package:azalia/pages/profile/subscriptions/subscriptions_page.dart';
import 'package:azalia/pages/start/startpage.dart';
import 'package:azalia/pages/wishlist/wishlistpage.dart';
import 'package:azalia/components/colors.dart';
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
        routes: [
          GoRoute(
            path: 'orders',
            name: 'profileOrders',
            builder: (context, state) => const OrderHistoryPage(),
          ),
          GoRoute(
            path: 'orders/:orderId',
            name: 'profileOrderDetails',
            builder: (context, state) {
              final orderId = int.tryParse(
                state.pathParameters['orderId'] ?? '',
              );
              if (orderId == null) {
                return Scaffold(
                  backgroundColor: AppColors.white,
                  appBar: AppBar(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.black,
                    title: const Text('Ошибка'),
                  ),
                  body: const Center(child: Text('Некорректный номер заказа')),
                );
              }
              return OrderDetailsPage(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'subscriptions',
            name: 'profileSubscriptions',
            builder: (context, state) => const SubscriptionsPage(),
          ),
          GoRoute(
            path: 'subscriptions/checkout',
            name: 'profileSubscriptionCheckout',
            builder: (context, state) {
              final args = state.extra as SubscriptionCheckoutPageArgs?;
              if (args == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Ошибка')),
                  body: const Center(child: Text('Некорректные данные оплаты')),
                );
              }
              return SubscriptionCheckoutPage(args: args);
            },
          ),
          GoRoute(
            path: 'calendar',
            name: 'profileCalendar',
            builder: (context, state) => const ProfileCalendarPage(),
            routes: [
              GoRoute(
                path: 'important',
                name: 'profileCalendarImportant',
                builder: (context, state) => const ImportantDatesPage(),
              ),
              GoRoute(
                path: 'care',
                name: 'profileCalendarCare',
                builder: (context, state) => const PlantCarePage(),
              ),
              GoRoute(
                path: 'corporate',
                name: 'profileCalendarCorporate',
                builder: (context, state) => const CorporateCalendarPage(),
              ),
            ],
          ),
        ],
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
        path: '/plant/:plantId',
        name: 'plantDetails',
        builder: (context, state) {
          final plantId = int.tryParse(state.pathParameters['plantId'] ?? '');
          if (plantId == null || plantId <= 0) {
            return Scaffold(
              appBar: AppBar(title: const Text('Ошибка')),
              body: const Center(child: Text('Некорректный товар')),
            );
          }

          final extra = state.extra;
          PlantDetailsRouteArgs args;
          if (extra is PlantDetailsRouteArgs) {
            args = PlantDetailsRouteArgs(
              plantId: plantId,
              initialPotSize: extra.initialPotSize,
              initialPotMaterial: extra.initialPotMaterial,
              initialPotColor: extra.initialPotColor,
              initialQuantity: extra.initialQuantity,
            );
          } else {
            args = PlantDetailsRouteArgs(plantId: plantId);
          }

          return PlantDetailsPage(args: args);
        },
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
          final extra = state.extra;
          if (extra is! PaymentWebViewArgs) {
            return Scaffold(
              appBar: AppBar(title: const Text('Ошибка')),
              body: const Center(
                child: Text('Некорректные данные для страницы оплаты'),
              ),
            );
          }
          final args = extra;
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
                builder: (context, state) =>
                    const AdminProductsCartProcurement(),
              ),
              GoRoute(
                path: 'warehouse',
                name: 'adminProductsWarehouse',
                builder: (context, state) => const AdminProductsCartWarehouse(),
              ),
              GoRoute(
                path: 'editor',
                name: 'adminProductsEditor',
                builder: (context, state) => const AdminProductsCartEditor(),
              ),
              GoRoute(
                path: 'delivery',
                name: 'adminProductsDelivery',
                builder: (context, state) => const AdminProductsCartDelivery(),
              ),
              GoRoute(
                path: 'orders',
                name: 'adminProductsOrders',
                builder: (context, state) => const AdminProductsCartOrders(),
              ),
              GoRoute(
                path: 'receipts',
                name: 'adminProductsReceipts',
                builder: (context, state) => const AdminProductsCartReceipts(),
              ),
              GoRoute(
                path: 'subscriptions',
                name: 'adminProductsSubscriptions',
                builder: (context, state) =>
                    const AdminProductsCartSubscriptions(),
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
  final double totalPrice;
  final String? address;
  final String paymentMethod;
  final String paymentTiming;
  final String? onDeliveryMethod;
  final List<int> selectedItemIds;
  final List<PaymentItemArgs> items;

  PaymentRouteArgs({
    required this.totalPrice,
    this.address,
    required this.paymentMethod,
    this.paymentTiming = 'online',
    this.onDeliveryMethod,
    required this.selectedItemIds,
    required this.items,
  });
}

class PaymentWebViewArgs {
  final int paymentLinkId;
  final String paymentUrl;

  PaymentWebViewArgs({required this.paymentLinkId, required this.paymentUrl});
}

class PaymentItemArgs {
  final int cartItemId;
  final String plantName;
  final int quantity;
  final double plantPrice;
  final double potPrice;
  final double itemTotal;

  PaymentItemArgs({
    required this.cartItemId,
    required this.plantName,
    required this.quantity,
    required this.plantPrice,
    required this.potPrice,
    required this.itemTotal,
  });
}
