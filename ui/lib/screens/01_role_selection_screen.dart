import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../cubit/assessment_cubit.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/disclaimer_dialog.dart';
import '02_child_selection_screen.dart';
import '07_doctor_workstation_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const BrandLogoWidget(size: 85),
              const SizedBox(height: 28),
              Text(
                'اختر وضع الاستخدام المناسب',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slateNavy,
                ),
              ),
              const SizedBox(height: 24),

              // Role Card 1: Parent / Guardian
              _buildRoleCard(
                context,
                title: 'ولي أمر (Parent / Guardian)',
                subtitle: 'فرز سريري ذكي للأعراض، خطوات إسعافية وتوجيه الرعاية المنزلية الآمنة',
                icon: Icons.family_restroom_rounded,
                color: AppColors.medicalTeal,
                gradient: AppColors.primaryGradient,
                onTap: () {
                  context.read<AssessmentCubit>().setRole('parent');
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChildSelectionScreen()),
                  );
                },
              ),

              const SizedBox(height: 18),

              // Role Card 2: Pediatrician / Clinician
              _buildRoleCard(
                context,
                title: 'طبيب أطفال (Pediatrician / Clinician)',
                subtitle: 'محطة العمل السريرية، حاسبة الجرعات بالمحقنة، وخطة الإنعاش الوريدي ورمز SBAR',
                icon: Icons.medical_services_rounded,
                color: const Color(0xFF0284C7),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () {
                  context.read<AssessmentCubit>().setRole('doctor');
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoctorWorkstationScreen()),
                  );
                },
              ),

              const SizedBox(height: 36),

              // Disclaimer Button Footer
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const DisclaimerDialog(),
                  );
                },
                icon: const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                label: Text(
                  'إخلاء المسؤولية الطبية والشروط السريرية',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slateNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
