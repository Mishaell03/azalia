import 'package:azalia/components/text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/components/colors.dart';
import 'package:flutter_svg/svg.dart';
import 'package:azalia/pages/error/loading_error.dart';
import 'package:azalia/components/widgets/love.dart';
import 'package:azalia/components/widgets/cart.dart';

class HomeCard extends StatefulWidget {
  final Plant plant;
  final Function(bool)? onWishlistUpdated;
  final Function(bool)? onCartUpdated;

  const HomeCard({
    super.key,
    required this.plant,
    this.onWishlistUpdated,
    this.onCartUpdated,
  });

  @override
  State<HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<HomeCard> {
  bool _hasImageError = false;

  void _retryLoadImage() {
    setState(() {
      _hasImageError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            child: FavoriteButton(
              plant: widget.plant,
              size: 24,
              onStateChanged: widget.onWishlistUpdated,
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
    final imageUrl = widget.plant.fullImageUrl.trim();
    if (imageUrl.isEmpty) {
      return _buildEmptyPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
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
        cacheKey: imageUrl,
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

  Widget _buildEmptyPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.grey_light,
      ),
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
              CartButton(
                plant: widget.plant,
                onStateChanged: widget.onCartUpdated,
                size: 32,
                showBackground: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
