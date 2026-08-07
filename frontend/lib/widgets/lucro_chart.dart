import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';

/// Gráfico de barras: uma barra por aposta resolvida (green/red), em ordem
/// cronológica, verde pra cima (lucro) e vermelho pra baixo (prejuízo).
/// Diferente do gráfico de evolução da banca (que é a soma acumulada), esse
/// mostra o tamanho de cada resultado individual — ajuda a enxergar
/// sequências de red ou apostas que pesaram muito no total.
class LucroBarChart extends StatelessWidget {
  final List<Aposta> apostas;

  const LucroBarChart({super.key, required this.apostas});

  @override
  Widget build(BuildContext context) {
    final resolvidas = apostas.where((a) => a.lucro != null).toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    if (resolvidas.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'O lucro de cada aposta aparece aqui assim que você tiver apostas resolvidas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
          ),
        ),
      );
    }

    final maiorAbsoluto = resolvidas.map((a) => a.lucro!.abs()).reduce((a, b) => a > b ? a : b);
    final tetoEixo = maiorAbsoluto == 0 ? 10.0 : maiorAbsoluto * 1.25;
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final larguraBarra = resolvidas.length > 30 ? 3.0 : (resolvidas.length > 12 ? 6.0 : 12.0);

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          minY: -tetoEixo,
          maxY: tetoEixo,
          alignment: BarChartAlignment.spaceEvenly,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 0, color: AppColors.borda, strokeWidth: 1),
            ],
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.superficieAlta,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final aposta = resolvidas[group.x.toInt()];
                return BarTooltipItem(
                  '${formatoMoeda.format(aposta.lucro)}\n',
                  const TextStyle(color: AppColors.textoPrimario, fontWeight: FontWeight.w700, fontSize: 12),
                  children: [
                    TextSpan(
                      text: aposta.descricao ?? aposta.casaDeApostas,
                      style: const TextStyle(color: AppColors.textoSecundario, fontWeight: FontWeight.w400, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (int i = 0; i < resolvidas.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: resolvidas[i].lucro!,
                    fromY: 0,
                    color: resolvidas[i].lucro! >= 0 ? AppColors.green : AppColors.red,
                    width: larguraBarra,
                    borderRadius: BorderRadius.circular(larguraBarra > 6 ? 3 : 1),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
