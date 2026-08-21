import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediacare_ai/cubit/assessment_cubit.dart';
import 'package:pediacare_ai/main.dart';
import 'package:pediacare_ai/models/child_model.dart';
import 'package:pediacare_ai/screens/05_evidence_sources_screen.dart';
import 'package:pediacare_ai/screens/06_doctor_summary_screen.dart';
import 'package:pediacare_ai/screens/07_doctor_workstation_screen.dart';
import 'package:pediacare_ai/utils/offline_imci_engine.dart';
import 'package:pediacare_ai/widgets/triage_badge.dart';

void main() {
  group('1. Offline WHO IMCI Clinical Decision Tree Engine Tests', () {
    final testChild23m = ChildModel(
      id: 'tc_older',
      name: 'كيرلس',
      birthDate: DateTime.now().subtract(const Duration(days: 700)), // 23 months
      weightKg: 12.0,
      gender: 'male',
    );

    final testInfant3w = ChildModel(
      id: 'tc_young',
      name: 'سارة',
      birthDate: DateTime.now().subtract(const Duration(days: 21)), // 3 weeks
      weightKg: 3.5,
      gender: 'female',
    );

    test('Query Age Override: 3-week-old infant on 23m profile escalates to RED PSBI in English', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: '3-week-old young infant with breathing rate 66 breaths/min, axillary temperature 35.2°C (hypothermia), and expiratory grunting',
        child: testChild23m, // older profile passed
      );

      expect(res.triageLevel, 'RED');
      expect(res.isRed, true);
      expect(res.detectedLanguage, 'en');
      expect(res.triageLabelEn.contains('POSSIBLE SERIOUS BACTERIAL INFECTION'), true);
      expect(res.fullRecommendation.contains('Ampicillin'), true);
      expect(res.fullRecommendation.contains('Gentamicin'), true);
      expect(res.summaryFound, isNotEmpty);
      expect(res.evidenceList.length, 4);
    });

    test('Severe Pneumonia returns 4 distinct chunks from Pages 20, 21, 22, 23 (No Page 16 trap)', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'كحة وسحب للصدر مع صعوبة في التنفس',
        child: testChild23m,
      );

      expect(res.triageLevel, 'RED');
      expect(res.isRed, true);
      expect(res.evidenceList.length, 4);
      final pages = res.evidenceList.map((e) => e.page).toList();
      expect(pages, [20, 21, 22, 23]);
      expect(res.evidenceList.first.sectionTitle.contains('SEVERE PNEUMONIA'), true);
    });

    test('General Danger Signs without chest indrawing returns 4 chunks from Pages 16, 17, 18, 19', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'الطفل غير قادر على الشرب ويتقيأ كل شيء ويعاني من خمول',
        child: testChild23m,
      );

      expect(res.triageLevel, 'RED');
      expect(res.triageLabelAr.contains('خطورة عامة'), true);
      expect(res.evidenceList.length, 4);
      final pages = res.evidenceList.map((e) => e.page).toList();
      expect(pages, [16, 17, 18, 19]);
    });

    test('Fast breathing without chest indrawing returns 4 Pneumonia chunks from Pages 20, 22, 21, 23', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'كحة منذ 3 أيام مع تنفس سريع 48 نفس بالدقيقة بدون انسحاب صدر',
        child: testChild23m,
      );

      expect(res.triageLevel, 'YELLOW');
      expect(res.isYellow, true);
      expect(res.evidenceList.length, 4);
      final pages = res.evidenceList.map((e) => e.page).toList();
      expect(pages, [20, 22, 21, 23]);
    });

    test('Severe dehydration with sunken eyes and slow skin pinch returns 4 chunks from Pages 28, 143, 27, 25', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'إسهال وجفاف مائي مستمر، عيون غائرة والجلد يرجع ببطء شديد',
        child: testChild23m,
      );

      expect(res.triageLevel, 'RED');
      expect(res.triageLabelAr.contains('جفاف شديد'), true);
      expect(res.evidenceList.length, 4);
      final pages = res.evidenceList.map((e) => e.page).toList();
      expect(pages, [28, 143, 27, 25]);
    });

    test('Blood in stool returns 4 Dysentery chunks from Pages 26, 30, 25, 28', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'إسهال مع دم في البراز ومخاط',
        child: testChild23m,
      );

      expect(res.triageLevel, 'YELLOW');
      expect(res.triageLabelAr.contains('دوزنتاريا'), true);
      expect(res.evidenceList.length, 4);
      final pages = res.evidenceList.map((e) => e.page).toList();
      expect(pages, [26, 30, 25, 28]);
    });

    test('Young infant with fast breathing (>=60 bpm) returns 4 PSBI chunks from Pages 62, 64, 61, 86', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'رضيع صغير يتنفس 66 نفس في الدقيقة مع انخفاض حرارة',
        child: testInfant3w,
      );

      expect(res.triageLevel, 'RED');
      expect(res.triageLabelAr.contains('بكتيرية وخيمة'), true);
      expect(res.evidenceList.length, 4);
      final pages = res.evidenceList.map((e) => e.page).toList();
      expect(pages, [62, 64, 61, 86]);
    });

    test('0ms Verification recalculation dynamically escalates triage to RED', () {
      final initial = OfflineImciEngine.evaluateLocally(
        query: 'كحة ورشح بسيط',
        child: testChild23m,
      );
      expect(initial.triageLevel, 'GREEN');

      final recalculated = OfflineImciEngine.evaluateLocally(
        query: 'كحة ورشح بسيط',
        child: testChild23m,
        verificationAnswers: {
          'هل يوجد انسحاب لأسفل جدار الصدر للداخل عند التنفس؟': true,
        },
      );

      expect(recalculated.triageLevel, 'RED');
      expect(recalculated.isRed, true);
    });

    test('Adult OOD Query Guardrail Refusal: Adult cardiology query returns REFUSAL (Zero Green Fallback)', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'علاج انسداد الشريان التاجي والنيتروجليسرين للبالغين',
        child: testChild23m,
      );

      expect(res.triageLevel, 'REFUSAL');
      expect(res.isGreen, false);
      expect(res.isYellow, false);
      expect(res.isRed, false);
      expect(res.triageLabelAr.contains('خارج نطاق طب الأطفال'), true);
      expect(res.fullRecommendation.contains('طبيب متخصص في طب البالغين'), true);
    });

    test('Adult OOD Query Guardrail Refusal in English returns REFUSAL', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'Adult cardiology hypertension treatment with nitroglycerin',
        child: testChild23m,
      );

      expect(res.triageLevel, 'REFUSAL');
      expect(res.isGreen, false);
      expect(res.triageLabelEn.contains('OUT OF DOMAIN'), true);
    });

    test('Non-Medical Input Gatekeeper: Chit-chat query "اي رايك ف لبسي" returns NON_CLINICAL_QUERY (Zero Green Fallback)', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'اي رايك ف لبسي (منذ أكثر من 3 أيام)',
        child: testChild23m,
      );

      expect(res.triageLevel, 'GRAY');
      expect(res.status, 'NON_CLINICAL_QUERY');
      expect(res.isGreen, false);
      expect(res.isYellow, false);
      expect(res.isRed, false);
      expect(res.triageLabelAr.contains('خارج النطاق الطبي'), true);
      expect(res.fullRecommendation.contains('عذراً، هذا الاستفسار غير طبي'), true);
    });

    test('Non-Medical Input Gatekeeper in English returns NON_CLINICAL_QUERY', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'Hello what outfit should I wear today',
        child: testChild23m,
      );

      expect(res.triageLevel, 'GRAY');
      expect(res.status, 'NON_CLINICAL_QUERY');
      expect(res.isGreen, false);
      expect(res.triageLabelEn.contains('NON-CLINICAL QUERY'), true);
    });

    test('Negation-Aware Triage: Query with negative danger signs returns GREEN instead of false RED', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'الطفل عنده كحة ورشح من يومين، لا يوجد تشنج ولا قيء ولا انسحاب بالصدر ويرضع بشكل طبيعي',
        child: testChild23m,
      );

      expect(res.triageLevel, 'GREEN');
      expect(res.isGreen, true);
      expect(res.isRed, false);
      expect(res.triageLabelAr.contains('رعاية منزلية'), true);
    });

    test('Ear Pain query correctly classifies as YELLOW Acute Ear Infection', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'طفل 3 سنوات يشتكي من ألم في الأذن منذ يومين',
        child: testChild23m,
      );

      expect(res.triageLevel, 'YELLOW');
      expect(res.isYellow, true);
      expect(res.triageLabelAr.contains('التهاب الأذن'), true);
      expect(res.fullRecommendation.contains('أموكسيسيلين'), true);
    });

    test('Diarrhea without dehydration correctly classifies as GREEN Plan A', () {
      final res = OfflineImciEngine.evaluateLocally(
        query: 'طفل عنده إسهال مائي منذ يوم ويرضع بشكل طبيعي ونشيط',
        child: testChild23m,
      );

      expect(res.triageLevel, 'GREEN');
      expect(res.isGreen, true);
      expect(res.triageLabelAr.contains('الخطة أ'), true);
      expect(res.fullRecommendation.contains('الزنك'), true);
    });
  });

  group('2. Widget & App UI Tests', () {
    final sampleChild = ChildModel(
      id: 'c_test_01',
      name: 'كيرلس',
      birthDate: DateTime.now().subtract(const Duration(days: 700)),
      weightKg: 10.0,
      gender: 'male',
    );

    final sampleAsmt = OfflineImciEngine.evaluateLocally(
      query: 'كحة مع تنفس سريع 48 نفس بالدقيقة منذ يومين',
      child: sampleChild,
    );

    testWidgets('TriageBadgeWidget renders RED emergency badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TriageBadgeWidget(
              triageLevel: 'RED',
              label: 'خطر عاجل - تحويل فوري للمستشفى 🔴',
            ),
          ),
        ),
      );

      expect(find.text('خطر عاجل - تحويل فوري للمستشفى 🔴'), findsOneWidget);
    });

    testWidgets('PediaCareApp boots into RoleSelectionScreen with strictly 2 role cards', (tester) async {
      await tester.pumpWidget(const PediaCareApp());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('PediaCare.AI'), findsOneWidget);
      expect(find.text('اختر وضع الاستخدام المناسب'), findsOneWidget);
      expect(find.text('ولي أمر (Parent / Guardian)'), findsOneWidget);
      expect(find.text('طبيب أطفال (Pediatrician / Clinician)'), findsOneWidget);
      expect(find.text('عيادة / مركز صحي (Health Center)'), findsNothing);
    });

    testWidgets('DoctorSummaryScreen (Screen 06) renders Vitals Header and SBAR sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => AssessmentCubit(),
            child: DoctorSummaryScreen(assessment: sampleAsmt),
          ),
        ),
      );

      expect(find.text('تقرير التسليم السريري (SBAR)'), findsOneWidget);
      expect(find.text('درجة الحرارة'), findsOneWidget);
      expect(find.text('معدل التنفس'), findsOneWidget);
      expect(find.text('مدة الأعراض'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('EvidenceSourcesScreen (Screen 05) renders 4 Verbatim Chunks and 1-Tap Toggle', (tester) async {
      final evList = sampleAsmt.evidenceList;

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceSourcesScreen(evidenceList: evList),
        ),
      );

      expect(find.text('المستندات والأدلة السريرية'), findsOneWidget);
      expect(find.text('لغة عرض النصوص المقتبسة'), findsOneWidget);
      expect(find.text('فاحص التوثيق السريري الثلاثي (RAG Triad)'), findsOneWidget);
      expect(find.text('دليل #1'), findsOneWidget);
    });

    testWidgets('DoctorWorkstationScreen (Screen 07) renders 3 Tabs and Protocols', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => AssessmentCubit(),
            child: const DoctorWorkstationScreen(),
          ),
        ),
      );

      expect(find.text('الأدلة والمراجع'), findsOneWidget);
      expect(find.text('الحاسبات والمحاليل'), findsOneWidget);
      expect(find.text('الإحالة و SBAR'), findsOneWidget);
      expect(find.text('البحث الحي في دليل منظمة الصحة العالمية (142 صفحة) 🔎'), findsOneWidget);
    });
  });
}
