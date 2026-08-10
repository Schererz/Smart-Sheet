import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum PeriodoFiltro { dia1, semana1, mes1, mes3, mes6, tudo }

extension PeriodoFiltroRotulo on PeriodoFiltro {
  String get rotulo {
    switch (this) {
      case PeriodoFiltro.dia1:
        return '1D';
      case PeriodoFiltro.semana1:
        return '1S';
      case PeriodoFiltro.mes1:
        return '1M';
      case PeriodoFiltro.mes3:
        return '3M';
      case PeriodoFiltro.mes6:
        return '6M';
      case PeriodoFiltro.tudo:
        return 'Tudo';
    }
  }

  /// Data de corte pra esse período (null = sem corte, mostra tudo).
  DateTime? dataDeCorte() {
    final hoje = DateTime.now();
    switch (this) {
      case PeriodoFiltro.dia1:
        return hoje.subtract(const Duration(days: 1));
      case PeriodoFiltro.semana1:
        return hoje.subtract(const Duration(days: 7));
      case PeriodoFiltro.mes1:
        return hoje.subtract(const Duration(days: 30));
      case PeriodoFiltro.mes3:
        return hoje.subtract(const Duration(days: 90));
      case PeriodoFiltro.mes6:
        return hoje.subtract(const Duration(days: 180));
      case PeriodoFiltro.tudo:
        return null;
    }
  }
}

class SeletorPeriodo extends StatelessWidget {
  final PeriodoFiltro selecionado;
  final ValueChanged<PeriodoFiltro> onSelecionar;

  const SeletorPeriodo({super.key, required this.selecionado, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: PeriodoFiltro.values.map((periodo) {
          final ativo = periodo == selecionado;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => onSelecionar(periodo),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ativo ? AppColors.destaque.withValues(alpha: 0.18) : AppColors.superficie,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ativo ? AppColors.destaque.withValues(alpha: 0.6) : AppColors.borda),
                ),
                child: Text(
                  periodo.rotulo,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ativo ? AppColors.destaque : AppColors.textoSecundario,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
