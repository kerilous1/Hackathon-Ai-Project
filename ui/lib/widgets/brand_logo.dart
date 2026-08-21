import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class BrandLogoWidget extends StatefulWidget {
  final double size;
  final bool showSubtitle;

  const BrandLogoWidget({
    super.key,
    this.size = 80,
    this.showSubtitle = true,
  });

  @override
  State<BrandLogoWidget> createState() => _BrandLogoWidgetState();
}

class _BrandLogoWidgetState extends State<BrandLogoWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.medicalTeal.withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.health_and_safety_rounded,
                size: widget.size * 0.55,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (widget.showSubtitle) ...[
          const SizedBox(height: 14),
          Text(
            'PediaCare.AI',
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.slateNavy,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'نظام دعم القرار السريري لطب الأطفال (WHO IMCI)',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
