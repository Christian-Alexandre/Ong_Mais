import '../models/models.dart';
import 'api_client.dart';
import 'session.dart';

/// Chamadas da API tipadas. Uma função por endpoint do backend.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();
  final _api = ApiClient.instance;

  // ---------- Auth ----------
  Future<void> _guardarSessao(Map<String, dynamic> r) => Session.instance.salvar(
        token: r['access_token'],
        papel: r['papel'],
        perfil: Map<String, dynamic>.from(r['perfil']),
      );

  Future<void> login(String email, String senha) async {
    final r = await _api.post('/auth/login', {'email': email.trim(), 'senha': senha});
    await _guardarSessao(Map<String, dynamic>.from(r));
  }

  Future<void> registrarVoluntario({
    required String nome,
    required String email,
    required String senha,
    required String confirmar,
  }) async {
    final r = await _api.post('/auth/registro/voluntario', {
      'nome_completo': nome.trim(),
      'email': email.trim(),
      'senha': senha,
      'confirmar_senha': confirmar,
    });
    await _guardarSessao(Map<String, dynamic>.from(r));
  }

  Future<void> registrarOng(Map<String, dynamic> dados) async {
    final r = await _api.post('/auth/registro/ong', dados);
    await _guardarSessao(Map<String, dynamic>.from(r));
  }

  // ---------- Voluntário ----------
  Future<Voluntario> meuPerfilVoluntario() async {
    final r = await _api.get('/voluntarios/me');
    await Session.instance.atualizarPerfil(Map<String, dynamic>.from(r));
    return Voluntario.fromJson(r);
  }

  Future<Voluntario> atualizarVoluntario({required String nome, required List<String> interesses}) async {
    final r = await _api.put('/voluntarios/me', {'nome_completo': nome.trim(), 'interesses': interesses});
    await Session.instance.atualizarPerfil(Map<String, dynamic>.from(r));
    return Voluntario.fromJson(r);
  }

  // ---------- ONG ----------
  Future<Ong> meuPerfilOng() async {
    final r = await _api.get('/auth/me');
    final perfil = Map<String, dynamic>.from(r['perfil']);
    await Session.instance.atualizarPerfil(perfil);
    return Ong.fromJson(perfil);
  }

  Future<Ong> atualizarOng(Map<String, dynamic> dados) async {
    final r = await _api.put('/ongs/me', dados);
    await Session.instance.atualizarPerfil(Map<String, dynamic>.from(r));
    return Ong.fromJson(r);
  }

  Future<List<Ong>> listarOngs({double? lat, double? lng, double? raioKm, String? categoria, String? q}) async {
    final query = <String, String>{
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
      if (raioKm != null) 'raio_km': '$raioKm',
      if (categoria != null && categoria.isNotEmpty) 'categoria': categoria,
      if (q != null && q.isNotEmpty) 'q': q,
    };
    final r = await _api.get('/ongs', query: query);
    return (r as List).map((e) => Ong.fromJson(e)).toList();
  }

  Future<Ong> perfilPublicoOng(int id) async => Ong.fromJson(await _api.get('/ongs/$id'));

  // ---------- Campanhas ----------
  Future<List<Campanha>> feed({String? tipo, String? q}) async {
    final r = await _api.get('/campanhas', query: {
      if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (r as List).map((e) => Campanha.fromJson(e)).toList();
  }

  Future<List<Campanha>> minhasCampanhas() async {
    final r = await _api.get('/campanhas/minhas');
    return (r as List).map((e) => Campanha.fromJson(e)).toList();
  }

  Future<Campanha> criarCampanha({required String tipo, required String titulo, String? descricao, String? fotoBase64}) async {
    final r = await _api.post('/campanhas', {
      'tipo': tipo,
      'titulo': titulo.trim(),
      'descricao': descricao?.trim(),
      'foto_base64': fotoBase64,
    });
    return Campanha.fromJson(r);
  }

  Future<Campanha> editarCampanha(int id, Map<String, dynamic> dados) async =>
      Campanha.fromJson(await _api.put('/campanhas/$id', dados));

  Future<void> excluirCampanha(int id) => _api.delete('/campanhas/$id');

  /// Retorna (curtiu, total).
  Future<(bool, int)> curtir(int campanhaId) async {
    final r = await _api.post('/campanhas/$campanhaId/curtir');
    return (r['curtiu'] == true, (r['curtidas'] as num).toInt());
  }

  // ---------- Comentários ----------
  Future<List<Comentario>> comentarios(int campanhaId) async {
    final r = await _api.get('/campanhas/$campanhaId/comentarios');
    return (r as List).map((e) => Comentario.fromJson(e)).toList();
  }

  Future<Comentario> comentar(int campanhaId, String texto) async =>
      Comentario.fromJson(await _api.post('/campanhas/$campanhaId/comentarios', {'texto': texto.trim()}));

  Future<void> apagarComentario(int id) => _api.delete('/campanhas/comentarios/$id');

  Future<Inscricao> inscrever(int campanhaId) async =>
      Inscricao.fromJson(await _api.post('/campanhas/$campanhaId/inscricoes'));

  Future<List<Inscricao>> inscritosDaCampanha(int campanhaId) async {
    final r = await _api.get('/campanhas/$campanhaId/inscricoes');
    return (r as List).map((e) => Inscricao.fromJson(e)).toList();
  }

  // ---------- Inscrições ----------
  Future<List<Inscricao>> minhasInscricoes() async {
    final r = await _api.get('/inscricoes/minhas');
    return (r as List).map((e) => Inscricao.fromJson(e)).toList();
  }

  Future<void> cancelarInscricao(int id) => _api.delete('/inscricoes/$id');

  Future<Inscricao> atualizarInscricao(int id, String status, {int? horas}) async =>
      Inscricao.fromJson(await _api.patch('/inscricoes/$id', {'status': status, if (horas != null) 'horas': horas}));
}
