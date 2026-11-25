import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/catalogo.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/interesses.dart';
import 'perfil_voluntario_publico_screen.dart';

/// Gerenciar Voluntários Inscritos: Aprovar / Recusar / Concluir (com horas).
class GerenciarInscritosScreen extends StatefulWidget {
  final Campanha campanha;
  const GerenciarInscritosScreen({super.key, required this.campanha});

  @override
  State<GerenciarInscritosScreen> createState() => _GerenciarInscritosScreenState();
}

class _GerenciarInscritosScreenState extends State<GerenciarInscritosScreen> {
  List<String> get _tagsDaOng {
    final p = Session.instance.perfil;
    return p == null ? const [] : Ong.fromJson(p).tags;
  }

  List<Inscricao>? _lista;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final l = await ApiService.instance.inscritosDaCampanha(widget.campanha.id);
      if (mounted) setState(() => _lista = l);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  Future<void> _mudar(Inscricao i, String status) async {
    int? horas;
    if (status == 'CONCLUIDO') {
      horas = await _pedirHoras(i);
      if (horas == null) return;
    }
    try {
      await ApiService.instance.atualizarInscricao(i.id, status, horas: horas);
      if (!mounted) return;
      mostrarSnack(context, switch (status) {
        'APROVADO' => '${i.voluntarioNome} aprovado(a)!',
        'RECUSADO' => 'Inscrição de ${i.voluntarioNome} recusada.',
        _ => 'Concluído! ${horas}h somadas a ${i.voluntarioNome}.',
      });
      await _carregar();
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro: $e', erro: true);
    }
  }

  Future<int?> _pedirHoras(Inscricao i) async {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concluir participação'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Quantas horas ${i.voluntarioNome} trabalhou nesta campanha?'),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ex: 4', suffixText: 'horas', prefixIcon: Icon(Icons.timer_outlined)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              final h = int.tryParse(ctrl.text.trim());
              if (h == null || h < 0) {
                mostrarSnack(ctx, 'Informe um número de horas válido.', erro: true);
                return;
              }
              Navigator.pop(ctx, h);
            },
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voluntários Inscritos'),
        actions: [IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh_rounded, color: AppColors.primary))],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(TipoCampanha.icone(widget.campanha.tipo), color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.campanha.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark))),
          ]),
        ),
        Expanded(child: _corpo()),
      ]),
    );
  }

  Widget _corpo() {
    if (_erro != null && _lista == null) return ErroCarregamento(mensagem: _erro!, onTentar: _carregar);
    if (_lista == null) return const Center(child: CircularProgressIndicator());
    if (_lista!.isEmpty) {
      return const ListaVazia(icone: Icons.people_outline, titulo: 'Nenhum voluntário inscrito', subtitulo: 'Quando alguém tocar em "Quero Ajudar", aparecerá aqui.');
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _lista!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, idx) {
          final i = _lista![idx];
          final comum = emComum(i.voluntarioInteresses, _tagsDaOng);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PerfilVoluntarioPublicoScreen(voluntarioId: i.voluntarioId, nomeInicial: i.voluntarioNome)),
                  ),
                  child: Row(children: [
                    AvatarVoluntario(fotoBase64: i.voluntarioFotoBase64, nome: i.voluntarioNome ?? '?', raio: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i.voluntarioNome ?? 'Voluntário', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
                        const Text('Ver perfil', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Etiqueta(texto: StatusInscricao.rotulo(i.status), cor: StatusInscricao.cor(i.status), icone: StatusInscricao.icone(i.status)),
                  ]),
                ),
                const SizedBox(height: 10),
                if (comum.isNotEmpty) ...[SeloEmComum(quantidade: comum.length), const SizedBox(height: 8)],
                ChipsInteresses(itens: i.voluntarioInteresses, emComum: comum, vazio: 'Sem interesses informados.'),
                const SizedBox(height: 6),
                Text('Inscrito em ${formatarDataHora(i.criadoEm)}${i.status == 'CONCLUIDO' ? ' • ${i.horas}h registradas' : ''}', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                if (i.status == 'PENDENTE' || i.status == 'APROVADO') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    if (i.status == 'PENDENTE')
                      Expanded(child: _acao('Aprovar', Icons.check_rounded, AppColors.primary, () => _mudar(i, 'APROVADO'))),
                    if (i.status == 'APROVADO')
                      Expanded(child: _acao('Concluir', Icons.verified_rounded, const Color(0xFF2E7D32), () => _mudar(i, 'CONCLUIDO'))),
                    const SizedBox(width: 10),
                    Expanded(child: _acao('Recusar', Icons.close_rounded, AppColors.danger, () => _mudar(i, 'RECUSADO'), contorno: true)),
                  ]),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _acao(String texto, IconData icone, Color cor, VoidCallback onTap, {bool contorno = false}) {
    if (contorno) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: Text(texto),
        style: OutlinedButton.styleFrom(foregroundColor: cor, side: BorderSide(color: cor), minimumSize: const Size(0, 44)),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icone, size: 18),
      label: Text(texto),
      style: ElevatedButton.styleFrom(backgroundColor: cor, minimumSize: const Size(0, 44), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}
