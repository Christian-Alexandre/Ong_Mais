import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';

const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

String _dois(int n) => n.toString().padLeft(2, '0');

String formatarHora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

/// "Sáb, 29/11 · 09:00–12:00"
String formatarTurno(Turno t) =>
    '${_diasSemana[t.inicio.weekday - 1]}, ${_dois(t.inicio.day)}/${_dois(t.inicio.month)} · ${formatarHora(t.inicio)}–${formatarHora(t.fim)}';

/// 40 → "40", 2.5 → "2,5"
String formatarQuantidade(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');

String rotuloVagas(Turno t) {
  if (t.encerrado) return 'Encerrado';
  if (t.lotado) return 'Lotado';
  return t.vagasLivres == 1 ? '1 vaga' : '${t.vagasLivres} vagas';
}

/// Linha compacta com o próximo turno da campanha (cards do feed e do painel).
class ResumoTurnos extends StatelessWidget {
  final Campanha campanha;
  const ResumoTurnos({super.key, required this.campanha});

  @override
  Widget build(BuildContext context) {
    final abertos = campanha.turnosAbertos;
    if (abertos.isEmpty) return const SizedBox.shrink();
    final prox = abertos.first;
    final livres = abertos.fold<int>(0, (s, t) => s + t.vagasLivres);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: abertos.length == 1 ? 'Turno: ' : 'Próximo turno: ', style: const TextStyle(color: AppColors.textGrey)),
            TextSpan(text: formatarTurno(prox), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
            if (abertos.length > 1) TextSpan(text: '  (+${abertos.length - 1})', style: const TextStyle(color: AppColors.textGrey)),
          ])),
        ),
        const SizedBox(width: 6),
        Text(livres == 0 ? 'Lotado' : (livres == 1 ? '1 vaga' : '$livres vagas'),
            style: TextStyle(fontWeight: FontWeight.bold, color: livres == 0 ? AppColors.danger : AppColors.primary)),
      ]),
    );
  }
}

/// Barras de progresso dos itens de uma campanha de doação.
class ProgressoDoacao extends StatelessWidget {
  final List<ItemDoacao> itens;
  final void Function(ItemDoacao)? onEditar; // ONG: toque no item para atualizar
  const ProgressoDoacao({super.key, required this.itens, this.onEditar});

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E6), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFFE8590C)),
          const SizedBox(width: 6),
          const Expanded(child: Text('O que estamos arrecadando', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark))),
          if (onEditar != null) const Text('toque para atualizar', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ]),
        const SizedBox(height: 6),
        for (final i in itens)
          InkWell(
            onTap: onEditar == null ? null : () => onEditar!(i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(i.nome, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark))),
                  Text('${formatarQuantidade(i.arrecadado)} / ${formatarQuantidade(i.meta)} ${i.unidade}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                  if (onEditar != null) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.edit_outlined, size: 16, color: AppColors.textGrey)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: i.progresso,
                    minHeight: 8,
                    backgroundColor: Colors.white,
                    color: i.progresso >= 1 ? const Color(0xFF2E7D32) : const Color(0xFFF76707),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Diálogo da ONG para informar quanto já chegou de um item.
Future<double?> pedirArrecadado(BuildContext context, ItemDoacao item) {
  final ctrl = TextEditingController(text: formatarQuantidade(item.arrecadado));
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Arrecadação: ${item.nome}'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Quantidade recebida', suffixText: '/ ${formatarQuantidade(item.meta)} ${item.unidade}'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final v = double.tryParse(ctrl.text.replaceAll(',', '.').trim());
            if (v == null || v < 0) return;
            Navigator.pop(ctx, v);
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// "Como ajudar" para Doação/Financeiro: itens, chave PIX (copiar) e WhatsApp.
Future<void> abrirComoAjudar(BuildContext context, Campanha c) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Como ajudar', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(c.titulo, style: const TextStyle(color: AppColors.textGrey)),
          if (c.itens.isNotEmpty) ProgressoDoacao(itens: c.itens),
          if (c.tipo == TipoCampanha.doacao) ...[
            const SizedBox(height: 12),
            const Text('Leve as doações até a sede da ONG ou combine a entrega/retirada pelo WhatsApp.',
                style: TextStyle(color: AppColors.textDark, height: 1.35)),
          ],
          if (c.ongChavePix != null && c.ongChavePix!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF32BCAD)), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.pix_rounded, color: Color(0xFF32BCAD), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Chave PIX da ONG', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    SelectableText(c.ongChavePix!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                ),
                IconButton.filledTonal(
                  tooltip: 'Copiar',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: c.ongChavePix!));
                    if (ctx.mounted) mostrarSnack(ctx, 'Chave PIX copiada! Cole no app do seu banco.');
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ]),
            ),
          ] else if (c.tipo == TipoCampanha.financeiro) ...[
            const SizedBox(height: 12),
            const Text('A ONG ainda não cadastrou uma chave PIX. Fale com ela pelo WhatsApp para saber como contribuir.',
                style: TextStyle(color: AppColors.textGrey)),
          ],
          const SizedBox(height: 18),
          BotaoWhatsApp(
            numero: c.ongWhatsapp,
            mensagem: 'Olá, ${c.ongNome}! Vi a campanha "${c.titulo}" no ONG Mais e quero ajudar.',
          ),
        ]),
      ),
    ),
  );
}

/// Botão verde padrão "Falar pelo WhatsApp".
class BotaoWhatsApp extends StatelessWidget {
  final String? numero;
  final String mensagem;
  final String rotulo;
  const BotaoWhatsApp({super.key, required this.numero, required this.mensagem, this.rotulo = 'Falar pelo WhatsApp'});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final ok = await abrirWhatsApp(numero, mensagem);
        if (!ok && context.mounted) mostrarSnack(context, 'Não foi possível abrir o WhatsApp da ONG.', erro: true);
      },
      icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
      label: Text(rotulo, style: const TextStyle(color: Color(0xFF128C7E), fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: Color(0xFF25D366))),
    );
  }
}

/// Resultado da folha "Quero ajudar" do voluntariado.
sealed class EscolhaAjuda {}

class InscreverNoTurno extends EscolhaAjuda {
  final Turno? turno;
  InscreverNoTurno(this.turno);
}

class PreferirWhatsApp extends EscolhaAjuda {}

/// Folha do voluntariado: escolher turno e se inscrever (conversa no app) ou ir pro WhatsApp.
Future<EscolhaAjuda?> escolherComoAjudar(BuildContext context, Campanha c) {
  final abertos = c.turnosAbertos;
  Turno? escolhido = abertos.where((t) => !t.lotado).firstOrNull;
  return showModalBottomSheet<EscolhaAjuda>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final todosLotados = abertos.isNotEmpty && escolhido == null;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Quero ajudar', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${c.titulo} • ${c.ongNome ?? ''}', style: const TextStyle(color: AppColors.textGrey)),
              if (abertos.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Escolha um turno', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 6),
                for (final t in abertos)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: escolhido == t ? AppColors.primary.withValues(alpha: 0.08) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: escolhido == t ? AppColors.primary : const Color(0xFFDEE2E6)),
                    ),
                    child: ListTile(
                      enabled: !t.lotado,
                      onTap: () => setS(() => escolhido = t),
                      leading: Icon(escolhido == t ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: t.lotado ? AppColors.textGrey : AppColors.primary),
                      title: Text(formatarTurno(t), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${t.horas}h de voluntariado'),
                      trailing: Text(rotuloVagas(t),
                          style: TextStyle(fontWeight: FontWeight.bold, color: t.lotado ? AppColors.danger : AppColors.primary)),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              const Text('Ao se inscrever, abre uma conversa com a ONG aqui no app para combinar os detalhes.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: todosLotados ? null : () => Navigator.pop(ctx, InscreverNoTurno(escolhido)),
                icon: const Icon(Icons.forum_outlined),
                label: Text(todosLotados ? 'Todos os turnos estão lotados' : 'Inscrever e conversar com a ONG'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, PreferirWhatsApp()),
                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                label: const Text('Prefiro falar pelo WhatsApp', style: TextStyle(color: Color(0xFF128C7E), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: Color(0xFF25D366))),
              ),
            ]),
          ),
        );
      },
    ),
  );
}
