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
  final String? chavePix;

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
    this.chavePix,
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
        chavePix: j['chave_pix'],
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
  final List<Turno> turnos;
  final List<ItemDoacao> itens;
  final String? ongChavePix;
  final int mensagensNaoLidas;

  /// Turnos que ainda não terminaram (os que o voluntário pode escolher).
  List<Turno> get turnosAbertos => turnos.where((t) => !t.encerrado).toList();

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
    this.turnos = const [],
    this.itens = const [],
    this.ongChavePix,
    this.mensagensNaoLidas = 0,
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
        turnos: (j['turnos'] as List? ?? []).map((e) => Turno.fromJson(Map<String, dynamic>.from(e))).toList(),
        itens: (j['itens'] as List? ?? []).map((e) => ItemDoacao.fromJson(Map<String, dynamic>.from(e))).toList(),
        ongChavePix: j['ong_chave_pix'],
        mensagensNaoLidas: _int(j['mensagens_nao_lidas']),
      );
}

/// Horário de uma campanha de voluntariado, com número de vagas.
class Turno {
  final int? id;
  final DateTime inicio; // horário local
  final DateTime fim;
  final int vagas;
  final int ocupadas;
  final int horas;
  final bool encerrado;

  Turno({this.id, required this.inicio, required this.fim, required this.vagas, this.ocupadas = 0, this.horas = 0, this.encerrado = false});

  int get vagasLivres => (vagas - ocupadas).clamp(0, vagas);
  bool get lotado => vagasLivres == 0;

  factory Turno.fromJson(Map<String, dynamic> j) => Turno(
        id: j['id'] == null ? null : _int(j['id']),
        inicio: parseUtc(j['inicio']) ?? DateTime.now(),
        fim: parseUtc(j['fim']) ?? DateTime.now(),
        vagas: _int(j['vagas']),
        ocupadas: _int(j['ocupadas']),
        horas: _int(j['horas']),
        encerrado: j['encerrado'] == true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'inicio': inicio.toUtc().toIso8601String(),
        'fim': fim.toUtc().toIso8601String(),
        'vagas': vagas,
      };
}

/// Item pedido numa campanha de doação, com meta e quanto já chegou.
class ItemDoacao {
  final int? id;
  final String nome;
  final String unidade;
  final double meta;
  final double arrecadado;

  ItemDoacao({this.id, required this.nome, this.unidade = 'un', required this.meta, this.arrecadado = 0});

  double get progresso => meta <= 0 ? 0 : (arrecadado / meta).clamp(0, 1).toDouble();

  factory ItemDoacao.fromJson(Map<String, dynamic> j) => ItemDoacao(
        id: j['id'] == null ? null : _int(j['id']),
        nome: j['nome'] ?? '',
        unidade: j['unidade'] ?? 'un',
        meta: _double(j['meta']) ?? 0,
        arrecadado: _double(j['arrecadado']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nome': nome,
        'unidade': unidade,
        'meta': meta,
        'arrecadado': arrecadado,
      };
}

/// Mensagem da conversa entre voluntário e ONG sobre uma inscrição.
class Mensagem {
  final int id;
  final int autorId;
  final String texto;
  final DateTime? criadoEm;
  final bool lida;
  final bool minha;

  Mensagem({required this.id, required this.autorId, required this.texto, this.criadoEm, this.lida = false, this.minha = false});

  factory Mensagem.fromJson(Map<String, dynamic> j) => Mensagem(
        id: _int(j['id']),
        autorId: _int(j['autor_id']),
        texto: j['texto'] ?? '',
        criadoEm: parseUtc(j['criado_em']),
        lida: j['lida'] == true,
        minha: j['minha'] == true,
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
  final Turno? turno;
  final int naoLidas;
  final String? ultimaMensagem;
  final bool ultimaMensagemMinha;
  final int? ongId;
  final String? ongLogoBase64;

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
    this.turno,
    this.naoLidas = 0,
    this.ultimaMensagem,
    this.ultimaMensagemMinha = false,
    this.ongId,
    this.ongLogoBase64,
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
        turno: j['turno'] == null ? null : Turno.fromJson(Map<String, dynamic>.from(j['turno'])),
        naoLidas: _int(j['mensagens_nao_lidas']),
        ultimaMensagem: j['ultima_mensagem']?['texto'],
        ultimaMensagemMinha: j['ultima_mensagem']?['minha'] == true,
        ongId: j['ong_id'] == null ? null : _int(j['ong_id']),
        ongLogoBase64: j['ong_logo_base64'],
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
