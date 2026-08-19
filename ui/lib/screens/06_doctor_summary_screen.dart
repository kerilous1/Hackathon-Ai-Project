import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../widgets/child_avatar.dart';
import '../widgets/triage_badge.dart';

class DoctorSummaryScreen extends StatelessWidget {
  const DoctorSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final child = state.activeChild;
        final assessment = state.currentAssessment;

        // Extract duration & chief complaint dynamically from summaryFound
        String durationText = 'أعراض بدأت حديثاً';
        String chiefComplaint = 'تقييم سريري شامل';
        final symptomsList = <String>[];

        if (assessment != null && assessment.summaryFound.isNotEmpty) {
          for (final item in assessment.summaryFound) {
            if (item.contains('مدة الأعراض')) {
              durationText = item;
            } else {
              symptomsList.add(item);
            }
          }
          if (symptomsList.isNotEmpty) {
            chiefComplaint = symptomsList.first;
          }
        }

        final missingQuestions = assessment?.missingInfo ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'ملخص الحالة للطبيب',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 24),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تصدير تقرير الحالة بنجاح بصيغة PDF', style: GoogleFonts.cairo()),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Child Header Profile Card (100% Dynamic)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      ChildAvatar(avatarType: child.avatarType, radius: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child.name,
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${child.ageDisplayAr} ، ${child.weight.toStringAsFixed(1)} كجم',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 2. Structured Clinical Summary Table Card (100% Dynamic from State)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('الشكوى الرئيسية', chiefComplaint),
                      const Divider(height: 20),
                      _buildSummaryRow('مدة الأعراض', durationText),
                      if (symptomsList.length > 1) ...[
                        const Divider(height: 20),
                        _buildSummaryRow('الأعراض المصاحبة', symptomsList.sublist(1).join(' ، ')),
                      ],
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'مستوى الخطورة',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TriageBadge(
                            triageLevel: assessment?.triageLevel ?? 'YELLOW',
                            label: assessment?.triageLabelAr ?? 'يحتاج إلى تقييم طبي',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Missing Information Checklist Card (100% Dynamic)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            missingQuestions.isNotEmpty ? Icons.help_outline_rounded : Icons.check_circle_outline_rounded,
                            color: missingQuestions.isNotEmpty ? const Color(0xFFEF4444) : AppColors.triageGreenBadge,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            missingQuestions.isNotEmpty ? 'معلومات مفقودة وأسئلة تحقق' : 'اكتمال الفحص السريري',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (missingQuestions.isNotEmpty)
                        ...missingQuestions.map((q) => _buildMissingItem(q))
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.triageGreenBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.triageGreenBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.triageGreenBadge, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تم استيفاء جميع علامات التحقق السريري المطلوبة في الاستفسار.',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.triageGreenText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 4. Share Button with Doctor
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم إنشاء رابط آمن لمشاركة الحالة مع الطبيب', style: GoogleFonts.cairo()),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'مشاركة مع الطبيب',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget _buildMissingItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
