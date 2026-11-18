# ONG Mais

Aplicativo que conecta voluntários a ONGs por geolocalização. Reconstrução do zero conforme
`ONG_MAIS_ESPECIFICACAO.md` (v1, 16/11/2026).

| Pasta  | O que é | Como rodar |
|--------|---------|------------|
| `api/` | Backend Python 3 + Flask (JWT, Bcrypt, Marshmallow, SQLAlchemy 2.0, Flask-Migrate). SQLite em dev, MySQL em produção. | `api/README.md` |
| `app/` | App Flutter (Android primeiro). | `app/README.md` |

## Como rodar (Windows)

1. **`iniciar_api.cmd`**: sobe a API (janela "ONG Mais API"; log em `api_log.txt`). Deixe aberta.
2. **`app_celular.cmd`**: compila e instala no emulador aberto ou no celular via USB
   (no celular usa o IP do PC no Wi-Fi automaticamente; log em `saida_flutter_run_HHMMSS.txt`).
3. Na tela de login: **Teste Rápido (1-Clique)** → Conta ONG / Conta Voluntário.
   A engrenagem no canto do login troca o endereço da API sem recompilar.

Banco: **MySQL** (`configurar_mysql.cmd` cria banco, usuário, `api/.env`, aplica as migrações e o seed).
Sem MySQL, apague `api/.env` (ou use `DATABASE_URL=sqlite:///ong_mais.db`) e a API usa SQLite.

Outros scripts: `diagnostico.cmd` (verifica API/porta/firewall), `verificar_app.cmd`
(flutter doctor + analyze + test), `instalar_flutter.cmd` (instalação inicial do SDK),
`publicar_github.cmd` (commit + push para o repositório).

### Primeira vez em outro PC (colegas da equipe)

1. Instalar Python 3, Flutter (ou `instalar_flutter.cmd`), Android Studio e MySQL Server 8.
2. `iniciar_api.cmd` uma vez (cria o venv e instala as dependências), depois `configurar_mysql.cmd`.
3. Na pasta `app`: `flutter pub get`; abrir um emulador e rodar `app_celular.cmd`.

Mapa: OpenStreetMap (sem chave). Veja `app/README.md` para trocar para Google Maps.

## Contas de teste (seed)

- ONG: `contato@patinhascarentes.org.br` / `123456` (Instituto Patinhas Carentes, 2 campanhas)
- Voluntário: `voluntario@teste.com` / `123456` (Lucas Silva)
