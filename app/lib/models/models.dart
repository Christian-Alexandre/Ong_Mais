import '../core/catalogo.dart';
import '../core/utils.dart';

int _int(dynamic v, [int def = 0]) => v is int ? v : int.tryParse('$v') ?? def;
double? _double(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
List<String> _strs(dynamic v) => (v as List? ?? []).map((e) => e.toString()).toList();

class Ong {
  final int id;
  final String? email;
  final String nomeFantasia;
  final String cnpj;
  final String categoria;
  final List<String> areasAtuacao;
  final String whatsapp;
  final String? endereco;
  final double? latitude;
  final double? longitude;
  final String? descricao;
  final String? logoBase64;
  final int campanhasAtivas;
  final double? distanciaKm;
  final List<Campanha> campanhas;

  Ong({
    required this.id,
    this.email,
    required this.nomeFantasia,
    required this.cnpj,
    required this.categoria,
    this.areasAtuacao = const [],
    required this.whatsapp,
    this.endereco,
    this.latitude,
    this.longitude,
    this.descricao,
    this.logoBase64,
    this.campanhasAtivas = 0,
    this.distanciaKm,
    this.campanhas = const [],
  });

  bool get temCoordenadas => latitude != null && longitude != null;

  /// Categoria + áreas, para comparar com os interesses do voluntário.
  List<String> get tags => tagsDaOng(categoria, areasAtuacao);

  factory Ong.fromJson(Map<String, dynamic> j) => Ong(
        id: _int(j['id']),
        email: j['email'],
        nomeFantasia: j['nome_fantasia'] ?? '',
        cnpj: j['cnpj'] ?? '',
        categoria: j['categoria'] ?? 'Outros',
        areasAtuacao: _strs(j['areas_atuacao']),
        whatsapp: j['whatsapp'] ?? '',
        endereco: j['endereco'],
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        descricao: j['descricao'],
        logoBase64: j['logo_base64'],
        campanhasAtivas: _int(j['campanhas_ativas']),
        distanciaKm: _double(j['distancia_km']),
        campanhas: (j['campanhas'] as List? ?? []).map((e) => Campanha.fromJson(e)).toList(),
      );
}

class Voluntario {
  final int id;
  final String? email;
  final String nomeCompleto;
  final List<String> interesses;
  final int horasTrabalhadas;
  final int acoesApoiadas;
  final String? fotoBase64;
  final DateTime? membroDesde;
  /// Só no perfil visto pela ONG: participação do voluntário nas campanhas dela.
  final List<Inscricao> inscricoesNaOng;

  Voluntario({
    required this.id,
    this.email,
    required this.nomeCompleto,
    this.interesses = const [],
    this.horasTrabalhadas = 0,
    this.acoesApoiadas = 0,
    this.fotoBase64,
    this.membroDesde,
    this.inscricoesNaOng = const [],
  });

  factory Voluntario.fromJson(Map<String, dynamic> j) => Voluntario(
        id: _int(j['id']),
        email: j['email'],
        nomeCompleto: j['nome_completo'] ?? '',
        interesses: _strs(j['interesses']),
        horasTrabalhadas: _int(j['horas_trabalhadas']),
        acoesApoiadas: _int(j['acoes_apoiadas']),
        fotoBase64: j['foto_base64'],
        membroDesde: parseUtc(j['membro_desde']),
        inscricoesNaOng: (j['inscricoes_na_ong'] as List? ?? []).map((e) => Inscricao.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}

class Campanha {
  final int id;
  final int ongId;
  final String? ongNome;
  final String? ongLogoBase64;
  final String? ongWhatsapp;
  final String? ongCategoria;
  final List<String> ongAreasAtuacao;
  final String tipo;
  final String titulo;
  final String? descricao;
  final String? fotoBase64;
  final DateTime? criadoEm;
  final bool ativa;
  int curtidas;
  bool curtiu;
  final int inscritos;
  int comentarios;
  Inscricao? minhaInscricao;

  /// Categoria + áreas da ONG dona da campanha.
  List<String> get ongTags => tagsDaOng(ongCategoria, ongAreasAtuacao);

  Campanha({
    required this.id,
    required this.ongId,
    this.ongNome,
    this.ongLogoBase64,
    this.ongWhatsapp,
    this.ongCategoria,
    this.ongAreasAtuacao = const [],
    required this.tipo,
    required this.titulo,
    this.descricao,
    this.fotoBase64,
    this.criadoEm,
    this.ativa = true,
    this.curtidas = 0,
    this.curtiu = false,
    this.inscritos = 0,
    this.comentarios = 0,
    this.minhaInscricao,
  });

  factory Campanha.fromJson(Map<String, dynamic> j) => Campanha(
        id: _int(j['id']),
        ongId: _int(j['ong_id']),
        ongNome: j['ong_nome'],
        ongLogoBase64: j['ong_logo_base64'],
        ongWhatsapp: j['ong_whatsapp'],
        ongCategoria: j['ong_categoria'],
        ongAreasAtuacao: _strs(j['ong_areas_atuacao']),
        tipo: j['tipo'] ?? 'VOLUNTARIADO',
        titulo: j['titulo'] ?? '',
        descricao: j['descricao'],
        fotoBase64: j['foto_base64'],
        criadoEm: parseUtc(j['criado_em']),
        ativa: j['ativa'] ?? true,
        curtidas: _int(j['curtidas']),
        curtiu: j['curtiu'] == true,
        inscritos: _int(j['inscritos']),
        comentarios: _int(j['comentarios']),
        minhaInscricao: j['minha_inscricao'] == null ? null : Inscricao.fromJson(j['minha_inscricao']),
      );
}

class Inscricao {
  final int id;
  final int campanhaId;
  final int voluntarioId;
  final String status;
  final int horas;
  final DateTime? criadoEm;
  final String? campanhaTitulo;
  final String? campanhaTipo;
  final String? ongNome;
  final String? ongWhatsapp;
  final String? voluntarioNome;
  final String? voluntarioEmail;
  final List<String> voluntarioInteresses;
  final String? voluntarioFotoBase64;

  Inscricao({
    required this.id,
    required this.campanhaId,
    required this.voluntarioId,
    required this.status,
    this.horas = 0,
    this.criadoEm,
    this.campanhaTitulo,
    this.campanhaTipo,
    this.ongNome,
    this.ongWhatsapp,
    this.voluntarioNome,
    this.voluntarioEmail,
    this.voluntarioInteresses = const [],
    this.voluntarioFotoBase64,
  });

  bool get pendente => status == 'PENDENTE';

  factory Inscricao.fromJson(Map<String, dynamic> j) => Inscricao(
        id: _int(j['id']),
        campanhaId: _int(j['campanha_id']),
        voluntarioId: _int(j['voluntario_id']),
        status: j['status'] ?? 'PENDENTE',
        horas: _int(j['horas']),
        criadoEm: parseUtc(j['criado_em']),
        campanhaTitulo: j['campanha_titulo'],
        campanhaTipo: j['campanha_tipo'],
        ongNome: j['ong_nome'],
        ongWhatsapp: j['ong_whatsapp'],
        voluntarioNome: j['voluntario_nome'],
        voluntarioEmail: j['voluntario_email'],
        voluntarioInteresses: _strs(j['voluntario_interesses']),
        voluntarioFotoBase64: j['voluntario_foto_base64'],
      );
}

class Comentario {
  final int id;
  final int campanhaId;
  final int usuarioId;
  final String autorNome;
  final String? autorPapel;
  final String? autorLogoBase64;
  final String? autorFotoBase64;
  final String texto;
  final DateTime? criadoEm;
  final bool podeApagar;

  Comentario({
    required this.id,
    required this.campanhaId,
    required this.usuarioId,
    required this.autorNome,
    this.autorPapel,
    this.autorLogoBase64,
    this.autorFotoBase64,
    required this.texto,
    this.criadoEm,
    this.podeApagar = false,
  });

  bool get daOng => autorPapel == 'ONG';

  factory Comentario.fromJson(Map<String, dynamic> j) => Comentario(
        id: _int(j['id']),
        campanhaId: _int(j['campanha_id']),
        usuarioId: _int(j['usuario_id']),
        autorNome: j['autor_nome'] ?? 'Usuário',
        autorPapel: j['autor_papel'],
        autorLogoBase64: j['autor_logo_base64'],
        autorFotoBase64: j['autor_foto_base64'],
        texto: j['texto'] ?? '',
        criadoEm: parseUtc(j['criado_em']),
        podeApagar: j['pode_apagar'] == true,
      );
}
