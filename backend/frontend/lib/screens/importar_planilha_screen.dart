import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ImportarPlanilhaScreen extends StatefulWidget {
  const ImportarPlanilhaScreen({super.key});

  @override
  State<ImportarPlanilhaScreen> createState() => _ImportarPlanilhaScreenState();
}

class _ImportarPlanilhaScreenState extends State<ImportarPlanilhaScreen> {
  final _api = ApiService();
  bool _importando = false;
  Map<String, dynamic>? _resultado;
  String? _erro;

  Future<void> _escolherEImportar() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (resultado == null || resultado.files.single.path == null) return; // cancelou

    setState(() {
      _importando = true;
      _erro = null;
      _resultado = null;
    });

    try {
      final arquivo = File(resultado.files.single.path!);
      final resposta = await _api.importarPlanilha(arquivo);
      setState(() => _resultado = resposta);
    } catch (e) {
      setState(() => _erro = '$e');
    } finally {
      setState(() => _importando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar planilha')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(14)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Antes de importar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  SizedBox(height: 10),
                  Text(
                    'Deixe na sua planilha só as colunas que a gente reconhece — apague as extras (tipster, esporte, etc).',
                    style: TextStyle(color: AppColors.textoSecundario, fontSize: 13),
                  ),
                  SizedBox(height: 12),
                  Text('Colunas reconhecidas:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 6),
                  Text(
                    '• Data\n• Casa (obrigatória)\n• Descrição\n• Odd (obrigatória)\n• Valor (obrigatória)\n• Retorno\n• Resultado (Green/Red/Aberto, ou variações como Ganhou/Perdeu)',
                    style: TextStyle(color: AppColors.textoSecundario, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _importando ? null : _escolherEImportar,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_importando ? 'Importando...' : 'Escolher planilha (.xlsx ou .csv)'),
            ),
            const SizedBox(height: 24),
            if (_importando) const Center(child: CircularProgressIndicator()),
            if (_erro != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(_erro!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
              ),
            if (_resultado != null) _ResumoImportacao(resultado: _resultado!),
          ],
        ),
      ),
    );
  }
}

class _ResumoImportacao extends StatelessWidget {
  final Map<String, dynamic> resultado;
  const _ResumoImportacao({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final total = resultado['total_linhas'] as int;
    final importadas = resultado['importadas'] as int;
    final erros = (resultado['erros'] as List).cast<Map<String, dynamic>>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.superficie, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                '$importadas de $total apostas importadas',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          if (erros.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${erros.length} linha(s) com problema:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            ...erros.take(10).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• Linha ${e['linha']}: ${e['motivo']}',
                      style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
                    ),
                  ),
                ),
            if (erros.length > 10)
              Text('...e mais ${erros.length - 10}', style: const TextStyle(color: AppColors.textoSecundario, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}
