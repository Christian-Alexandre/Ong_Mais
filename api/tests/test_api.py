"""Smoke test de ponta a ponta usando SQLite em memória.

Rodar:  cd api && python -m pytest -q
"""
import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["AUTO_SEED"] = "1"

from app import create_app  # noqa: E402


@pytest.fixture(scope="module")
def client():
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def _login(client, email, senha="123456"):
    r = client.post("/auth/login", json={"email": email, "senha": senha})
    assert r.status_code == 200, r.get_json()
    return {"Authorization": f"Bearer {r.get_json()['access_token']}"}


def test_fluxo_completo(client):
    ong = _login(client, "contato@patinhascarentes.org.br")
    vol = _login(client, "voluntario@teste.com")

    # Feed
    r = client.get("/campanhas", headers=vol)
    assert r.status_code == 200 and len(r.get_json()) == 2
    camp = next(c for c in r.get_json() if c["tipo"] == "VOLUNTARIADO")
    assert camp["criado_em"].endswith("Z")

    # Curtir / descurtir
    r = client.post(f"/campanhas/{camp['id']}/curtir", headers=vol)
    assert r.get_json() == {"curtiu": True, "curtidas": 1}
    r = client.post(f"/campanhas/{camp['id']}/curtir", headers=vol)
    assert r.get_json() == {"curtiu": False, "curtidas": 0}

    # Inscrever (Quero Ajudar) -> Pendente
    r = client.post(f"/campanhas/{camp['id']}/inscricoes", headers=vol)
    assert r.status_code == 201 and r.get_json()["status"] == "PENDENTE"
    insc_id = r.get_json()["id"]

    # Minhas inscrições
    r = client.get("/inscricoes/minhas", headers=vol)
    assert len(r.get_json()) == 1 and r.get_json()[0]["ong_nome"] == "Instituto Patinhas Carentes"

    # ONG vê inscritos e aprova / conclui com horas
    r = client.get(f"/campanhas/{camp['id']}/inscricoes", headers=ong)
    assert r.get_json()[0]["voluntario_nome"] == "Lucas Silva"
    r = client.patch(f"/inscricoes/{insc_id}", json={"status": "CONCLUIDO"}, headers=ong)
    assert r.status_code == 400  # Pendente -> Concluído não permitido
    r = client.patch(f"/inscricoes/{insc_id}", json={"status": "APROVADO"}, headers=ong)
    assert r.get_json()["status"] == "APROVADO"
    r = client.patch(f"/inscricoes/{insc_id}", json={"status": "CONCLUIDO", "horas": 15}, headers=ong)
    assert r.get_json()["status"] == "CONCLUIDO"

    # Perfil do voluntário: 1 ação apoiada, 15h
    r = client.get("/voluntarios/me", headers=vol)
    assert r.get_json()["acoes_apoiadas"] == 1 and r.get_json()["horas_trabalhadas"] == 15

    # Voluntário não pode cancelar inscrição concluída
    r = client.delete(f"/inscricoes/{insc_id}", headers=vol)
    assert r.status_code == 400

    # Voluntário não pode criar campanha
    r = client.post("/campanhas", json={"tipo": "DOACAO", "titulo": "x"}, headers=vol)
    assert r.status_code == 403

    # ONG cria, edita e exclui campanha
    r = client.post("/campanhas", json={"tipo": "FINANCEIRO", "titulo": "Vaquinha", "descricao": "Pix"}, headers=ong)
    assert r.status_code == 201
    cid = r.get_json()["id"]
    r = client.put(f"/campanhas/{cid}", json={"titulo": "Vaquinha 2"}, headers=ong)
    assert r.get_json()["titulo"] == "Vaquinha 2"
    r = client.delete(f"/campanhas/{cid}", headers=ong)
    assert r.status_code == 200

    # Mapa: ONG com distância (ponto próximo da Paulista)
    r = client.get("/ongs?lat=-23.56&lng=-46.65", headers=vol)
    assert r.get_json()[0]["distancia_km"] < 2
    r = client.get("/ongs?lat=-23.56&lng=-46.65&raio_km=0.1", headers=vol)
    assert r.get_json() == []

    # Perfil público com campanhas ativas
    r = client.get(f"/ongs/{camp['ong_id']}", headers=vol)
    assert len(r.get_json()["campanhas"]) == 2


def test_cadastros(client):
    r = client.post("/auth/registro/voluntario", json={"nome_completo": "Ana", "email": "ana@x.com", "senha": "123456"})
    assert r.status_code == 201 and r.get_json()["papel"] == "VOLUNTARIO"
    r = client.post("/auth/registro/voluntario", json={"nome_completo": "Ana", "email": "ana@x.com", "senha": "123456"})
    assert r.status_code == 409

    base = {
        "nome_fantasia": "ONG Teste", "categoria": "Educação", "whatsapp": "(11) 91234-5678",
        "email": "ong@x.com", "senha": "123456", "confirmar_senha": "123456",
        "latitude": -23.5, "longitude": -46.6,
    }
    r = client.post("/auth/registro/ong", json={**base, "cnpj": "11.111.111/1111-11"})
    assert r.status_code == 422  # CNPJ inválido
    r = client.post("/auth/registro/ong", json={**base, "cnpj": "11.222.333/0001-81"})
    assert r.status_code == 201, r.get_json()
    assert r.get_json()["perfil"]["whatsapp"] == "11912345678"


def test_comentarios(client):
    ong = _login(client, "contato@patinhascarentes.org.br")
    vol = _login(client, "voluntario@teste.com")
    camp = client.get("/campanhas", headers=vol).get_json()[0]
    cid = camp["id"]
    assert camp["comentarios"] == 0

    # vazio e validação
    assert client.post(f"/campanhas/{cid}/comentarios", json={"texto": ""}, headers=vol).status_code == 422

    # voluntário comenta, ONG dona responde
    r = client.post(f"/campanhas/{cid}/comentarios", json={"texto": "Posso levar meu filho?"}, headers=vol)
    assert r.status_code == 201
    c1 = r.get_json()
    assert c1["autor_nome"] == "Lucas Silva" and c1["pode_apagar"] and c1["criado_em"].endswith("Z")
    r = client.post(f"/campanhas/{cid}/comentarios", json={"texto": "Pode sim!"}, headers=ong)
    assert r.status_code == 201 and r.get_json()["autor_papel"] == "ONG"

    lista = client.get(f"/campanhas/{cid}/comentarios", headers=vol).get_json()
    assert [c["texto"] for c in lista] == ["Posso levar meu filho?", "Pode sim!"]
    assert lista[1]["pode_apagar"] is False  # voluntário não apaga o da ONG
    assert client.get(f"/campanhas/{cid}", headers=vol).get_json()["comentarios"] == 2

    # voluntário não apaga comentário da ONG; ONG (dona) modera o do voluntário
    assert client.delete(f"/campanhas/comentarios/{lista[1]['id']}", headers=vol).status_code == 403
    assert client.delete(f"/campanhas/comentarios/{c1['id']}", headers=ong).status_code == 200
    assert len(client.get(f"/campanhas/{cid}/comentarios", headers=vol).get_json()) == 1


def test_telefone_com_ddd():
    from app.catalogo import telefone_erro

    assert telefone_erro("(11) 98765-4321") is None  # celular
    assert telefone_erro("(21) 3456-7890") is None  # fixo
    assert telefone_erro("+55 11 98765-4321") is None  # com código do país
    assert telefone_erro("(20) 98765-4321") == "DDD 20 não existe."
    assert "começar com 9" in telefone_erro("(11) 88765-4321")
    assert "fixo inválido" in telefone_erro("(11) 8765-4321")
    assert telefone_erro("11 9876") is not None
    assert telefone_erro("(11) 99999-9999") == "Número inválido."


def test_cadastro_ong_areas_e_telefone(client):
    base = {
        "nome_fantasia": "ONG Teste Áreas",
        "cnpj": "11.444.777/0001-61",
        "categoria": "Animais",
        "whatsapp": "(11) 91234-5678",
        "email": "areas@teste.com",
        "senha": "123456",
        "latitude": -23.5,
        "longitude": -46.6,
    }
    # telefone com DDD inexistente
    r = client.post("/auth/registro/ong", json={**base, "whatsapp": "(20) 91234-5678"})
    assert r.status_code == 422 and "whatsapp" in r.get_json()["detalhes"]
    # área de outra categoria
    r = client.post("/auth/registro/ong", json={**base, "areas_atuacao": ["Adoção", "Reciclagem"]})
    assert r.status_code == 422 and "areas_atuacao" in r.get_json()["detalhes"]
    # ok
    r = client.post("/auth/registro/ong", json={**base, "areas_atuacao": ["Adoção", "Castração", "Adoção"]})
    assert r.status_code == 201, r.get_json()
    perfil = r.get_json()["perfil"]
    assert perfil["areas_atuacao"] == ["Adoção", "Castração"] and perfil["whatsapp"] == "11912345678"

    tok = {"Authorization": f"Bearer {r.get_json()['access_token']}"}
    # troca de categoria sem mandar áreas: áreas antigas que não valem mais saem
    r = client.put("/ongs/me", json={"categoria": "Educação"}, headers=tok)
    assert r.status_code == 200 and r.get_json()["areas_atuacao"] == []
    r = client.put("/ongs/me", json={"areas_atuacao": ["Alfabetização"], "whatsapp": "11 3456-7890"}, headers=tok)
    assert r.status_code == 200 and r.get_json()["areas_atuacao"] == ["Alfabetização"]
    assert client.put("/ongs/me", json={"whatsapp": "123"}, headers=tok).status_code == 422


def test_catalogo_e_perfil_do_voluntario(client):
    r = client.get("/catalogo")
    assert r.status_code == 200 and "Adoção" in r.get_json()["categorias"]["Animais"]

    ong = _login(client, "contato@patinhascarentes.org.br")
    vol = _login(client, "voluntario@teste.com")
    me = client.get("/voluntarios/me", headers=vol).get_json()
    assert "Adoção" in me["interesses"] and me["membro_desde"].endswith("Z")

    # campanha do feed traz categoria e áreas da ONG (para o app calcular os pontos em comum)
    camp = client.get("/campanhas", headers=vol).get_json()[0]
    assert camp["ong_categoria"] == "Animais" and "Adoção" in camp["ong_areas_atuacao"]

    # outro voluntário (ex.: pelos comentários) vê o perfil sem e-mail e sem participação
    r = client.get(f"/voluntarios/{me['id']}", headers=vol)
    assert r.status_code == 200 and r.get_json()["email"] is None and "inscricoes_na_ong" not in r.get_json()
    r = client.get(f"/voluntarios/{me['id']}", headers=ong)
    assert r.status_code == 200
    dados = r.get_json()
    assert dados["nome_completo"] == "Lucas Silva" and isinstance(dados["inscricoes_na_ong"], list)
    assert client.get("/voluntarios/99999", headers=ong).status_code == 404


def test_endereco_pela_localizacao(client, monkeypatch):
    from app.routes import geo

    monkeypatch.setattr(geo, "endereco_de_coordenadas", lambda lat, lng: "Av. Paulista, 1000 - Bela Vista, São Paulo - SP")
    r = client.get("/geo/endereco?lat=-23.5653&lng=-46.6520")
    assert r.status_code == 200 and r.get_json()["endereco"].startswith("Av. Paulista")
    assert client.get("/geo/endereco?lat=abc").status_code == 400

    from app.services.geocoding import _montar_endereco

    texto = _montar_endereco({"address": {"road": "Avenida Paulista", "house_number": "1000", "suburb": "Bela Vista", "city": "São Paulo", "ISO3166-2-lvl4": "BR-SP"}})
    assert texto == "Avenida Paulista, 1000 - Bela Vista, São Paulo - SP"


def test_catalogo_igual_no_app():
    """A cópia do catálogo no app (catalogo.dart) precisa ter as mesmas áreas da API."""
    import re

    from app.catalogo import AREAS_POR_CATEGORIA

    dart = os.path.join(os.path.dirname(__file__), "..", "..", "app", "lib", "core", "catalogo.dart")
    if not os.path.exists(dart):
        pytest.skip("app/ não está ao lado da api/")
    texto = open(dart, encoding="utf-8").read()
    for categoria, areas in AREAS_POR_CATEGORIA.items():
        linha = re.search(rf"'{re.escape(categoria)}': \[(.*?)\]", texto)
        assert linha, categoria
        assert re.findall(r"'([^']+)'", linha.group(1)) == areas, categoria


def test_impacto_da_ong(client):
    ong = _login(client, "contato@patinhascarentes.org.br")
    vol = _login(client, "voluntario@teste.com")
    assert client.get("/ongs/me/impacto", headers=vol).status_code == 403

    camp = next(c for c in client.get("/campanhas", headers=vol).get_json() if c["tipo"] == "VOLUNTARIADO")
    antes = client.get("/ongs/me/impacto", headers=ong).get_json()
    client.post(f"/campanhas/{camp['id']}/curtir", headers=vol)
    client.post(f"/campanhas/{camp['id']}/comentarios", json={"texto": "Quero ajudar!"}, headers=vol)
    client.post(f"/campanhas/{camp['id']}/comentarios", json={"texto": "Obrigado!"}, headers=ong)  # resposta não conta

    r = client.get("/ongs/me/impacto", headers=ong)
    assert r.status_code == 200
    d = r.get_json()
    assert d["curtidas"] == antes["curtidas"] + 1
    assert d["comentarios"] == antes["comentarios"] + 1
    assert set(d["status"]) == {"PENDENTE", "APROVADO", "CONCLUIDO", "RECUSADO"}
    assert len(d["semanas"]) == 8 and d["semanas"][-1]["curtidas"] >= 1
    assert d["por_campanha"][0]["id"] == camp["id"]  # a mais engajada vem primeiro
    assert d["voluntarios"] >= 1 and any(x["interesse"] == "Adoção" for x in d["interesses_voluntarios"])
    assert d["horas_doadas"] >= 0



def test_cadastro_voluntario_com_foto_e_interesses(client):
    foto = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    r = client.post(
        "/auth/registro/voluntario",
        json={"nome_completo": "Ana Souza", "email": "ana@teste.com", "senha": "123456",
              "interesses": ["Animais", "Adoção", "Adoção", " "], "foto_base64": foto},
    )
    assert r.status_code == 201, r.get_json()
    perfil = r.get_json()["perfil"]
    assert perfil["interesses"] == ["Animais", "Adoção"] and perfil["foto_base64"] == foto
    ana = {"Authorization": f"Bearer {r.get_json()['access_token']}"}

    # a foto aparece no comentário e pode ser removida
    vol = _login(client, "voluntario@teste.com")
    camp = client.get("/campanhas", headers=ana).get_json()[0]
    c = client.post(f"/campanhas/{camp['id']}/comentarios", json={"texto": "Oi!"}, headers=ana).get_json()
    assert c["autor_foto_base64"] == foto and c["autor_logo_base64"] is None
    # Lucas abre o perfil da Ana pelo comentário
    assert client.get(f"/voluntarios/{c['usuario_id']}", headers=vol).get_json()["nome_completo"] == "Ana Souza"

    r = client.put("/voluntarios/me", json={"foto_base64": None}, headers=ana)
    assert r.status_code == 200 and r.get_json()["foto_base64"] is None
    assert client.put("/voluntarios/me", json={"foto_base64": "x" * 1_600_000}, headers=ana).status_code == 422
