# Frontend - App de Apostas (Flutter)

Esse pacote tem o código Dart (`lib/`) e as dependências (`pubspec.yaml`),
mas **não tem** as pastas `android/`/`ios/` que o Flutter gera automaticamente
com `flutter create`. Isso é proposital: gerar essas pastas exige o Flutter
SDK rodando de verdade, então você faz esse passo uma vez no seu PC.

## Passo a passo (primeira vez)

1. Se ainda não tem o Flutter SDK, instale seguindo
   https://docs.flutter.dev/get-started/install (escolha Windows).
   Confirme que deu certo com `flutter doctor` no terminal.

2. Crie um projeto Flutter novo, num lugar separado desse zip:
   ```
   flutter create apostas_app
   ```

3. Copie os arquivos deste pacote **por cima** do projeto que acabou de criar:
   - Copie a pasta `lib/` inteira, substituindo a que já existe (ela cria um
     `lib/main.dart` de exemplo que você não vai usar)
   - Abra o `pubspec.yaml` do projeto novo e copie a seção `dependencies:`
     deste `pubspec.yaml` pra dentro dele (mantenha o `name:` e o resto que
     o `flutter create` já gerou)

4. Dentro da pasta do projeto, rode:
   ```
   flutter pub get
   ```

5. Configure a permissão de câmera (necessária pro `image_picker`):
   - **Android**: abra `android/app/src/main/AndroidManifest.xml` e adicione,
     dentro da tag `<manifest>`, antes de `<application>`:
     ```xml
     <uses-permission android:name="android.permission.CAMERA" />
     ```
   - Também confira se `minSdkVersion` em `android/app/build.gradle` está
     em pelo menos 21 (o `google_mlkit_text_recognition` exige isso).

6. Com um emulador Android aberto (ou celular conectado com depuração USB
   ativada), rode:
   ```
   flutter run
   ```

## Sobre o endereço do backend

O app está configurado pra falar com `http://10.0.2.2:8000` (veja
`lib/services/api_service.dart`) — esse é o IP especial que o **emulador**
Android usa pra enxergar o `localhost` da sua máquina, onde o backend
(`uvicorn`) está rodando.

- Testando no emulador Android: não precisa mudar nada, já funciona,
  desde que o backend esteja rodando na sua máquina.
- Testando num celular físico: troque `10.0.2.2` pelo IP da sua máquina
  na rede Wi-Fi (ex: `192.168.0.10`), e garanta que o celular está na
  mesma rede.
- Rode `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000` no
  backend (o `--host 0.0.0.0` é o que permite outros aparelhos da rede
  acessarem, não só a própria máquina).

## O que já está pronto

- **Tela inicial (hub)**: banca atual, gráfico de evolução da banca, resumo
  (lucro, ROI, taxa de acerto) + lista de apostas em cards, cada uma com um
  botão de status que cicla aberto → green → red a cada toque, e um botão
  de excluir (com confirmação) — ou dá pra arrastar o card pra esquerda
- **Banca inicial**: na primeira vez que abre o app, pergunta a banca
  inicial (dá pra editar depois pelo ícone de engrenagem no topo)
- **Seleção de casa**: tela que aparece ao tocar no "+", lista as casas já
  cadastradas (mais usadas primeiro), permite cadastrar uma nova e excluir
  as que não usa mais
- **Captura de imagem + OCR local**: tira foto ou escolhe da galeria, lê o
  texto com o Google ML Kit (offline) e manda os blocos pro backend
  estruturar
- **Formulário de confirmação/edição**: tanto pro fluxo do OCR (pré-cheio,
  pra revisar antes de salvar) quanto pro cadastro manual

Se você já tinha rodado `flutter pub get` antes, rode de novo depois de
atualizar os arquivos — adicionei a dependência `fl_chart` (gráfico de
evolução da banca).

## O que falta / próximos passos

- Calibração do OCR por casa específica (precisa de prints reais de cada
  casa pra ajustar as regras — hoje o parser é genérico)
- Modo offline de verdade (hoje toda ação depende do backend estar
  acessível — dá pra evoluir com um banco local (`sqflite`) que sincroniza
  depois)
- Tela de edição de uma aposta já salva (hoje só dá pra criar/excluir/ciclar
  o status)
- Filtros na lista (por casa, por período, por status)
