import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/wishlist.dart';
import 'package:azalia/pages/error/app_errors.dart';

class FavoriteButton extends StatefulWidget {
  final Plant plant;
  final bool showSnackbar;
  final Function(bool)? onStateChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const FavoriteButton({
    super.key,
    required this.plant,
    this.showSnackbar = true,
    this.onStateChanged,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _isFavorite = false;
  bool _isLoading = false;
  late CartWishlistService _service;

  @override
  void initState() {
    super.initState();
    _service = CartWishlistService(plant: widget.plant);
    _loadInitialState();
  }

  void _loadInitialState() async {
    try {
      final isInWishlist = await _service.checkWishlistStatus();
      if (mounted) {
        setState(() {
          _isFavorite = isInWishlist;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки статуса избранного: $e');
    }
  }

  void _toggleFavorite() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _service.toggleWishlist(_isFavorite);

      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
        });
      }

      widget.onStateChanged?.call(_isFavorite);

      if (mounted && widget.showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.white,
            content: Text(
              _isFavorite ? 'Добавлено в избранное' : 'Удалено из избранного',
              style: AppText.medium_16.copyWith(
                color: AppColors.black_transparent,
              ),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      final errorMessage = AppErrors.isUnauthorizedError(e.toString())
          ? AppErrors.unauthorizedMessage
          : 'Не удалось обновить избранное';

      if (mounted && widget.showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: AppText.medium_14.copyWith(color: AppColors.error),
            ),
            backgroundColor: AppColors.white,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? AppColors.brown;
    final inactiveColor = widget.inactiveColor ?? AppColors.white.withOpacity(0.9);

    return GestureDetector(
      onTap: _toggleFavorite,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _isFavorite ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.white),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _isLoading
              ? SizedBox(
                  width: widget.size - 8,
                  height: widget.size - 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _isFavorite ? AppColors.white : activeColor,
                  ),
                )
              : SvgPicture.asset(
                  'assets/icons/Love.svg',
                  width: widget.size - 8,
                  height: widget.size - 8,
                  colorFilter: ColorFilter.mode(
                    _isFavorite ? AppColors.white : activeColor,
                    BlendMode.srcIn,
                  ),
                ),
        ),
      ),
    );
  }
}