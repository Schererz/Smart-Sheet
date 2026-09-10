import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';
import '../utils/resumo_calculado.dart';

/// Paleta usada pras linhas de tipster (a linha "Total" tem cor própria,
/// verde/vermelho conforme o resultado). Se aparecerem mais tipsters que
/// cores, ela repete — o que é aceitável, já que na prática são poucos.
const coresTipster = [
  Color(0xFF4B9EE0), // azul
  Color(0xFFE0B84B), // amarelo
  Color(0xFF9B6FE0), // roxo
  Color(0xFF4BE0B8), // turquesa
  Color(0xFFE06FA8), // rosa
];

const _semTipster = 'Sem tipster';

/// Gráfico de evolução da banca com uma linha por tipster.
///
/// Os botões embaixo NÃO são só "mostrar/esconder a linha": desmarcar um
/// tipster o remove do cálculo do TOTAL também, respondendo "como estaria
/// minha banca se eu não tivesse seguido esse cara?".
class EvolucaoBancaMultiChart extends StatefulWidget {
  final List<Aposta> apostas;
  final double bancaInicial;

  const EvolucaoBancaMultiChart({super.key, required this.apostas, required this.bancaInicial});

  @override
  State<EvolucaoBancaMultiChart> createState() => _EvolucaoBancaMultiChartState();
}

class _EvolucaoBancaMultiChartState extends State<EvolucaoBancaMultiChart> {
  final Set<String> _excluidos = {};

  String _tipsterDe(Aposta a) =>
      (a.tipster == null || a.tipster!.trim().isEmpty) ? _semTipster : a.tipster!;

  List<String> get _nomesTipsters {
    final nomes = widget.apostas.map(_tipsterDe).toSet().toList()..sort();
    return nomes;
  }

  @override
  Widget build(BuildContext context) {
    final nomes = _nomesTipsters;

    // apostas que entram na conta do total: só as de tipsters marcados
    final apostasConsideradas =
        widget.apostas.where((a) => !_excluidos.contains(_tipsterDe(a))).toList();

    final total = construirEvolucaoLocal(apostasConsideradas, widget.bancaInicial);

    // uma linha por tipster que continua marcado
    final series = <String, List<PontoEvolucaoBanca>>{};
    for (final nome in nomes) {
      if (_excluidos.contains(nome)) continue;
      series[nome] = construirEvolucaoLocal(
        widget.apostas.where((a) => _tipsterDe(a) == nome).toList(),
        widget.bancaInicial,
      );
    }

    if (widget.apostas.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'A evolução da banca aparece aqui assim que você tiver apostas resolvidas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
          ),
        ),
      );
    }

    final todasAsDatas = [
      ...total.map((p) => p.data),
      for (final pontos in series.values) ...pontos.map((p) => p.data),
    ];

    final linhas = <LineChartBarData>[];
    final valoresY = <double>[];

    if (todasAsDatas.isNotEmpty) {
      final dataMinima = todasAsDatas.reduce((a, b) => a.isBefore(b) ? a : b);

      List<FlSpot> paraSpots(List<PontoEvolucaoBanca> pontos) => pontos
          .map((p) => FlSpot(p.data.difference(dataMinima).inDays.toDouble(), p.banca))
          .toList();

      if (total.length >= 2) {
        final subiu = total.last.banca >= total.first.banca;
        final cor = subiu ? AppColors.green : AppColors.red;
        final spots = paraSpots(total);
        valoresY.addAll(spots.map((s) => s.y));
        linhas.add(_linha(spots, cor, comArea: true));
      }

      for (var i = 0; i < nomes.length; i++) {
        final pontos = series[nomes[i]];
        if (pontos == null || pontos.length < 2) continue;
        final spots = paraSpots(pontos);
        valoresY.addAll(spots.map((s) => s.y));
        linhas.add(_linha(spots, coresTipster[i % coresTipster.length]));
      }
    }

    double minY = 0, maxY = 0;
    if (valoresY.isNotEmpty) {
      minY = valoresY.reduce((a, b) => a < b ? a : b);
      maxY = valoresY.reduce((a, b) => a > b ? a : b);
    }
    final margem = ((maxY - minY).abs() * 0.15).clamp(5, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: linhas.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum tipster selecionado',
                    style: TextStyle(color: AppColors.textoSecundario, fontSize: 12),
                  ),
                )
              : LineChart(
                  LineChartData(
                    minY: minY - margem,
                    maxY: maxY + margem,
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppColors.superficieAlta,
                        getTooltipItems: (spots) => spots.map((s) {
                          return LineTooltipItem(
                            'R\$ ${s.y.toStringAsFixed(2)}',
                            const TextStyle(
                                color: AppColors.textoPrimario, fontWeight: FontWeight.w600, fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: linhas,
                  ),
                ),
        ),
        if (_excluidos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Total sem ${_excluidos.join(", ")} — como estaria se você não tivesse essas apostas.',
              style: const TextStyle(color: AppColors.textoSecundario, fontSize: 11.5),
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < nomes.length; i++)
              _botao(
                nomes[i],
                coresTipster[i % coresTipster.length],
                !_excluidos.contains(nomes[i]),
                () => setState(() {
                  if (_excluidos.contains(nomes[i])) {
                    _excluidos.remove(nomes[i]);
                  } else {
                    _excluidos.add(nomes[i]);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  LineChartBarData _linha(List<FlSpot> spots, Color cor, {bool comArea = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: cor,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: comArea, color: cor.withValues(alpha: 0.10)),
    );
  }

  Widget _botao(String rotulo, Color cor, bool ativo, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.18) : AppColors.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? cor.withValues(alpha: 0.6) : AppColors.borda),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              rotulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ativo ? AppColors.textoPrimario : AppColors.textoSecundario,
                decoration: ativo ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
