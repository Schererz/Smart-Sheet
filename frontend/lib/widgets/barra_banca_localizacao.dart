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

    if (dados.total <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Defina sua banca (no Dashboard) pra essa barra funcionar — ela usa esse valor como referência de 100%.',
          style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
        ),
      );
    }

    final somaAlocada = dados.casas.fold<double>(0, (s, c) => s + c.valor);
    // se depositou mais do que a banca definida, "no banco" ficaria
    // negativo — não faz sentido como fatia da barra, vira um aviso à parte
    final excedeu = somaAlocada > dados.total;
    final excedente = somaAlocada - dados.total;

    final fatias = <_Fatia>[
      for (var i = 0; i < dados.casas.length; i++)
        _Fatia(nome: dados.casas[i].casa, valor: dados.casas[i].valor, cor: _cores[i % _cores.length]),
      if (!excedeu) _Fatia(nome: 'No banco', valor: dados.banco, cor: AppColors.borda),
    ].where((f) => f.valor > 0).toList();

    if (fatias.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Nenhuma movimentação registrada ainda.',
          style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
        ),
      );
    }

    // quando excedeu a banca, a barra passa a mostrar a proporção entre
    // as casas dentro do que foi ALOCADO (não dá mais pra usar a banca
    // como 100%, já que ela toda — e mais um pouco — já está nas casas)
    final totalParaBarra = excedeu ? somaAlocada : dados.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (excedeu)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.destaque.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Você tem ${formatoMoeda.format(excedente)} a mais depositado do que sua banca configurada — isso é dinheiro que entrou do seu bolso, fora da banca.',
              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: fatias
                  .map((f) => Expanded(
                        flex: (f.valor / totalParaBarra * 1000).round().clamp(1, 1000),
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
            final pct = (f.valor / totalParaBarra * 100);
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
