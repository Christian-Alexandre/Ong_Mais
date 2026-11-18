# ONG Mais

<img src="app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" alt="Ícone do ONG Mais" width="96" align="right">

Aplicativo Android que conecta voluntários a ONGs por geolocalização. A ONG publica campanhas
(voluntariado, doação ou financeiro); o voluntário encontra pelo feed ou pelo mapa, toca em
**Quero Ajudar** e fala com a ONG pelo WhatsApp; a ONG aprova, recusa ou conclui a inscrição
registrando as horas doadas. Voluntários comentam nas campanhas e a ONG responde e modera os
comentários pelo próprio painel. Especificação: `ONG_MAIS_ESPECIFICACAO.md`.

| Pasta  | O que é | Detalhes |
|--------|---------|----------|
| `api/` | Backend Python 3 + Flask (JWT, Bcrypt, Marshmallow, SQLAlchemy 2.0, Flask-Migrate). MySQL em produção, SQLite em dev. | `api/README.md` |
| `app/` | App Flutter (Android), mapa OpenStreetMap. | `app/README.md` |

Documentação do projeto: `apresentacao_mobile.docx`.

## Rodar no dia a dia (Windows)

1. **`iniciar_tunel.cmd`**: sobe a API e publica na internet pelo ngrok em
   **https://dismiss-duct-vacate.ngrok-free.dev**. Enquanto a janela estiver aberta o PC não entra
   em suspensão. Fechar a janela tira o app do ar fora de casa.
2. Instalar o **`ONG_Mais.apk`** no celular. Ele já aponta para o endereço do ngrok, então funciona
   no 4G ou em qualquer Wi-Fi.
3. Na tela de login: **Teste Rápido (1-Clique)** → Conta ONG / Conta Voluntário.

A **engrenagem** na tela de login troca o servidor sem gerar outro APK: deixe em branco para usar o
endereço do ngrok ou digite o IP do PC (ex.: `192.168.0.10`) para usar só na rede local, com
`iniciar_api.cmd` no lugar do túnel.

## Scripts

| Script | Para quê |
|--------|----------|
| `iniciar_tunel.cmd` | API + túnel ngrok (instala/atualiza o ngrok e pede o authtoken na 1ª vez) |
| `iniciar_api.cmd` | Só a API, na rede local; aplica as migrações do MySQL ao subir (log em `api_log.txt`) |
| `atualizar_api.cmd` | Reinicia a API para carregar código novo, sem apagar dados (o túnel pode ficar aberto) |
| `gerar_apk.cmd` | Gera o `ONG_Mais.apk` de release e instala nos aparelhos conectados |
| `app_celular.cmd` | Roda o app em modo de desenvolvimento (celular USB ou emulador) |
| `limpar_dados.cmd` | Volta o banco ao estado inicial (só as contas de teste) |
| `configurar_mysql.cmd` | Cria banco, usuário, `api/.env`, migrações e seed no MySQL |
| `diagnostico.cmd` | Verifica API, porta e firewall |
| `verificar_app.cmd` | flutter doctor + analyze + test |
| `capturar_telas.cmd` | Prints do emulador em alta resolução (pasta `telas/`) |
| `publicar_github.cmd` | Commit + push (usa `mensagem_commit.txt`, se existir) |

O domínio do ngrok fica em `iniciar_tunel.ps1` e `gerar_apk.ps1` (`$dominio` / `$dominioNgrok`).
Com `$dominioNgrok = ''` o APK sai apontando para o IP do PC na rede.

## Primeira vez em outro PC (colegas da equipe)

1. Instalar Python 3, Flutter (ou `instalar_flutter.cmd`), Android Studio e MySQL Server 8.
2. `iniciar_api.cmd` uma vez (cria o venv e instala as dependências), depois `configurar_mysql.cmd`.
3. Na pasta `app`: `flutter pub get`; abrir um emulador e rodar `app_celular.cmd`.
4. Para acesso pela internet, cada um usa a própria conta ngrok: troque o domínio nos dois scripts.

Sem MySQL, apague `api/.env` (ou use `DATABASE_URL=sqlite:///ong_mais.db`) e a API usa SQLite.
Mapa: OpenStreetMap (sem chave). Veja `app/README.md` para usar Google Maps.

## Contas de teste (seed)

- ONG: `contato@patinhascarentes.org.br` / `123456` (Instituto Patinhas Carentes, 2 campanhas)
- Voluntário: `voluntario@teste.com` / `123456` (Lucas Silva)
