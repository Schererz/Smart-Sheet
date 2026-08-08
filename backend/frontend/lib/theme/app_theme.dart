import 'package:flutter/material.dart';

/// Paleta pensada pra um "hub" de apostas: fundo escuro (uso à noite/no dia
/// a dia é confortável), cards neutros, e as cores de status (green/red)
/// bem separadas de qualquer outra cor da interface — elas precisam ser
/// reconhecidas num piscar de olhos na lista.
class AppColors {
  static const fundo = Color(0xFF0F1115);
  static const superficie = Color(0xFF171A21);
  static const superficieAlta = Color(0xFF1F232C);
  static const borda = Color(0xFF2A2F3A);

  static const textoPrimario = Color(0xFFEDEDEF);
  static const textoSecundario = Color(0xFF9096A2);

  static const destaque = Color(0xFF5B8DEF); // links, ações principais
  static const aberto = Color(0xFFE8A33D); // aposta pendente
  static const green = Color(0xFF2FB67C); // aposta ganha
  static const red = Color(0xFFE5484D); // aposta perdida
}

class AppTheme {
  static ThemeData get tema {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fundo,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.superficie,
        primary: AppColors.destaque,
        secondary: AppColors.destaque,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.fundo,
        foregroundColor: AppColors.textoPrimario,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textoPrimario,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textoPrimario,
        displayColor: AppColors.textoPrimario,
      ),
      cardTheme: CardThemeData(
        color: AppColors.superficie,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borda),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficieAlta,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textoSecundario),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.destaque,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.destaque,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Cor associada a cada status — usada no botão que cicla aberto/green/red.
  static Color corDoStatus(String resultado) {
    switch (resultado) {
      case 'green':
        return AppColors.green;
      case 'red':
        return AppColors.red;
      default:
        return AppColors.aberto;
    }
  }

  static String rotuloDoStatus(String resultado) {
    switch (resultado) {
      case 'green':
        return 'GREEN';
      case 'red':
        return 'RED';
      default:
        return 'ABERTO';
    }
  }
}
