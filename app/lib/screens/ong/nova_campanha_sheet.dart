import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/campanha_extras.dart';
import '../../widgets/common.dart';

/// Abre o bottom sheet de Nova Campanha (ou edição). Retorna true se salvou.
Future<bool?> mostrarNovaCampanha(BuildContext context, {Campanha? editar}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _NovaCampanhaSheet(editar: editar),
  );
}

class _NovaCampanhaSheet extends StatefulWidget {
  final Campanha? editar;
  const _NovaCampanhaSheet({this.editar});

  @override
  State<_NovaCampanhaSheet> createState() => _NovaCampanhaSheetState();
}

class _NovaCampanhaSheetState extends State<_NovaCampanhaSheet> {
  late final _titulo = TextEditingController(text: widget.editar?.titulo ?? '');
  late final _descricao = TextEditingController(text: widget.editar?.descricao ?? '');
  late String _tipo = widget.editar?.tipo ?? TipoCampanha.voluntariado;
  late String? _foto = widget.editar?.fotoBase64;
  late final List<Turno> _turnos = [...?widget.editar?.turnos];
  late final List<ItemDoacao> _itens = [...?widget.editar?.itens];
  bool _salvando = false;

  bool get _edicao => widget.editar != null;

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto(ImageSource src) async {
    final b64 = await escolherImagemBase64(context, origem: src);
    if (b64 != null) setState(() => _foto = b64);
  }

  Future<void> _publicar() async {
    if (_titulo.text.trim().length < 2) {
      mostrarSnack(context, 'Informe o título da campanha.', erro: true);
      return;
    }
    // Turnos só no voluntariado; itens só na doação.
    final turnos = _tipo == TipoCampanha.voluntariado ? _turnos : <Turno>[];
    final itens = _tipo == TipoCampanha.doacao ? _itens : <ItemDoacao>[];
    setState(() => _salvando = true);
    try {
      if (_edicao) {
        await ApiService.instance.editarCampanha(widget.editar!.id, {
          'tipo': _tipo,
          'titulo': _titulo.text.trim(),
          'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
          'foto_base64': _foto,
          'turnos': turnos.map((t) => t.toJson()).toList(),
          'itens': itens.map((i) => i.toJson()).toList(),
        });
      } else {
        await ApiService.instance.criarCampanha(
          tipo: _tipo,
          titulo: _titulo.text,
          descricao: _descricao.text.trim().isEmpty ? null : _descricao.text,
          fotoBase64: _foto,
          turnos: turnos,
          itens: itens,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao salvar campanha: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoBytes = decodeBase64(_foto);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFD9DEE3), borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 14),
            Row(children: [
              Text(_edicao ? 'Editar Campanha' : 'Nova Campanha', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 10),
            const Text('Tipo de Ação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Row(children: [
              _tipoBtn(TipoCampanha.voluntariado),
              const SizedBox(width: 10),
              _tipoBtn(TipoCampanha.doacao),
              const SizedBox(width: 10),
              _tipoBtn(TipoCampanha.financeiro),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _titulo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Título da Campanha'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descricao,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Descrição e Instruções'),
            ),
            if (_tipo == TipoCampanha.voluntariado) _secaoTurnos(),
            if (_tipo == TipoCampanha.doacao) _secaoItens(),
            const SizedBox(height: 20),
            const Text('Foto da Campanha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            if (fotoBytes != null) ...[
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(fotoBytes, height: 180, width: double.infinity, fit: BoxFit.cover)),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _foto = null)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
            ],
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _escolherFoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: () => _escolherFoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Câmera'))),
            ]),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _salvando ? null : _publicar,
              child: _salvando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_edicao ? 'Salvar Alterações' : 'Publicar Campanha'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Turnos (voluntariado) ----------
  Widget _secaoTurnos() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      Row(children: [
        const Expanded(child: Text('Turnos e vagas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        TextButton.icon(onPressed: () => _editarTurno(), icon: const Icon(Icons.add_rounded), label: const Text('Adicionar')),
      ]),
      if (_turnos.isEmpty)
        const Text('Opcional: defina datas, horários e quantas pessoas cabem em cada turno. As horas do voluntário saem da duração.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
      for (final (idx, t) in _turnos.indexed)
        Card(
          margin: const EdgeInsets.only(top: 6),
          child: ListTile(
            leading: const Icon(Icons.event_rounded, color: AppColors.primary),
            title: Text(formatarTurno(t), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${t.vagas} vagas${t.ocupadas > 0 ? ' • ${t.ocupadas} inscritos' : ''}'),
            onTap: () => _editarTurno(idx),
            trailing: IconButton(
              tooltip: 'Remover',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () => setState(() => _turnos.removeAt(idx)),
            ),
          ),
        ),
    ]);
  }

  Future<void> _editarTurno([int? idx]) async {
    final atual = idx == null ? null : _turnos[idx];
    final amanha = DateTime.now().add(const Duration(days: 1));
    var dia = atual?.inicio ?? DateTime(amanha.year, amanha.month, amanha.day);
    var ini = atual == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay.fromDateTime(atual.inicio);
    var fim = atual == null ? const TimeOfDay(hour: 12, minute: 0) : TimeOfDay.fromDateTime(atual.fim);
    final vagas = TextEditingController(text: '${atual?.vagas ?? 10}');
    String two(int n) => n.toString().padLeft(2, '0');
    final novo = await showDialog<Turno>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(idx == null ? 'Novo turno' : 'Editar turno'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_rounded),
              title: Text(formatarData(dia)),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: dia, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setD(() => dia = d);
              },
            ),
            Row(children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text('${two(ini.hour)}:${two(ini.minute)}'),
                  subtitle: const Text('Início'),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: ini);
                    if (t != null) setD(() => ini = t);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${two(fim.hour)}:${two(fim.minute)}'),
                  subtitle: const Text('Fim'),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: fim);
                    if (t != null) setD(() => fim = t);
                  },
                ),
              ),
            ]),
            TextField(
              controller: vagas,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Vagas', prefixIcon: Icon(Icons.groups_outlined)),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final i = DateTime(dia.year, dia.month, dia.day, ini.hour, ini.minute);
                var f = DateTime(dia.year, dia.month, dia.day, fim.hour, fim.minute);
                if (!f.isAfter(i)) f = f.add(const Duration(days: 1)); // turno que vira a noite
                final v = int.tryParse(vagas.text.trim());
                if (v == null || v < 1 || v > 500) {
                  mostrarSnack(ctx, 'Informe de 1 a 500 vagas.', erro: true);
                  return;
                }
                if (f.difference(i).inHours > 24) {
                  mostrarSnack(ctx, 'O turno pode ter no máximo 24 horas.', erro: true);
                  return;
                }
                Navigator.pop(ctx, Turno(id: atual?.id, inicio: i, fim: f, vagas: v, ocupadas: atual?.ocupadas ?? 0));
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    vagas.dispose();
    if (novo == null) return;
    setState(() {
      if (idx == null) {
        _turnos.add(novo);
      } else {
        _turnos[idx] = novo;
      }
      _turnos.sort((a, b) => a.inicio.compareTo(b.inicio));
    });
  }

  // ---------- Itens (doação) ----------
  Widget _secaoItens() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      Row(children: [
        const Expanded(child: Text('Itens e metas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        TextButton.icon(onPressed: () => _editarItem(), icon: const Icon(Icons.add_rounded), label: const Text('Adicionar')),
      ]),
      if (_itens.isEmpty)
        const Text('Opcional: liste o que precisa (ex.: Ração, 100 kg) e mostre o progresso da arrecadação.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
      for (final (idx, it) in _itens.indexed)
        Card(
          margin: const EdgeInsets.only(top: 6),
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFFE8590C)),
            title: Text(it.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Meta: ${formatarQuantidade(it.meta)} ${it.unidade} • já tem ${formatarQuantidade(it.arrecadado)}'),
            onTap: () => _editarItem(idx),
            trailing: IconButton(
              tooltip: 'Remover',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: () => setState(() => _itens.removeAt(idx)),
            ),
          ),
        ),
    ]);
  }

  Future<void> _editarItem([int? idx]) async {
    final atual = idx == null ? null : _itens[idx];
    final nome = TextEditingController(text: atual?.nome ?? '');
    final unidade = TextEditingController(text: atual?.unidade ?? 'un');
    final meta = TextEditingController(text: atual == null ? '' : formatarQuantidade(atual.meta));
    final tem = TextEditingController(text: atual == null ? '0' : formatarQuantidade(atual.arrecadado));
    double? num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());
    final novo = await showDialog<ItemDoacao>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(idx == null ? 'Novo item' : 'Editar item'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nome, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Item (ex.: Ração)')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: meta, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Meta'))),
              const SizedBox(width: 10),
              SizedBox(width: 90, child: TextField(controller: unidade, decoration: const InputDecoration(labelText: 'Unidade'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: tem, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Já arrecadado')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final m = num(meta);
              if (nome.text.trim().isEmpty || m == null || m <= 0) {
                mostrarSnack(ctx, 'Informe o nome do item e uma meta maior que zero.', erro: true);
                return;
              }
              Navigator.pop(
                ctx,
                ItemDoacao(
                  id: atual?.id,
                  nome: nome.text.trim(),
                  unidade: unidade.text.trim().isEmpty ? 'un' : unidade.text.trim(),
                  meta: m,
                  arrecadado: (num(tem) ?? 0).clamp(0, 1e6).toDouble(),
                ),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    for (final c in [nome, unidade, meta, tem]) {
      c.dispose();
    }
    if (novo == null) return;
    setState(() => idx == null ? _itens.add(novo) : _itens[idx] = novo);
  }

  Widget _tipoBtn(String tipo) {
    final ativo = _tipo == tipo;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tipo = tipo),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: ativo ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ativo ? AppColors.primary : Colors.transparent, width: 2),
          ),
          child: Column(children: [
            Icon(TipoCampanha.icone(tipo), color: ativo ? AppColors.primary : AppColors.textDark),
            const SizedBox(height: 6),
            Text(TipoCampanha.rotulo(tipo), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ativo ? AppColors.primary : AppColors.textDark)),
          ]),
        ),
      ),
    );
  }
}
