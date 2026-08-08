import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';

class ApostaCard extends StatelessWidget {
  final Aposta aposta;
  final VoidCallback onTocarStatus;
  final VoidCallback? onExcluir;
  final VoidCallback? onEditar;

  const ApostaCard({
    super.key,
    required this.aposta,
    required this.onTocarStatus,
    this.onExcluir,
    this.onEditar,
  });

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
    if (confirmou == true) onExcluir?.call();
  }

  @override
  Widget build(BuildContext context) {
    final formatoData = DateFormat('dd/MM');
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final corStatus = AppTheme.corDoStatus(aposta.resultado.name);

    return Dismissible(
      key: ValueKey(aposta.id),
      direction: onExcluir == null ? DismissDirection.none : DismissDirection.endToStart,
      onDismissed: (_) => onExcluir?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.red),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Faixa de cor lateral: reforça o status sem precisar ler nada.
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
                  onTap: onEditar,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aposta.descricao?.isNotEmpty == true ? aposta.descricao! : aposta.casaDeApostas,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${aposta.casaDeApostas} · ${formatoData.format(aposta.data)} · odd ${aposta.odd.toStringAsFixed(2)}',
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
                    aposta.lucro == null ? '—' : formatoMoeda.format(aposta.lucro),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: aposta.lucro == null
                          ? AppColors.textoSecundario
                          : (aposta.lucro! >= 0 ? AppColors.green : AppColors.red),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _BotaoStatus(resultado: aposta.resultado.name, onTap: onTocarStatus),
                ],
              ),
              if (onExcluir != null) ...[
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
    );
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
