import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/assessment_model.dart';
import '../widgets/child_avatar.dart';
import '../widgets/triage_badge.dart';
import '../widgets/app_bottom_nav.dart';
import '02_child_selection_screen.dart';
import '03_smart_chat_screen.dart';
import '04_assessment_result_screen.dart';
import '08_symptom_timeline_screen.dart';
import '09_child_profile_screen.dart';

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final history = state.historyList;

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
              'سجل الاستشارات السريرية',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد استشارات سابقة حتى الآن',
                          style: GoogleFonts.cairo(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final record = history[index];
                          return _buildHistoryCard(context, record, state.activeChild.avatarType);
                        },
                      ),
              ),

              // Bottom Button: "محادثة جديدة +"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<AssessmentCubit>().resetChat();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SmartChatScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  label: Text(
                    'استشارة سريرية جديدة',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: 1,
            onTap: (index) {
              context.read<AssessmentCubit>().setBottomNavIndex(index);
              if (index == 0) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChildSelectionScreen()));
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

  Widget _buildHistoryCard(BuildContext context, AssessmentRecordModel record, String avatarType) {
    return InkWell(
      onTap: () {
        // Hydrate the current assessment state with this record's actual evidence and triage data
        final response = AssessmentResponse(
          status: 'success',
          triageLevel: record.triageLevel,
          triageLabelAr: record.triageLabelAr,
          summaryFound: record.symptomsSummary,
          missingInfo: record.missingQuestions,
          fullRecommendation: record.fullRecommendation,
          evidenceList: record.evidences,
          differentialDiagnoses: record.differentialDiagnoses,
        );

        context.read<AssessmentCubit>().setCurrentAssessment(response);

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssessmentResultScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.date,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.chiefComplaint,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TriageBadge(
                    triageLevel: record.triageLevel,
                    label: record.triageLabelAr,
                  ),
                ],
              ),
            ),
            ChildAvatar(avatarType: avatarType, radius: 26),
          ],
        ),
      ),
    );
  }
}
