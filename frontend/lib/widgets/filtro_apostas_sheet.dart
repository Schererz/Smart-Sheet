import 'package:flutter/material.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';
import 'filtro_apostas.dart';
import 'seletor_periodo.dart';

/// Abre o bottom sheet de filtro e devolve o filtro escolhido (ou null se
/// o usuário fechou sem aplicar nada).
Future<FiltroApostas?> abrirFiltroApostas(
  BuildContext context, {
  required FiltroApostas filtroAtual,
  required List<String> casasDisponiveis,
}) {
  return showModalBottomSheet<FiltroApostas>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.superficieAlta,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FiltroApostasSheet(filtroAtual: filtroAtual, casasDisponiveis: casasDisponiveis),
  );
}

class _FiltroApostasSheet extends StatefulWidget {
  final FiltroApostas filtroAtual;
  final List<String> casasDisponiveis;

  const _FiltroApostasSheet({required this.filtroAtual, required this.casasDisponiveis});

  @override
  State<_FiltroApostasSheet> createState() => _FiltroApostasSheetState();
}

class _FiltroApostasSheetState extends State<_FiltroApostasSheet> {
  late FiltroApostas _filtro;
  late TextEditingController _busca;

  @override
  void initState() {
    super.initState();
    _filtro = widget.filtroAtual;
    _busca = TextEditingController(text: _filtro.busca);
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Filtrar apostas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                if (_filtro.temFiltroAtivo)
                  TextButton(
                    onPressed: () => setState(() {
                      _filtro = const FiltroApostas();
                      _busca.clear();
                    }),
                    child: const Text('Limpar'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const _Rotulo('Descrição'),
            TextField(
              controller: _busca,
              decoration: const InputDecoration(hintText: 'Buscar por texto...'),
              onChanged: (v) => setState(() => _filtro = _filtro.copyWith(busca: v)),
            ),
            const SizedBox(height: 16),

            const _Rotulo('Casa'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  rotulo: 'Todas',
                  selecionado: _filtro.casa == null,
                  onTap: () => setState(() => _filtro = _filtro.copyWith(casa: () => null)),
                ),
                ...widget.casasDisponiveis.map(
                  (casa) => _Chip(
                    rotulo: casa,
                    selecionado: _filtro.casa == casa,
                    onTap: () => setState(() => _filtro = _filtro.copyWith(casa: () => casa)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const _Rotulo('Status'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  rotulo: 'Todos',
                  selecionado: _filtro.status == null,
                  onTap: () => setState(() => _filtro = _filtro.copyWith(status: () => null)),
                ),
                _Chip(
                  rotulo: 'Aberto',
                  selecionado: _filtro.status == ResultadoAposta.aberto,
                  onTap: () => setState(() => _filtro = _filtro.copyWith(status: () => ResultadoAposta.aberto)),
                ),
                _Chip(
                  rotulo: 'Green',
                  cor: AppColors.green,
                  selecionado: _filtro.status == ResultadoAposta.green,
                  onTap: () => setState(() => _filtro = _filtro.copyWith(status: () => ResultadoAposta.green)),
                ),
                _Chip(
                  rotulo: 'Red',
                  cor: AppColors.red,
                  selecionado: _filtro.status == ResultadoAposta.red,
                  onTap: () => setState(() => _filtro = _filtro.copyWith(status: () => ResultadoAposta.red)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const _Rotulo('Período'),
            SeletorPeriodo(
              selecionado: _filtro.periodo,
              onSelecionar: (p) => setState(() => _filtro = _filtro.copyWith(periodo: p)),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () => Navigator.pop(context, _filtro),
              child: const Text('Aplicar filtro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  final String texto;
  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texto, style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario, fontWeight: FontWeight.w600)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;
  final Color? cor;

  const _Chip({required this.rotulo, required this.selecionado, required this.onTap, this.cor});

  @override
  Widget build(BuildContext context) {
    final corAtiva = cor ?? AppColors.destaque;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? corAtiva.withValues(alpha: 0.18) : AppColors.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selecionado ? corAtiva.withValues(alpha: 0.6) : AppColors.borda),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selecionado ? corAtiva : AppColors.textoSecundario,
          ),
        ),
      ),
    );
  }
}
