import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../theme/app_theme.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/assessment_model.dart';
import '../widgets/triage_badge.dart';
import '../widgets/app_bottom_nav.dart';
import '02_child_selection_screen.dart';
import '08_symptom_timeline_screen.dart';
import '09_child_profile_screen.dart';
import '10_chat_history_screen.dart';

class DoctorDashboardScreen extends StatelessWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final child = state.activeChild;
        final assessment = state.currentAssessment;

        // Dynamic Duration Extraction
        String durationText = 'أعراض حديثة';
        if (assessment != null && assessment.summaryFound.isNotEmpty) {
          for (final item in assessment.summaryFound) {
            if (item.contains('مدة الأعراض')) {
              durationText = item.replaceAll('مدة الأعراض: ', '');
              break;
            }
          }
        }

        final diffList = assessment?.differentialDiagnoses ?? [];
        final evidenceList = assessment?.evidenceList ?? [];

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
              'لوحة تحكم الطبيب السريرية',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Overview Stats (100% Dynamic)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'نظرة عامة على المريض',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: _buildStatBox('العمر', child.ageDisplayAr)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatBox('الوزن', '${child.weight.toStringAsFixed(1)} كجم')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatBox('المدة', durationText)),
                  ],
                ),

                const SizedBox(height: 18),

                // Section 2: Triage Risk Badge Card (100% Dynamic)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'تصنيف الخطورة السريرية (WHO IMCI)',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TriageBadge(
                        triageLevel: assessment?.triageLevel ?? 'YELLOW',
                        label: assessment?.triageLabelAr ?? 'يحتاج إلى تقييم طبي',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Section 3: Differential Diagnosis Probabilities (100% Dynamic from Backend)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الاحتمالات التشخيصية التفريقية',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'مستخرجة آلياً بناءً على مصفوفة أدلة WHO IMCI والأعراض السريرية',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (diffList.isNotEmpty)
                        ...diffList.asMap().entries.map((entry) {
                          final index = entry.key + 1;
                          final diag = entry.value;
                          return _buildDiagnosisItem(index, diag);
                        })
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              'لا توجد احتمالات تفريقية مسجلة لهذا التقييم.',
                              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Section 4: Evidence & Protocol Sources Summary
                if (evidenceList.isNotEmpty) ...[
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
                            const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'الأدلة المرجعية المعتمدة (${evidenceList.length} مصادر)',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...evidenceList.map((ev) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${ev.section} (${ev.page})',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${ev.relevanceScore.toStringAsFixed(0)}%',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const SizedBox(height: 10),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: 2,
            isDoctorMode: true,
            onTap: (index) {
              context.read<AssessmentCubit>().setBottomNavIndex(index);
              if (index == 0) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChildSelectionScreen()));
              } else if (index == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
              } else if (index == 2) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SymptomTimelineScreen()));
              } else if (index == 3) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildProfileScreen()));
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisItem(int index, DifferentialDiagnosis diag) {
    final colors = [
      const Color(0xFFEF4444), // Red for #1 condition
      const Color(0xFFF59E0B), // Amber for #2
      const Color(0xFF6366F1), // Indigo for #3
    ];
    final color = colors[(index - 1) % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diag.name,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${diag.probability}%',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            lineHeight: 8.0,
            percent: (diag.probability / 100.0).clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF1F5F9),
            progressColor: color,
            barRadius: const Radius.circular(8),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
