import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubit/assessment_cubit.dart';
import 'cubit/assessment_state.dart';
import 'screens/01_role_selection_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PediaCareApp());
}

class PediaCareApp extends StatelessWidget {
  const PediaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AssessmentCubit()..init(),
      child: BlocBuilder<AssessmentCubit, AssessmentState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'PediaCare.AI — WHO IMCI CDSS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            builder: (context, child) {
              return Directionality(
                textDirection: state.isArabicMode ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              );
            },
            home: const RoleSelectionScreen(),
          );
        },
      ),
    );
  }
}
