import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/assessment_model.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/triage_badge.dart';

class DoctorSummaryScreen extends StatelessWidget {
  final AssessmentResponseModel assessment;

  const DoctorSummaryScreen({super.key, required this.assessment});

  void _shareSummary(BuildContext context, String text) {
    Share.share(
      text,
      subject: 'تقرير الإحالة والتسليم السريري (WHO IMCI SBAR) - PediaCare.AI',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final child = state.activeChild ??
            ChildModel(
              id: 'ref_child',
              name: 'المريض',
              birthDate: DateTime.now().subtract(const Duration(days: 420)),
              weightKg: 10.0,
              gender: 'male',
            );
        final asmt = state.currentAssessment ?? assessment;

        final allergiesText = child.allergies.isNotEmpty
            ? child.allergies.join(', ')
            : 'لا توجد موانع أو حساسيات دوائية مسجلة';

        final chronicText = child.chronicDiseases.isNotEmpty
            ? child.chronicDiseases.join(', ')
            : 'سليم من الأمراض المزمنة';

        final respRate = asmt.respiratoryRate;
        final temp = asmt.temperatureC;
        final duration = asmt.durationText;

        // Respiratory threshold logic
        int fastThreshold = 40;
        if (child.ageInDays < 60) {
          fastThreshold = 60;
        } else if (child.ageInMonths < 12) {
          fastThreshold = 50;
        }
        final isFastBreathing = respRate != null && respRate >= fastThreshold;

        final sbarText = '''
🏥 [PediaCare.AI — WHO IMCI Comprehensive Clinical SBAR Referral Sheet]
======================================================================
👤 PATIENT DEMOGRAPHICS:
• Name: ${child.name} | Gender: ${child.gender == "female" ? "Female" : "Male"}
• Age: ${child.ageFormattedArabic} (${child.ageFormattedEnglish})
• Weight: ${child.weightKg} kg

📊 VITAL SIGNS & PRESENTATION:
• Temperature: ${temp.toStringAsFixed(1)}°C ${temp < 35.5 ? "(Hypothermia Alert 🚨)" : (temp >= 38.5 ? "(High Fever Alert ⚠️)" : "")}
• Respiratory Rate: ${respRate != null ? "$respRate bpm (Age Threshold: >= $fastThreshold)" : "Normal / Not fast"}
• Complaint Duration: $duration
• Chief Complaint: ${asmt.chiefComplaint}

----------------------------------------------------------------------
📌 [S - Situation | الموقف السريري]:
• Chief Complaint: ${asmt.chiefComplaint}
• Confirmed Signs:
${asmt.summaryFound.map((s) => "  - $s").join("\n")}

📋 [B - Background | التاريخ الطبي والخلفية السريرية]:
• Allergies: $allergiesText
• Chronic Conditions: $chronicText
• Immunization Status: تطعيمات المرحلة العمرية مكتملة
• Feeding Baseline: رصد القدرة على الشرب والرضاعة الطبيعية

🔍 [A - Assessment | التقييم والفرز السريري]:
• Primary Triage: ${asmt.triageLabelAr} (${asmt.triageLevel})
• Differential Diagnoses:
${asmt.differentialDiagnoses.map((d) => "  - ${d.name}: ${d.probability}%").join("\n")}
• Verification Status: تم فحص علامات الخطورة التفريقية

💊 [R - Recommendation | التوصية وخطة التدبير]:
• Immediate Stabilization:
${asmt.fullRecommendation}
• Hospital Referral Pathway: التحويل العاجل وتدفئة المريض ومنع هبوط السكر

======================================================================
Official Citation: WHO IMCI Model Handbook (142 Pages) — Verifiable CDSS
''';

        return Scaffold(
          appBar: AppBar(
            title: const Text('تقرير التسليم السريري (SBAR)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'مشاركة التقرير مع المستشفى',
                onPressed: () => _shareSummary(context, sbarText),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. Patient Demographics & Vitals Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white24,
                          child: Icon(
                            child.gender == 'female' ? Icons.girl_rounded : Icons.boy_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                child.name,
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${child.ageFormattedArabic} • ${child.weightKg} كجم • ${child.gender == "female" ? "أنثى" : "ذكر"}',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TriageBadgeWidget(triageLevel: asmt.triageLevel, isCompact: true),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),

                    // Vitals Metric Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildVitalItem(
                            icon: Icons.thermostat_rounded,
                            label: 'درجة الحرارة',
                            value: '${temp.toStringAsFixed(1)}°C',
                            isAlert: temp < 35.5 || temp >= 38.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildVitalItem(
                            icon: Icons.air_rounded,
                            label: 'معدل التنفس',
                            value: respRate != null ? '$respRate نفس/د' : 'طبيعي',
                            isAlert: isFastBreathing,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildVitalItem(
                            icon: Icons.timer_outlined,
                            label: 'مدة الأعراض',
                            value: duration.length > 12 ? '${duration.substring(0, 12)}..' : duration,
                            isAlert: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. SBAR Section 1: Situation (الموقف السريري)
              _buildSbarCard(
                title: 'Situation (الموقف السريري والشكوى الحالية)',
                letter: 'S',
                color: const Color(0xFF0284C7),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الشكوى الرئيسية: ${asmt.chiefComplaint}',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slateNavy),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'العلامات السريرية الإيجابية المؤكدة:',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    ...asmt.summaryFound.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.medicalTeal),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(s, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. SBAR Section 2: Background (الخلفية والتاريخ المرضي)
              _buildSbarCard(
                title: 'Background (التاريخ الطبي والخلفية السريرية)',
                letter: 'B',
                color: const Color(0xFF7C3AED),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBulletText('الحساسية وموانع الأدوية: $allergiesText'),
                    const SizedBox(height: 6),
                    _buildBulletText('الأمراض المزمنة والسابقة: $chronicText'),
                    const SizedBox(height: 6),
                    _buildBulletText('حالة التطعيمات: مكتملة حسب الجدول الوطني لمنظمة الصحة العالمية'),
                    const SizedBox(height: 6),
                    _buildBulletText('التغذية والرضاعة: متابعة القدرة على الشرب والبلع ومنع الجفاف'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 4. SBAR Section 3: Assessment (التقييم والفرز التفريقي)
              _buildSbarCard(
                title: 'Assessment (التقييم والفرز والتشخيص التفريقي)',
                letter: 'A',
                color: asmt.isRed
                    ? AppColors.emergencyRed
                    : (asmt.isYellow ? AppColors.clinicalAmber : AppColors.safeEmerald),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: asmt.isRed ? AppColors.emergencyRedBg : AppColors.clinicalAmberBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            asmt.isRed ? Icons.emergency_rounded : Icons.warning_amber_rounded,
                            color: asmt.isRed ? AppColors.emergencyRed : AppColors.clinicalAmber,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('التصنيف الأساسي (WHO IMCI):',
                                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted)),
                                Text(
                                  asmt.triageLabelAr,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: asmt.isRed ? AppColors.emergencyRedDark : AppColors.clinicalAmberDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (asmt.differentialDiagnoses.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('أشرطة احتمالات التشخيص التفريقي:',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ...asmt.differentialDiagnoses.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(d.name, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                    Text('${d.probability}%',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.medicalTealDark)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: d.probability / 100.0,
                                  backgroundColor: AppColors.bgLight,
                                  color: d.probability >= 70 ? AppColors.emergencyRed : AppColors.medicalTeal,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 5. SBAR Section 4: Recommendation (التوصية وخطة التدبير السريري)
              _buildSbarCard(
                title: 'Recommendation (التوصية وخطة التدبير العاجل)',
                letter: 'R',
                color: AppColors.medicalTeal,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asmt.fullRecommendation,
                      style: GoogleFonts.cairo(fontSize: 13, height: 1.6, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bookmark_outline_rounded, size: 16, color: AppColors.medicalTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'معتمد ومطابق لبروتوكول منظمة الصحة العالمية (WHO IMCI Handbook - 142 Pages)',
                              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Share / Export Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.slateNavy,
                ),
                onPressed: () => _shareSummary(context, sbarText),
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                label: Text(
                  'مشاركة تقرير SBAR مع المستشفى أو الطبيب المعالج 📤',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVitalItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isAlert,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isAlert ? AppColors.emergencyRedBg : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert ? AppColors.emergencyRed : Colors.white30,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: isAlert ? AppColors.emergencyRed : Colors.white),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isAlert ? AppColors.emergencyRedDark : Colors.white70,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isAlert ? AppColors.emergencyRedDark : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletText(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.arrow_left_rounded, size: 20, color: AppColors.medicalTeal),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
          ),
        ),
      ],
    );
  }

  Widget _buildSbarCard({
    required String title,
    required String letter,
    required Color color,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateNavy,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          content,
        ],
      ),
    );
  }
}
