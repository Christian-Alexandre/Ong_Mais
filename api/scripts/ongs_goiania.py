"""Cadastra ONGs reais de Goiânia (dados públicos) com campanhas de exemplo, pela API.

Uso:  python scripts/ongs_goiania.py https://SEU-TUNEL.ngrok-free.dev
As campanhas são exemplos para a demonstração do app (não são campanhas oficiais das ONGs).
Contato, CNPJ e e-mail são de demonstração; senha de todas as contas: 123456.
Rodar de novo não duplica: ONG já cadastrada é ignorada.
"""
import json
import random
import sys
import urllib.error
import urllib.request

AVISO = "\n\nPerfil de demonstração do app ONG Mais, criado com informações públicas; as campanhas são exemplos."
WHATS_DEMO = "(62) 98765-4321"  # número de demonstração (troque pelo real da ONG, se quiser)


def cnpj_demo(semente: int) -> str:
    rnd = random.Random(semente)
    base = [rnd.randint(0, 9) for _ in range(8)] + [0, 0, 0, 1]

    def dv(nums, pesos):
        r = sum(n * p for n, p in zip(nums, pesos)) % 11
        return 0 if r < 2 else 11 - r

    p1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    d1 = dv(base, p1)
    d2 = dv(base + [d1], [6] + p1)
    d = "".join(map(str, base + [d1, d2]))
    return f"{d[:2]}.{d[2:5]}.{d[5:8]}/{d[8:12]}-{d[12:]}"


def turno(dia: str, ini_utc: str, fim_utc: str, vagas: int) -> dict:
    return {"inicio": f"{dia}T{ini_utc}:00Z", "fim": f"{dia}T{fim_utc}:00Z", "vagas": vagas}


def item(nome, unidade, meta, arrecadado):
    return {"nome": nome, "unidade": unidade, "meta": meta, "arrecadado": arrecadado}


# Horários em UTC (Goiânia = UTC-3): 09h local = 12:00Z
ONGS = [
    {
        "nome_fantasia": "OVG – Organização das Voluntárias de Goiás",
        "email": "ovg@goiania.demo",
        "categoria": "Outros",
        "areas_atuacao": ["Assistência social", "Esporte e lazer", "Cultura e arte"],
        "endereco": "Rua T-14, nº 249, Setor Bueno, Goiânia - GO, 74230-130",
        "latitude": -16.7005,
        "longitude": -49.2760,
        "descricao": "Associação civil de Goiânia que atua na assistência social a pessoas em situação de "
        "vulnerabilidade e no incentivo ao voluntariado em Goiás. Mantém centros de idosos, o Restaurante do "
        "Bem e o Banco de Alimentos, e promove o Natal do Bem.",
        "campanhas": [
            {
                "tipo": "VOLUNTARIADO",
                "titulo": "Natal do Bem: montagem de kits",
                "descricao": "Precisamos de voluntários para separar brinquedos e alimentos e montar os kits "
                "que serão entregues às famílias no fim do ano. Atividade na sede, no Setor Bueno.",
                "turnos": [
                    turno("2026-12-05", "12:00", "15:00", 15),
                    turno("2026-12-05", "17:00", "20:00", 15),
                    turno("2026-12-12", "12:00", "15:00", 15),
                ],
            },
            {
                "tipo": "DOACAO",
                "titulo": "Banco de Alimentos: arrecadação de fim de ano",
                "descricao": "Arrecadação de alimentos não perecíveis para as famílias atendidas. "
                "Entregas na sede, de segunda a sexta, em horário comercial.",
                "itens": [
                    item("Arroz", "kg", 500, 120),
                    item("Feijão", "kg", 300, 80),
                    item("Óleo", "un", 200, 45),
                    item("Leite em pó", "latas", 150, 30),
                ],
            },
        ],
    },
    {
        "nome_fantasia": "APAE de Goiânia",
        "email": "apae@goiania.demo",
        "categoria": "Saúde",
        "areas_atuacao": ["Pessoas com deficiência", "Apoio a pacientes"],
        "endereco": "Rua 255, nº 628, Setor Coimbra, Goiânia - GO, 74533-150",
        "latitude": -16.6795,
        "longitude": -49.2830,
        "descricao": "Associação de Pais e Amigos dos Excepcionais de Goiânia: entidade filantrópica que oferece "
        "educação especial e atendimento a pessoas com deficiência intelectual e às suas famílias. Mantém a "
        "Escola Especial Helena Antipoff, no Setor Coimbra, e atividades de esporte e cultura, como capoeira.",
        "campanhas": [
            {
                "tipo": "VOLUNTARIADO",
                "titulo": "Apoio nas aulas de capoeira e música",
                "descricao": "Voluntários para ajudar os professores nas aulas de capoeira e percussão dos alunos. "
                "Não precisa saber tocar: o apoio é na organização e no acolhimento da turma.",
                "turnos": [
                    turno("2026-12-03", "11:00", "14:00", 4),
                    turno("2026-12-10", "11:00", "14:00", 4),
                ],
            },
            {
                "tipo": "DOACAO",
                "titulo": "Materiais pedagógicos e de higiene",
                "descricao": "Arrecadação de materiais para as salas de aula e para os cuidados diários dos alunos.",
                "itens": [
                    item("Fraldas", "pacotes", 100, 35),
                    item("Papel A4", "resmas", 50, 12),
                    item("Lápis de cor", "caixas", 80, 20),
                ],
            },
        ],
    },
    {
        "nome_fantasia": "Araújo Jorge – Associação de Combate ao Câncer em Goiás",
        "email": "accg@goiania.demo",
        "categoria": "Saúde",
        "areas_atuacao": ["Apoio a pacientes", "Campanhas de prevenção"],
        "endereco": "Setor Leste Universitário, ao lado da Praça Universitária, Goiânia - GO",
        "latitude": -16.6790,
        "longitude": -49.2385,
        "descricao": "Instituição filantrópica fundada em 1956 que mantém o Hospital de Câncer Araújo Jorge, "
        "referência no tratamento oncológico em Goiás e único CACON do estado, com pacientes de todo o Brasil. "
        "Também realiza campanhas de prevenção, como o Outubro Rosa.",
        "campanhas": [
            {
                "tipo": "VOLUNTARIADO",
                "titulo": "Acolhimento de pacientes e acompanhantes",
                "descricao": "Voluntários para recepcionar, orientar e fazer companhia a pacientes e "
                "acompanhantes nas salas de espera: conversa, leitura e um cafezinho.",
                "turnos": [
                    turno("2026-11-30", "11:00", "15:00", 6),
                    turno("2026-12-02", "11:00", "15:00", 6),
                    turno("2026-12-04", "16:00", "20:00", 6),
                ],
            },
            {
                "tipo": "DOACAO",
                "titulo": "Kits de conforto para quem está em tratamento",
                "descricao": "Itens para quem passa longos períodos no hospital, principalmente pacientes "
                "que vêm do interior.",
                "itens": [
                    item("Cobertores", "un", 100, 30),
                    item("Kits de higiene", "un", 200, 70),
                    item("Suplemento alimentar", "latas", 120, 25),
                ],
            },
        ],
    },
    {
        "nome_fantasia": "Focinho Caridoso",
        "email": "focinho@goiania.demo",
        "categoria": "Animais",
        "areas_atuacao": ["Adoção", "Resgate de animais", "Lar temporário"],
        "endereco": "Feiras de adoção no Passeio das Águas Shopping – Av. Perimetral Norte, 8303, "
        "Fazenda Caveiras, Goiânia - GO",
        "latitude": -16.6255,
        "longitude": -49.2670,
        "descricao": "ONG e abrigo de proteção animal de Goiânia que resgata cães e gatos e promove feiras de "
        "adoção responsável em shoppings da cidade, como o Passeio das Águas e o Bougainville. As feiras "
        "dependem de voluntários para receber o público e cuidar dos animais.",
        "campanhas": [
            {
                "tipo": "VOLUNTARIADO",
                "titulo": "Feira de adoção no Passeio das Águas",
                "descricao": "Ajude na feira de adoção do último sábado do mês: receber as famílias, apresentar "
                "os cães e gatos e cuidar deles durante o evento.",
                "turnos": [
                    turno("2026-11-28", "17:00", "20:00", 8),
                    turno("2026-12-26", "17:00", "20:00", 8),
                ],
            },
            {
                "tipo": "DOACAO",
                "titulo": "Ração e areia para o abrigo",
                "descricao": "Os animais resgatados dependem de doações. Entregue nas feiras ou combine a retirada.",
                "itens": [
                    item("Ração para cães", "kg", 300, 110),
                    item("Ração para gatos", "kg", 150, 40),
                    item("Areia higiênica", "kg", 100, 30),
                    item("Vermífugo", "doses", 80, 15),
                ],
            },
        ],
    },
    {
        "nome_fantasia": "Instituto Plantadores de Água",
        "email": "plantadores@goiania.demo",
        "categoria": "Meio Ambiente",
        "areas_atuacao": ["Reflorestamento", "Educação ambiental"],
        "endereco": "Ponto de plantio no Setor Goiânia 2, Goiânia - GO",
        "latitude": -16.6290,
        "longitude": -49.2580,
        "descricao": "Instituto formado por voluntários que planta mudas nativas do Cerrado em áreas degradadas, "
        "nascentes e praças de Goiânia e região no período chuvoso, e cuida da manutenção dos plantios na seca. "
        "Já atuou no Residencial Talismã, Veredas dos Buritis, Goiânia 2 e Vila Rosa, entre outros.",
        "campanhas": [
            {
                "tipo": "VOLUNTARIADO",
                "titulo": "Mutirão de plantio de mudas do Cerrado",
                "descricao": "Domingo de manhã é dia de plantar! Traga chapéu, protetor solar e garrafinha "
                "de água. As ferramentas e as mudas ficam por nossa conta.",
                "turnos": [
                    turno("2026-11-29", "10:00", "13:00", 30),
                    turno("2026-12-13", "10:00", "13:00", 30),
                ],
            },
            {
                "tipo": "DOACAO",
                "titulo": "Mudas e ferramentas para o plantio",
                "descricao": "Para ampliar os plantios desta temporada de chuvas.",
                "itens": [
                    item("Mudas nativas", "un", 500, 180),
                    item("Adubo orgânico", "sacos", 60, 15),
                    item("Enxadas", "un", 20, 6),
                ],
            },
        ],
    },
]


def chamar(url, metodo="GET", corpo=None, token=None):
    req = urllib.request.Request(url, method=metodo, data=json.dumps(corpo).encode() if corpo is not None else None)
    req.add_header("Content-Type", "application/json")
    req.add_header("ngrok-skip-browser-warning", "1")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def main(base):
    base = base.rstrip("/")
    for i, ong in enumerate(ONGS):
        dados = {k: v for k, v in ong.items() if k != "campanhas"}
        dados.update(
            cnpj=cnpj_demo(1000 + i),
            whatsapp=WHATS_DEMO,
            senha="123456",
            confirmar_senha="123456",
            descricao=ong["descricao"] + AVISO,
        )
        st, r = chamar(f"{base}/auth/registro/ong", "POST", dados)
        if st == 409:
            print(f"- {ong['nome_fantasia']}: já cadastrada, pulando")
            continue
        if st != 201:
            print(f"! {ong['nome_fantasia']}: erro {st} {r}")
            continue
        token = r["access_token"]
        for c in ong["campanhas"]:
            st, rc = chamar(f"{base}/campanhas", "POST", c, token)
            print(f"  {'ok' if st == 201 else 'ERRO ' + str(st)}  {c['titulo']}" + ("" if st == 201 else f" {rc}"))
        print(f"+ {ong['nome_fantasia']} ({ong['email']})")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:5000")
