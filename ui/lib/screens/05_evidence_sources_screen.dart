import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/assessment_model.dart';

class EvidenceSourcesScreen extends StatefulWidget {
  const EvidenceSourcesScreen({super.key});

  @override
  State<EvidenceSourcesScreen> createState() => _EvidenceSourcesScreenState();
}

class _EvidenceSourcesScreenState extends State<EvidenceSourcesScreen> {
  int _selectedTab = 0; // 0: الأدلة المسترجعة, 1: مرجعية WHO IMCI, 2: لماذا هذه المصادر؟

  String _cleanEvidenceText(String text) {
    return text
        .replaceAll(RegExp(r'[#*▼▲■●➤►\u25bc\u25b2\u25a0\u25cf\u27a4_`~]'), '')
        .replaceAll(RegExp(r'--+|===+'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final evidences = state.currentAssessment?.evidenceList ?? [];

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
              'الأدلة السريرية الداعمة',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.verified_rounded, color: AppColors.primary, size: 24),
                onPressed: () {},
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter Tabs Bar
                _buildFilterTabs(evidences.length),

                const SizedBox(height: 20),

                if (_selectedTab == 2)
                  _buildWhySourcesCard()
                else if (_selectedTab == 1)
                  _buildWhoProtocolCard()
                else ...[
                  if (evidences.isEmpty)
                    _buildEmptyEvidenceCard()
                  else
                    // Dynamic List of Genuine Retrieved WHO IMCI Evidence Chunks (Sorted Descending)
                    ...(List<EvidenceItem>.from(evidences)..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore))).asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final evidence = entry.value;
                      return _buildEvidenceCard(context, index, evidence);
                    }),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterTabs(int count) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'الأدلة ($count)'),
          _buildTabItem(1, 'مرجعية IMCI'),
          _buildTabItem(2, 'لماذا هذه المصادر؟'),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceCard(BuildContext context, int index, EvidenceItem evidence) {
    final double normalizedScore = evidence.relevanceScore <= 1.0 && evidence.relevanceScore > 0.0
        ? evidence.relevanceScore * 100.0
        : evidence.relevanceScore.clamp(0.0, 100.0);
    final scoreText = '${normalizedScore.toStringAsFixed(1)}% تطابق';

    final cleanedHighlight = _cleanEvidenceText(evidence.highlightText);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Index & Source Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1B4B),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إرشادات منظمة الصحة العالمية (WHO IMCI)',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            evidence.section,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          evidence.page,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Verbatim Retrieved Highlighted Text (Cleaned & LTR Directionality for English)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFEF08A), width: 1),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                cleanedHighlight,
                textAlign: TextAlign.left,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.6,
                  color: const Color(0xFF854D0E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Footer: Relevance Score & Full text button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      scoreText,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showFullTextModal(context, evidence),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  'عرض النص الكامل',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEvidenceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'لا توجد نصوص إرشادية مسترجعة لهذه الحالة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'قد تكون الحالة خارج نطاق دليل WHO IMCI أو أن نسبة التطابق السريري أقل من الحد الأدنى المقبول للأمان.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoProtocolCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الدليل المرجعي: WHO IMCI Guidelines',
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'بروتوكول التدبير المتكامل لصحة الطفل (Integrated Management of Childhood Illness) هو المعيار العالمي المعتمد من منظمة الصحة العالمية واليونيسف لتقييم وتصنيف وعلاج الحالات الشائعة والخطرة للأطفال من عمر الولادة حتى 5 سنوات.',
            style: GoogleFonts.cairo(fontSize: 13, height: 1.6, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWhySourcesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أمان وموثوقية القرارات السريرية',
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'تعتمد منظومة PediaCare.AI حصراً على الدليل الإرشادي الرسمي الصادر عن منظمة الصحة العالمية (WHO IMCI) بعد فهرسته دلالياً في قاعدة بيانات متجهة ChromaDB. يتم التحقق من درجة الصلة الرياضية (Cosine Similarity) قبل توليد أي استجابة لضمان دقة القرارات ومنع أي استنتاج غير موثق.',
            style: GoogleFonts.cairo(fontSize: 13, height: 1.6, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showFullTextModal(BuildContext context, EvidenceItem evidence) {
    final cleanFullText = _cleanEvidenceText(evidence.highlightText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'إرشادات منظمة الصحة العالمية (WHO IMCI)',
              style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              '${evidence.section} • ${evidence.page}',
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    cleanFullText,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.7,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Center(child: Text('إغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
            ),
          ],
        ),
      ),
    );
  }
}
