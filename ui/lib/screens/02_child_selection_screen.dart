import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '03_smart_chat_screen.dart';
import '08_symptom_timeline_screen.dart';
import '09_child_profile_screen.dart';
import '10_consultation_history_screen.dart';

class ChildSelectionScreen extends StatelessWidget {
  const ChildSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final children = state.children;
        final activeChild = state.activeChild;

        return Scaffold(
          appBar: AppBar(
            title: const Text('اختيار الطفل والملفات'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: 'سجل الاستشارات',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConsultationHistoryScreen()),
                  );
                },
              ),
            ],
          ),
          body: children.isEmpty
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (activeChild != null) ...[
                      Text(
                        'الملف النشط حالياً',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slateNavy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildActiveChildHeroCard(context, activeChild),
                      const SizedBox(height: 24),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'جميع الأطفال المسجلين (${children.length})',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateNavy,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAddChildModal(context),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('إضافة طفل'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...children.map((c) => _buildChildListItem(context, c, isSelected: c.id == activeChild?.id)),
                  ],
                ),
          floatingActionButton: children.isNotEmpty && activeChild != null
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SmartChatScreen()),
                    );
                  },
                  backgroundColor: AppColors.medicalTeal,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                  label: Text(
                    'بدء فحص ${activeChild.name}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.medicalTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.child_care_rounded, size: 64, color: AppColors.medicalTeal),
            ),
            const SizedBox(height: 20),
            Text(
              'لا يوجد أطفال مسجلون بعد',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.slateNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف بيانات طفلك للبدء في الفرز السريري الدقيق وفق معايير منظمة الصحة العالمية (WHO IMCI).',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddChildModal(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة طفل جديد الآن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveChildHeroCard(BuildContext context, ChildModel child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.medicalTeal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.25),
                child: Icon(
                  child.gender == 'female' ? Icons.girl_rounded : Icons.boy_rounded,
                  size: 38,
                  color: Colors.white,
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
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${child.ageFormattedArabic} • ${child.weightKg} كجم',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChildProfileScreen()),
                  );
                },
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 28),
                tooltip: 'الملف الصحي',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SymptomTimelineScreen()),
                    );
                  },
                  icon: const Icon(Icons.timeline_rounded, size: 16),
                  label: const Text('مخطط الأعراض'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.medicalTealDark,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SmartChatScreen()),
                    );
                  },
                  child: const Text('بدء الفرز السريري'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildListItem(BuildContext context, ChildModel child, {required bool isSelected}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.medicalTeal.withOpacity(0.06) : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.medicalTeal : AppColors.borderLight,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isSelected ? AppColors.medicalTeal : AppColors.bgLight,
          child: Icon(
            child.gender == 'female' ? Icons.girl_rounded : Icons.boy_rounded,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
        title: Text(
          child.name,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(
          '${child.ageFormattedArabic} • ${child.weightKg} كجم',
          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.medicalTeal)
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () {
                  context.read<AssessmentCubit>().selectChild(child);
                },
                child: const Text('اختيار'),
              ),
        onTap: () {
          context.read<AssessmentCubit>().selectChild(child);
        },
      ),
    );
  }

  void _showAddChildModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const _AddChildModalSheet(),
    );
  }
}

class _AddChildModalSheet extends StatefulWidget {
  const _AddChildModalSheet();

  @override
  State<_AddChildModalSheet> createState() => _AddChildModalSheetState();
}

class _AddChildModalSheetState extends State<_AddChildModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 365));
  String _gender = 'male';
  String? _ageError;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  int get _ageInDays => DateTime.now().difference(_birthDate).inDays;
  double get _ageInMonths => _ageInDays / 30.417;

  void _validateAge() {
    setState(() {
      if (_ageInDays < 7) {
        _ageError = '🚨 العمر أقل من 7 أيام (يتطلب تقييماً فورياً في NICU)';
      } else if (_ageInMonths > 60.0) {
        _ageError = '⚠️ العمر يتجاوز 5 سنوات (نطاق WHO IMCI هو 7 أيام إلى 5 سنوات)';
      } else {
        _ageError = null;
      }
    });
  }

  void _validateAndSubmit() {
    _validateAge();

    if (!_formKey.currentState!.validate() || _ageError != null) {
      return;
    }

    final name = _nameController.text.trim();
    final weight = double.parse(_weightController.text.trim());

    final newChild = ChildModel(
      id: const Uuid().v4(),
      name: name,
      birthDate: _birthDate,
      weightKg: weight,
      gender: _gender,
    );

    context.read<AssessmentCubit>().addChild(newChild);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إضافة ملف طفل جديد 👶',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateNavy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الطفل',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'يرجى إدخال اسم الطفل';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'الوزن بالكيلوجرام (مثلاً: 9.5)',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
                suffixText: 'كجم',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'يرجى إدخال وزن الطفل';
                }
                final parsed = double.tryParse(val.trim());
                if (parsed == null || parsed < 2.0 || parsed > 35.0) {
                  return 'الوزن يجب أن يكون بين 2 و 35 كجم';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Date of birth picker with inline validation
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _birthDate = picked;
                  });
                  _validateAge();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _ageError != null ? AppColors.emergencyRed : AppColors.borderLight,
                    width: _ageError != null ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: AppColors.medicalTeal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تاريخ الميلاد',
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
                          ),
                          Text(
                            '${DateFormat('yyyy/MM/dd').format(_birthDate)} (${(_ageInDays < 30) ? '$_ageInDays يوماً' : '${(_ageInDays / 30.417).floor()} شهراً'})',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            if (_ageError != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  _ageError!,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emergencyRed,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Gender Selector
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text('ذكر 👦', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ),
                    selected: _gender == 'male',
                    onSelected: (val) => setState(() => _gender = 'male'),
                    selectedColor: AppColors.medicalTeal.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text('أنثى 👧', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    ),
                    selected: _gender == 'female',
                    onSelected: (val) => setState(() => _gender = 'female'),
                    selectedColor: AppColors.medicalTeal.withOpacity(0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _validateAndSubmit,
                child: const Text('حفظ وبدء المتابعة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
