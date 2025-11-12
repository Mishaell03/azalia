import 'package:azalia/components/text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/components/colors.dart';
import 'package:flutter_svg/svg.dart';
import 'package:azalia/pages/error/loading_error.dart';

class PlantCard extends StatefulWidget {
  final Plant plant;

  const PlantCard({super.key, required this.plant});

  @override
  State<PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<PlantCard> {
  bool _hasImageError = false;
  bool _isFavorite = false;

  void _retryLoadImage() {
    setState(() {
      _hasImageError = false;
    });
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _addToCart() {
    // временная заглушка
    print('Добавлено в корзину: ${widget.plant.name}');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.plant.inStock) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 24, left: 24, top: 16),
      child: Row(
        children: [
          _buildPlantImage(),
          const SizedBox(width: 20),
          _buildPlantInfo(),
        ],
      ),
    );
  }

  Widget _buildPlantImage() {
    return Container(
      width: 113,
      height: 88,
      decoration: BoxDecoration(),
      child: Stack(
        children: [
          _hasImageError ? _buildErrorPlaceholder() : _buildCachedImage(),
          Positioned(
            bottom: 4,
            right: 4,
            child: GestureDetector(
              onTap: _toggleFavorite,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SvgPicture.asset(
                    'assets/icons/Love.svg',
                    width: 16,
                    height: 16,
                    color: _isFavorite ? AppColors.brown : AppColors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return GestureDetector(
      onTap: _retryLoadImage,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.grey_light,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 30, color: AppColors.grey),
            const SizedBox(height: 4),
            Text(
              'Повторить',
              style: AppText.medium_14.copyWith(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: widget.plant.fullImageUrl,
        width: 113,
        height: 88,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildLoadingIndicator(),
        errorWidget: (context, url, error) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasImageError = true;
              });
            }
          });
          return _buildErrorPlaceholder();
        },
        cacheKey: widget.plant.fullImageUrl,
        maxWidthDiskCache: 300,
        maxHeightDiskCache: 300,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.grey_light,
      ),
      child: const LoadingWidget(size: 20, strokeWidth: 2),
    );
  }

  Widget _buildPlantInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
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
          if (widget.plant.heightCm != null)
            Text(
              'Высота до ${widget.plant.heightCm} см',
              style: AppText.medium_14.copyWith(
                color: AppColors.black_transparent,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${widget.plant.basePrice} ₽',
                style: AppText.medium_16.copyWith(color: AppColors.black),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _addToCart,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.white_dark.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: SvgPicture.asset(
                      'assets/icons/Bag.svg',
                      width: 20,
                      height: 20,
                      color: AppColors.brown,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
