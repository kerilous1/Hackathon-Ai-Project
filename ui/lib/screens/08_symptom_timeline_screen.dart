import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/symptom_timeline_model.dart';
import '../theme/app_theme.dart';
import '../widgets/triage_badge.dart';

class SymptomTimelineScreen extends StatelessWidget {
  const SymptomTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final child = state.activeChild;
        final timeline = state.timelineEntries;

        return Scaffold(
          appBar: AppBar(
            title: Text(child != null ? 'مخطط أعراض ${child.name}' : 'مخطط الأعراض'),
          ),
          body: timeline.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: timeline.length,
                  itemBuilder: (context, index) {
                    final entry = timeline[index];
                    final isFirst = index == 0;
                    final isLast = index == timeline.length - 1;
                    return _buildTimelineItem(context, entry, isFirst: isFirst, isLast: isLast);
                  },
                ),
          floatingActionButton: child != null
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddLogModal(context, child.id),
                  backgroundColor: AppColors.medicalTeal,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text('تسجيل متابعة يومية', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: Colors.white)),
                )
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timeline_rounded, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              'لا توجد سجلات متابعة بعد',
              style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slateNavy),
            ),
            const SizedBox(height: 8),
            Text(
              'تسجيل درجات الحرارة والأعراض اليومية يساعد في رصد استجابة الطفل للعلاج وتحديد موعد المتابعة.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, SymptomLogEntry entry, {required bool isFirst, required bool isLast}) {
    final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(entry.date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline axis
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: entry.triageLevel == 'RED' ? AppColors.emergencyRed : AppColors.medicalTeal,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 110,
                color: AppColors.borderLight,
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Content Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                    TriageBadgeWidget(triageLevel: entry.triageLevel, isCompact: true),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.thermostat_rounded, size: 16, color: AppColors.emergencyRed),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.temperatureC}°C',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slateNavy),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.restaurant_rounded, size: 16, color: AppColors.medicalTeal),
                    const SizedBox(width: 4),
                    Text(
                      'الرضاعة: ${entry.feedingStatus}',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                    ),
                  ],
                ),
                if (entry.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.notes,
                    style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddLogModal(BuildContext context, String childId) {
    final tempController = TextEditingController(text: '37.8');
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تسجيل قراءة جديدة للأعراض', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(
                controller: tempController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'درجة الحرارة (°C)', prefixIcon: Icon(Icons.thermostat_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات الأعراض والتغذية', prefixIcon: Icon(Icons.note_alt_outlined)),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final temp = double.tryParse(tempController.text.trim()) ?? 37.0;
                    final newEntry = SymptomLogEntry(
                      id: 'log_${const Uuid().v4()}',
                      childId: childId,
                      date: DateTime.now(),
                      temperatureC: temp,
                      coughStatus: 'none',
                      diarrheaStoolsCount: 0,
                      feedingStatus: 'normal',
                      notes: notesController.text.trim(),
                      triageLevel: temp >= 38.5 ? 'YELLOW' : 'GREEN',
                    );
                    context.read<AssessmentCubit>().addTimelineEntry(newEntry);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('حفظ في المخطط الزمني'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
