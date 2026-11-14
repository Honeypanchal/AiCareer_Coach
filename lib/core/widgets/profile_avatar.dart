import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double radius;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoUrl = '',
    this.radius = 44,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    final hasPhoto = photoUrl.isNotEmpty;

    // Gradient circle with a soft ring; a photo fills it when there is one.
    final avatar = Container(
      padding: EdgeInsets.all(radius > 30 ? 3 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.hero,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: radius * 0.6,
            offset: Offset(0, radius * 0.15),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
        child: hasPhoto
            ? null
            : Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.78,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );

    final content = showEditBadge
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          )
        : avatar;

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
