import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/pages/error/loading_error.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/cart.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:azalia/pages/wishlist/widgets/cards.dart';
import 'package:azalia/pages/wishlist/widgets/header.dart';
import 'package:go_router/go_router.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  List<Plant> _wishlistPlants = [];
  bool _isLoading = true;
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
      });

      final token = await _sessionService.getToken();
      if (token == null) {
        context.go('/profile');
        return;
      }

      final wishlistResponse = await WishlistService.getWishlist(token);

      final plants = wishlistResponse.items.map((item) => item.plant).toList();

      setState(() {
        _wishlistPlants = plants;
        _isLoading = false;
      });
    } catch (e) {
      if (e.toString().contains('401') ||
          e.toString().contains('authorized') ||
          e.toString().contains('session') ||
          e.toString().contains('token')) {
        if (mounted) {
          context.go('/auth');
        }
        return;
      }

      setState(() {
        _error = 'Не удалось загрузить избранное';
        print(e);
        _isLoading = false;
      });
    }
  }

  void _onWishlistUpdated(Plant removedPlant) {
    setState(() {
      _wishlistPlants.removeWhere((plant) => plant.id == removedPlant.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WishlistHeader(),
      bottomNavigationBar: const AppFooter(),
      body: _isLoading
          ? const LoadingWidget()
          : _error.isNotEmpty
          ? GenericErrorWidget(onRetry: _loadWishlist)
          : _wishlistPlants.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadWishlist,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                itemCount: _wishlistPlants.length,
                itemBuilder: (context, index) {
                  final plant = _wishlistPlants[index];
                  return WishlistCard(
                    key: Key('wishlist_${plant.id}'),
                    plant: plant,
                    onWishlistUpdated: (removedPlant) {
                      _onWishlistUpdated(removedPlant);
                    },
                  );
                },
              ),
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
            width: 350,
          ),
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
}
