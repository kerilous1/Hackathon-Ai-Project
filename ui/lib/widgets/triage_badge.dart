import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TriageBadgeWidget extends StatelessWidget {
  final String triageLevel; // 'RED', 'YELLOW', 'GREEN', 'GRAY'
  final String? label;
  final bool isCompact;

  const TriageBadgeWidget({
    super.key,
    required this.triageLevel,
    this.label,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String defaultLabel;

    switch (triageLevel.toUpperCase()) {
      case 'RED':
        bg = AppColors.emergencyRedBg;
        border = AppColors.emergencyRedBorder;
        text = AppColors.emergencyRedDark;
        icon = Icons.emergency_rounded;
        defaultLabel = 'خطر عاجل - تحويل فوري للمستشفى 🔴';
        break;
      case 'YELLOW':
        bg = AppColors.clinicalAmberBg;
        border = AppColors.clinicalAmberBorder;
        text = AppColors.clinicalAmberDark;
        icon = Icons.warning_amber_rounded;
        defaultLabel = 'علاج نوعي في العيادة 🟡';
        break;
      case 'GREEN':
        bg = AppColors.safeEmeraldBg;
        border = AppColors.safeEmeraldBorder;
        text = AppColors.safeEmeraldDark;
        icon = Icons.check_circle_rounded;
        defaultLabel = 'رعاية منزلية آمنة 🟢';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = const Color(0xFF475569);
        icon = Icons.shield_outlined;
        defaultLabel = 'رفض سريري / خارج النطاق 🛡️';
    }

    final displayText = label ?? defaultLabel;

    if (isCompact) {
      String compactLabel;
      switch (triageLevel.toUpperCase()) {
        case 'RED':
          compactLabel = 'خطر عاجل 🔴';
          break;
        case 'YELLOW':
          compactLabel = 'علاج عيادة 🟡';
          break;
        case 'GREEN':
          compactLabel = 'رعاية منزلية 🟢';
          break;
        default:
          compactLabel = 'خارج النطاق 🛡️';
      }
      final displayText = label ?? compactLabel;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: text),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                displayText,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: text.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: text.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تصنيف الفرز السريري (WHO IMCI)',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: text.withOpacity(0.8),
                  ),
                ),
                Text(
                  displayText,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
