import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

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
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://10.0.2.2:8000';
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

  Future<void> deletarCasa(int id) async {
    final resposta = await http.delete(_uri('/casas/$id'), headers: _headers());
    _verificarErro(resposta);
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
}
