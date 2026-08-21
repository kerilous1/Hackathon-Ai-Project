import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';

class PewsCardWidget extends StatefulWidget {
  final ChildModel child;
  final int initialBpm;
  final bool hasRetractions;
  final bool isLethargic;

  const PewsCardWidget({
    super.key,
    required this.child,
    this.initialBpm = 45,
    this.hasRetractions = false,
    this.isLethargic = false,
  });

  @override
  State<PewsCardWidget> createState() => _PewsCardWidgetState();
}

class _PewsCardWidgetState extends State<PewsCardWidget> {
  late int _respiratoryScore;
  late int _cardioScore;
  late int _behaviorScore;

  @override
  void initState() {
    super.initState();
    _respiratoryScore = widget.hasRetractions ? 2 : (widget.initialBpm >= 50 ? 1 : 0);
    _cardioScore = 0;
    _behaviorScore = widget.isLethargic ? 3 : 0;
  }

  int get totalScore => _respiratoryScore + _cardioScore + _behaviorScore;

  Color get riskColor {
    if (totalScore >= 5) return AppColors.emergencyRed;
    if (totalScore >= 3) return AppColors.clinicalAmber;
    return AppColors.safeEmerald;
  }

  String get riskLabelAr {
    if (totalScore >= 5) return '🔴 تدهور سريري وشيك (خطر مرتفع جداً)';
    if (totalScore >= 3) return '🟡 خطر متوسط (استدعاء طبيب ومراقبة مكثفة)';
    return '🟢 مستقر (مراقبة روتينية)';
  }

  String get actionAr {
    if (totalScore >= 5) {
      return 'استدعاء فوري لطبيب الأطفال الأول، تجهيز الأكسجين والإنعاش، وإعادة التقييم كل 15 دقيقة.';
    }
    if (totalScore >= 3) {
      return 'إبلاغ الطبيب المناوب، قياس العلامات الحيوية كل ساعتين، وتقييم الاستجابة للعلاج.';
    }
    return 'متابعة سريرية روتينية ومراقبة العلامات الحيوية كل 4-6 ساعات.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: riskColor.withOpacity(0.06),
            blurRadius: 12,
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.speed_rounded, color: riskColor, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مقياس الإنذار المبكر (PEWS) 📈',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slateNavy,
                            ),
                          ),
                          Text(
                            'Pediatric Early Warning Score',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Score: $totalScore / 9',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Risk Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              riskLabelAr,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: riskColor,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3 Component Selectors
          _buildScoreSelector(
            title: '1. الجهاز التنفسي (Respiratory)',
            currentValue: _respiratoryScore,
            labels: ['طبيعي (0)', 'تسارع بسيط (+1)', 'انسحاب صدر (+2)', 'شخير وأنين (+3)'],
            onChanged: (val) => setState(() => _respiratoryScore = val),
          ),
          const SizedBox(height: 8),
          _buildScoreSelector(
            title: '2. الدورة الدموية (Cardiovascular)',
            currentValue: _cardioScore,
            labels: ['وردي <2s (0)', 'شاحب 2s (+1)', 'رمادي 3s (+2)', 'مزرق >4s (+3)'],
            onChanged: (val) => setState(() => _cardioScore = val),
          ),
          const SizedBox(height: 8),
          _buildScoreSelector(
            title: '3. السلوك والوعي (Behavior)',
            currentValue: _behaviorScore,
            labels: ['يقظ وهادئ (0)', 'نائم يستجيب (+1)', 'هياج مستمر (+2)', 'خامل / لا يستجيب (+3)'],
            onChanged: (val) => setState(() => _behaviorScore = val),
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.medicalTealDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    actionAr,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSelector({
    required String title,
    required int currentValue,
    required List<String> labels,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateNavy),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(labels.length, (idx) {
              final isSel = currentValue == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(labels[idx], style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700)),
                  selected: isSel,
                  selectedColor: AppColors.medicalTeal.withOpacity(0.2),
                  onSelected: (sel) {
                    if (sel) onChanged(idx);
                  },
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
