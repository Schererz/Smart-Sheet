import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../theme/app_theme.dart';

class ResumoCasasList extends StatelessWidget {
  final List<ResumoPorCasa> casas;

  const ResumoCasasList({super.key, required this.casas});

  @override
  Widget build(BuildContext context) {
    if (casas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Assim que você tiver apostas em mais de uma casa, a comparação aparece aqui.',
          style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
        ),
      );
    }

    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      children: casas.map((c) {
        final corLucro = c.lucroTotal >= 0 ? AppColors.green : AppColors.red;
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
                    child: Text(c.casa, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  ),
                  Text(
                    formatoMoeda.format(c.lucroTotal),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: corLucro),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Estatistica(rotulo: 'Apostas', valor: '${c.totalApostas}'),
                  _Estatistica(
                    rotulo: 'Acerto',
                    valor: c.taxaAcerto != null ? '${c.taxaAcerto!.toStringAsFixed(0)}%' : '—',
                  ),
                  _Estatistica(rotulo: 'Odd média', valor: c.oddMedia?.toStringAsFixed(2) ?? '—'),
                  _Estatistica(
                    rotulo: c.roiBanca != null ? 'ROI banca' : 'ROI',
                    valor: c.roiBanca != null
                        ? '${c.roiBanca!.toStringAsFixed(1)}%'
                        : (c.roiApostado != null ? '${c.roiApostado!.toStringAsFixed(1)}%' : '—'),
                  ),
                ],
              ),
              if (c.bancaInicial != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Banca: ${formatoMoeda.format(c.bancaInicial)} → ${formatoMoeda.format(c.bancaAtual)}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario),
                ),
              ],
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
