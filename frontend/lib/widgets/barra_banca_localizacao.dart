import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/movimentacao.dart';
import '../theme/app_theme.dart';

/// Paleta fixa pra cada "fatia" da barra — repete se tiver mais casas
/// que cores, mas na prática cobre bem a quantidade normal de casas.
const _cores = [
  AppColors.destaque,
  Color(0xFF2FB67C), // verde
  Color(0xFFE0A64B), // amarelo/laranja
  Color(0xFFE5484D), // vermelho
  Color(0xFF7C6FE0), // roxo
  Color(0xFF4BC0E0), // azul claro
];

class BarraBancaLocalizacao extends StatelessWidget {
  final BancaPorLocalizacao dados;

  const BarraBancaLocalizacao({super.key, required this.dados});

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    // monta a lista de fatias: cada casa + o "banco" por último
    final fatias = <_Fatia>[
      for (var i = 0; i < dados.casas.length; i++)
        _Fatia(nome: dados.casas[i].casa, valor: dados.casas[i].valor, cor: _cores[i % _cores.length]),
      _Fatia(nome: 'No banco', valor: dados.banco, cor: AppColors.borda),
    ].where((f) => f.valor > 0).toList(); // não mostra fatia com valor zero/negativo

    final total = dados.total <= 0 ? 1.0 : dados.total; // evita divisão por zero

    if (fatias.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Nenhuma movimentação registrada ainda.',
          style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: fatias
                  .map((f) => Expanded(
                        flex: (f.valor / total * 1000).round().clamp(1, 1000),
                        child: Container(color: f.cor),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: fatias.map((f) {
            final pct = (f.valor / total * 100);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: f.cor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  '${f.nome}  ${formatoMoeda.format(f.valor)}  (${pct.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Fatia {
  final String nome;
  final double valor;
  final Color cor;
  _Fatia({required this.nome, required this.valor, required this.cor});
}
