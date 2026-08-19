import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/child_model.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../widgets/child_avatar.dart';
import '../widgets/app_bottom_nav.dart';
import '03_smart_chat_screen.dart';
import '08_symptom_timeline_screen.dart';
import '09_child_profile_screen.dart';
import '10_chat_history_screen.dart';

class ChildSelectionScreen extends StatelessWidget {
  const ChildSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 28),
              onPressed: () => _showSideDrawer(context, state),
            ),
            title: Text(
              'أطفالي',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
                ),
                onPressed: () => _showAddChildDialog(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.children.isEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.child_care_rounded, size: 54, color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text(
                          'لا يوجد أطفال مسجلين بعد',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ابدأ بإضافة ملف طفلك للبدء في التقييم السريري الذكي وفق دليل WHO IMCI.',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // List of Children
                  ...state.children.map((child) {
                    final isSelected = child.id == state.activeChild.id;
                    return _buildChildCard(context, child, isSelected);
                  }),
                ],

                const SizedBox(height: 16),

                // Dotted Border Card: Add New Child
                _buildAddChildDottedCard(context),

                const SizedBox(height: 30),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: state.bottomNavIndex,
            onTap: (index) {
              context.read<AssessmentCubit>().setBottomNavIndex(index);
              if (index == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
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

  Widget _buildChildCard(BuildContext context, ChildModel child, bool isSelected) {
    if (isSelected) {
      // Active Purple Gradient Card
      return InkWell(
        onTap: () {
          context.read<AssessmentCubit>().selectChild(child);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SmartChatScreen()),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B42F3), Color(0xFF7C3AED)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B42F3).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${child.ageDisplayAr}  •  ${child.weight.toStringAsFixed(0)} كجم',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              ChildAvatar(
                avatarType: child.avatarType,
                radius: 36,
                showBorder: true,
                borderColor: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    // Inactive White Card
    return InkWell(
      onTap: () {
        context.read<AssessmentCubit>().selectChild(child);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textMuted, width: 2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${child.ageDisplayAr}  •  ${child.weight.toStringAsFixed(0)} كجم',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ChildAvatar(
              avatarType: child.avatarType,
              radius: 30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddChildDottedCard(BuildContext context) {
    return InkWell(
      onTap: () => _showAddChildDialog(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أضف طفل',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'إنشاء ملف جديد لطفلك (من عمر يوم حتى 5 سنوات)',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.child_care_rounded, color: AppColors.primaryLight, size: 30),
          ],
        ),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController(text: '3');
    final weightCtrl = TextEditingController(text: '14.5');
    String gender = 'ذكر';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Text(
                'إضافة طفل جديد',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'بروتوكول WHO IMCI مخصص للأطفال حتى عمر 5 سنوات',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: 'اسم الطفل',
                      labelStyle: GoogleFonts.cairo(),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسم الطفل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                          labelText: 'العمر (سنوات/أشهر)',
                          hintText: '0.5 = ٦ أشهر',
                          labelStyle: GoogleFonts.cairo(fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          validator: (val) {
                            final parsed = double.tryParse(val ?? '');
                            if (parsed == null || parsed < 0 || parsed > 5.0) {
                              return 'من 0 إلى 5 سنوات فقط (يقبل كسور: 0.5 = 6 أشهر)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'الوزن (2-35 كجم)',
                            labelStyle: GoogleFonts.cairo(fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          validator: (val) {
                            final parsed = double.tryParse(val ?? '');
                            if (parsed == null || parsed < 2.0 || parsed > 35.0) {
                              return 'من 2 إلى 35 كجم';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text('ذكر 👦', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        selected: gender == 'ذكر',
                        selectedColor: AppColors.primaryContainer,
                        onSelected: (val) => setDialogState(() => gender = 'ذكر'),
                      ),
                      const SizedBox(width: 14),
                      ChoiceChip(
                        label: Text('أنثى 👧', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        selected: gender == 'أنثى',
                        selectedColor: const Color(0xFFFCE7F3),
                        onSelected: (val) => setDialogState(() => gender = 'أنثى'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final age = double.parse(ageCtrl.text.trim());
                  final weight = double.parse(weightCtrl.text.trim());
                  final newChild = ChildModel(
                    id: 'child_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    age: age,
                    weight: weight,
                    gender: gender,
                    birthDate: ChildModel.calculateBirthDate(age),
                    avatarType: gender == 'ذكر' ? 'boy' : 'girl',
                  );
                  context.read<AssessmentCubit>().addChild(newChild);
                  Navigator.pop(ctx);
                }
              },
              child: Text('إضافة وحفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSideDrawer(BuildContext context, AssessmentState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'القائمة الرئيسية',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.people_rounded, color: AppColors.primary),
              title: Text('أطفالي', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary),
              title: Text('المحادثة الذكية (تقييم فوري)', style: GoogleFonts.cairo()),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartChatScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: AppColors.primary),
              title: Text('المحادثات السابقة', style: GoogleFonts.cairo()),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.timeline_rounded, color: AppColors.primary),
              title: Text('الخط الزمني للأعراض', style: GoogleFonts.cairo()),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SymptomTimelineScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
