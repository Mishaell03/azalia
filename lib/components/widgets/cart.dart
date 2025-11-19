import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/wishlist.dart';
import 'package:azalia/pages/error/app_errors.dart';

class CartButton extends StatefulWidget {
  final Plant plant;
  final bool showSnackbar;
  final Function(bool)? onStateChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showBackground;

  const CartButton({
    super.key,
    required this.plant,
    this.showSnackbar = true,
    this.onStateChanged,
    this.size = 32,
    this.activeColor,
    this.inactiveColor,
    this.showBackground = true,
  });

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton> {
  bool _isInCart = false;
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
      final isInCart = await _service.checkCartStatus();
      if (mounted) {
        setState(() {
          _isInCart = isInCart;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки статуса корзины: $e');
    }
  }

  void _addToCart() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _service.quickAddToCart();

      if (mounted) {
        setState(() {
          _isInCart = true;
        });
      }

      widget.onStateChanged?.call(true);

      if (mounted && widget.showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.white,
            content: Text(
              '${widget.plant.name} добавлен в корзину',
              style: AppText.medium_16.copyWith(
                color: AppColors.black_transparent,
              ),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      widget.onStateChanged?.call(false);

      final errorMessage = AppErrors.isUnauthorizedError(e.toString())
          ? AppErrors.unauthorizedMessage
          : 'Не удалось добавить в корзину';

      if (mounted && widget.showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.white,
            content: Text(
              errorMessage,
              style: AppText.medium_14.copyWith(color: AppColors.error),
            ),
            duration: const Duration(seconds: 3),
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
    final inactiveColor = widget.inactiveColor ?? AppColors.white_dark.withOpacity(0.6);

    return GestureDetector(
      onTap: _addToCart,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: widget.showBackground
            ? BoxDecoration(
                color: _isInCart ? activeColor.withOpacity(0.8) : inactiveColor,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: _isLoading
              ? SizedBox(
                  width: widget.size - 12,
                  height: widget.size - 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _isInCart ? AppColors.white : activeColor,
                  ),
                )
              : SvgPicture.asset(
                  'assets/icons/Bag.svg',
                  width: widget.size - 12,
                  height: widget.size - 12,
                  colorFilter: ColorFilter.mode(
                    _isInCart ? AppColors.white : activeColor,
                    BlendMode.srcIn,
                  ),
                ),
        ),
      ),
    );
  }
}