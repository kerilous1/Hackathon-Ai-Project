import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/assessment_model.dart';
import '../theme/app_theme.dart';
import '../widgets/triage_badge.dart';
import '03_smart_chat_screen.dart';
import '04_assessment_result_screen.dart';

class ConsultationHistoryScreen extends StatefulWidget {
  const ConsultationHistoryScreen({super.key});

  @override
  State<ConsultationHistoryScreen> createState() => _ConsultationHistoryScreenState();
}

class _ConsultationHistoryScreenState extends State<ConsultationHistoryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final assessments = state.historyAssessments;
        final filtered = assessments.where((a) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return a.summaryFound.any((s) => s.toLowerCase().contains(q)) ||
              a.fullRecommendation.toLowerCase().contains(q) ||
              a.triageLabelAr.contains(q);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('سجل الاستشارات السابقة'),
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'البحث في الاستشارات السابقة...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),

              // List of Consultations
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? 'لا توجد نتائج مطابقة لبحثك' : 'لا توجد استشارات مسجلة بعد',
                          style: GoogleFonts.cairo(color: AppColors.textMuted, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final asmt = filtered[index];
                          return _buildHistoryCard(context, asmt);
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SmartChatScreen()),
              );
            },
            backgroundColor: AppColors.medicalTeal,
            icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
            label: Text('استشارة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, AssessmentResponseModel asmt) {
    final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(asmt.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                dateStr,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TriageBadgeWidget(triageLevel: asmt.triageLevel, isCompact: true),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              asmt.summaryFound.isNotEmpty ? asmt.summaryFound.first : asmt.fullRecommendation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.slateNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              asmt.triageLabelAr,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AssessmentResultScreen(assessment: asmt),
            ),
          );
        },
      ),
    );
  }
}
