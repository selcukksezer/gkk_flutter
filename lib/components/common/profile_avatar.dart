import 'package:flutter/material.dart';

/// Selectable profile photos bundled in [assets/profile/].
abstract final class ProfilePhotoCatalog {
  static const String assetBase = 'assets/profile/';

  static const List<String> selectablePhotos = <String>[
    '${assetBase}profil1.png',
    '${assetBase}profil2.png',
    '${assetBase}profil3.png',
    '${assetBase}profil4.png',
    '${assetBase}profil5.png',
    '${assetBase}profil6.png',
    '${assetBase}profil7.png',
  ];
}

/// Square profile photo with light corner rounding.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.avatarUrl,
    this.backgroundColor,
    this.glowFrame = false,
    this.border,
    this.placeholderIconColor = Colors.white,
  });

  final double size;
  final String? avatarUrl;
  final Color? backgroundColor;
  final bool glowFrame;
  final BoxBorder? border;
  final Color placeholderIconColor;

  static double cornerRadiusFor(double size) => (size * 0.125).clamp(4, 10);

  @override
  Widget build(BuildContext context) {
    final double radius = cornerRadiusFor(size);
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white10,
        borderRadius: borderRadius,
        border: border,
        boxShadow: glowFrame
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImage(radius),
    );
  }

  Widget _buildImage(double radius) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return Center(
        child: Icon(
          Icons.person_rounded,
          color: placeholderIconColor,
          size: size * 0.5,
        ),
      );
    }

    final Widget image = avatarUrl!.startsWith('http')
        ? Image.network(
            avatarUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, Object error, StackTrace? stack) =>
                _placeholder(),
          )
        : Image.asset(
            avatarUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, Object error, StackTrace? stack) =>
                _placeholder(),
          );

    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        Icons.person_rounded,
        color: placeholderIconColor.withValues(alpha: 0.7),
        size: size * 0.5,
      ),
    );
  }
}
