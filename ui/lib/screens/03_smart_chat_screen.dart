import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/chat_message_model.dart';
import '../services/clinical_api_service.dart';
import '04_assessment_result_screen.dart';

class SmartChatScreen extends StatefulWidget {
  const SmartChatScreen({super.key});

  @override
  State<SmartChatScreen> createState() => _SmartChatScreenState();
}

class _SmartChatScreenState extends State<SmartChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedDuration = 'من 1 إلى 3 أيام';
  int _selectedDurationDays = 3;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AssessmentCubit, AssessmentState>(
      listener: (context, state) {
        if (state.status == AssessmentStatus.loading) {
          setState(() => _isLoading = true);
        } else {
          setState(() => _isLoading = false);
        }
        // Show SnackBar for server errors or validation errors
        if ((state.status == AssessmentStatus.validationError || state.status == AssessmentStatus.failure) &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage!,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.right,
              ),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
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
            title: Column(
              children: [
                Text(
                  '${child.name} - ${child.ageDisplayAr} (${child.weight.toStringAsFixed(0)} كجم)',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'WHO IMCI Triage Engine',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
                tooltip: 'إعادة ضبط المحادثة',
                onPressed: () {
                  context.read<AssessmentCubit>().resetChat();
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Chat Messages Area
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: state.chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = state.chatMessages[index];
                        return _buildChatBubble(msg);
                      },
                    ),
                  ),

                  // Option Chips for Duration
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDurationChip('أكثر من 3 أيام', 4),
                        _buildDurationChip('من 1 إلى 3 أيام', 3),
                        _buildDurationChip('أقل من 24 ساعة', 1),
                      ],
                    ),
                  ),

                  // Quick Symptom Selector Bar
                  _buildQuickSymptomBar(child.name),

                  // Text & Voice Input Area
                  _buildInputBar(child.name),
                ],
              ),

              // Fullscreen Loading Overlay during API assessment
              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3.5,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'جاري الاسترجاع والتقييم من دليل WHO IMCI...',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'WHO Integrated Management of Childhood Illness',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatBubble(ChatMessageModel msg) {
    final isAi = msg.sender == 'ai';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAi) ...[
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE9FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAi ? Colors.white : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isAi ? 4 : 20),
                  bottomRight: Radius.circular(isAi ? 20 : 4),
                ),
                border: isAi ? Border.all(color: AppColors.cardBorder, width: 1.2) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isAi ? AppColors.textPrimary : Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(String title, int days) {
    final isSelected = _selectedDuration == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDuration = title;
          _selectedDurationDays = days;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSymptomBar(String childName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أعراض سريرية شائعة (اضغط للتقييم الفوري)',
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSymptomIconBtn('حرارة وكحة', Icons.thermostat_rounded, const Color(0xFFEF4444)),
              _buildSymptomIconBtn('صعوبة تنفس', Icons.air_rounded, const Color(0xFF3B82F6)),
              _buildSymptomIconBtn('قيء مستمر', Icons.sentiment_very_dissatisfied_rounded, const Color(0xFF10B981)),
              _buildSymptomIconBtn('طفح جلدي', Icons.coronavirus_outlined, const Color(0xFFF59E0B)),
              _buildSymptomIconBtn('إسهال مائي', Icons.water_drop_outlined, const Color(0xFF8B5CF6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomIconBtn(String label, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        _triggerAssessment(label);
      },
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(String childName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder, width: 1),
                ),
                child: TextField(
                  controller: _textController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'اكتب أعراض $childName هنا...',
                    hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _triggerAssessment(val.trim());
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                final text = _textController.text.trim();
                if (text.isNotEmpty) {
                  _triggerAssessment(text);
                } else {
                  _triggerAssessment('حرارة وكحة منذ يومين');
                }
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerAssessment(String symptoms) async {
    final cubit = context.read<AssessmentCubit>();
    await cubit.sendChatMessage(symptoms);
    _textController.clear();

    try {
      await cubit.assessSymptoms(
        symptoms: symptoms,
        durationDays: _selectedDurationDays,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AssessmentResultScreen()),
      );
    } catch (_) {
      // Errors (ClinicalValidationException, ClinicalApiException) are handled by the BlocConsumer listener SnackBar
      return;
    }
  }
}
