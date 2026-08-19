import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeline_tile/timeline_tile.dart';
import '../theme/app_theme.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/assessment_model.dart';
import '../widgets/app_bottom_nav.dart';
import '02_child_selection_screen.dart';
import '09_child_profile_screen.dart';
import '10_chat_history_screen.dart';

class SymptomTimelineScreen extends StatelessWidget {
  const SymptomTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final child = state.activeChild;
        final history = state.historyList.where((h) => h.childId == child.id || h.childName == child.name).toList();

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
              'الخط الزمني للأعراض - ${child.name}',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سجل وتطور الحالة السريرية لـ ${child.name}',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                if (history.isNotEmpty) ...[
                  ...history.asMap().entries.map((entry) {
                    final index = entry.key;
                    final isFirst = index == 0;
                    final isLast = index == history.length - 1;
                    final record = entry.value;

                    Color nodeColor = const Color(0xFF10B981);
                    if (record.triageLevel == 'RED') {
                      nodeColor = const Color(0xFFEF4444);
                    } else if (record.triageLevel == 'YELLOW') {
                      nodeColor = const Color(0xFFF59E0B);
                    }

                    return TimelineTile(
                      alignment: TimelineAlign.start,
                      isFirst: isFirst,
                      isLast: isLast,
                      indicatorStyle: IndicatorStyle(
                        width: 22,
                        height: 22,
                        indicator: Container(
                          decoration: BoxDecoration(
                            color: nodeColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.circle, color: Colors.white, size: 8),
                          ),
                        ),
                      ),
                      beforeLineStyle: const LineStyle(color: Color(0xFFE2E8F0), thickness: 2.5),
                      afterLineStyle: const LineStyle(color: Color(0xFFE2E8F0), thickness: 2.5),
                      endChild: _buildTimelineCard(record, nodeColor),
                    );
                  }),
                ] else ...[
                  // Dynamic default recent progression if no history yet
                  _buildSampleTimeline(child.name),
                ],

                const SizedBox(height: 30),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: 2,
            onTap: (index) {
              context.read<AssessmentCubit>().setBottomNavIndex(index);
              if (index == 0) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChildSelectionScreen()));
              } else if (index == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
              } else if (index == 3) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildProfileScreen()));
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildTimelineCard(AssessmentRecordModel record, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 16, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                record.date.isNotEmpty ? record.date : 'اليوم',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  record.triageLabelAr,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record.chiefComplaint,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...record.symptomsSummary.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSampleTimeline(String childName) {
    return Column(
      children: [
        TimelineTile(
          alignment: TimelineAlign.start,
          isFirst: true,
          indicatorStyle: IndicatorStyle(
            width: 22,
            height: 22,
            indicator: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.circle, color: Colors.white, size: 8),
              ),
            ),
          ),
          beforeLineStyle: const LineStyle(color: Color(0xFFE2E8F0), thickness: 2.5),
          afterLineStyle: const LineStyle(color: Color(0xFFE2E8F0), thickness: 2.5),
          endChild: Container(
            margin: const EdgeInsets.only(right: 16, bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اليوم - متابعة مستمرة',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                ),
                const SizedBox(height: 4),
                Text(
                  'تم بدء التقييم السريري لـ $childName عبر محرك WHO IMCI.',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
