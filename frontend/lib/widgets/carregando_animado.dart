import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Substitui o CircularProgressIndicator genérico nas telas de carregamento
/// principais — um ícone de gráfico pulsando, sem depender de nenhum
/// pacote/arquivo externo (só Flutter puro), então o custo de desempenho
/// é praticamente zero. Só aparece enquanto o app já estaria esperando de
/// qualquer jeito — não atrasa nada, só deixa a espera mais agradável.
class CarregandoAnimado extends StatefulWidget {
  final String? mensagem;

  const CarregandoAnimado({super.key, this.mensagem});

  @override
  State<CarregandoAnimado> createState() => _CarregandoAnimadoState();
}

class _CarregandoAnimadoState extends State<CarregandoAnimado> with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controlador,
            builder: (context, _) {
              final onda = (1 + math.sin(_controlador.value * 2 * math.pi)) / 2; // 0 -> 1 -> 0
              return Transform.scale(
                scale: 0.85 + 0.15 * onda,
                child: Opacity(
                  opacity: 0.55 + 0.45 * onda,
                  child: const Icon(Icons.show_chart_rounded, size: 46, color: AppColors.destaque),
                ),
              );
            },
          ),
          if (widget.mensagem != null) ...[
            const SizedBox(height: 14),
            Text(widget.mensagem!, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
