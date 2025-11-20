import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/profile/widgets/image.dart';

class AppProfileHeader extends StatelessWidget {
  final bool showExpandedHeader;
  final String userName;
  final String? positionTitle;
  final bool isEmployee;
  final File? selectedImageFile;
  final VoidCallback onEditPressed;
  final VoidCallback onImageTap;

  const AppProfileHeader({
    super.key,
    required this.showExpandedHeader,
    required this.userName,
    required this.positionTitle,
    required this.isEmployee,
    required this.selectedImageFile,
    required this.onEditPressed,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      leading: Padding(
        padding: const EdgeInsets.only(left: 24.0),
        child: IconButton(
          onPressed: () {
            context.goNamed('home');
          },
          icon: SvgPicture.asset('assets/icons/Back.svg'),
        ),
      ),
      leadingWidth: 80,
      title: showExpandedHeader
          ? null
          : Row(
              children: [
                AppProfileImage(
                  selectedImageFile: selectedImageFile,
                  onTap: () {},
                  size: 40,
                  cameraIconSize: 16,
                  showCameraIcon: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName.length > 15
                            ? '${userName.substring(0, 15)}...'
                            : userName,
                        style: AppText.bold_20.copyWith(color: AppColors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isEmployee && positionTitle != null)
                        Text(
                          positionTitle!,
                          style: AppText.medium_12.copyWith(
                            color: AppColors.brown,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      backgroundColor: AppColors.white,
      elevation: showExpandedHeader ? 0 : 1,
      shadowColor: AppColors.grey_light.withOpacity(0.3),
      pinned: true,
      expandedHeight: 220.0,
      actions: [
        IconButton(
          icon: Icon(Icons.edit, color: AppColors.brown),
          onPressed: onEditPressed,
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: showExpandedHeader
          ? FlexibleSpaceBar(
              background: Container(
                color: AppColors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppProfileImage(
                      selectedImageFile: selectedImageFile,
                      onTap:
                          () {},
                      size: 80,
                      cameraIconSize: 24,
                      showCameraIcon: false,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userName.length > 15
                          ? '${userName.substring(0, 15)}...'
                          : userName,
                      style: AppText.bold_23.copyWith(color: AppColors.black),
                    ),
                    const SizedBox(height: 8),
                    if (isEmployee && positionTitle != null)
                      Text(
                        positionTitle!,
                        style: AppText.medium_16.copyWith(
                          color: AppColors.brown,
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
