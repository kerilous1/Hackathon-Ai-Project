import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/child_model.dart';
import '../widgets/child_avatar.dart';
import '../widgets/app_bottom_nav.dart';
import '02_child_selection_screen.dart';
import '08_symptom_timeline_screen.dart';
import '10_chat_history_screen.dart';

class ChildProfileScreen extends StatelessWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final child = state.activeChild;

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
              'ملف الطفل السريري',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 24),
                tooltip: 'تعديل الملف الطبي',
                onPressed: () => _showEditProfileModal(context, child),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Child Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      ChildAvatar(avatarType: child.avatarType, radius: 30),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child.name,
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${child.ageDisplayAr}  •  ${child.weight.toStringAsFixed(1)} كجم',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'WHO IMCI',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Medical Info Card ("معلومات أساسية")
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
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
                      Text(
                        'معلومات أساسية وسجل صحي',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildProfileRow('تاريخ الميلاد التقريبي', child.birthDate),
                      const Divider(height: 20),
                      _buildProfileRow('الجنس', child.gender),
                      const Divider(height: 20),
                      _buildProfileRow('الحساسية الدوائية والغذائية', child.allergies),
                      const Divider(height: 20),
                      _buildProfileRow('الأمراض المزمنة السابقة', child.chronicDiseases),
                      const Divider(height: 20),
                      _buildProfileRow('الأدوية الحالية', child.medications),
                      const Divider(height: 20),
                      _buildProfileRow('ملاحظات سريرية', child.notes),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: 3,
            onTap: (index) {
              context.read<AssessmentCubit>().setBottomNavIndex(index);
              if (index == 0) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChildSelectionScreen()));
              } else if (index == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
              } else if (index == 2) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SymptomTimelineScreen()));
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditProfileModal(BuildContext context, ChildModel child) {
    final allergyCtrl = TextEditingController(text: child.allergies);
    final chronicCtrl = TextEditingController(text: child.chronicDiseases);
    final medCtrl = TextEditingController(text: child.medications);
    final notesCtrl = TextEditingController(text: child.notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تعديل الملف الطبي لـ ${child.name}',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: allergyCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'الحساسية',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chronicCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'الأمراض المزمنة',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: medCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'الأدوية الحالية',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'ملاحظات إضافية',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final updated = child.copyWith(
                    allergies: allergyCtrl.text.trim(),
                    chronicDiseases: chronicCtrl.text.trim(),
                    medications: medCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                  );
                  context.read<AssessmentCubit>().updateChild(updated);
                  Navigator.pop(ctx);
                },
                child: Text('حفظ التعديلات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
