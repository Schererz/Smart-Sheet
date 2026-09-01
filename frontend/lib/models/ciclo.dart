import 'aposta.dart'; // reaproveita PontoEvolucaoBanca, já existente

class CicloMensal {
  final int id;
  final String nome;
  final DateTime dataInicio;
  final DateTime? dataFim;
  final double bancaInicialCiclo;

  CicloMensal({
    required this.id,
    required this.nome,
    required this.dataInicio,
    required this.dataFim,
    required this.bancaInicialCiclo,
  });

  bool get emAndamento => dataFim == null;

  factory CicloMensal.fromJson(Map<String, dynamic> json) {
    return CicloMensal(
      id: json['id'] as int,
      nome: json['nome'] as String,
      dataInicio: DateTime.parse(json['data_inicio'] as String),
      dataFim: json['data_fim'] != null ? DateTime.parse(json['data_fim'] as String) : null,
      bancaInicialCiclo: (json['banca_inicial_ciclo'] as num).toDouble(),
    );
  }
}

class ResumoPorCasaCiclo {
  final String casa;
  final int totalApostas;
  final double lucroTotal;
  final double? taxaAcerto;

  ResumoPorCasaCiclo({
    required this.casa,
    required this.totalApostas,
    required this.lucroTotal,
    required this.taxaAcerto,
  });

  factory ResumoPorCasaCiclo.fromJson(Map<String, dynamic> json) {
    return ResumoPorCasaCiclo(
      casa: json['casa'] as String,
      totalApostas: json['total_apostas'] as int,
      lucroTotal: (json['lucro_total'] as num).toDouble(),
      taxaAcerto: (json['taxa_acerto'] as num?)?.toDouble(),
    );
  }
}

class DashboardCiclo {
  final CicloMensal ciclo;
  final double bancaAtualCiclo;
  final double lucroCiclo;
  final int totalApostasCiclo;
  final List<PontoEvolucaoBanca> evolucao;
  final List<ResumoPorCasaCiclo> resumoPorCasa;

  DashboardCiclo({
    required this.ciclo,
    required this.bancaAtualCiclo,
    required this.lucroCiclo,
    required this.totalApostasCiclo,
    required this.evolucao,
    required this.resumoPorCasa,
  });

  factory DashboardCiclo.fromJson(Map<String, dynamic> json) {
    return DashboardCiclo(
      ciclo: CicloMensal.fromJson(json['ciclo'] as Map<String, dynamic>),
      bancaAtualCiclo: (json['banca_atual_ciclo'] as num).toDouble(),
      lucroCiclo: (json['lucro_ciclo'] as num).toDouble(),
      totalApostasCiclo: json['total_apostas_ciclo'] as int,
      evolucao: (json['evolucao'] as List).map((j) => PontoEvolucaoBanca.fromJson(j)).toList(),
      resumoPorCasa: (json['resumo_por_casa'] as List).map((j) => ResumoPorCasaCiclo.fromJson(j)).toList(),
    );
  }
}
