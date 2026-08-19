import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TriageBadge extends StatelessWidget {
  final String triageLevel; // 'RED', 'YELLOW', 'GREEN', 'REFUSAL'
  final String? label;
  final bool isLarge;

  const TriageBadge({
    super.key,
    required this.triageLevel,
    this.label,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final level = triageLevel.toUpperCase();
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String defaultLabel;

    switch (level) {
      case 'RED':
        bgColor = AppColors.triageRedBg;
        borderColor = AppColors.triageRedBorder;
        textColor = AppColors.triageRedText;
        icon = Icons.error_rounded;
        defaultLabel = 'خطر عاجل - تحويل فوري';
        break;
      case 'GREEN':
        bgColor = AppColors.triageGreenBg;
        borderColor = AppColors.triageGreenBorder;
        textColor = AppColors.triageGreenText;
        icon = Icons.check_circle_rounded;
        defaultLabel = 'لا توجد علامات خطر';
        break;
      case 'REFUSAL':
        bgColor = const Color(0xFFF1F5F9);
        borderColor = const Color(0xFFCBD5E1);
        textColor = const Color(0xFF475569);
        icon = Icons.shield_rounded;
        defaultLabel = 'خارج نطاق التقييم';
        break;
      case 'YELLOW':
      default:
        bgColor = AppColors.triageYellowBg;
        borderColor = AppColors.triageYellowBorder;
        textColor = AppColors.triageYellowText;
        icon = Icons.warning_amber_rounded;
        defaultLabel = 'يحتاج إلى تقييم طبي';
        break;
    }

    final displayText = label ?? defaultLabel;

    if (isLarge) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              'مستوى الخطورة',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  displayText,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              level == 'RED'
                  ? 'يجب التوجه فوراً إلى أقرب مستشفى أو وحدة طوارئ.'
                  : level == 'GREEN'
                      ? 'رعاية منزلية آمنة مع استمرار المتابعة والتغذية.'
                      : level == 'REFUSAL'
                          ? 'هذه الحالة خارج نطاق بروتوكول WHO IMCI. يرجى استشارة طبيب مختص.'
                          : 'لا توجد علامات خطر فورية، لكن يفضل استشارة طبيب...',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: textColor.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
