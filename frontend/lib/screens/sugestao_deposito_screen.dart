import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/casa.dart';
import '../models/movimentacao.dart';
import '../models/unidade.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SugestaoDepositoScreen extends StatefulWidget {
  const SugestaoDepositoScreen({super.key});

  @override
  State<SugestaoDepositoScreen> createState() => _SugestaoDepositoScreenState();
}

class _SugestaoDepositoScreenState extends State<SugestaoDepositoScreen> {
  final _api = ApiService();
  final _bancaController = TextEditingController();

  bool _calculando = false;
  bool _aplicando = false;
  String? _erro;
  SugestaoDeposito? _resultado;
  List<Casa> _casas = [];

  @override
  void initState() {
    super.initState();
    _api.listarCasas().then((c) => setState(() => _casas = c)).catchError((_) {});
  }

  @override
  void dispose() {
    _bancaController.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    final banca = double.tryParse(_bancaController.text.trim().replaceAll(',', '.'));
    if (banca == null || banca <= 0) {
      setState(() => _erro = 'Digite um valor de banca válido.');
      return;
    }
    setState(() {
      _calculando = true;
      _erro = null;
      _resultado = null;
    });
    try {
      final resultado = await _api.obterSugestaoDeposito(bancaTotalMes: banca);
      setState(() => _resultado = resultado);
    } catch (e) {
      setState(() => _erro = '$e');
    } finally {
      setState(() => _calculando = false);
    }
  }

  Future<void> _aplicarTudo() async {
    if (_resultado == null) return;
    setState(() => _aplicando = true);
    try {
      for (final item in _resultado!.sugestoes) {
        if (item.sugerido <= 0) continue; // já está bem servida, nada a depositar
        final casa = _casas.where((c) => c.nome == item.casa).toList();
        if (casa.isEmpty) continue; // segurança, não deveria acontecer
        await _api.criarMovimentacao(
          casaId: casa.first.id,
          tipo: TipoMovimentacao.deposito,
          valor: item.sugerido,
          data: DateTime.now(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Depósitos lançados! Confere em "Saques e depósitos".')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deu erro no meio do caminho: $e')));
      }
    } finally {
      if (mounted) setState(() => _aplicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Sugestão de depósito')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Olha quanto cada casa participou do lucro total nos últimos 30 dias, e sugere depositar '
                'proporcional a isso (um pouco menos que a participação, guardando folga como reserva). '
                'Nenhuma sugestão passa de R\$300 nem fica abaixo de R\$50.',
                style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _bancaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Banca total desse mês', hintText: 'R\$ 0,00'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _calculando ? null : _calcular,
              child: _calculando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Calcular sugestão'),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
            ],
            if (_resultado != null) ...[
              const SizedBox(height: 20),
              if (_resultado!.bancaInsuficienteParaMinimos)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppColors.destaque.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'A soma dos valores mínimos por casa passou da banca informada — reduzi mais fino pra caber, '
                    'pode ter ficado abaixo do mínimo ideal nalguma casa.',
                    style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    ..._resultado!.sugestoes.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.casa, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  Text(
                                    item.lucroPeriodo > 0
                                        ? 'Lucro: ${formatoMoeda.format(item.lucroPeriodo)} (${item.participacaoPct.toStringAsFixed(0)}% do total)'
                                        : 'Sem lucro no período',
                                    style: const TextStyle(color: AppColors.textoSecundario, fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            Text(formatoMoeda.format(item.sugerido), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.superficieAlta, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Fica no banco', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(formatoMoeda.format(_resultado!.bancoSugerido), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Nova unidade sugerida', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(formatoMoeda.format(_resultado!.novaUnidadeSugerida), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _aplicando ? null : _aplicarTudo,
                      child: _aplicando
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Aplicar (lançar todos os depósitos)'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
