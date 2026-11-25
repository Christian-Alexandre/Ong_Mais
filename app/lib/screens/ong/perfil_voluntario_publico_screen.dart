import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/catalogo.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/interesses.dart';

/// Perfil de um voluntário.
/// - Visto pela ONG: e-mail, pontos em comum com a ONG e a participação nas campanhas dela.
/// - Visto por outro voluntário (pelos comentários): foto, interesses em comum com você e números.
class PerfilVoluntarioPublicoScreen extends StatefulWidget {
  final int voluntarioId;
  final String? nomeInicial;
  const PerfilVoluntarioPublicoScreen({super.key, required this.voluntarioId, this.nomeInicial});

  @override
  State<PerfilVoluntarioPublicoScreen> createState() => _PerfilVoluntarioPublicoScreenState();
}

class _PerfilVoluntarioPublicoScreenState extends State<PerfilVoluntarioPublicoScreen> {
  Voluntario? _vol;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final v = await ApiService.instance.perfilDoVoluntario(widget.voluntarioId);
      if (mounted) setState(() => _vol = v);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  bool get _souOng => Session.instance.isOng;
  bool get _souEu => !_souOng && (Session.instance.perfil?['id'] as num?)?.toInt() == widget.voluntarioId;

  /// O que comparar: categoria + áreas da ONG logada, ou os interesses do voluntário logado.
  List<String> get _minhasTags {
    final p = Session.instance.perfil;
    if (p == null) return const [];
    if (_souOng) return Ong.fromJson(p).tags;
    return (p['interesses'] as List? ?? []).map((e) => e.toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final v = _vol;
    return Scaffold(
      appBar: AppBar(title: Text(v?.nomeCompleto ?? widget.nomeInicial ?? 'Voluntário')),
      body: v == null
          ? (_erro != null ? ErroCarregamento(mensagem: _erro!, onTentar: _carregar) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _cabecalho(v),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _numero(Icons.check_circle_outline_rounded, '${v.acoesApoiadas}', 'Ações apoiadas')),
                  const SizedBox(width: 12),
                  Expanded(child: _numero(Icons.timer_outlined, '${v.horasTrabalhadas}h', 'Horas doadas')),
                  if (_souOng) ...[
                    const SizedBox(width: 12),
                    Expanded(child: _numero(Icons.apartment_rounded, '${v.inscricoesNaOng.length}', 'Com sua ONG')),
                  ],
                ]),
                const SizedBox(height: 16),
                _secao(
                  'Interesses',
                  Icons.favorite_rounded,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!_souEu && v.interesses.isNotEmpty) FaixaEmComum(emComum: emComum(v.interesses, _minhasTags), com: _souOng ? 'com sua ONG' : 'com você'),
                    if (!_souEu && v.interesses.isNotEmpty) const SizedBox(height: 14),
                    ChipsInteresses(itens: v.interesses, emComum: _souEu ? const [] : emComum(v.interesses, _minhasTags), vazio: 'Este voluntário ainda não escolheu interesses.'),
                  ]),
                ),
                if (_souOng) const SizedBox(height: 16),
                if (_souOng)
                _secao(
                  'Participação nas suas campanhas',
                  Icons.history_rounded,
                  v.inscricoesNaOng.isEmpty
                      ? const Text('Ainda não participou das suas campanhas.', style: TextStyle(color: AppColors.textGrey))
                      : Column(children: [
                          for (final i in v.inscricoesNaOng)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(StatusInscricao.icone(i.status), color: StatusInscricao.cor(i.status)),
                              title: Text(i.campanhaTitulo ?? 'Campanha', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Inscrito em ${formatarData(i.criadoEm)}${i.horas > 0 ? ' • ${i.horas}h' : ''}'),
                              trailing: Etiqueta(texto: StatusInscricao.rotulo(i.status), cor: StatusInscricao.cor(i.status)),
                            ),
                        ]),
                ),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }

  Widget _cabecalho(Voluntario v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: AvatarVoluntario(fotoBase64: v.fotoBase64, nome: v.nomeCompleto, raio: 44, fundo: const Color(0xFFE6FAF4), corTexto: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(v.nomeCompleto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        if (v.email != null) Text(v.email!, style: const TextStyle(color: Colors.white70)),
        if (v.membroDesde != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Text('Voluntário desde ${formatarData(v.membroDesde)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  Widget _numero(IconData icone, String valor, String rotulo) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(children: [
            Icon(icone, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
          ]),
        ),
      );

  Widget _secao(String titulo, IconData icone, Widget filho) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icone, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ]),
            const SizedBox(height: 14),
            filho,
          ]),
        ),
      );
}
