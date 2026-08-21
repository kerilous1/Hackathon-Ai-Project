import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/chat_message_model.dart';
import '../theme/app_theme.dart';
import '../widgets/respiratory_rate_counter.dart';
import '04_assessment_result_screen.dart';

class SmartChatScreen extends StatefulWidget {
  const SmartChatScreen({super.key});

  @override
  State<SmartChatScreen> createState() => _SmartChatScreenState();
}

class _SmartChatScreenState extends State<SmartChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  String _selectedDuration = '';

  final List<String> _quickSymptoms = [
    'حرارة وسخونية',
    'كحة وسعال',
    'قيء مستمر',
    'إسهال مائي',
    'انسحاب الصدر للداخل',
    'خمول وصعوبة رضاعة',
  ];

  final List<String> _durations = [
    'منذ أقل من 24 ساعة',
    'منذ 1 إلى 3 أيام',
    'منذ أكثر من 3 أيام',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? customText]) {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty) return;

    String fullQuery = text;
    if (_selectedDuration.isNotEmpty && !text.contains(_selectedDuration)) {
      fullQuery += ' ($_selectedDuration)';
    }

    _textController.clear();
    context.read<AssessmentCubit>().sendMessage(fullQuery);
    _scrollToBottom();
  }

  void _openBreathCounter(BuildContext context) {
    final activeChild = context.read<AssessmentCubit>().state.activeChild;
    if (activeChild == null) return;

    showDialog(
      context: context,
      builder: (_) => RespiratoryRateCounterDialog(
        child: activeChild,
        onFinished: (bpm) {
          _sendMessage('قمت بعد معدل التنفس للطفل: $bpm نفس في الدقيقة.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AssessmentCubit, AssessmentState>(
      listener: (context, state) {
        _scrollToBottom();
      },
      builder: (context, state) {
        final activeChild = state.activeChild;
        final messages = state.chatMessages;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(
                  activeChild?.name ?? 'المحادثة الذكية',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                if (activeChild != null)
                  Text(
                    '${activeChild.ageFormattedArabic} • ${activeChild.weightKg} كجم',
                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'إعادة تعيين المحادثة',
                onPressed: () {
                  context.read<AssessmentCubit>().resetChat();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Offline Indicator Banner if local fallback was used
              if (state.isOffline)
                Container(
                  width: double.infinity,
                  color: AppColors.clinicalAmberBg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 14, color: AppColors.clinicalAmberDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'وضع المعالجة المحلية السريعة بدون إنترنت (WHO IMCI Local Engine)',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.clinicalAmberDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // --- LIVE DEMO SHOWCASE SPEED-DIAL BAR ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.slateNavy.withOpacity(0.04),
                  border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.medicalTealDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🌟 سيناريوهات التحكيم المباشر (Demo Presets):',
                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.emergencyRed),
                        label: Text('🔴 رضيع 3 أسابيع (PSBI)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                        backgroundColor: AppColors.emergencyRedBg,
                        onPressed: () => _sendMessage('3-week-old young infant with breathing rate 66 breaths/min, axillary temperature 35.2°C (hypothermia), and expiratory grunting'),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.air_rounded, size: 14, color: AppColors.emergencyRed),
                        label: Text('🔴 التهاب رئوي وخيم (سحب صدر)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                        backgroundColor: AppColors.emergencyRedBg,
                        onPressed: () => _sendMessage('طفل 14 شهر يعاني من كحة مع تنفس سريع 48 نفس بالدقيقة وانسحاب أسفل جدار الصدر للداخل'),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.health_and_safety_rounded, size: 14, color: AppColors.emergencyRed),
                        label: Text('🔴 سوء تغذية حاد (Marasmus)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                        backgroundColor: AppColors.emergencyRedBg,
                        onPressed: () => _sendMessage('طفل 18 شهر يظهر عليه هزال شديد واضح (جلد على عظم) مع تورم بالقدمين'),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.water_drop_rounded, size: 14, color: AppColors.emergencyRed),
                        label: Text('🔴 جفاف شديد (الخطة ج)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                        backgroundColor: AppColors.emergencyRedBg,
                        onPressed: () => _sendMessage('طفل مصاب بإسهال مائي منذ 3 أيام، فاقد للوعي، عيون غائرة وثنية الجلد ترجع ببطء شديد'),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.shield_outlined, size: 14, color: AppColors.slateNavy),
                        label: Text('🛡️ رفض استشارة بالغين (OOD)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onPressed: () => _sendMessage('علاج انسداد الشريان التاجي والنيتروجليسرين للبالغين'),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.block_rounded, size: 14, color: AppColors.slateNavy),
                        label: Text('🛡️ رفض كلام عام (Non-Medical)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onPressed: () => _sendMessage('اي رايك ف لبسي النهاردة؟'),
                      ),
                    ],
                  ),
                ),
              ),

              // Chat Message Stream
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(context, msg);
                  },
                ),
              ),

              // Quick Symptom Chips
              Container(
                color: AppColors.surfaceWhite,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.timer_outlined, size: 16, color: AppColors.medicalTeal),
                        label: Text('عدّ التنفس 🫁', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12)),
                        onPressed: () => _openBreathCounter(context),
                        backgroundColor: AppColors.medicalTeal.withOpacity(0.12),
                      ),
                      const SizedBox(width: 8),
                      ..._quickSymptoms.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(s, style: GoogleFonts.cairo(fontSize: 12)),
                              onPressed: () => _sendMessage(s),
                            ),
                          )),
                    ],
                  ),
                ),
              ),

              // Duration Selector
              Container(
                color: AppColors.surfaceWhite,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'المدة:',
                      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _durations.map((d) {
                            final isSel = _selectedDuration == d;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(d, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600)),
                                selected: isSel,
                                onSelected: (val) => setState(() => _selectedDuration = val ? d : ''),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Input Bar with Voice Dictation simulation button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  border: const Border(top: BorderSide(color: AppColors.borderLight)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.medicalTeal.withOpacity(0.1),
                        ),
                        icon: const Icon(Icons.mic_rounded, color: AppColors.medicalTealDark),
                        tooltip: 'إملاء صوتي سريري (Voice Dictation)',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.medicalTealDark,
                              duration: const Duration(seconds: 2),
                              content: Text(
                                '🎙️ جاري الاستماع للإملاء الصوتي السريري...',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                              ),
                            ),
                          );
                          _sendMessage('طفل يعاني من كحة وتنفس سريع 48 نفس في الدقيقة منذ يومين');
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'اكتب أعراض الطفل أو علامات الخطورة...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.medicalTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                        onPressed: () => _sendMessage(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessageModel msg) {
    if (msg.isTyping) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.medicalTeal),
              ),
              const SizedBox(width: 10),
              Text(
                msg.text,
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? AppColors.medicalTeal : AppColors.surfaceWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: GoogleFonts.cairo(
                fontSize: 13,
                height: 1.5,
                fontWeight: isUser ? FontWeight.w700 : FontWeight.w600,
                color: isUser ? Colors.white : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  msg.timestamp,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : AppColors.textLight,
                  ),
                ),
              ],
            ),

            // If AI message contains assessment result, provide direct Action Button to Screen 04
            if (!isUser && msg.assessment != null && !msg.assessment!.isRefusal) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slateNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssessmentResultScreen(assessment: msg.assessment!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: Text(
                    'عرض نتيجة التقييم والتحقق التفريقي 📊',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
