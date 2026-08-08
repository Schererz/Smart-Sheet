import 'package:flutter/material.dart';

import '../models/aposta.dart';
import '../theme/app_theme.dart';
import '../widgets/aposta_card.dart';

class ApostasScreen extends StatelessWidget {
  final List<Aposta> apostas;
  final bool carregando;
  final String? erro;
  final void Function(Aposta) onTocarStatus;
  final void Function(Aposta) onExcluir;
  final void Function(Aposta) onEditar;
  final Future<void> Function() onRefresh;

  const ApostasScreen({
    super.key,
    required this.apostas,
    required this.carregando,
    required this.erro,
    required this.onTocarStatus,
    required this.onExcluir,
    required this.onEditar,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas apostas'), backgroundColor: AppColors.fundo),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: carregando
            ? const Center(child: CircularProgressIndicator())
            : erro != null
                ? _EstadoErro(mensagem: erro!, onTentarDeNovo: onRefresh)
                : apostas.isEmpty
                    ? const _EstadoVazio()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: apostas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final aposta = apostas[i];
                          return ApostaCard(
                            aposta: aposta,
                            onTocarStatus: () => onTocarStatus(aposta),
                            onExcluir: () => onExcluir(aposta),
                            onEditar: () => onEditar(aposta),
                          );
                        },
                      ),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Nenhuma aposta ainda.\nToque no + pra registrar a primeira.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textoSecundario, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoErro extends StatelessWidget {
  final String mensagem;
  final Future<void> Function() onTentarDeNovo;
  const _EstadoErro({required this.mensagem, required this.onTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: AppColors.textoSecundario, size: 36),
                  const SizedBox(height: 12),
                  Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSecundario)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: onTentarDeNovo, child: const Text('Tentar de novo')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
