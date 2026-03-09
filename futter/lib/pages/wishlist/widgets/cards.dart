import 'package:flutter/material.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/components/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:azalia/components/widgets/love.dart';
import 'package:azalia/components/widgets/cart.dart';

class WishlistCard extends StatefulWidget {
  final Plant plant;
  final Function(Plant)? onWishlistUpdated;
  final Function(bool)? onCartUpdated;

  const WishlistCard({
    super.key,
    required this.plant,
    this.onWishlistUpdated,
    this.onCartUpdated,
  });

  @override
  State<WishlistCard> createState() => _WishlistCardState();
}

class _WishlistCardState extends State<WishlistCard> {
  bool _hasImageError = false;
  bool _showCard = true;

  void _handleWishlistUpdate(bool isFavorite) {
    if (!isFavorite) {
      setState(() {
        _showCard = false;
      });
      widget.onWishlistUpdated?.call(widget.plant);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showCard) {
      return const SizedBox.shrink();
    }

    final bool isOutOfStock =
        !widget.plant.inStock || widget.plant.stockQuantity <= 0;

    return Padding(
      padding: const EdgeInsets.only(right: 24, left: 24, top: 16),
      child: isOutOfStock ? _buildOutOfStockCard() : _buildNormalCard(),
    );
  }

  Widget _buildNormalCard() {
    return Row(
      children: [
        _buildPlantImage(),
        const SizedBox(width: 20),
        _buildPlantInfo(),
      ],
    );
  }

  Widget _buildOutOfStockCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey_light.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey_light),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildPlantImage(outOfStock: true),
            const SizedBox(width: 16),
            _buildOutOfStockInfo(),
            _buildRemoveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantImage({bool outOfStock = false}) {
    return Container(
      width: outOfStock ? 80 : 113,
      height: outOfStock ? 60 : 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.white,
      ),
      child: Stack(
        children: [
          Container(
            width: outOfStock ? 80 : 113,
            height: outOfStock ? 60 : 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: outOfStock
                  ? AppColors.grey_light.withOpacity(0.1)
                  : AppColors.white,
            ),
          ),
          _hasImageError
              ? _buildErrorPlaceholder(outOfStock: outOfStock)
              : _buildCachedImage(outOfStock: outOfStock),
          if (outOfStock)
            Container(
              width: outOfStock ? 80 : 113,
              height: outOfStock ? 60 : 88,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            ),
          if (outOfStock != true)
            Positioned(
              bottom: 4,
              right: 4,
              child: FavoriteButton(
                plant: widget.plant,
                size: 24,
                activeColor: AppColors.brown,
                onStateChanged: _handleWishlistUpdate,
                showSnackbar: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder({bool outOfStock = false}) {
    return Container(
      width: outOfStock ? 80 : 113,
      height: outOfStock ? 60 : 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.grey_light,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: outOfStock ? 18 : 24,
            color: AppColors.grey,
          ),
          SizedBox(height: outOfStock ? 2 : 4),
          Text(
            'Повторить',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (outOfStock ? AppText.medium_12 : AppText.medium_12)
                .copyWith(
                  color: AppColors.grey,
                  fontSize: outOfStock ? 10 : null,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedImage({bool outOfStock = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: widget.plant.fullImageUrl,
        width: outOfStock ? 80 : 113,
        height: outOfStock ? 60 : 88,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            _buildLoadingIndicator(outOfStock: outOfStock),
        errorWidget: (context, url, error) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasImageError = true;
              });
            }
          });
          return _buildErrorPlaceholder(outOfStock: outOfStock);
        },
        cacheKey: widget.plant.fullImageUrl,
        maxWidthDiskCache: 300,
        maxHeightDiskCache: 300,
      ),
    );
  }

  Widget _buildLoadingIndicator({bool outOfStock = false}) {
    return Container(
      width: outOfStock ? 80 : 113,
      height: outOfStock ? 60 : 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.grey_light,
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildPlantInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.plant.name,
                  style: AppText.bold_18.copyWith(color: AppColors.black),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.plant.rating != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/icons/Star.svg'),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.plant.rating}',
                      style: AppText.semibold_13.copyWith(
                        color: AppColors.star,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Высота до ${widget.plant.heightCm} см',
              style: AppText.medium_14.copyWith(
                color: AppColors.black_transparent,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                '${widget.plant.basePrice} ₽',
                style: AppText.medium_16.copyWith(color: AppColors.black),
              ),
              const Spacer(),
              CartButton(
                plant: widget.plant,
                onStateChanged: widget.onCartUpdated,
                size: 32,
                showBackground: true,
                inactiveColor: AppColors.white_dark.withOpacity(0.6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfStockInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.plant.name,
            style: AppText.bold_20.copyWith(
              color: AppColors.grey,
              decoration: TextDecoration.lineThrough,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Высота до ${widget.plant.heightCm} см',
            style: AppText.medium_14.copyWith(
              color: AppColors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.plant.basePrice} ₽',
            style: AppText.medium_16.copyWith(
              color: AppColors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Нет в наличии',
              style: AppText.medium_12.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveButton() {
    return IconButton(
      onPressed: () {
        setState(() {
          _showCard = false;
        });
        widget.onWishlistUpdated?.call(widget.plant);
      },
      icon: Icon(Icons.close, color: AppColors.grey, size: 20),
    );
  }
}
