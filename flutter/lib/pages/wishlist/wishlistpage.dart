import 'package:azalia/backend/services/wishlist.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/components/widgets/account_blocked_notice.dart';
import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/pages/error/loading_error.dart';
import 'package:azalia/pages/error/app_errors.dart';
import 'package:azalia/backend/models/wishlist.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:azalia/pages/wishlist/widgets/cards.dart';
import 'package:azalia/pages/wishlist/widgets/header.dart';
import 'package:azalia/pages/wishlist/widgets/unauthorized.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  List<WishlistItem> _availableItems = [];
  List<WishlistItem> _outOfStockItems = [];
  bool _isLoading = true;
  bool _isUnauthorized = false;
  String _error = '';
  final SessionService _sessionService = SessionService();

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
        _isUnauthorized = false;
      });

      if (!_sessionService.isLoggedIn || !_sessionService.isTokenValid) {
        _handleUnauthorized();
        return;
      }

      final wishlistResponse = await WishlistService.getWishlist();

      final List<WishlistItem> availableItems = [];
      final List<WishlistItem> outOfStockItems = [];

      for (final item in wishlistResponse.items) {
        final plant = item.plant;
        final isRemovedFromSale = !plant.isActive || plant.deletedAt != null;
        if (isRemovedFromSale) {
          outOfStockItems.add(item);
        } else {
          availableItems.add(item);
        }
      }

      setState(() {
        _availableItems = availableItems;
        _outOfStockItems = outOfStockItems;
        _isLoading = false;
      });
    } catch (e) {
      if (AppErrors.isForbiddenAccountError(e.toString())) {
        setState(() {
          _error = AppErrors.accountBlockedMessage;
          _isLoading = false;
          _isUnauthorized = false;
        });
        return;
      }

      if (e.toString().contains('401') ||
          e.toString().contains('authorized') ||
          e.toString().contains('session') ||
          e.toString().contains('token')) {
        _handleUnauthorized();
        return;
      }

      setState(() {
        _error = 'Не удалось загрузить избранное';
        debugPrint('Не удалось загрузить избранное: $e');
        _isLoading = false;
      });
    }
  }

  void _handleUnauthorized() {
    setState(() {
      _isUnauthorized = true;
      _isLoading = false;
    });
  }

  void _onWishlistUpdated(WishlistItem removedItem) {
    setState(() {
      _availableItems.removeWhere((item) => item.id == removedItem.id);
      _outOfStockItems.removeWhere((item) => item.id == removedItem.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnauthorized) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                color: AppColors.white,
                child: AppBar(
                  elevation: 0,
                  backgroundColor: AppColors.white,
                  leading: IconButton(
                    onPressed: () {
                      context.goNamed('home');
                    },
                    icon: SvgPicture.asset(
                      "assets/icons/Back.svg",
                      colorFilter: ColorFilter.mode(
                        AppColors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  title: Text(
                    "Избранное",
                    style: AppText.semibold_25.copyWith(color: AppColors.black),
                  ),
                  centerTitle: true,
                ),
              ),
              Expanded(child: WishlistUnauthorized()),
            ],
          ),
        ),
        bottomNavigationBar: const AppFooter(items: userFooterItems),
      );
    }
    return Scaffold(
      appBar: WishlistHeader(
        itemCount: _availableItems.length + _outOfStockItems.length,
      ),
      bottomNavigationBar: const AppFooter(items: userFooterItems),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_error.isNotEmpty) {
      if (_error == AppErrors.accountBlockedMessage) {
        return const AccountBlockedNotice();
      }
      return GenericErrorWidget(onRetry: _loadWishlist);
    }

    if (_availableItems.isEmpty && _outOfStockItems.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadWishlist,
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        children: [
          // доступные товары
          ..._availableItems.map(
            (item) => WishlistCard(
              key: Key('wishlist_${item.id}'),
              item: item,
              onWishlistUpdated: _onWishlistUpdated,
            ),
          ),

          // недоступные товары с разделителем
          if (_outOfStockItems.isNotEmpty) ...[
            _buildOutOfStockSection(),
            ..._outOfStockItems.map(
              (item) => WishlistCard(
                key: Key('wishlist_out_${item.id}'),
                item: item,
                onWishlistUpdated: _onWishlistUpdated,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/love.png',
            fit: BoxFit.contain,
            height: 250,
          ),
          const SizedBox(height: 30),
          Text(
            'В избранном пока пусто',
            style: AppText.bold_20.copyWith(color: AppColors.black),
          ),
          const SizedBox(height: 12),
          Text(
            'Добавляйте товары в избранное,\nчтобы не потерять',
            style: AppText.medium_16.copyWith(color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              context.goNamed('home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brown,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'На главную',
              style: AppText.medium_16.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfStockSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.grey_light),
          const SizedBox(height: 16),
          Text(
            'Нет в наличии',
            style: AppText.bold_18.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Эти товары временно недоступны',
            style: AppText.medium_14.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
