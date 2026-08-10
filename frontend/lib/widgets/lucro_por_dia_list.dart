import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../theme/app_theme.dart';

class LucroPorDiaList extends StatefulWidget {
  final List<PontoLucroDia> pontos; // vem do backend em ordem crescente de data

  const LucroPorDiaList({super.key, required this.pontos});

  @override
  State<LucroPorDiaList> createState() => _LucroPorDiaListState();
}

class _LucroPorDiaListState extends State<LucroPorDiaList> {
  static const _quantidadePadrao = 5;
  bool _mostrarTudo = false;

  @override
  Widget build(BuildContext context) {
    if (widget.pontos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Nenhum dia com aposta resolvida ainda.',
          style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
        ),
      );
    }

    // mais recente primeiro
    final invertidos = widget.pontos.reversed.toList();
    final visiveis = _mostrarTudo ? invertidos : invertidos.take(_quantidadePadrao).toList();
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final formatoData = DateFormat('dd/MM');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visiveis.map((ponto) {
          final cor = ponto.lucro >= 0 ? AppColors.green : AppColors.red;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    formatoData.format(ponto.data),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
                  ),
                ),
                Expanded(
                  child: Text(
                    ponto.totalApostas == 1 ? '1 aposta' : '${ponto.totalApostas} apostas',
                    style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                  ),
                ),
                Text(
                  formatoMoeda.format(ponto.lucro),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: cor),
                ),
              ],
            ),
          );
        }),
        if (invertidos.length > _quantidadePadrao)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
              onPressed: () => setState(() => _mostrarTudo = !_mostrarTudo),
              child: Text(
                _mostrarTudo ? 'Mostrar só os últimos $_quantidadePadrao dias' : 'Ver todo o histórico (${invertidos.length} dias)',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
      ],
    );
  }
}
