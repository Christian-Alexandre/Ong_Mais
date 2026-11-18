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
