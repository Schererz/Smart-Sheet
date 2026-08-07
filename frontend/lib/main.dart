import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ApostasApp());
}

class ApostasApp extends StatelessWidget {
  const ApostasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planilha de Apostas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      home: const HomeScreen(),
    );
  }
}
