import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../cubit/assessment_cubit.dart';
import '../cubit/assessment_state.dart';
import '../models/child_model.dart';
import '../models/evidence_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/syringe_visualizer.dart';
import '../widgets/iv_fluid_calculator.dart';
import '../widgets/pews_card_widget.dart';
import '../widgets/triage_badge.dart';

class DoctorWorkstationScreen extends StatefulWidget {
  const DoctorWorkstationScreen({super.key});

  @override
  State<DoctorWorkstationScreen> createState() => _DoctorWorkstationScreenState();
}

class _DoctorWorkstationScreenState extends State<DoctorWorkstationScreen> with SingleTickerProviderStateMixin {
  // Tab 1 Search State
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<EvidenceModel> _searchResults = [];
  bool _searchShowEnglish = false;
  String _activeSearchQuery = '';

  // Tab 2 Medication & IV State
  String _selectedMedication = 'amoxicillin';
  double _calculatedDoseMl = 5.0;
  String _dosageInstructions = '5.0 مل مرتان يومياً لمدة 5 أيام';
  bool _isMetronomeRunning = false;
  Timer? _metronomeTimer;
  late AnimationController _pulseController;

  final List<String> _suggestedQueries = [
    'جرعة فيتامين أ',
    'التهاب الأذن والخشّاء',
    'الخطة ب للجفاف',
    'سوء التغذية الشديد',
    'التهاب رئوي وخيم',
    'الرضيع الصغير PSBI',
  ];

  final List<Map<String, dynamic>> _expandedProtocols = [
    {
      'title': '🚨 علامات الخطورة العامة (General Danger Signs)',
      'page': '16–18',
      'triage': 'RED',
      'criteria': 'غير قادر على الشرب/الرضاعة، يتقيأ كل شيء، تشنجات خلال المرض الحالي، خامل أو فاقد للوعي.',
      'action': 'إعطاء الجرعة الأولى من المضاد الحيوي، منع هبوط السكر برشفات ماء بسكر، التدفئة، والإحالة الفورية للمستشفى.',
    },
    {
      'title': '🫁 السعال وصعوبة التنفس (Cough & Breathing)',
      'page': '20–24',
      'triage': 'RED / YELLOW',
      'criteria': 'عتبات التنفس السريع: ≥60 (< شهرين)، ≥50 (2–11 شهراً)، ≥40 (1–5 سنوات). انسحاب جدار الصدر أو صرير والطفل هادئ = التهاب رئوي وخيم (🔴).',
      'action': 'التهاب رئوي وخيم: أكسجين + جرعة تحويلية أولى + إحالة عاجلة. تنفس سريع فقط: أموكسيسيلين فموي 5 أيام ومتابعة بعد يومين.',
    },
    {
      'title': '💧 الإسهال والجفاف (Diarrhoea & Dehydration)',
      'page': '25–31',
      'triage': 'RED / YELLOW',
      'criteria': 'جفاف شديد (🔴 الخطة ج): علامتان (خمول/فقدان وعي، عيون غائرة، عجز عن الشرب، رجوع الجلد > ثانيتين). بعض الجفاف (🟡 الخطة ب): تململ/هياج، شرب بلهفة، رجوع الجلد ببطء.',
      'action': 'الخطة ج: رينجر لاكتات وريدي 100 مل/كجم. الخطة ب: محلول جفاف 75 مل/كجم خلال 4 ساعات + زنك لمدة 14 يوماً. دوزنتاريا (دم بالبراز): سيبروفلوكساسين 5 أيام.',
    },
    {
      'title': '🌡️ الحمى والأمراض الحموية (Fever & Malaria)',
      'page': '32–42',
      'triage': 'RED / YELLOW',
      'criteria': 'مرض حموي وخيم (🔴): تيبس بالرقبة أو أي علامة خطورة عامة. ملاريا: فحص RDT إيجابي أو سخونة مستمرة في منطقة توطن.',
      'action': 'مرض حموي وخيم: سيفترياكسون أو أمبيسيلين بالعضل + باراسيتامول للحمى ≥38.5°C + إحالة عاجلة. ملاريا غير وخيمة: كورس ACT كامل.',
    },
    {
      'title': '👂 مشاكل الأذن والتهاب الخشاء (Ear Problems)',
      'page': '43–46',
      'triage': 'RED / YELLOW',
      'criteria': 'التهاب الخشاء (🔴): تورم مؤلم خلف الأذن فوق عظمة الخشاء. التهاب أذن حاد: ألم بالأذن أو صديد يخرج منذ < 14 يوماً. مزمن: صديد منذ ≥ 14 يوماً.',
      'action': 'التهاب الخشاء: جرعة تحويلية من المضاد الحيوي + باراسيتامول + إحالة عاجلة. التهاب أذن حاد: أموكسيسيلين فموي 5 أيام وتجفيف الأذن.',
    },
    {
      'title': '🥗 سوء التغذية وفقر الدم (Malnutrition & Anaemia)',
      'page': '47–52',
      'triage': 'RED / YELLOW',
      'criteria': 'سوء تغذية وخيم (🔴): هزال شديد مرئي (جلد على عظم) أو وذمة بالقدمين. شحوب شديد براحة اليد = فقر دم وخيم.',
      'action': 'سوء تغذية وخيم: فيتامين أ + علاج لمنع هبوط السكر والحرارة + تحويل فوري لمركز تغذية علاجي (TFC). فقر دم غير وخيم: حديد + ميبندازول (> سنة).',
    },
    {
      'title': '👶 الرضيع الصغير (Young Infant 7d–2m PSBI)',
      'page': '61–72',
      'triage': 'RED',
      'criteria': 'تنفس سريع ≥60 نفس/د، انخفاض حرارة <35.5°C، شخير عند الزفير، انسحاب شديد بالصدر، خمول أو ضعف حركة.',
      'action': 'احتمال عدوى بكتيرية وخيمة (PSBI): أمبيسيلين 50 مجم/كجم عضل + جنتاميسين 5 مجم/كجم عضل + تدفئة + سكر + إحالة عاجلة. يمنع الأموكسيسيلين الفموي.',
    },
    {
      'title': '💉 التحصين وفيتامين أ (Immunization & Vitamin A)',
      'page': '53–55, 93',
      'triage': 'ROUTINE',
      'criteria': 'جدول التطعيمات الروتينية (EPI): BCG، شلل الأطفال، الخماسي، الحصبة، الروتا، المكورات الرئوية. فيتامين أ: وقائي كل 6 أشهر (> 6 أشهر).',
      'action': 'جرعات فيتامين أ العلاجية: < 6 أشهر (50,000 وحدة)، 6–11 شهراً (100,000 وحدة)، 1–5 سنوات (200,000 وحدة) في الحصبة وسوء التغذية.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _metronomeTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _performSemanticSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _activeSearchQuery = query;
    });

    try {
      final results = await ApiService().retrieveEvidence(query, topK: 3);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _toggleDripMetronome(double dropsPerMinute) {
    if (_isMetronomeRunning) {
      _metronomeTimer?.cancel();
      setState(() => _isMetronomeRunning = false);
    } else {
      final intervalMs = (60000.0 / dropsPerMinute.clamp(10.0, 300.0)).round();
      setState(() => _isMetronomeRunning = true);
      _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
        _pulseController.forward(from: 0.0);
      });
    }
  }

  void _recalculateDose(ChildModel? child) {
    if (child == null) return;
    final w = child.weightKg;

    if (_selectedMedication == 'amoxicillin') {
      if (w < 4.0) {
        _calculatedDoseMl = 0.0;
        _dosageInstructions = 'الوزن < 4 كجم: بروتوكول الرضع الصغار (أمبيسيلين 50mg/kg + جنتاميسين 5mg/kg بالعضل)';
      } else if (w < 10.0) {
        _calculatedDoseMl = 5.0;
        _dosageInstructions = '5.0 مل (125 مجم) فموياً مرتان يومياً لمدة 5 أيام';
      } else {
        _calculatedDoseMl = 10.0;
        _dosageInstructions = '10.0 مل (250 مجم) فموياً مرتان يومياً لمدة 5 أيام';
      }
    } else if (_selectedMedication == 'paracetamol') {
      if (w < 6.0) {
        _calculatedDoseMl = 2.5;
        _dosageInstructions = '2.5 مل (60 مجم) كل 6 ساعات عند اللزوم (الحرارة ≥ 38.5°C)';
      } else if (w < 10.0) {
        _calculatedDoseMl = 5.0;
        _dosageInstructions = '5.0 مل (120 مجم) كل 6 ساعات عند اللزوم';
      } else if (w < 14.0) {
        _calculatedDoseMl = 7.5;
        _dosageInstructions = '7.5 مل (180 مجم) كل 6 ساعات عند اللزوم';
      } else {
        _calculatedDoseMl = 10.0;
        _dosageInstructions = '10.0 مل (240 مجم) كل 6 ساعات عند اللزوم';
      }
    } else if (_selectedMedication == 'ibuprofen') {
      if (w < 6.0) {
        _calculatedDoseMl = 0.0;
        _dosageInstructions = 'غير موصى به للأطفال أقل من 6 كجم أو أقل من 3 أشهر';
      } else if (w < 10.0) {
        _calculatedDoseMl = 2.5;
        _dosageInstructions = '2.5 مل (50 مجم) 3 مرات يومياً بعد الرضاعة/الأكل';
      } else {
        _calculatedDoseMl = 5.0;
        _dosageInstructions = '5.0 مل (100 مجم) 3 مرات يومياً بعد الأكل';
      }
    } else if (_selectedMedication == 'zinc') {
      if (child.ageInMonths < 6.0) {
        _calculatedDoseMl = 2.5;
        _dosageInstructions = '10 مجم (نصف قرص مذاب في حليب الثدي) يومياً لمدة 14 يوماً';
      } else {
        _calculatedDoseMl = 5.0;
        _dosageInstructions = '20 مجم (قرص كامل مذاب في ماء/حليب) يومياً لمدة 14 يوماً';
      }
    } else if (_selectedMedication == 'vitamin_a') {
      if (child.ageInMonths < 6.0) {
        _calculatedDoseMl = 1.0;
        _dosageInstructions = '50,000 وحدة دولية (قطرة زرقاء واحدة) جرعة علاجية وحيدة';
      } else if (child.ageInMonths < 12.0) {
        _calculatedDoseMl = 2.0;
        _dosageInstructions = '100,000 وحدة دولية (كبسولة زرقاء كاملة) جرعة علاجية وحيدة';
      } else {
        _calculatedDoseMl = 4.0;
        _dosageInstructions = '200,000 وحدة دولية (كبسولة حمراء كاملة) جرعة علاجية وحيدة';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssessmentCubit, AssessmentState>(
      builder: (context, state) {
        final child = state.activeChild ??
            ChildModel(
              id: 'doc_active_child',
              name: 'المريض',
              birthDate: DateTime.now().subtract(const Duration(days: 420)),
              weightKg: 10.0,
              gender: 'male',
            );

        final asmt = state.currentAssessment;
        _recalculateDose(child);

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text('محطة عمل الطبيب 🩺', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16)),
              bottom: TabBar(
                indicatorColor: AppColors.medicalTeal,
                indicatorWeight: 3,
                labelColor: AppColors.medicalTealDark,
                unselectedLabelColor: AppColors.textMuted,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 11),
                unselectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 11),
                tabs: const [
                  Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'الأدلة والمراجع'),
                  Tab(icon: Icon(Icons.calculate_rounded, size: 18), text: 'الحاسبات والمحاليل'),
                  Tab(icon: Icon(Icons.assignment_ind_rounded, size: 18), text: 'الإحالة و SBAR'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // Tab 1: Guidelines Search & Expandable Protocols
                _buildTab1Guidelines(),

                // Tab 2: Calculators & IV Resuscitation
                _buildTab2Calculators(child),

                // Tab 3: Patient SBAR & QR Code
                _buildTab3Sbar(child, asmt),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 1: WHO GUIDELINES & PROTOCOL EXPLORER ---
  Widget _buildTab1Guidelines() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Semantic Search Header Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.medicalTeal.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'البحث الحي في دليل منظمة الصحة العالمية (142 صفحة) 🔎',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slateNavy,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث عن عرض أو جرعة أو بروتوكول...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.medicalTeal),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _activeSearchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onSubmitted: _performSemanticSearch,
              ),
              const SizedBox(height: 10),

              // Suggestion Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestedQueries.map((q) {
                  return ActionChip(
                    label: Text(q, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.bgLight,
                    onPressed: () {
                      _searchController.text = q;
                      _performSemanticSearch(q);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Live Search Results
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchResults.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نتائج البحث عن: "$_activeSearchQuery" (${_searchResults.length})',
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.medicalTealDark),
              ),
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.medicalTeal,
                  selectedForegroundColor: Colors.white,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('عربي')),
                  ButtonSegment(value: true, label: Text('EN')),
                ],
                selected: {_searchShowEnglish},
                onSelectionChanged: (set) => setState(() => _searchShowEnglish = set.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._searchResults.map((ev) => _buildSearchResultCard(ev)),
          const Divider(height: 28, color: AppColors.borderLight),
        ],

        // 8 Interactive Expandable WHO IMCI Protocol Cards
        Text(
          'بروتوكولات الفرز السريري (8 WHO IMCI Master Protocols) 📑',
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.slateNavy,
          ),
        ),
        const SizedBox(height: 10),

        ..._expandedProtocols.map((p) => _buildExpandableProtocolCard(p)),
      ],
    );
  }

  Widget _buildSearchResultCard(EvidenceModel ev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Expanded(
                child: Text(
                  ev.sectionTitle,
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slateNavy),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.medicalTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ص ${ev.page} • ${ev.relevanceScore.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.medicalTealDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _searchShowEnglish
                ? Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      ev.highlightTextEn.isNotEmpty ? ev.highlightTextEn : 'Verbatim clinical text from WHO handbook.',
                      style: GoogleFonts.inter(fontSize: 12, height: 1.5, color: AppColors.textMain),
                    ),
                  )
                : Directionality(
                    textDirection: TextDirection.rtl,
                    child: SelectableText(
                      ev.highlightTextAr.isNotEmpty ? ev.highlightTextAr : 'البروتوكول السريري المعتمد من دليل منظمة الصحة العالمية.',
                      style: GoogleFonts.cairo(fontSize: 12, height: 1.55, fontWeight: FontWeight.w600, color: AppColors.textMain),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableProtocolCard(Map<String, dynamic> p) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceWhite,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p['triage'] == 'RED'
                  ? AppColors.emergencyRedBg
                  : (p['triage'] == 'YELLOW' ? AppColors.clinicalAmberBg : AppColors.safeEmeraldBg),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.health_and_safety_rounded,
              size: 20,
              color: p['triage'] == 'RED'
                  ? AppColors.emergencyRed
                  : (p['triage'] == 'YELLOW' ? AppColors.clinicalAmber : AppColors.safeEmerald),
            ),
          ),
          title: Text(
            p['title'] as String,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.slateNavy),
          ),
          subtitle: Text(
            'الصفحة: ${p['page']} من دليل WHO IMCI',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 10),
                  Text('المعايير والعلامات السريرية:',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slateNavy)),
                  Text(p['criteria'] as String,
                      style: GoogleFonts.cairo(fontSize: 12, height: 1.5, color: AppColors.textMain)),
                  const SizedBox(height: 8),
                  Text('الإجراء والتدبير التحويلي العاجل:',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.emergencyRedDark)),
                  Text(p['action'] as String,
                      style: GoogleFonts.cairo(fontSize: 12, height: 1.5, color: AppColors.textMain)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: CALCULATORS & IV FLUID RESUSCITATION ---
  Widget _buildTab2Calculators(ChildModel child) {
    // Plan C Drip Calculation (20 drops/ml standard)
    final dripRateStage1 = (child.weightKg * 30.0 * 20.0 / 60.0).roundToDouble();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Medication Selection Chips
        Text(
          'حاسبة الجرعات بالمحقنة السريرية 💉',
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slateNavy),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildMedChip('amoxicillin', 'أموكسيسيلين (125mg/5ml)'),
            _buildMedChip('paracetamol', 'باراسيتامول (120mg/5ml)'),
            _buildMedChip('ibuprofen', 'إيبوبروفين (100mg/5ml)'),
            _buildMedChip('zinc', 'زنك فموي (20mg)'),
            _buildMedChip('vitamin_a', 'فيتامين أ (علاجي)'),
          ],
        ),
        const SizedBox(height: 14),

        // Syringe Visualizer
        SyringeVisualizerWidget(
          currentVolumeMl: _calculatedDoseMl,
          maxVolumeMl: 10.0,
          medicationName: _getMedNameArabic(_selectedMedication),
          frequencyText: _dosageInstructions,
        ),

        const SizedBox(height: 22),

        // Plan C IV Fluid Calculator
        Text(
          'خطة إنعاش الجفاف الشديد (Plan C: رينجر لاكتات 100 مل/كجم) 💧',
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slateNavy),
        ),
        const SizedBox(height: 10),
        IvFluidCalculatorWidget(child: child),
        const SizedBox(height: 12),

        // IV Drip Rate Metronome Widget
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isMetronomeRunning ? AppColors.medicalTeal.withOpacity(0.2) : AppColors.bgLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 24,
                    color: _isMetronomeRunning ? AppColors.medicalTealDark : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معدل التنقيط الوريدي (المرحلة الأولى)',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${dripRateStage1.toStringAsFixed(0)} قطرة / دقيقة (20 drops/ml)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.medicalTealDark,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMetronomeRunning ? AppColors.emergencyRed : AppColors.medicalTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () => _toggleDripMetronome(dripRateStage1),
                child: Text(
                  _isMetronomeRunning ? 'إيقاف' : 'تشغيل النبض',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Pediatric Early Warning Score (PEWS) Deterioration Predictor
        PewsCardWidget(child: child),
        const SizedBox(height: 22),

        // Pediatric Emergency CPR & Resuscitation Quick Guide
        _buildEmergencyResuscitationCard(child),
      ],
    );
  }

  Widget _buildEmergencyResuscitationCard(ChildModel? child) {
    final w = child?.weightKg ?? 10.0;
    final epiDoseMg = (w * 0.01).toStringAsFixed(2);
    final epiDoseMl = (w * 0.1).toStringAsFixed(1); // 1:10,000 (0.1 ml/kg)
    final shockJoules = (w * 2.0).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.emergencyRedBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.emergencyRed.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.emergencyRedBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency_outlined, color: AppColors.emergencyRed, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دليل الإنعاش القلبي الرئوي السريع (PALS Resuscitation) 🚨',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.slateNavy),
                    ),
                    Text(
                      'جرعات الطوارئ محسوبة لوزن ($w كجم)',
                      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResusRow('نسبة الضغطات والتنفس (CPR Ratio):', '15 ضغطة : 2 نفس إنعاشي (معدل 100-120/دقيقة)'),
          const SizedBox(height: 6),
          _buildResusRow('جرعة الأدرينالين (Epinephrine 1:10,000):', '$epiDoseMl مل ($epiDoseMg مجم) وريدي/عظمي كل 3-5 دقائق'),
          const SizedBox(height: 6),
          _buildResusRow('جرعة الصدمة الكهربائية (Defibrillation):', '$shockJoules جول (2 Joules/kg للصدمة الأولى)'),
          const SizedBox(height: 6),
          _buildResusRow('انسداد مجرى الهواء بالبلع (Choking):', '5 خبطات ظهرية متبادلة مع 5 ضغطات صدرية'),
        ],
      ),
    );
  }

  Widget _buildResusRow(String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slateNavy)),
          Text(desc, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.emergencyRedDark)),
        ],
      ),
    );
  }

  Widget _buildMedChip(String key, String label) {
    final isSelected = _selectedMedication == key;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700)),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedMedication = key);
      },
    );
  }

  String _getMedNameArabic(String key) {
    switch (key) {
      case 'amoxicillin':
        return 'Amoxicillin Oral Suspension (125mg/5ml)';
      case 'paracetamol':
        return 'Paracetamol Pediatric Syrup (120mg/5ml)';
      case 'ibuprofen':
        return 'Ibuprofen Suspension (100mg/5ml)';
      case 'zinc':
        return 'Zinc Sulfate Dispersible Tablets (20mg)';
      case 'vitamin_a':
        return 'Vitamin A Retinol Soft Gel Capsule';
      default:
        return 'Oral Medication';
    }
  }

  // --- TAB 3: PATIENT SUMMARY, SBAR & QR REFERRAL ---
  Widget _buildTab3Sbar(ChildModel child, dynamic asmt) {
    final qrData =
        'PEDIACARE_SBAR:${child.name}|${child.ageFormattedArabic}|${child.weightKg}kg|TRIAGE:${asmt?.triageLevel ?? "RED"}|STATUS:VERIFIED';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Patient Vitals Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المريض: ${child.name}',
                    style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  if (asmt != null) TriageBadgeWidget(triageLevel: asmt.triageLevel, isCompact: true),
                ],
              ),
              Text(
                '${child.ageFormattedArabic} • ${child.weightKg} كجم • ${child.gender == "female" ? "أنثى" : "ذكر"}',
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.white.withOpacity(0.9)),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('الحرارة', '${asmt?.temperatureC?.toStringAsFixed(1) ?? "37.5"}°C'),
                  _buildMiniStat('معدل التنفس', '${asmt?.respiratoryRate ?? "40"} نفس/د'),
                  _buildMiniStat('المدة', 'يومان (حالة حادة)'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // SBAR Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ملخص التسليم السريري (SBAR Summary):',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slateNavy)),
              const SizedBox(height: 8),
              _buildSbarRow('S', 'الموقف:', asmt?.summaryFound?.join(', ') ?? 'أعراض حادة مستجدة'),
              _buildSbarRow('B', 'التاريخ:', 'خالٍ من الأمراض المزمنة، التطعيمات مكتملة'),
              _buildSbarRow('A', 'التقييم:', asmt?.triageLabelAr ?? 'فرز وفق دليل منظمة الصحة العالمية'),
              _buildSbarRow('R', 'التوصية:', asmt?.fullRecommendation ?? 'استكمال الفحص والعلاج التحويلي العاجل'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // QR Code
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Text('رمز الإحالة المشفر (SBAR Emergency QR):',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slateNavy)),
              const SizedBox(height: 12),
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 150.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.slateNavy),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.medicalTealDark),
              ),
              const SizedBox(height: 10),
              Text(
                'مسح الرمز ينقل التقييم المعتمد لقسم الطوارئ فوراً.',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: AppColors.slateNavy,
          ),
          onPressed: () {
            Share.share(
              '🏥 تقرير إحالة سريرية (SBAR) - PediaCare.AI\nالمريض: ${child.name}\nالتصنيف: ${asmt?.triageLabelAr ?? "RED"}\nالتوصية: ${asmt?.fullRecommendation ?? ""}',
              subject: 'تقرير إحالة PediaCare.AI',
            );
          },
          icon: const Icon(Icons.share_rounded, color: Colors.white),
          label: Text('مشاركة التقرير مع المستشفى المعالج', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.cairo(fontSize: 10, color: Colors.white70)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }

  Widget _buildSbarRow(String letter, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.medicalTeal.withOpacity(0.15),
            child: Text(letter, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.medicalTealDark)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textMain),
                children: [
                  TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: desc.length > 90 ? '${desc.substring(0, 90)}...' : desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
