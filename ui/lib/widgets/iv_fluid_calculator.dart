import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';

class IvFluidCalculatorWidget extends StatelessWidget {
  final ChildModel child;

  const IvFluidCalculatorWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final w = child.weightKg;
    final isUnder12m = child.ageInMonths < 12.0;

    final totalFluid = (w * 100.0).toStringAsFixed(0);
    final stage1Vol = (w * 30.0).toStringAsFixed(0);
    final stage2Vol = (w * 70.0).toStringAsFixed(0);

    final stage1Time = isUnder12m ? 'ساعة واحدة (60 دقيقة)' : '30 دقيقة';
    final stage2Time = isUnder12m ? '5 ساعات' : 'ساعتان ونصف';
    final totalDuration = isUnder12m ? '6 ساعات' : '3 ساعات';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emergencyRedBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.emergencyRed.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_rounded, color: AppColors.emergencyRed, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حاسبة إنعاش الجفاف الشديد (الخطة ج)',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slateNavy,
                      ),
                    ),
                    Text(
                      'محلول رينجر لاكتات وريدي (100 مل/كجم)',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.emergencyRedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'الحجم الإجمالي المطلوب:',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emergencyRedDark,
                  ),
                ),
                Text(
                  '$totalFluid مل على مدار $totalDuration',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.emergencyRedDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stages
          _buildStageRow('المرحلة 1 (30 مل/كجم):', '$stage1Vol مل خلال $stage1Time', Icons.looks_one_rounded),
          const SizedBox(height: 8),
          _buildStageRow('المرحلة 2 (70 مل/كجم):', '$stage2Vol مل خلال $stage2Time', Icons.looks_two_rounded),

          const SizedBox(height: 10),
          Text(
            '⚠️ افحص النبض وتروية الأطراف كل ساعة. بمجرد قدرة الطفل على الشرب، ابدأ محلول ORS الفموي (5 مل/كجم/ساعة).',
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageRow(String title, String desc, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.medicalTeal),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.medicalTealDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
