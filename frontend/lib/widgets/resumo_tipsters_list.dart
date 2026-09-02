import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/resumo_calculado.dart';

class ResumoTipstersList extends StatelessWidget {
  final List<ResumoPorTipster> tipsters;

  const ResumoTipstersList({super.key, required this.tipsters});

  @override
  Widget build(BuildContext context) {
    if (tipsters.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Assim que suas apostas tiverem um tipster marcado, a comparação aparece aqui.',
          style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
        ),
      );
    }

    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      children: tipsters.map((t) {
        final corLucro = t.lucroTotal >= 0 ? AppColors.green : AppColors.red;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.tipster, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  ),
                  Text(
                    formatoMoeda.format(t.lucroTotal),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: corLucro),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Estatistica(rotulo: 'Apostas', valor: '${t.totalApostas}'),
                  _Estatistica(
                    rotulo: 'Acerto',
                    valor: t.taxaAcerto != null ? '${t.taxaAcerto!.toStringAsFixed(0)}%' : '—',
                  ),
                  _Estatistica(rotulo: 'Investido', valor: formatoMoeda.format(t.totalApostado)),
                  _Estatistica(
                    rotulo: 'ROI',
                    valor: t.roiApostado != null ? '${t.roiApostado!.toStringAsFixed(1)}%' : '—',
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Estatistica extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _Estatistica({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          Text(rotulo, style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ],
      ),
    );
  }
}
