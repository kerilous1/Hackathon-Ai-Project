import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';

class ChildProfileScreen extends StatelessWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final child = state.activeChild;

        if (child == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('الملف الصحي للطفل')),
            body: const Center(child: Text('لم يتم اختيار طفل.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('الملف الصحي: ${child.name}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.emergencyRed),
                tooltip: 'حذف الملف',
                onPressed: () => _confirmDelete(context, child),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Avatar & Basic Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.medicalTeal.withOpacity(0.12),
                      child: Icon(
                        child.gender == 'female' ? Icons.girl_rounded : Icons.boy_rounded,
                        size: 48,
                        color: AppColors.medicalTealDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      child.name,
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slateNavy,
                      ),
                    ),
                    Text(
                      '${child.gender == "female" ? "أنثى" : "ذكر"} • ${child.ageFormattedArabic}',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'الوزن الحالي',
                      '${child.weightKg} كجم',
                      Icons.monitor_weight_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      'تاريخ الميلاد',
                      DateFormat('yyyy/MM/dd').format(child.birthDate),
                      Icons.cake_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Medical Records Cards
              _buildRecordSection(
                title: 'الحساسية وموانع الأدوية 🚫',
                items: child.allergies,
                emptyText: 'لا توجد حساسيات دوائية أو غذائية مسجلة.',
                icon: Icons.warning_amber_rounded,
                color: AppColors.clinicalAmber,
              ),

              const SizedBox(height: 12),

              _buildRecordSection(
                title: 'الأمراض المزمنة والتشخيصات السابقة 📋',
                items: child.chronicDiseases,
                emptyText: 'الطفل سليم ولا يعاني من أمراض مزمنة.',
                icon: Icons.medical_services_outlined,
                color: const Color(0xFF0284C7),
              ),

              const SizedBox(height: 12),

              _buildRecordSection(
                title: 'الأدوية الحالية المستمرة 💊',
                items: child.currentMedications,
                emptyText: 'لا يتناول أدوية مزمنة بانتظام حالياً.',
                icon: Icons.medication_outlined,
                color: AppColors.medicalTeal,
              ),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: () => _showEditNotesModal(context, child),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('إضافة ملاحظات الطبيب الخاصة'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.medicalTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted)),
                Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slateNavy)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordSection({
    required String title,
    required List<String> items,
    required String emptyText,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slateNavy),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              emptyText,
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textLight),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items.map((it) => Chip(label: Text(it, style: GoogleFonts.cairo(fontSize: 11)))).toList(),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChildModel child) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد حذف الملف', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: Text('هل أنت متأكد من رغبتك في حذف ملف ${child.name} وجميع سجلاته؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
            onPressed: () {
              context.read<AssessmentCubit>().deleteChild(child.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  void _showEditNotesModal(BuildContext context, ChildModel child) {
    final noteController = TextEditingController(text: child.notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
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
            Text('ملاحظات الطبيب الخاصة', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'اكتب التوصيات الطبية والملاحظات هنا...'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final updatedChild = ChildModel(
                    id: child.id,
                    name: child.name,
                    birthDate: child.birthDate,
                    weightKg: child.weightKg,
                    gender: child.gender,
                    allergies: child.allergies,
                    chronicDiseases: child.chronicDiseases,
                    currentMedications: child.currentMedications,
                    notes: noteController.text.trim(),
                  );
                  context.read<AssessmentCubit>().addChild(updatedChild);
                  Navigator.of(ctx).pop();
                },
                child: const Text('حفظ الملاحظات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
