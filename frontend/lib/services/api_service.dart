import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;
import '../models/movimentacao.dart';
import '../models/unidade.dart';
import '../models/ciclo.dart';

import '../models/aposta.dart';
import '../models/casa.dart';
import '../models/bloco_ocr.dart';
import 'auth_service.dart';

/// Ponto único de configuração da URL do backend.
///
/// - Web (testando local com `flutter run -d chrome`): 'http://localhost:8000'
///   funciona direto, já que o navegador roda na mesma máquina que o backend.
/// - Emulador Android: use 10.0.2.2 — é o IP especial que o emulador usa
///   pra enxergar o "localhost" da sua máquina.
/// - Celular físico na mesma rede Wi-Fi: troque pelo IP da sua máquina,
///   ex: 'http://192.168.0.10:8000'.
/// - Depois do deploy: troque pela URL pública do backend (ex: Render).
class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'https://smart-sheet-api.onrender.com';
    return 'https://smart-sheet-api.onrender.com';
  }
}

class ApiException implements Exception {
  final String mensagem;
  ApiException(this.mensagem);
  @override
  String toString() => mensagem;
}

class ApiService {
  final String baseUrl;
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Uri _uri(String caminho, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$caminho').replace(queryParameters: query);

  /// Cabeçalhos padrão, já com o token de quem está logado (se houver).
  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (SessaoAtual.token != null) headers['Authorization'] = 'Bearer ${SessaoAtual.token}';
    return headers;
  }

  void _verificarErro(http.Response resposta) {
    if (resposta.statusCode >= 400) {
      String detalhe = resposta.body;
      try {
        detalhe = (jsonDecode(resposta.body) as Map)['detail']?.toString() ?? detalhe;
      } catch (_) {}
      throw ApiException('Erro ${resposta.statusCode}: $detalhe');
    }
  }

  // ---------------- Casas ----------------

  Future<List<Casa>> listarCasas() async {
    final resposta = await http.get(_uri('/casas/'), headers: _headers());
    _verificarErro(resposta);
    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    return lista.map((j) => Casa.fromJson(j)).toList();
  }

  Future<Casa> criarCasa(String nome) async {
    final resposta = await http.post(
      _uri('/casas/'),
      headers: _headers(json: true),
      body: jsonEncode({'nome': nome}),
    );
    _verificarErro(resposta);
    return Casa.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  // ---------------- Apostas ----------------

  Future<List<Aposta>> listarApostas() async {
    final resposta = await http.get(_uri('/apostas/'), headers: _headers());
    _verificarErro(resposta);
    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    return lista.map((j) => Aposta.fromJson(j)).toList();
  }

  Future<ResumoStats> obterResumo() async {
    final resposta = await http.get(_uri('/apostas/resumo'), headers: _headers());
    _verificarErro(resposta);
    return ResumoStats.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<Aposta> criarAposta(
    Aposta aposta, {
    List<BlocoOCR>? blocosOcr,
    RascunhoAposta? sugestaoOriginal,
  }) async {
    final resposta = await http.post(
      _uri('/apostas/'),
      headers: _headers(json: true),
      body: jsonEncode(aposta.paraCriacao(blocosOcr: blocosOcr, sugestaoOriginal: sugestaoOriginal)),
    );
    _verificarErro(resposta);
    return Aposta.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<Aposta> atualizarAposta(int id, Map<String, dynamic> campos) async {
    final resposta = await http.patch(
      _uri('/apostas/$id'),
      headers: _headers(json: true),
      body: jsonEncode(campos),
    );
    _verificarErro(resposta);
    return Aposta.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<Aposta> ciclarStatus(int id) async {
    final resposta = await http.post(_uri('/apostas/$id/ciclar-status'), headers: _headers());
    _verificarErro(resposta);
    return Aposta.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<void> deletarAposta(int id) async {
    final resposta = await http.delete(_uri('/apostas/$id'), headers: _headers());
    _verificarErro(resposta);
  }

  Future<int> deletarTodasApostas() async {
    final resposta = await http.delete(_uri('/apostas/todas', {'confirmacao': 'APAGAR TUDO'}), headers: _headers());
    _verificarErro(resposta);
    final json = jsonDecode(utf8.decode(resposta.bodyBytes));
    return json['apagadas'] as int;
  }

  Future<void> deletarCasa(int id) async {
    final resposta = await http.delete(_uri('/casas/$id'), headers: _headers());
    _verificarErro(resposta);
  }

  Future<Casa> atualizarBancaCasa(int casaId, double valor) async {
    final resposta = await http.patch(
      _uri('/casas/$casaId/banca'),
      headers: _headers(json: true),
      body: jsonEncode({'banca_inicial': valor}),
    );
    _verificarErro(resposta);
    return Casa.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<List<ResumoPorCasa>> obterResumoPorCasa() async {
    final resposta = await http.get(_uri('/apostas/resumo-por-casa'), headers: _headers());
    _verificarErro(resposta);
    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    return lista.map((j) => ResumoPorCasa.fromJson(j)).toList();
  }

  Future<List<PontoLucroDia>> obterLucroPorDia() async {
    final resposta = await http.get(_uri('/apostas/lucro-por-dia'), headers: _headers());
    _verificarErro(resposta);
    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    return lista.map((j) => PontoLucroDia.fromJson(j)).toList();
  }

  // ---------------- Configuração / banca ----------------

  Future<Configuracao> obterConfiguracao() async {
    final resposta = await http.get(_uri('/configuracao/'), headers: _headers());
    _verificarErro(resposta);
    return Configuracao.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<Configuracao> definirBancaInicial(double valor) async {
    final resposta = await http.put(
      _uri('/configuracao/'),
      headers: _headers(json: true),
      body: jsonEncode({'banca_inicial': valor}),
    );
    _verificarErro(resposta);
    return Configuracao.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<List<PontoEvolucaoBanca>> obterEvolucaoBanca() async {
    final resposta = await http.get(_uri('/apostas/evolucao-banca'), headers: _headers());
    _verificarErro(resposta);
    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    return lista.map((j) => PontoEvolucaoBanca.fromJson(j)).toList();
  }

  // ---------------- Parsing (OCR) ----------------

  Future<RascunhoAposta> analisarBlocos(String casa, List<BlocoOCR> blocos) async {
    final resposta = await http.post(
      _uri('/parsing/analisar'),
      headers: _headers(json: true),
      body: jsonEncode({'casa': casa, 'blocos': blocos.map((b) => b.toJson()).toList()}),
    );
    _verificarErro(resposta);
    return RascunhoAposta.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  /// Lê o texto de uma imagem chamando o backend (que usa a Google Cloud
  /// Vision) — usado SÓ na versão web, onde o ML Kit local não existe.
  /// No celular, prefira OcrService.lerBlocos (roda no aparelho, offline).
  Future<List<BlocoOCR>> lerImagemViaServidor(XFile imagem) async {
    final bytes = await imagem.readAsBytes();
    final request = http.MultipartRequest('POST', _uri('/ocr/ler-imagem'));
    request.headers.addAll(_headers());
    request.files.add(http.MultipartFile.fromBytes('arquivo', bytes, filename: imagem.name));
    final resposta = await request.send();
    final corpo = await resposta.stream.bytesToString();
    if (resposta.statusCode >= 400) {
      String detalhe = corpo;
      try {
        detalhe = (jsonDecode(corpo) as Map)['detail']?.toString() ?? detalhe;
      } catch (_) {}
      throw ApiException('Erro ${resposta.statusCode}: $detalhe');
    }
    final lista = jsonDecode(corpo) as List;
    return lista.map((j) => BlocoOCR.fromJson(j)).toList();
  }

  // ---------------- Apostas turbinadas ----------------

  Future<double> calcularRetornoTurbinado({
    required double valorApostado,
    required double odd,
    required double aumentoPercentual,
  }) async {
    final resposta = await http.post(
      _uri('/apostas/calcular-retorno-turbinado'),
      headers: _headers(json: true),
      body: jsonEncode({
        'valor_apostado': valorApostado,
        'odd': odd,
        'aumento_percentual': aumentoPercentual,
      }),
    );
    _verificarErro(resposta);
    final json = jsonDecode(utf8.decode(resposta.bodyBytes));
    return (json['retorno_potencial'] as num).toDouble();
  }

  // ---------------- Importação de planilha ----------------

  Future<Map<String, dynamic>> importarPlanilha(Uint8List bytes, String nomeArquivo) async {
    final request = http.MultipartRequest('POST', _uri('/importacao/planilha'));
    request.headers.addAll(_headers());
    request.files.add(http.MultipartFile.fromBytes('arquivo', bytes, filename: nomeArquivo));
    final resposta = await request.send();
    final corpo = await resposta.stream.bytesToString();
    if (resposta.statusCode >= 400) {
      String detalhe = corpo;
      try {
        detalhe = (jsonDecode(corpo) as Map)['detail']?.toString() ?? detalhe;
      } catch (_) {}
      throw ApiException('Erro ${resposta.statusCode}: $detalhe');
    }
    return jsonDecode(corpo) as Map<String, dynamic>;
  }

  // ---------------- Telegram ----------------

  Future<Map<String, dynamic>> gerarCodigoTelegram() async {
    final resposta = await http.post(_uri('/telegram/gerar-codigo'), headers: _headers());
    _verificarErro(resposta);
    return jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
  }

  Future<bool> statusTelegram() async {
    final resposta = await http.get(_uri('/telegram/status'), headers: _headers());
    _verificarErro(resposta);
    final json = jsonDecode(utf8.decode(resposta.bodyBytes));
    return json['conectado'] as bool;
  }

  Future<void> desconectarTelegram() async {
    final resposta = await http.post(_uri('/telegram/desconectar'), headers: _headers());
    _verificarErro(resposta);
  }


// ---------------- Movimentações (saques/depósitos) ----------------

  Future<Movimentacao> criarMovimentacao({
    required int casaId,
    required TipoMovimentacao tipo,
    required double valor,
    required DateTime data,
  }) async {
    final resposta = await http.post(
      _uri('/movimentacoes/'),
      headers: _headers(json: true),
      body: jsonEncode({
        'casa_id': casaId,
        'tipo': tipo.valor,
        'valor': valor,
        'data': data.toIso8601String().split('T').first,
      }),
    );
    _verificarErro(resposta);
    return Movimentacao.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<List<Movimentacao>> listarMovimentacoes({
    int? casaId,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    final query = <String, String>{};
    if (casaId != null) query['casa_id'] = '$casaId';
    if (dataInicio != null) query['data_inicio'] = dataInicio.toIso8601String().split('T').first;
    if (dataFim != null) query['data_fim'] = dataFim.toIso8601String().split('T').first;

    final resposta = await http.get(_uri('/movimentacoes/', query), headers: _headers());
    _verificarErro(resposta);
    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    return lista.map((j) => Movimentacao.fromJson(j)).toList();
  }

  Future<void> deletarMovimentacao(int id) async {
    final resposta = await http.delete(_uri('/movimentacoes/$id'), headers: _headers());
    _verificarErro(resposta);
  }

  Future<BancaPorLocalizacao> obterBancaPorLocalizacao() async {
    final resposta = await http.get(_uri('/movimentacoes/banca-por-localizacao'), headers: _headers());
    _verificarErro(resposta);
    return BancaPorLocalizacao.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  // ---------------- Unidade ----------------

  Future<StatusUnidade> obterStatusUnidade() async {
    final resposta = await http.get(_uri('/configuracao/unidade'), headers: _headers());
    _verificarErro(resposta);
    return StatusUnidade.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<StatusUnidade> recalcularUnidade() async {
    final resposta = await http.post(_uri('/configuracao/unidade/recalcular'), headers: _headers());
    _verificarErro(resposta);
    return StatusUnidade.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<StatusUnidade> definirIntervaloUnidade(int dias) async {
    final resposta = await http.put(
      _uri('/configuracao/unidade/intervalo'),
      headers: _headers(json: true),
      body: jsonEncode({'intervalo_dias': dias}),
    );
    _verificarErro(resposta);
    return StatusUnidade.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  // ---------------- Sugestão de depósito ----------------

  Future<SugestaoDeposito> obterSugestaoDeposito({required double bancaTotalMes, int diasPeriodo = 30}) async {
    final resposta = await http.post(
      _uri('/movimentacoes/sugestao-deposito'),
      headers: _headers(json: true),
      body: jsonEncode({'banca_total_mes': bancaTotalMes, 'dias_periodo': diasPeriodo}),
    );
    _verificarErro(resposta);
    return SugestaoDeposito.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  // ---------------- Ciclos mensais ----------------

  Future<bool> obterModoMensal() async {
    final resposta = await http.get(_uri('/ciclos/modo-mensal'), headers: _headers());
    _verificarErro(resposta);
    return (jsonDecode(utf8.decode(resposta.bodyBytes)) as Map)['ativado'] as bool;
  }

  Future<bool> definirModoMensal(bool ativado) async {
    final resposta = await http.put(
      _uri('/ciclos/modo-mensal'),
      headers: _headers(json: true),
      body: jsonEncode({'ativado': ativado}),
    );
    _verificarErro(resposta);
    return (jsonDecode(utf8.decode(resposta.bodyBytes)) as Map)['ativado'] as bool;
  }

  Future<CicloMensal?> obterCicloAtual() async {
    final resposta = await http.get(_uri('/ciclos/atual'), headers: _headers());
    _verificarErro(resposta);
    final corpo = utf8.decode(resposta.bodyBytes);
    if (corpo == 'null') return null;
    return CicloMensal.fromJson(jsonDecode(corpo));
  }

  Future<CicloMensal> iniciarCiclo({String? nome}) async {
    final resposta = await http.post(
      _uri('/ciclos/iniciar'),
      headers: _headers(json: true),
      body: jsonEncode({'nome': nome}),
    );
    _verificarErro(resposta);
    return CicloMensal.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }

  Future<List<CicloMensal>> listarCiclos() async {
    final resposta = await http.get(_uri('/ciclos/'), headers: _headers());
    _verificarErro(resposta);
    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    return lista.map((j) => CicloMensal.fromJson(j)).toList();
  }

  Future<DashboardCiclo> obterDashboardCiclo(int cicloId) async {
    final resposta = await http.get(_uri('/ciclos/$cicloId/dashboard'), headers: _headers());
    _verificarErro(resposta);
    return DashboardCiclo.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)));
  }
}