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

/// Resumo agrupado por tipster (de quem veio a indicação) — mesma lógica
/// do resumo por casa, mas agrupando por esse campo em vez do nome da casa.
class ResumoPorTipster {
  final String tipster;
  final int totalApostas;
  final double totalApostado;
  final double lucroTotal;
  final double? taxaAcerto;
  final double? roiApostado;

  ResumoPorTipster({
    required this.tipster,
    required this.totalApostas,
    required this.totalApostado,
    required this.lucroTotal,
    this.taxaAcerto,
    this.roiApostado,
  });
}

List<ResumoPorTipster> calcularResumoPorTipsterLocal(List<Aposta> apostas) {
  final porTipster = <String, List<Aposta>>{};
  for (final a in apostas) {
    final chave = (a.tipster == null || a.tipster!.trim().isEmpty) ? 'Sem tipster' : a.tipster!;
    porTipster.putIfAbsent(chave, () => []).add(a);
  }

  final resultado = porTipster.entries.map((entrada) {
    final apostasDoTipster = entrada.value;
    final totalApostas = apostasDoTipster.length;
    final totalApostado = apostasDoTipster.fold<double>(0, (soma, a) => soma + a.valorApostado);
    final lucroTotal = apostasDoTipster.fold<double>(0, (soma, a) => soma + (a.lucro ?? 0));

    final resolvidas = apostasDoTipster.where((a) => a.resultado != ResultadoAposta.aberto).toList();
    final ganhas = resolvidas.where((a) => a.resultado == ResultadoAposta.green).length;
    final taxaAcerto = resolvidas.isEmpty ? null : 100 * ganhas / resolvidas.length;
    final roiApostado = totalApostado == 0 ? null : 100 * lucroTotal / totalApostado;

    return ResumoPorTipster(
      tipster: entrada.key,
      totalApostas: totalApostas,
      totalApostado: totalApostado,
      lucroTotal: lucroTotal,
      taxaAcerto: taxaAcerto,
      roiApostado: roiApostado,
    );
  }).toList();

  resultado.sort((a, b) => b.lucroTotal.compareTo(a.lucroTotal));
  return resultado;
}

/// Constrói uma série de evolução (tipo "evolução da banca"), mas
/// calculada no próprio app a partir de uma lista de apostas já filtrada
/// — usada pras 3 linhas do gráfico (total / Girino / Props), todas
/// partindo do mesmo ponto de banca inicial, cada uma acumulando só o
/// lucro do subconjunto de apostas que lhe cabe.
List<PontoEvolucaoBanca> construirEvolucaoLocal(List<Aposta> apostas, double bancaBase) {
  if (apostas.isEmpty) return [];

  final ordenadas = [...apostas]..sort((a, b) => a.data.compareTo(b.data));
  final porDia = <DateTime, double>{};
  for (final a in ordenadas) {
    final dia = DateTime(a.data.year, a.data.month, a.data.day);
    porDia[dia] = (porDia[dia] ?? 0) + (a.lucro ?? 0);
  }
  final dias = porDia.keys.toList()..sort();

  // âncora um dia ANTES do primeiro dado real, pra não duplicar o mesmo
  // dia com dois valores diferentes (banca base, depois já com lucro)
  final ancora = dias.first.subtract(const Duration(days: 1));
  final pontos = <PontoEvolucaoBanca>[PontoEvolucaoBanca(data: ancora, banca: bancaBase)];

  var acumulado = bancaBase;
  for (final dia in dias) {
    acumulado += porDia[dia]!;
    pontos.add(PontoEvolucaoBanca(data: dia, banca: double.parse(acumulado.toStringAsFixed(2))));
  }
  return pontos;
}
