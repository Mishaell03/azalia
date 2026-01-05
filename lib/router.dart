import 'package:azalia/pages/admin/pages/analytics.dart';
import 'package:azalia/pages/admin/pages/flowers.dart';
import 'package:azalia/pages/admin/pages/settings.dart';
import 'package:azalia/pages/admin/pages/user.dart';
import 'package:azalia/pages/wishlist/wishlistpage.dart';
import 'package:go_router/go_router.dart';

import 'package:azalia/pages/home/homepage.dart';
import 'package:azalia/pages/error/error_page.dart';
import 'package:azalia/pages/auth/authpage.dart';
import 'package:azalia/pages/profile/profilepage.dart';
import 'package:azalia/pages/cart/cartpage.dart';

class AppRouter {
  late final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
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
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPageAnalytics(),
        routes: [
          GoRoute(
            path: 'settings',
            name: 'adminSettings',
            builder: (context, state) => const AdminPageSettings(),
          ),
          GoRoute(
            path: 'users',
            name: 'adminUsers',
            builder: (context, state) => const AdminPageUser(),
          ),
          GoRoute(
            path: 'flowers',
            name: 'adminFlowers',
            builder: (context, state) => const AdminPageFlowers(),
          ),
        ],
      ),
    ],
    errorBuilder:(context, state) => ErrorPage(),
  );
}
