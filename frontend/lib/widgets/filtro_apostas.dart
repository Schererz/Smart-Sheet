import '../models/aposta.dart';
import 'seletor_periodo.dart';

class FiltroApostas {
  final String? casa;
  final ResultadoAposta? status;
  final PeriodoFiltro periodo;
  final String busca;

  const FiltroApostas({
    this.casa,
    this.status,
    this.periodo = PeriodoFiltro.tudo,
    this.busca = '',
  });

  bool get temFiltroAtivo => casa != null || status != null || periodo != PeriodoFiltro.tudo || busca.isNotEmpty;

  int get quantidadeAtiva =>
      (casa != null ? 1 : 0) + (status != null ? 1 : 0) + (periodo != PeriodoFiltro.tudo ? 1 : 0) + (busca.isNotEmpty ? 1 : 0);

  FiltroApostas copyWith({
    String? Function()? casa,
    ResultadoAposta? Function()? status,
    PeriodoFiltro? periodo,
    String? busca,
  }) {
    return FiltroApostas(
      casa: casa != null ? casa() : this.casa,
      status: status != null ? status() : this.status,
      periodo: periodo ?? this.periodo,
      busca: busca ?? this.busca,
    );
  }

  List<Aposta> aplicar(List<Aposta> apostas) {
    var resultado = apostas;
    if (casa != null) {
      resultado = resultado.where((a) => a.casaDeApostas == casa).toList();
    }
    if (status != null) {
      resultado = resultado.where((a) => a.resultado == status).toList();
    }
    final corte = periodo.dataDeCorte();
    if (corte != null) {
      resultado = resultado.where((a) => !a.data.isBefore(corte)).toList();
    }
    if (busca.isNotEmpty) {
      final termo = busca.toLowerCase();
      resultado = resultado.where((a) => (a.descricao ?? '').toLowerCase().contains(termo)).toList();
    }
    return resultado;
  }
}
