# ONG Mais — App (Flutter)

Aqui estão apenas os arquivos que importam (`lib/`, `pubspec.yaml` e o `AndroidManifest.xml`).
A pasta `android/` completa é gerada pelo próprio Flutter no passo 1.

## 1. Gerar o projeto Android (uma vez)

```bash
cd app
flutter create --org br.com.ongmais --platforms android --project-name ong_mais .
flutter pub get
```

`flutter create .` só cria o que falta; não sobrescreve `lib/`, `pubspec.yaml` nem o `AndroidManifest.xml`.
Requer Flutter **3.27 ou mais novo** (`flutter --version`).

## 2. Ajustes no Android

**a) `android/app/build.gradle.kts`** (ou `build.gradle`): dentro de `defaultConfig`, deixe

```kotlin
minSdk = 23
```

(`flutter_secure_storage` e `google_maps_flutter` exigem isso).

**b) Mapa:** o app usa **OpenStreetMap** por padrão (gratuito, sem chave). A Maps Demo Key do
Google não funciona no Android (o Maps SDK for Android exige chave com faturamento). Para trocar
para Google Maps no futuro: crie uma chave com faturamento, ative a *Maps SDK for Android*,
restrinja ao pacote `br.com.ongmais.ong_mais` + SHA-1 do seu keystore, cole no
`AndroidManifest.xml` e rode com `--dart-define=USAR_GOOGLE_MAPS=true`
(ou mude `$usarGoogleMaps = $true` no `app_celular.ps1`).

## 3. Apontar para a API

A URL padrão é `http://10.0.2.2:5000` (emulador Android → PC). Para celular físico na mesma
rede Wi-Fi, use o IP do PC (`ipconfig` → IPv4):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:5000
```

Lembre de liberar a porta 5000 no firewall do Windows e subir a API com `python run.py`
(ela já escuta em `0.0.0.0`).

## Estrutura

```
lib/
  main.dart                      # raiz, decide ONG x Voluntário pelo papel salvo
  core/
    config.dart                  # API_BASE_URL, USAR_GOOGLE_MAPS
    theme.dart                   # cores e tema (verde-água do protótipo)
    session.dart                 # JWT + papel + perfil no flutter_secure_storage
    api_client.dart              # HTTP + tratamento de erro
    api_service.dart             # uma função por endpoint
    utils.dart                   # datas UTC→local, Base64, CNPJ, WhatsApp, rótulos
  models/models.dart             # Ong, Voluntario, Campanha, Inscricao
  widgets/common.dart            # avatar/logo/foto Base64, image picker, campos, etiquetas
  screens/
    auth/      login_screen, cadastro_screen (Voluntário | Sou ONG)
    voluntario/voluntario_shell (Feed | Mapa | Meu Perfil), feed_screen (Explorar / Minhas Inscrições), perfil_voluntario_screen
    mapa/      mapa_screen (busca, chips, pinos, distância), mapa_widget (Google / OSM)
    ong/       ong_shell (Meu Painel | Nova Campanha | Perfil Público), painel_screen, nova_campanha_sheet,
               gerenciar_inscritos_screen, editar_perfil_ong_screen, perfil_publico_screen
```

## Regras implementadas (conforme especificação)

- **Quero Ajudar** no feed: Voluntariado → cria inscrição *Pendente* e abre o WhatsApp da ONG com
  mensagem pronta; Doação/Financeiro → só abre o WhatsApp.
- **Minhas Inscrições**: Pendente / Aprovado / Concluído / Recusado; *Cancelar* só se Pendente.
- **Gerenciar Voluntários Inscritos** (ONG): Aprovar / Recusar / Concluir; ao concluir pede as horas,
  que somam em *Horas Doadas* do voluntário. *Ações Apoiadas* = inscrições aprovadas + concluídas.
- **Tempo relativo** corrigido: servidor grava UTC (`...Z`), o app converte para o fuso do aparelho
  (nunca mostra "há -171 min").
- **Curtir** funcional com contador real; comentar/compartilhar apenas visuais.
- **Perfil Público**: sem Resgates/Avaliação/Verificada; botão laranja *QUERO AJUDAR* abre o WhatsApp.
- **Mapa**: distância em km vinda da API (Haversine, laço O(n)); ONG sem coordenadas não aparece.
