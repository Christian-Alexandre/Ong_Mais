import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/catalogo.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Aba Impacto da ONG: o resultado do trabalho em números.
class ImpactoScreen extends StatefulWidget {
  const ImpactoScreen({super.key});

  @override
  State<ImpactoScreen> createState() => ImpactoScreenState();
}

class ImpactoScreenState extends State<ImpactoScreen> {
  Map<String, dynamic>? _d;
  String? _erro;

  static const _corInscricoes = AppColors.primary;
  static const _corComentarios = Color(0xFF4C6EF5);
  static const _corCurtidas = AppColors.danger;

  @override
  void initState() {
    super.initState();
    recarregar();
  }

  Future<void> recarregar() async {
    setState(() => _erro = null);
    try {
      final d = await ApiService.instance.impactoOng();
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  int _n(String k) => (_d?[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impacto'),
        actions: [IconButton(onPressed: recarregar, icon: const Icon(Icons.refresh_rounded, color: AppColors.primary), tooltip: 'Atualizar')],
      ),
      body: d == null
          ? (_erro != null ? ErroCarregamento(mensagem: _erro!, onTentar: recarregar) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: recarregar,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                _destaque(),
                const SizedBox(height: 14),
                _grade(),
                const SizedBox(height: 14),
                _cartao('Inscrições de voluntários', Icons.filter_alt_outlined, _funil()),
                const SizedBox(height: 14),
                _cartao('Atividade nas últimas 8 semanas', Icons.bar_chart_rounded, _atividade()),
                const SizedBox(height: 14),
                _cartao('Campanhas que mais engajam', Icons.emoji_events_outlined, _ranking()),
                const SizedBox(height: 14),
                _cartao('O que seus voluntários curtem', Icons.favorite_border_rounded, _interesses()),
              ]),
            ),
    );
  }

  // ------------------------------------------------------------ blocos

  Widget _destaque() {
    final horas = _n('horas_doadas');
    final vols = _n('voluntarios');
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Horas doadas à sua causa', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text('${horas}h', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, height: 1.1)),
            const SizedBox(height: 6),
            Text(
              vols == 0 ? 'Nenhum voluntário inscrito ainda' : (vols == 1 ? 'por 1 voluntário' : 'por $vols voluntários diferentes'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 40),
        ),
      ]),
    );
  }

  Widget _grade() {
    Widget kpi(IconData icone, Color cor, String valor, String rotulo) => Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icone, color: cor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                  Text(rotulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        Expanded(child: kpi(Icons.how_to_reg_outlined, _corInscricoes, '${_n('inscricoes')}', 'Inscrições')),
        const SizedBox(width: 12),
        Expanded(child: kpi(Icons.campaign_outlined, AppColors.orange, '${_n('campanhas_ativas')}/${_n('campanhas_total')}', 'Campanhas ativas')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: kpi(Icons.favorite_rounded, _corCurtidas, '${_n('curtidas')}', 'Curtidas')),
        const SizedBox(width: 12),
        Expanded(child: kpi(Icons.mode_comment_outlined, _corComentarios, '${_n('comentarios')}', 'Comentários')),
      ]),
    ]);
  }

  Widget _funil() {
    final status = Map<String, dynamic>.from(_d!['status'] as Map? ?? {});
    final total = status.values.fold<int>(0, (a, b) => a + (b as num).toInt());
    final taxa = _d!['taxa_aprovacao'];
    if (total == 0) return const _Vazio('Quando voluntários tocarem em "Quero Ajudar", o andamento aparece aqui.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final s in const ['PENDENTE', 'APROVADO', 'CONCLUIDO', 'RECUSADO'])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _barraRotulada(
            rotulo: StatusInscricao.rotulo(s),
            icone: StatusInscricao.icone(s),
            valor: (status[s] as num?)?.toInt() ?? 0,
            maximo: total,
            cor: StatusInscricao.cor(s),
          ),
        ),
      if (taxa != null)
        Text('Taxa de aprovação: $taxa% das inscrições respondidas', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
    ]);
  }

  Widget _atividade() {
    final semanas = (_d!['semanas'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    int v(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;
    final totais = [for (final s in semanas) v(s, 'inscricoes') + v(s, 'comentarios') + v(s, 'curtidas')];
    final maximo = totais.isEmpty ? 0 : totais.reduce(math.max);
    if (maximo == 0) return const _Vazio('Ainda sem curtidas, comentários ou inscrições nas últimas semanas.');
    const alturaMax = 120.0;
    return Column(children: [
      SizedBox(
        height: alturaMax + 40,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < semanas.length; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (totais[i] > 0) Text('${totais[i]}', style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                // barra empilhada: inscrições (base), comentários, curtidas (topo)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Column(children: [
                      Container(height: alturaMax * v(semanas[i], 'curtidas') / maximo, color: _corCurtidas),
                      Container(height: alturaMax * v(semanas[i], 'comentarios') / maximo, color: _corComentarios),
                      Container(height: alturaMax * v(semanas[i], 'inscricoes') / maximo, color: _corInscricoes),
                      if (totais[i] == 0) Container(height: 3, color: const Color(0xFFE9ECEF)),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                Text(i == semanas.length - 1 ? 'Agora' : _rotuloSemana(semanas[i]['inicio'] as String?),
                    style: TextStyle(fontSize: 10.5, color: i == semanas.length - 1 ? AppColors.primary : AppColors.textGrey, fontWeight: i == semanas.length - 1 ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 4, children: [
        _legenda(_corInscricoes, 'Inscrições'),
        _legenda(_corComentarios, 'Comentários'),
        _legenda(_corCurtidas, 'Curtidas'),
      ]),
    ]);
  }

  Widget _ranking() {
    final lista = (_d!['por_campanha'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).take(5).toList();
    if (lista.isEmpty) return const _Vazio('Publique uma campanha para acompanhar o engajamento.');
    final maximo = math.max(1, (lista.first['engajamento'] as num).toInt());
    return Column(children: [
      for (var i = 0; i < lista.length; i++) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: i == 0 ? const Color(0xFFFFD43B) : const Color(0xFFF1F3F5), shape: BoxShape.circle),
            child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lista[i]['titulo'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (lista[i]['engajamento'] as num).toInt() / maximo,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF1F3F5),
                  color: TipoCampanha.cor(lista[i]['tipo'] ?? ''),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 12, children: [
                _mini(Icons.favorite_rounded, _corCurtidas, lista[i]['curtidas']),
                _mini(Icons.mode_comment_outlined, _corComentarios, lista[i]['comentarios']),
                if (lista[i]['tipo'] == TipoCampanha.voluntariado) _mini(Icons.how_to_reg_outlined, _corInscricoes, lista[i]['inscritos']),
                if (lista[i]['ativa'] != true) const Text('inativa', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
              ]),
            ]),
          ),
        ]),
        if (i < lista.length - 1) const Divider(height: 22),
      ],
    ]);
  }

  Widget _interesses() {
    final lista = (_d!['interesses_voluntarios'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    if (lista.isEmpty) return const _Vazio('Quando voluntários se inscreverem, mostramos as causas que eles mais apoiam.');
    final p = Session.instance.perfil;
    final tags = p == null ? const <String>[] : Ong.fromJson(p).tags;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final x in lista)
          Builder(builder: (_) {
            final nome = x['interesse'] as String;
            final daOng = emComum([nome], tags).isNotEmpty;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: daOng ? AppColors.accent.withValues(alpha: 0.16) : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: daOng ? AppColors.accent : const Color(0xFFDEE2E6)),
              ),
              child: Text('$nome  ·  ${x['voluntarios']}', style: TextStyle(fontWeight: daOng ? FontWeight.bold : FontWeight.w500, color: daOng ? AppColors.primaryDark : AppColors.textDark)),
            );
          }),
      ]),
      const SizedBox(height: 8),
      const Text('Número = voluntários inscritos com esse interesse. Em verde, os que combinam com as suas áreas.', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
    ]);
  }

  // ------------------------------------------------------------ peças

  Widget _cartao(String titulo, IconData icone, Widget filho) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icone, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark))),
            ]),
            const SizedBox(height: 16),
            filho,
          ]),
        ),
      );

  Widget _barraRotulada({required String rotulo, required IconData icone, required int valor, required int maximo, required Color cor}) {
    return Row(children: [
      Icon(icone, size: 18, color: cor),
      const SizedBox(width: 6),
      SizedBox(width: 82, child: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: maximo == 0 ? 0 : valor / maximo, minHeight: 12, backgroundColor: const Color(0xFFF1F3F5), color: cor),
        ),
      ),
      SizedBox(width: 36, child: Text('$valor', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark))),
    ]);
  }

  Widget _legenda(Color cor, String texto) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ]);

  Widget _mini(IconData icone, Color cor, dynamic valor) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 14, color: cor),
        const SizedBox(width: 3),
        Text('${valor ?? 0}', style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
      ]);

  String _rotuloSemana(String? iso) {
    final dt = iso == null ? null : DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

class _Vazio extends StatelessWidget {
  final String texto;
  const _Vazio(this.texto);
  @override
  Widget build(BuildContext context) => Text(texto, style: const TextStyle(color: AppColors.textGrey));
}
