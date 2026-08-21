import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DisclaimerDialog extends StatelessWidget {
  const DisclaimerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.medicalTeal.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gavel_rounded,
                size: 32,
                color: AppColors.medicalTeal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'إخلاء المسؤولية الطبية والقانونية',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.slateNavy,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'نظام PediaCare.AI هو نظام ذكي لدعم القرار السريري مستند إلى دليل منظمة الصحة العالمية (WHO IMCI Model Handbook). '
                'هذا النظام مصمم لمساعدة مقدمي الرعاية الصحية والأسر في الفرز المبدئي، ولا يعتبر بديلاً عن الفحص الطبي المباشر أو التقييم السريري للطبيب المختص. '
                'في حالات الطوارئ القصوى، توجه فوراً إلى أقرب مستشفى أو قسم طوارئ أطفال.',
                textAlign: TextAlign.justify,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('أوافق وأفهم الشروط'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
