import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/assessment_model.dart';
import '../theme/app_theme.dart';
import '../widgets/triage_badge.dart';
import '05_evidence_sources_screen.dart';
import '06_doctor_summary_screen.dart';

class AssessmentResultScreen extends StatelessWidget {
  final AssessmentResponseModel assessment;

  const AssessmentResultScreen({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        // Use live recalculated assessment from Cubit if available, else original passed assessment
        final currentAsmt = state.currentAssessment ?? assessment;
        final child = state.activeChild;

        return Scaffold(
          appBar: AppBar(
            title: const Text('نتيجة التقييم السريري'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'مشاركة ملخص الحالة',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DoctorSummaryScreen(assessment: currentAsmt),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Hero Triage Badge Banner
              TriageBadgeWidget(
                triageLevel: currentAsmt.triageLevel,
                label: currentAsmt.detectedLanguage == 'en'
                    ? currentAsmt.triageLabelEn
                    : currentAsmt.triageLabelAr,
              ),
              const SizedBox(height: 18),

              // Child Header Bar
              if (child != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.child_care_rounded, size: 20, color: AppColors.medicalTeal),
                      const SizedBox(width: 8),
                      Text(
                        'الطفل: ${child.name} (${child.ageFormattedArabic}، ${child.weightKg} كجم)',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),

              // Section 1: ما الذي وجدناه؟ (Summary Findings)
              _buildCard(
                title: 'ما الذي وجدناه؟ 🔎',
                icon: Icons.checklist_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...currentAsmt.summaryFound.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16, color: AppColors.medicalTeal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s,
                                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section 2: التوصية والإجراءات العاجلة
              _buildCard(
                title: 'التوصية السريرية وخطة التدبير 📋',
                icon: Icons.medical_information_outlined,
                child: Text(
                  currentAsmt.fullRecommendation,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Section 3: أسئلة التحقق التفريقي اللحظية (0ms Dynamic Recalculation)
              if (currentAsmt.missingInfo.isNotEmpty)
                _buildCard(
                  title: 'معلومات نحتاجها للتحقق التفريقي ❓',
                  icon: Icons.help_outline_rounded,
                  headerColor: AppColors.clinicalAmberDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجابتك على هذه الأسئلة تعيد احتساب درجة الخطورة فورياً (0ms):',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      ...currentAsmt.missingInfo.map((q) {
                        final currentAns = currentAsmt.verificationAnswers[q];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q,
                                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      label: Center(
                                        child: Text('نعم 🔴', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                      ),
                                      selected: currentAns == true,
                                      onSelected: (val) {
                                        context.read<AssessmentCubit>().recalculateWithVerification(q, true);
                                      },
                                      selectedColor: AppColors.emergencyRedBg,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ChoiceChip(
                                      label: Center(
                                        child: Text('لا 🟢', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                      ),
                                      selected: currentAns == false,
                                      onSelected: (val) {
                                        context.read<AssessmentCubit>().recalculateWithVerification(q, false);
                                      },
                                      selectedColor: AppColors.safeEmeraldBg,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Navigation Actions
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EvidenceSourcesScreen(evidenceList: currentAsmt.evidenceList),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('عرض التفاصيل والأدلة السريرية (WHO) 📖'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DoctorSummaryScreen(assessment: currentAsmt),
                    ),
                  );
                },
                icon: const Icon(Icons.summarize_rounded),
                label: const Text('عرض ملخص للطبيب بنظام SBAR 🩺'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color? headerColor,
  }) {
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
            children: [
              Icon(icon, size: 20, color: headerColor ?? AppColors.medicalTeal),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: headerColor ?? AppColors.slateNavy,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          child,
        ],
      ),
    );
  }
}
