# ONG Mais — API (Flask)

## Rodar em desenvolvimento (SQLite)

```bash
cd api
python -m venv .venv
.venv\Scripts\activate          # Windows   (Linux/mac: source .venv/bin/activate)
pip install -r requirements.txt
copy .env.example .env          # Windows   (Linux/mac: cp .env.example .env)
python run.py
```

Sobe em `http://0.0.0.0:5000`. Ao subir, cria as tabelas e semeia as contas de **Teste Rápido**
(`AUTO_SEED=1`):

| Perfil     | E-mail                               | Senha  |
|------------|--------------------------------------|--------|
| ONG        | contato@patinhascarentes.org.br      | 123456 |
| Voluntário | voluntario@teste.com                 | 123456 |

Testes: `pip install pytest && python -m pytest -q`

## MySQL (produção / apresentação)

Automático (Windows): na raiz do projeto, dê duplo clique em **`configurar_mysql.cmd`**.
Ele pede a senha do `root` (não grava), cria o banco `ong_mais` e o usuário `ong_mais` com senha
gerada, grava `api/.env`, aplica as migrações, cria as contas de teste e reinicia a API.

Manual:

```sql
CREATE DATABASE ong_mais CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'ong_mais'@'localhost' IDENTIFIED BY 'uma-senha-forte';
GRANT ALL PRIVILEGES ON ong_mais.* TO 'ong_mais'@'localhost';
```

`.env`: `DATABASE_URL=mysql+pymysql://ong_mais:uma-senha-forte@127.0.0.1:3306/ong_mais?charset=utf8mb4`

```bash
set FLASK_APP=run.py            # Windows (Linux/mac: export FLASK_APP=run.py)
flask db upgrade                # cria/atualiza as tabelas pelas migrações (pasta migrations/)
flask seed                      # contas do Teste Rápido
flask reset-db                  # (opcional) apaga tudo e volta só ao seed
```

Com SQLite (`DATABASE_URL=sqlite:///...`) as tabelas são criadas automaticamente ao subir a API.
Com MySQL elas vêm **só das migrações**. Ao mudar `models.py`, gere uma nova migração:
`flask db migrate -m "descricao"` e depois `flask db upgrade`.

## Endpoints

Todas as rotas (exceto login/registro) exigem `Authorization: Bearer <token>`.
O papel (`ONG` | `VOLUNTARIO`) vai como claim `papel` dentro do JWT.

| Método | Rota | Quem | Descrição |
|---|---|---|---|
| POST | /auth/login | — | `{email, senha}` → `{access_token, papel, perfil}` |
| POST | /auth/registro/voluntario | — | `{nome_completo, email, senha, confirmar_senha}` |
| POST | /auth/registro/ong | — | `{nome_fantasia, cnpj, categoria, whatsapp, endereco?, latitude?, longitude?, descricao?, logo_base64?, email, senha, confirmar_senha}` — sem lat/lng tenta geocodificar o endereço |
| GET | /auth/me | ambos | perfil do usuário logado |
| GET | /voluntarios/me | VOL | perfil + `acoes_apoiadas` + `horas_trabalhadas` |
| PUT | /voluntarios/me | VOL | `{nome_completo?, interesses?: [..]}` |
| GET | /ongs | ambos | mapa. Query `lat, lng, raio_km, categoria, q` → inclui `distancia_km` (Haversine, laço O(n)) |
| GET | /ongs/:id | ambos | perfil público + `campanhas` ativas |
| PUT | /ongs/me | ONG | editar perfil da ONG |
| GET | /campanhas | ambos | feed (ativas, mais recentes primeiro). Query `tipo`, `q`. Para voluntário inclui `curtiu` e `minha_inscricao` |
| GET | /campanhas/minhas | ONG | campanhas da ONG (painel) |
| POST | /campanhas | ONG | `{tipo, titulo, descricao?, foto_base64?}` |
| PUT | /campanhas/:id | ONG | editar (`ativa` também) |
| DELETE | /campanhas/:id | ONG | excluir |
| POST | /campanhas/:id/curtir | VOL | alterna curtida → `{curtiu, curtidas}` |
| POST | /campanhas/:id/inscricoes | VOL | Quero Ajudar (só VOLUNTARIADO) → inscrição PENDENTE |
| GET | /campanhas/:id/inscricoes | ONG | lista de inscritos (nome, interesses, status) |
| GET | /inscricoes/minhas | VOL | Minhas Inscrições |
| DELETE | /inscricoes/:id | VOL | cancelar (só PENDENTE) |
| PATCH | /inscricoes/:id | ONG | `{status: APROVADO\|RECUSADO\|CONCLUIDO, horas?}` — ao concluir, `horas` é obrigatório e soma ao voluntário |

Datas são gravadas em UTC e serializadas como `2026-11-16T23:21:00Z`; o app converte para o fuso local.
