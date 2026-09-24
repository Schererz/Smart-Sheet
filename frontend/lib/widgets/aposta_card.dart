import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';

class ApostaCard extends StatefulWidget {
  final Aposta aposta;
  final VoidCallback onTocarStatus;
  final void Function(ResultadoAposta)? onMudarStatusPara;
  final VoidCallback? onExcluir;
  final VoidCallback? onEditar;

  const ApostaCard({
    super.key,
    required this.aposta,
    required this.onTocarStatus,
    this.onMudarStatusPara,
    this.onExcluir,
    this.onEditar,
  });

  @override
  State<ApostaCard> createState() => _ApostaCardState();
}

class _ApostaCardState extends State<ApostaCard> {
  double _dx = 0.0;
  bool _arrastando = false;
  bool _saindoParaExcluir = false;

  // arrastar pra ESQUERDA (negativo): excluir, igual sempre foi
  static const _limiarExcluir = -120.0;
  static const _limiteEsquerda = -160.0;

  // arrastar pra DIREITA (positivo): muda status, em 2 estágios por distância
  static const _limiarPrimeiro = 70.0;
  static const _limiarSegundo = 150.0;
  static const _limiteDireita = 190.0;

  /// A opção "próxima" (arrasto curto) e "distante" (arrasto longo) dependem
  /// de qual é o status ATUAL da aposta — nunca oferece o status que já está.
  (ResultadoAposta, Color, IconData, String) _opcao({required bool distante}) {
    switch (widget.aposta.resultado) {
      case ResultadoAposta.aberto:
        return distante
            ? (ResultadoAposta.red, AppColors.red, Icons.cancel_outlined, 'Red')
            : (ResultadoAposta.green, AppColors.green, Icons.check_circle_outline, 'Green');
      case ResultadoAposta.red:
        return distante
            ? (ResultadoAposta.aberto, AppColors.textoSecundario, Icons.radio_button_unchecked, 'Aberto')
            : (ResultadoAposta.green, AppColors.green, Icons.check_circle_outline, 'Green');
      case ResultadoAposta.green:
        return distante
            ? (ResultadoAposta.aberto, AppColors.textoSecundario, Icons.radio_button_unchecked, 'Aberto')
            : (ResultadoAposta.red, AppColors.red, Icons.cancel_outlined, 'Red');
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.onExcluir == null && widget.onMudarStatusPara == null) return;
    setState(() {
      _arrastando = true;
      var novo = _dx + details.delta.dx;
      if (novo < 0 && widget.onExcluir == null) novo = 0;
      if (novo > 0 && widget.onMudarStatusPara == null) novo = 0;
      _dx = novo.clamp(_limiteEsquerda, _limiteDireita);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _arrastando = false;

    if (_dx <= _limiarExcluir) {
      // não exclui na hora — anima saindo da tela, e só chama o callback
      // quando a animação terminar de verdade (fica mais suave)
      setState(() {
        _saindoParaExcluir = true;
        _dx = -500;
      });
      return;
    }

    ResultadoAposta? novoStatus;
    if (_dx >= _limiarSegundo) {
      novoStatus = _opcao(distante: true).$1;
    } else if (_dx >= _limiarPrimeiro) {
      novoStatus = _opcao(distante: false).$1;
    }

    setState(() => _dx = 0.0);
    if (novoStatus != null) widget.onMudarStatusPara?.call(novoStatus);
  }

  @override
  Widget build(BuildContext context) {
    final formatoData = DateFormat('dd/MM');
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final corStatus = AppTheme.corDoStatus(widget.aposta.resultado.name);

    final indoExcluir = _dx < 0;
    final estagio = indoExcluir ? 0 : (_dx >= _limiarSegundo ? 2 : (_dx >= _limiarPrimeiro ? 1 : 0));

    Widget fundo = const SizedBox.shrink();
    if (indoExcluir && _dx.abs() > 4) {
      fundo = Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: AppColors.red),
      );
    } else if (estagio > 0) {
      final (_, cor, icone, rotulo) = _opcao(distante: estagio == 2);
      fundo = Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(color: cor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: cor),
            const SizedBox(width: 8),
            Text(rotulo, style: TextStyle(color: cor, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: fundo),
        GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedContainer(
            duration: _arrastando ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dx, 0, 0),
            onEnd: _saindoParaExcluir ? () => widget.onExcluir?.call() : null,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 46,
                      decoration: BoxDecoration(
                        color: corStatus,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: widget.onEditar,
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.aposta.descricao?.isNotEmpty == true ? widget.aposta.descricao! : widget.aposta.casaDeApostas,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.aposta.casaDeApostas} · ${formatoData.format(widget.aposta.data)} · odd ${widget.aposta.odd.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.aposta.lucro == null ? '—' : formatoMoeda.format(widget.aposta.lucro),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: widget.aposta.lucro == null
                                ? AppColors.textoSecundario
                                : (widget.aposta.lucro! >= 0 ? AppColors.green : AppColors.red),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _BotaoStatus(resultado: widget.aposta.resultado.name, onTap: widget.onTocarStatus),
                      ],
                    ),
                    if (widget.onExcluir != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _confirmarExclusao(context),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.textoSecundario,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarExclusao(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: const Text('Excluir aposta?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmou == true) widget.onExcluir?.call();
  }
}

class _BotaoStatus extends StatelessWidget {
  final String resultado;
  final VoidCallback onTap;

  const _BotaoStatus({required this.resultado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = AppTheme.corDoStatus(resultado);
    final rotulo = AppTheme.rotuloDoStatus(resultado);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withValues(alpha: 0.4)),
        ),
        child: Text(
          rotulo,
          style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.4),
        ),
      ),
    );
  }
}
