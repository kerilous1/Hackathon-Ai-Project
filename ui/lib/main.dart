import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/hive_service.dart';
import 'cubit/assessment_cubit.dart';
import 'theme/app_theme.dart';
import 'screens/01_role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize strongly-typed Hive storage
  await HiveService.init();

  // Configure system UI overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const PediaCareApp());
}

class PediaCareApp extends StatelessWidget {
  const PediaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AssessmentCubit(),
      child: MaterialApp(
        title: 'PediaCare.AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // Robust Arabic RTL Configuration
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [
          Locale('ar', 'EG'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const RoleSelectionScreen(),
      ),
    );
  }
}
