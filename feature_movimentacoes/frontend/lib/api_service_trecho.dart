// ADICIONAR ao api_service.dart, antes do fechamento da classe (import de
// '../models/movimentacao.dart' no topo do arquivo também é necessário)

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
