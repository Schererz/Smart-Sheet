import '../models/aposta.dart';
import '../models/casa.dart';

/// Espelha o cálculo que o backend faz em calcular_resumo, mas rodando no
/// próprio app em cima de uma lista já filtrada (por período, por casa,
/// etc.) — assim os números de texto acompanham o que o gráfico mostra,
/// em vez de continuar vindo do total geral.
class ResumoCalculado {
  final int totalApostas;
  final double totalApostado;
  final double lucroTotal;
  final double? taxaAcerto;
  final double? roi;
  final double? oddMedia;
  final double? valorMedioApostado;
  final int apostasEmAberto;

  ResumoCalculado({
    required this.totalApostas,
    required this.totalApostado,
    required this.lucroTotal,
    this.taxaAcerto,
    this.roi,
    this.oddMedia,
    this.valorMedioApostado,
    required this.apostasEmAberto,
  });
}

ResumoCalculado calcularResumoLocal(List<Aposta> apostas) {
  if (apostas.isEmpty) {
    return ResumoCalculado(totalApostas: 0, totalApostado: 0, lucroTotal: 0, apostasEmAberto: 0);
  }

  final totalApostas = apostas.length;
  final totalApostado = apostas.fold<double>(0, (soma, a) => soma + a.valorApostado);
  final lucroTotal = apostas.fold<double>(0, (soma, a) => soma + (a.lucro ?? 0));
  final oddMedia = apostas.fold<double>(0, (soma, a) => soma + a.odd) / totalApostas;
  final valorMedioApostado = totalApostado / totalApostas;

  final resolvidas = apostas.where((a) => a.resultado != ResultadoAposta.aberto).toList();
  final ganhas = resolvidas.where((a) => a.resultado == ResultadoAposta.green).length;
  final taxaAcerto = resolvidas.isEmpty ? null : 100 * ganhas / resolvidas.length;
  final roi = totalApostado == 0 ? null : 100 * lucroTotal / totalApostado;
  final apostasEmAberto = apostas.where((a) => a.resultado == ResultadoAposta.aberto).length;

  return ResumoCalculado(
    totalApostas: totalApostas,
    totalApostado: totalApostado,
    lucroTotal: lucroTotal,
    taxaAcerto: taxaAcerto,
    roi: roi,
    oddMedia: oddMedia,
    valorMedioApostado: valorMedioApostado,
    apostasEmAberto: apostasEmAberto,
  );
}

/// Mesma ideia do calcularResumoLocal, mas agrupado por casa — usado pra
/// fazer o "Resumo por casa" do dashboard acompanhar o período escolhido
/// (o endpoint do backend é sempre "desde o início", então essa conta
/// local é o que permite reagir ao filtro de 1D/1S/1M/etc sem precisar
/// de uma chamada nova ao servidor a cada troca de período).
List<ResumoPorCasa> calcularResumoPorCasaLocal(List<Aposta> apostas) {
  final porCasa = <String, List<Aposta>>{};
  for (final a in apostas) {
    porCasa.putIfAbsent(a.casaDeApostas, () => []).add(a);
  }

  final resultado = porCasa.entries.map((entrada) {
    final casaApostas = entrada.value;
    final totalApostas = casaApostas.length;
    final totalApostado = casaApostas.fold<double>(0, (soma, a) => soma + a.valorApostado);
    final lucroTotal = casaApostas.fold<double>(0, (soma, a) => soma + (a.lucro ?? 0));
    final oddMedia = casaApostas.fold<double>(0, (soma, a) => soma + a.odd) / totalApostas;

    final resolvidas = casaApostas.where((a) => a.resultado != ResultadoAposta.aberto).toList();
    final ganhas = resolvidas.where((a) => a.resultado == ResultadoAposta.green).length;
    final taxaAcerto = resolvidas.isEmpty ? null : 100 * ganhas / resolvidas.length;
    final roiApostado = totalApostado == 0 ? null : 100 * lucroTotal / totalApostado;

    return ResumoPorCasa(
      casa: entrada.key,
      totalApostas: totalApostas,
      totalApostado: totalApostado,
      lucroTotal: lucroTotal,
      taxaAcerto: taxaAcerto,
      oddMedia: oddMedia,
      roiApostado: roiApostado,
      bancaInicial: null, // banca por casa é um valor fixo, não faz sentido "filtrar por período"
      bancaAtual: null,
      roiBanca: null,
    );
  }).toList();

  resultado.sort((a, b) => b.lucroTotal.compareTo(a.lucroTotal));
  return resultado;
}
