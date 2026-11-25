"""Geocodificação de endereço (fallback quando a ONG não captura o GPS).

Usa o Nominatim (OpenStreetMap), gratuito e sem chave. Falhas são silenciosas:
sem coordenadas a ONG simplesmente não aparece no mapa.
"""
import logging

import requests

log = logging.getLogger(__name__)

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"


def geocodificar(endereco: str) -> tuple[float | None, float | None]:
    try:
        r = requests.get(
            NOMINATIM_URL,
            params={"q": endereco, "format": "json", "limit": 1, "countrycodes": "br"},
            headers={"User-Agent": "ONGMais/1.0 (projeto academico)"},
            timeout=6,
        )
        r.raise_for_status()
        resultados = r.json()
        if resultados:
            return float(resultados[0]["lat"]), float(resultados[0]["lon"])
    except Exception as e:  # noqa: BLE001
        log.warning("Falha ao geocodificar '%s': %s", endereco, e)
    return None, None


NOMINATIM_REVERSE_URL = "https://nominatim.openstreetmap.org/reverse"
_cache_reverso: dict[tuple[float, float], str | None] = {}


def endereco_de_coordenadas(lat: float, lng: float) -> str | None:
    """Endereço legível a partir do GPS: "Rua, número - Bairro, Cidade - UF".

    Resultados ficam em cache (coordenadas arredondadas ~11 m) para respeitar o limite
    de 1 requisição/segundo do Nominatim.
    """
    chave = (round(lat, 4), round(lng, 4))
    if chave in _cache_reverso:
        return _cache_reverso[chave]
    endereco = None
    try:
        r = requests.get(
            NOMINATIM_REVERSE_URL,
            params={"lat": lat, "lon": lng, "format": "jsonv2", "addressdetails": 1, "zoom": 18, "accept-language": "pt-BR"},
            headers={"User-Agent": "ONGMais/1.0 (projeto academico)"},
            timeout=6,
        )
        r.raise_for_status()
        endereco = _montar_endereco(r.json())
    except Exception as e:  # noqa: BLE001
        log.warning("Falha no endereço reverso (%s, %s): %s", lat, lng, e)
        return None  # não guarda falha no cache: pode ter sido rede
    _cache_reverso[chave] = endereco
    return endereco


def _montar_endereco(dados: dict) -> str | None:
    a = dados.get("address") or {}
    rua = a.get("road") or a.get("pedestrian") or a.get("footway") or a.get("street")
    numero = a.get("house_number")
    bairro = a.get("suburb") or a.get("neighbourhood") or a.get("quarter") or a.get("city_district")
    cidade = a.get("city") or a.get("town") or a.get("village") or a.get("municipality")
    uf = (a.get("ISO3166-2-lvl4") or "").replace("BR-", "") or a.get("state")

    primeira = ", ".join(p for p in (rua, numero) if p)
    segunda = ", ".join(p for p in (bairro, cidade) if p)
    if uf:
        segunda = f"{segunda} - {uf}" if segunda else uf
    partes = [p for p in (primeira, segunda) if p]
    if partes:
        return " - ".join(partes)
    return dados.get("display_name")
