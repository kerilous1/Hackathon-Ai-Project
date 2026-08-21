import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SyringeVisualizerWidget extends StatelessWidget {
  final double currentVolumeMl;
  final double maxVolumeMl;
  final String medicationName;
  final String frequencyText;

  const SyringeVisualizerWidget({
    super.key,
    required this.currentVolumeMl,
    this.maxVolumeMl = 10.0,
    required this.medicationName,
    required this.frequencyText,
  });

  @override
  Widget build(BuildContext context) {
    final fillFraction = (currentVolumeMl / maxVolumeMl).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'محقنة الجرعة الموصوفة 💉',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slateNavy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.medicalTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$currentVolumeMl مل',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.medicalTealDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Syringe Barrel Graphic
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight, width: 1.5),
            ),
            child: Stack(
              children: [
                // Liquid Fill
                FractionallySizedBox(
                  widthFactor: fillFraction,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF22D3EE)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.horizontal(
                        left: const Radius.circular(6),
                        right: Radius.circular(fillFraction >= 0.98 ? 6 : 0),
                      ),
                    ),
                  ),
                ),
                // Calibrated Ticks
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (index) {
                    final tickNum = index + 1;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 1.5,
                          height: 10,
                          color: AppColors.textMuted.withOpacity(0.5),
                        ),
                        Text(
                          '$tickNum',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Container(
                          width: 1.5,
                          height: 6,
                          color: AppColors.textMuted.withOpacity(0.3),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.medication_liquid_rounded, size: 16, color: AppColors.medicalTeal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$medicationName • $frequencyText',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
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
