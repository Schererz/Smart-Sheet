import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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


class PeriodoSelecionado {
  final PeriodoFiltro? preset; // null quando for personalizado
  final DateTimeRange? personalizado;

  const PeriodoSelecionado.preset(this.preset) : personalizado = null;
  const PeriodoSelecionado.range(DateTimeRange intervalo)
      : preset = null,
        personalizado = intervalo;

  static const tudo = PeriodoSelecionado.preset(PeriodoFiltro.tudo);

  bool get ehPersonalizado => personalizado != null;

  /// Data de início do filtro (inclusive). Null = sem limite inferior.
  DateTime? get inicio {
    if (personalizado != null) {
      final i = personalizado!.start;
      return DateTime(i.year, i.month, i.day);
    }
    return preset?.dataDeCorte();
  }

  DateTime? get fim {
    if (personalizado == null) return null;
    final f = personalizado!.end;
    return DateTime(f.year, f.month, f.day, 23, 59, 59);
  }

  String get rotulo {
    if (personalizado != null) {
      final formato = DateFormat('dd/MM');
      return '${formato.format(personalizado!.start)} - ${formato.format(personalizado!.end)}';
    }
    return preset!.rotulo;
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodoSelecionado &&
      other.preset == preset &&
      other.personalizado?.start == personalizado?.start &&
      other.personalizado?.end == personalizado?.end;

  @override
  int get hashCode => Object.hash(preset, personalizado?.start, personalizado?.end);
}

class SeletorPeriodo extends StatelessWidget {
  final PeriodoSelecionado selecionado;
  final ValueChanged<PeriodoSelecionado> onSelecionar;

  const SeletorPeriodo({super.key, required this.selecionado, required this.onSelecionar});

  Future<void> _escolherIntervalo(BuildContext context) async {
    final agora = DateTime.now();
    final intervalo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(agora.year - 5),
      lastDate: agora,
      initialDateRange: selecionado.personalizado ??
          DateTimeRange(start: agora.subtract(const Duration(days: 30)), end: agora),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.destaque,
                onPrimary: Colors.white,
                surface: AppColors.superficieAlta,
              ),
        ),
        child: child!,
      ),
    );
    if (intervalo != null) {
      onSelecionar(PeriodoSelecionado.range(intervalo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...PeriodoFiltro.values.map((periodo) {
            final ativo = !selecionado.ehPersonalizado && periodo == selecionado.preset;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Chip(
                rotulo: periodo.rotulo,
                ativo: ativo,
                onTap: () => onSelecionar(PeriodoSelecionado.preset(periodo)),
              ),
            );
          }),
          _Chip(
            rotulo: selecionado.ehPersonalizado ? selecionado.rotulo : '📅',
            ativo: selecionado.ehPersonalizado,
            onTap: () => _escolherIntervalo(context),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;

  const _Chip({required this.rotulo, required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ativo ? AppColors.destaque.withValues(alpha: 0.18) : AppColors.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? AppColors.destaque.withValues(alpha: 0.6) : AppColors.borda),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: ativo ? AppColors.destaque : AppColors.textoSecundario,
          ),
        ),
      ),
    );
  }
}
