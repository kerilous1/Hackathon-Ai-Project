import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChildAvatar extends StatelessWidget {
  final String avatarType; // 'boy', 'girl', 'doctor', 'parent', 'clinic'
  final double radius;
  final bool showBorder;
  final Color? borderColor;

  const ChildAvatar({
    super.key,
    this.avatarType = 'boy',
    this.radius = 28,
    this.showBorder = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppColors.primary,
                width: 2.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getGradientColors(),
            ),
          ),
          child: Center(
            child: _buildAvatarGraphic(),
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (avatarType) {
      case 'boy':
        return [const Color(0xFFFDE047), const Color(0xFFFACC15)];
      case 'girl':
        return [const Color(0xFFF472B6), const Color(0xFFEC4899)];
      case 'parent':
        return [const Color(0xFF38BDF8), const Color(0xFF0284C7)];
      case 'doctor':
        return [const Color(0xFF34D399), const Color(0xFF059669)];
      case 'clinic':
        return [const Color(0xFFA78BFA), const Color(0xFF7C3AED)];
      default:
        return [const Color(0xFFFDE047), const Color(0xFFFACC15)];
    }
  }

  Widget _buildAvatarGraphic() {
    switch (avatarType) {
      case 'boy':
        return Stack(
          alignment: Alignment.center,
          children: [
            // Head
            Container(
              width: radius * 1.3,
              height: radius * 1.3,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDBAC),
                shape: BoxShape.circle,
              ),
            ),
            // Hair
            Positioned(
              top: radius * 0.25,
              child: Container(
                width: radius * 1.25,
                height: radius * 0.65,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A2810),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
              ),
            ),
            // Face details
            Positioned(
              bottom: radius * 0.45,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: radius * 0.14, height: radius * 0.14, decoration: const BoxDecoration(color: Color(0xFF2D1E18), shape: BoxShape.circle)),
                  SizedBox(width: radius * 0.4),
                  Container(width: radius * 0.14, height: radius * 0.14, decoration: const BoxDecoration(color: Color(0xFF2D1E18), shape: BoxShape.circle)),
                ],
              ),
            ),
            // Smile
            Positioned(
              bottom: radius * 0.35,
              child: Container(
                width: radius * 0.3,
                height: radius * 0.12,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFB45309), width: 2),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'girl':
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: radius * 1.3,
              height: radius * 1.3,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE0BD),
                shape: BoxShape.circle,
              ),
            ),
            Positioned(
              top: radius * 0.2,
              child: Container(
                width: radius * 1.35,
                height: radius * 0.7,
                decoration: const BoxDecoration(
                  color: Color(0xFF854D0E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
              ),
            ),
            Positioned(
              bottom: radius * 0.45,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: radius * 0.14, height: radius * 0.14, decoration: const BoxDecoration(color: Color(0xFF3B1E08), shape: BoxShape.circle)),
                  SizedBox(width: radius * 0.4),
                  Container(width: radius * 0.14, height: radius * 0.14, decoration: const BoxDecoration(color: Color(0xFF3B1E08), shape: BoxShape.circle)),
                ],
              ),
            ),
            Positioned(
              bottom: radius * 0.35,
              child: Container(
                width: radius * 0.3,
                height: radius * 0.12,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE11D48), width: 2),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'doctor':
        return const Icon(Icons.medical_services_rounded, color: Colors.white, size: 28);
      case 'parent':
        return const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 28);
      case 'clinic':
        return const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28);
      default:
        return const Icon(Icons.person_rounded, color: Colors.white, size: 28);
    }
  }
}
