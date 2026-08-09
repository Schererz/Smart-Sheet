# Backend - Planilha de Apostas

API em Python (FastAPI) que serve de base pro app Android. Cuida de:
guardar as apostas (a "planilha"), estruturar o texto lido de imagens
(OCR feito no celular) e, mais pra frente, rodar o modelo de ML.

## Como rodar

```bash
cd backend
python3 -m venv venv
source venv/bin/activate   # no Windows: venv\Scripts\activate
pip install -r requirements.txt

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Depois disso, abra `http://localhost:8000/docs` no navegador — o FastAPI
gera uma interface interativa (Swagger) onde dá pra testar todos os
endpoints sem precisar do app ainda.

Se for testar a partir do celular/emulador na mesma rede, use o IP da
sua máquina em vez de `localhost` (ex: `http://192.168.0.10:8000`).

## Rodando em produção (deploy na nuvem)

Duas variáveis de ambiente controlam o comportamento em produção:

- `DATABASE_URL` — se não definida, usa SQLite local (bom pra desenvolver).
  Em produção, aponte pra um Postgres, ex:
  `postgresql://usuario:senha@host:5432/banco`
- `GOOGLE_VISION_API_KEY` — só necessária se for usar a versão **web** do
  app (o celular usa OCR local, não precisa disso). Sem essa variável, o
  endpoint `/ocr/ler-imagem` retorna erro 500 explicando o que falta — o
  resto do app funciona normal.

O `Procfile` já define o comando de start esperado pela maioria dos
serviços de hospedagem (`uvicorn app.main:app --host 0.0.0.0 --port $PORT`).

## Endpoints principais

- `POST /casas/` — cadastra uma casa de apostas nova (o usuário digita o nome)
- `GET /casas/` — lista as casas cadastradas, ordenadas pelas mais usadas
  primeiro (é isso que popula a tela de seleção antes do upload da imagem)
- `DELETE /casas/{id}` — remove uma casa
- `POST /ocr/ler-imagem` — usado SÓ pela versão web: recebe uma imagem,
  chama a Google Cloud Vision e devolve os blocos de texto no mesmo
  formato que o celular gera localmente com o ML Kit. Precisa da variável
  `GOOGLE_VISION_API_KEY` configurada
- `POST /parsing/analisar` — recebe `{casa, blocos}` (a casa já escolhida +
  a lista de blocos de texto que o OCR detectou na imagem, cada um com
  posição normalizada x/y/largura/altura) e devolve um rascunho de aposta
  (odd, valor, retorno potencial, descrição) pra o usuário confirmar antes
  de salvar. Usa a posição dos blocos, não só o texto — funciona mesmo
  quando a imagem não tem rótulos explícitos como "Odd:"
- `GET /parsing/dataset-treino` — exporta os exemplos acumulados (blocos +
  sugestão original + valores confirmados) pra treinar/calibrar um modelo
  de verdade mais pra frente. Aceita `?casa=Betano` pra filtrar
- `POST /apostas/` — cria uma aposta (manual ou a partir do rascunho confirmado).
  Ao criar, o contador de uso da casa correspondente sobe automaticamente
- `GET /apostas/` — lista as apostas
- `GET /apostas/resumo` — estatísticas (total apostado, lucro, ROI, taxa de
  acerto, banca inicial e banca atual)
- `GET /apostas/evolucao-banca` — pontos da banca ao longo do tempo (banca
  inicial + soma acumulada do lucro de cada aposta resolvida), pro gráfico
- `PATCH /apostas/{id}` — edita qualquer campo da aposta
- `POST /apostas/{id}/ciclar-status` — avança o status: aberto → green → red → aberto...
  é isso que o botão de status no app deve chamar a cada clique
- `DELETE /apostas/{id}` — remove uma aposta
- `GET /configuracao/` — retorna a banca inicial configurada (e se já foi definida)
- `PUT /configuracao/` — define/atualiza a banca inicial

## Banco de dados

Por padrão usa SQLite (arquivo `apostas.db`, criado automaticamente na
primeira vez que voce roda o servidor). Não precisa instalar nada a mais
pra desenvolver. Quando quiser usar Postgres, defina a variável de
ambiente `DATABASE_URL` antes de subir o servidor.

## Sobre casas de apostas e como o "treino" funciona

Casas não são mais uma lista fixa no código — o usuário cadastra as que usa
(`POST /casas/`). A lista se reordena sozinha: toda vez que uma casa é usada
numa aposta, o contador dela sobe, e `GET /casas/` já devolve com as mais
usadas primeiro.

O fluxo pensado no app é: clicar em "+", escolher a casa numa lista (ou
cadastrar uma nova se for a primeira vez), tirar a foto, o ML Kit extrai os
blocos de texto **com posição** na imagem, e isso é mandado pra
`/parsing/analisar` junto com a casa escolhida.

Por que posição, e não só o texto? Muita imagem não tem rótulo explícito
("Odd:", "Valor:") — só números soltos em cantos específicos da tela. Hoje
o parser é único e genérico pra todas as casas (duas estratégias: acha um
rótulo próximo, ou cai numa zona aproximada da tela — veja `parsing.py`).

Toda aposta salva com origem "ocr" guarda os blocos originais e a sugestão
que o parser deu (`blocos_ocr`, `sugestao_original`), junto com os valores
finais que o usuário confirmou. Isso é o dataset, por casa: dá pra puxar
pelo `/parsing/dataset-treino?casa=X` e, quando uma casa específica tiver
exemplos suficientes, calibrar algo só pra ela (guardado no campo
`zonas_calibradas` da própria Casa) — no lugar do genérico único que temos
hoje.

## Próximos passos sugeridos

1. Testar os endpoints pelo `/docs` com dados de exemplo
2. Começar o app Flutter consumindo essa API
3. Adicionar câmera + OCR local (ML Kit) no app
4. SQLite local no app + sincronização com esse backend
5. Módulo de ML de verdade em cima dos dados acumulados
