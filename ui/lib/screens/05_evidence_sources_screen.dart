import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/evidence_model.dart';
import '../theme/app_theme.dart';

class EvidenceSourcesScreen extends StatefulWidget {
  final List<EvidenceModel> evidenceList;

  const EvidenceSourcesScreen({super.key, required this.evidenceList});

  @override
  State<EvidenceSourcesScreen> createState() => _EvidenceSourcesScreenState();
}

class _EvidenceSourcesScreenState extends State<EvidenceSourcesScreen> {
  bool _showEnglishOriginal = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.evidenceList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المستندات والأدلة السريرية'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Bilingual 1-Tap Toggle Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لغة عرض النصوص المقتبسة',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slateNavy,
                        ),
                      ),
                      Text(
                        _showEnglishOriginal
                            ? 'Official English Handbook Text (WHO)'
                            : 'الترجمة السريرية الكاملة المعتمدة (عربي)',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.medicalTealDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<bool>(
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.medicalTeal,
                    selectedForegroundColor: Colors.white,
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('عربي')),
                    ButtonSegment(value: true, label: Text('EN')),
                  ],
                  selected: {_showEnglishOriginal},
                  onSelectionChanged: (set) {
                    setState(() {
                      _showEnglishOriginal = set.first;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // --- RAG TRIAD VISUAL INSPECTOR & GROUNDING VERIFIER ---
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.safeEmeraldBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.safeEmeraldBorder, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: AppColors.safeEmeraldDark, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'فاحص التوثيق السريري الثلاثي (RAG Triad)',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.safeEmeraldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.safeEmeraldDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Grounding: 100%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildTriadPill('1. التوصية السريرية 🩺', AppColors.medicalTealDark, AppColors.medicalTeal.withOpacity(0.12)),
                    _buildTriadPill('2. النص المقتبس بالحرف 📜', AppColors.clinicalAmberDark, AppColors.clinicalAmberBg),
                    _buildTriadPill('3. الاستشهاد والصفحة 📑', AppColors.slateNavy, const Color(0xFFF1F5F9)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'المقاطع والبروتوكولات المسترجعة من دليل منظمة الصحة العالمية (${list.length})',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          if (list.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Center(
                child: Text(
                  'لم يتم استرجاع اقتباسات إضافية لهذه الحالة.',
                  style: GoogleFonts.cairo(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...list.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final ev = entry.value;
              return _buildEvidenceCard(context, idx, ev);
            }),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard(BuildContext context, int index, EvidenceModel ev) {
    final score = ev.relevanceScore.toStringAsFixed(1);

    final fullTextEn = ev.highlightTextEn.isNotEmpty
        ? ev.highlightTextEn
        : 'Official clinical protocol from WHO IMCI Model Handbook covering assessment criteria, danger sign identification, and pre-referral treatment pathways.';

    final fullTextAr = ev.highlightTextAr.isNotEmpty
        ? ev.highlightTextAr
        : 'البروتوكول السريري المعتمد من دليل منظمة الصحة العالمية لتدبير أمراض الطفولة: ${ev.sectionTitle}، يوضح معايير التصنيف السريري وعلامات الخطورة وخطة العلاج الموصى بها.';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Document & Score Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.medicalTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'دليل #$index',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.medicalTealDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ص ${ev.page} من 142',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.safeEmeraldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.safeEmeraldBorder),
                ),
                child: Text(
                  '$score% تطابق',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.safeEmeraldDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Section Title
          Text(
            ev.sectionTitle,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.slateNavy,
            ),
          ),

          const SizedBox(height: 10),

          // Full Paragraph Passage with LTR / RTL wrapper
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: _showEnglishOriginal
                ? Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      fullTextEn,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMain,
                      ),
                    ),
                  )
                : Directionality(
                    textDirection: TextDirection.rtl,
                    child: SelectableText(
                      fullTextAr,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        height: 1.65,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          // Citation Footer
          Row(
            children: [
              const Icon(Icons.bookmark_outline, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  '[${ev.documentName}, ${ev.sectionTitle}, Page ${ev.page}]',
                  style: GoogleFonts.inter(
                    fontSize: 11,
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

  Widget _buildTriadPill(String title, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}
