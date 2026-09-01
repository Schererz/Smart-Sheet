import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/unidade.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CartaoUnidade extends StatefulWidget {
  const CartaoUnidade({super.key});

  @override
  State<CartaoUnidade> createState() => _CartaoUnidadeState();
}

class _CartaoUnidadeState extends State<CartaoUnidade> {
  final _api = ApiService();
  StatusUnidade? _status;
  bool _carregando = true;
  bool _recalculando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final status = await _api.obterStatusUnidade();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // silencioso — não é crítico, só não mostra o cartão
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _recalcular() async {
    setState(() => _recalculando = true);
    try {
      final status = await _api.recalcularUnidade();
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui recalcular: $e')));
      }
    } finally {
      if (mounted) setState(() => _recalculando = false);
    }
  }

  Future<void> _abrirConfigIntervalo() async {
    final novoIntervalo = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.superficieAlta,
        title: const Text('Recalcular unidade a cada:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              value: 7,
              // ignore: deprecated_member_use
              groupValue: _status?.intervaloDias,
              title: const Text('1 semana'),
              onChanged: (v) => Navigator.pop(context, v),
            ),
            RadioListTile<int>(
              value: 30,
              // ignore: deprecated_member_use
              groupValue: _status?.intervaloDias,
              title: const Text('1 mês'),
              onChanged: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
      ),
    );
    if (novoIntervalo != null) {
      try {
        final status = await _api.definirIntervaloUnidade(novoIntervalo);
        if (mounted) setState(() => _status = status);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui salvar: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando || _status == null) return const SizedBox.shrink();

    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final status = _status!;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: status.recalculoPendente ? AppColors.destaque.withValues(alpha: 0.12) : AppColors.superficie,
        borderRadius: BorderRadius.circular(14),
        border: status.recalculoPendente ? Border.all(color: AppColors.destaque.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Unidade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _abrirConfigIntervalo,
                      child: const Icon(Icons.settings_outlined, size: 15, color: AppColors.textoSecundario),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (status.unidadeAtual == null)
                  const Text('Ainda não calculada', style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5))
                else
                  Text(
                    formatoMoeda.format(status.unidadeAtual),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                if (status.recalculoPendente)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      status.unidadeAtual == null
                          ? 'Toque em recalcular pra definir'
                          : 'Ficaria em ${formatoMoeda.format(status.unidadeSeRecalcularAgora)}',
                      style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (status.recalculoPendente)
            _recalculando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton(
                    onPressed: _recalcular,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                    child: const Text('Recalcular', style: TextStyle(fontSize: 12.5)),
                  ),
        ],
      ),
    );
  }
}
