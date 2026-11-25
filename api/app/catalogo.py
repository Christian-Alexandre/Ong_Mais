"""Catálogo de causas: categoria da ONG -> áreas de atuação.

O voluntário escolhe interesses deste mesmo catálogo (categorias e/ou áreas), o que permite
mostrar os "pontos em comum" entre voluntário e ONG. A cópia do app fica em
app/lib/core/catalogo.dart — mantenha as duas iguais.
"""
import re

AREAS_POR_CATEGORIA: dict[str, list[str]] = {
    "Animais": [
        "Adoção",
        "Resgate de animais",
        "Cuidados veterinários",
        "Castração",
        "Lar temporário",
        "Alimentação animal",
    ],
    "Educação": [
        "Reforço escolar",
        "Alfabetização",
        "Cursos profissionalizantes",
        "Inclusão digital",
        "Leitura e cultura",
        "Educação infantil",
    ],
    "Alimentação": [
        "Cestas básicas",
        "Refeições comunitárias",
        "Combate ao desperdício",
        "Hortas comunitárias",
        "Banco de alimentos",
    ],
    "Saúde": [
        "Apoio a pacientes",
        "Saúde mental",
        "Doação de sangue",
        "Campanhas de prevenção",
        "Cuidado de idosos",
        "Pessoas com deficiência",
    ],
    "Meio Ambiente": [
        "Reflorestamento",
        "Reciclagem",
        "Limpeza de praias e rios",
        "Educação ambiental",
        "Proteção da fauna",
    ],
    "Outros": [
        "Assistência social",
        "Moradia",
        "Esporte e lazer",
        "Cultura e arte",
        "Direitos humanos",
        "Emergências e desastres",
    ],
}

CATEGORIAS = tuple(AREAS_POR_CATEGORIA)
TODAS_AS_AREAS = tuple(a for areas in AREAS_POR_CATEGORIA.values() for a in areas)


def areas_validas(categoria: str, areas: list[str] | None) -> tuple[list[str], list[str]]:
    """Retorna (áreas aceitas sem repetição, áreas inválidas para a categoria)."""
    permitidas = AREAS_POR_CATEGORIA.get(categoria, [])
    aceitas: list[str] = []
    invalidas: list[str] = []
    for a in areas or []:
        a = (a or "").strip()
        if not a:
            continue
        if a in permitidas:
            if a not in aceitas:
                aceitas.append(a)
        else:
            invalidas.append(a)
    return aceitas, invalidas


# ---------------------------------------------------------------- Telefone

# DDDs em uso no Brasil (Anatel)
DDDS_VALIDOS = frozenset(
    {
        11, 12, 13, 14, 15, 16, 17, 18, 19,
        21, 22, 24, 27, 28,
        31, 32, 33, 34, 35, 37, 38,
        41, 42, 43, 44, 45, 46, 47, 48, 49,
        51, 53, 54, 55,
        61, 62, 63, 64, 65, 66, 67, 68, 69,
        71, 73, 74, 75, 77, 79,
        81, 82, 83, 84, 85, 86, 87, 88, 89,
        91, 92, 93, 94, 95, 96, 97, 98, 99,
    }
)


def telefone_erro(valor: str | None) -> str | None:
    """None se o telefone brasileiro (DDD + número) é válido; senão a mensagem de erro.

    Celular: DDD + 9 dígitos começando com 9. Fixo: DDD + 8 dígitos começando com 2 a 5.
    Aceita o prefixo 55 (código do país).
    """
    d = re.sub(r"\D", "", valor or "")
    if len(d) in (12, 13) and d.startswith("55"):
        d = d[2:]
    if len(d) not in (10, 11):
        return "Informe DDD + número (10 ou 11 dígitos)."
    if int(d[:2]) not in DDDS_VALIDOS:
        return f"DDD {d[:2]} não existe."
    numero = d[2:]
    if len(numero) == 9 and numero[0] != "9":
        return "Celular deve começar com 9 depois do DDD."
    if len(numero) == 8 and numero[0] not in "2345":
        return "Número fixo inválido (celular precisa do 9 na frente)."
    if len(set(numero)) == 1:
        return "Número inválido."
    return None


def normalizar_telefone(valor: str) -> str:
    d = re.sub(r"\D", "", valor or "")
    if len(d) in (12, 13) and d.startswith("55"):
        d = d[2:]
    return d
