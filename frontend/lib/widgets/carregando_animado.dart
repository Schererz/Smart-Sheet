import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum _TipoCena { prateleiraVerde, graficoSobe, prateleiraVermelha, graficoDesce }

/// Animação de carregamento: alterna entre 4 cenas em loop — prateleirinhas
/// verdes (simulando apostas "green"), um gráfico subindo, prateleirinhas
/// vermelhas ("red"), e um gráfico descendo. A caixinha inteira entra/sai
/// suave a cada troca de cena, e embaixo tem 5 pontinhos pulsando devagar.
///
/// Tudo feito com Flutter puro (AnimationController + CustomPaint) — sem
/// pacote externo nem arquivo de imagem, então o custo de desempenho é
/// desprezível; só aparece durante uma espera que já ia acontecer de
/// qualquer jeito.
class CarregandoAnimado extends StatefulWidget {
  final String? mensagem;

  const CarregandoAnimado({super.key, this.mensagem});

  @override
  State<CarregandoAnimado> createState() => _CarregandoAnimadoState();
}

class _CarregandoAnimadoState extends State<CarregandoAnimado> with TickerProviderStateMixin {
  static const _corFundoCaixa = Color(0xFF0B0D12); // um pouco mais escuro que AppColors.fundo
  static const _duracaoPrateleiras = Duration(milliseconds: 1900);
  static const _duracaoGrafico = Duration(milliseconds: 2700);
  static const _duracaoEntradaSaida = Duration(milliseconds: 600);
  static const _folgaAntesDeTrocar = Duration(milliseconds: 450); // tempo parado depois da animação terminar

  static final _subidas = [
    [const Offset(5, 58), const Offset(26, 44), const Offset(42, 50), const Offset(60, 28), const Offset(78, 34), const Offset(96, 18), const Offset(118, 6)],
    [const Offset(5, 60), const Offset(24, 50), const Offset(44, 54), const Offset(64, 32), const Offset(80, 40), const Offset(100, 20), const Offset(118, 10)],
    [const Offset(5, 55), const Offset(22, 40), const Offset(40, 46), const Offset(58, 22), const Offset(76, 30), const Offset(98, 14), const Offset(118, 4)],
  ];
  static final _descidas = [
    [const Offset(5, 6), const Offset(26, 20), const Offset(42, 14), const Offset(60, 36), const Offset(78, 30), const Offset(96, 46), const Offset(118, 58)],
    [const Offset(5, 4), const Offset(24, 14), const Offset(44, 10), const Offset(64, 32), const Offset(80, 24), const Offset(100, 44), const Offset(118, 60)],
    [const Offset(5, 10), const Offset(22, 24), const Offset(40, 18), const Offset(58, 42), const Offset(76, 34), const Offset(98, 50), const Offset(118, 60)],
  ];

  final _random = Random();
  int _cenaIndex = 0;
  List<Offset> _caminhoAtual = const [];

  late final AnimationController _entradaSaida;
  late final AnimationController _grafico;
  late final AnimationController _prateleiras;
  late final AnimationController _pontinhos;

  Timer? _timerProximaCena;

  _TipoCena get _tipoAtual => _TipoCena.values[_cenaIndex];

  @override
  void initState() {
    super.initState();
    _entradaSaida = AnimationController(vsync: this, duration: _duracaoEntradaSaida)..value = 1.0;
    _grafico = AnimationController(vsync: this, duration: _duracaoGrafico);
    _prateleiras = AnimationController(vsync: this, duration: _duracaoPrateleiras);
    _pontinhos = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

    _iniciarCena(0);
  }

  @override
  void dispose() {
    _timerProximaCena?.cancel();
    _entradaSaida.dispose();
    _grafico.dispose();
    _prateleiras.dispose();
    _pontinhos.dispose();
    super.dispose();
  }

  void _iniciarCena(int indice) {
    _cenaIndex = indice % _TipoCena.values.length;
    if (_tipoAtual == _TipoCena.graficoSobe) {
      _caminhoAtual = _subidas[_random.nextInt(_subidas.length)];
    } else if (_tipoAtual == _TipoCena.graficoDesce) {
      _caminhoAtual = _descidas[_random.nextInt(_descidas.length)];
    }
    if (mounted) setState(() {});

    _entradaSaida.forward(from: 0);

    final Duration duracaoInterna;
    if (_tipoAtual == _TipoCena.prateleiraVerde || _tipoAtual == _TipoCena.prateleiraVermelha) {
      _prateleiras.forward(from: 0);
      duracaoInterna = _duracaoPrateleiras;
    } else {
      _grafico.forward(from: 0);
      duracaoInterna = _duracaoGrafico;
    }

    _timerProximaCena?.cancel();
    _timerProximaCena = Timer(duracaoInterna + _folgaAntesDeTrocar, _saindoESeguindo);
  }

  Future<void> _saindoESeguindo() async {
    await _entradaSaida.reverse();
    if (!mounted) return;
    _iniciarCena(_cenaIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _entradaSaida,
            builder: (context, child) {
              final t = _entradaSaida.value;
              return Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
              );
            },
            child: _construirCaixa(),
          ),
          const SizedBox(height: 24),
          _construirPontinhos(),
          if (widget.mensagem != null) ...[
            const SizedBox(height: 14),
            Text(widget.mensagem!, style: const TextStyle(color: AppColors.textoSecundario, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _construirCaixa() {
    final ehPrateleira = _tipoAtual == _TipoCena.prateleiraVerde || _tipoAtual == _TipoCena.prateleiraVermelha;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _corFundoCaixa,
        border: Border.all(color: AppColors.borda, width: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ehPrateleira ? _construirPrateleiras() : _construirGrafico(),
    );
  }

  Widget _construirPrateleiras() {
    final cor = _tipoAtual == _TipoCena.prateleiraVerde ? AppColors.green : AppColors.red;
    final totalMs = _duracaoPrateleiras.inMilliseconds;

    return AnimatedBuilder(
      animation: _prateleiras,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final inicioMs = 150 + i * 400;
            const duracaoIndividualMs = 950;
            final progresso = ((_prateleiras.value * totalMs - inicioMs) / duracaoIndividualMs).clamp(0.0, 1.0);
            return Opacity(
              opacity: progresso,
              child: Transform.translate(
                offset: Offset((1 - progresso) * -10, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: SizedBox(
                    width: 150,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(color: AppColors.borda, borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(width: 9, height: 9, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _construirGrafico() {
    final cor = _tipoAtual == _TipoCena.graficoSobe ? AppColors.green : AppColors.red;
    return SizedBox(
      width: 122,
      height: 64,
      child: AnimatedBuilder(
        animation: _grafico,
        builder: (context, _) {
          return CustomPaint(painter: _GraficoPainter(pontos: _caminhoAtual, progresso: _grafico.value, cor: cor));
        },
      ),
    );
  }

  Widget _construirPontinhos() {
    return AnimatedBuilder(
      animation: _pontinhos,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final atraso = i * 0.1;
            var fase = (_pontinhos.value - atraso) % 1.0;
            if (fase < 0) fase += 1.0;

            double intensidade;
            if (fase < 0.3) {
              intensidade = fase / 0.3;
            } else if (fase < 0.6) {
              intensidade = 1 - (fase - 0.3) / 0.3;
            } else {
              intensidade = 0;
            }

            final corPonto = Color.lerp(AppColors.borda, AppColors.destaque, intensidade)!;
            final escala = 1.0 + 0.35 * intensidade;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.5),
              child: Transform.scale(
                scale: escala,
                child: Container(width: 7, height: 7, decoration: BoxDecoration(color: corPonto, shape: BoxShape.circle)),
              ),
            );
          }),
        );
      },
    );
  }
}

class _GraficoPainter extends CustomPainter {
  final List<Offset> pontos;
  final double progresso;
  final Color cor;

  _GraficoPainter({required this.pontos, required this.progresso, required this.cor});

  @override
  void paint(Canvas canvas, Size size) {
    if (pontos.isEmpty) return;

    final caminho = Path()..moveTo(pontos.first.dx, pontos.first.dy);
    for (final p in pontos.skip(1)) {
      caminho.lineTo(p.dx, p.dy);
    }

    final metrica = caminho.computeMetrics().first;
    final comprimentoParcial = metrica.length * progresso;
    final caminhoParcial = metrica.extractPath(0, comprimentoParcial);

    final tinta = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(caminhoParcial, tinta);
  }

  @override
  bool shouldRepaint(covariant _GraficoPainter oldDelegate) =>
      oldDelegate.progresso != progresso || oldDelegate.pontos != pontos || oldDelegate.cor != cor;
}
