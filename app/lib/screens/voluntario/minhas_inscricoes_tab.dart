import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/campanha_extras.dart';
import '../../widgets/common.dart';

class MinhasInscricoesTab extends StatelessWidget {
  final List<Inscricao>? inscricoes;
  final String? erro;
  final Future<void> Function() onRecarregar;
  final void Function(Inscricao) onCancelar;
  final void Function(Inscricao) onConversar;

  const MinhasInscricoesTab({
    super.key,
    required this.inscricoes,
    required this.erro,
    required this.onRecarregar,
    required this.onCancelar,
    required this.onConversar,
  });

  @override
  Widget build(BuildContext context) {
    if (erro != null && inscricoes == null) return ErroCarregamento(mensagem: erro!, onTentar: onRecarregar);
    if (inscricoes == null) return const Center(child: CircularProgressIndicator());
    if (inscricoes!.isEmpty) {
      return const ListaVazia(icone: Icons.assignment_outlined, titulo: 'Você ainda não se inscreveu', subtitulo: 'Toque em "Quero Ajudar" em uma campanha de Voluntariado.');
    }
    return RefreshIndicator(
      onRefresh: onRecarregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: inscricoes!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final insc = inscricoes![i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Etiqueta(texto: StatusInscricao.rotulo(insc.status), cor: StatusInscricao.cor(insc.status), icone: StatusInscricao.icone(insc.status)),
                  const Spacer(),
                  Text(formatarData(insc.criadoEm), style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                Text(insc.campanhaTitulo ?? 'Campanha', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.apartment_rounded, size: 16, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(insc.ongNome ?? '', style: const TextStyle(color: AppColors.textGrey, fontSize: 15))),
                ]),
                if (insc.turno != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.event_rounded, size: 16, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Text(formatarTurno(insc.turno!), style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
                  ]),
                ],
                if (insc.status == 'CONCLUIDO') ...[
                  const SizedBox(height: 6),
                  Text('${insc.horas}h registradas', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                ],
                if (insc.ultimaMensagem != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => onConversar(insc),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Icon(insc.ultimaMensagemMinha ? Icons.reply_rounded : Icons.mark_chat_unread_outlined, size: 16,
                            color: insc.naoLidas > 0 ? AppColors.primary : AppColors.textGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${insc.ultimaMensagemMinha ? 'Você: ' : ''}${insc.ultimaMensagem}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: insc.naoLidas > 0 ? AppColors.textDark : AppColors.textGrey,
                              fontWeight: insc.naoLidas > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onConversar(insc),
                      icon: Badge(
                        isLabelVisible: insc.naoLidas > 0,
                        label: Text('${insc.naoLidas}'),
                        child: const Icon(Icons.forum_outlined, size: 20),
                      ),
                      label: const Text('Conversar'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'WhatsApp da ONG',
                    onPressed: () async {
                      final ok = await abrirWhatsApp(insc.ongWhatsapp, 'Olá, ${insc.ongNome}! Sou voluntário inscrito na campanha "${insc.campanhaTitulo}" pelo ONG Mais.');
                      if (!ok && context.mounted) mostrarSnack(context, 'Não foi possível abrir o WhatsApp da ONG.', erro: true);
                    },
                    icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                  ),
                  if (insc.pendente)
                    IconButton(
                      tooltip: 'Cancelar inscrição',
                      onPressed: () => onCancelar(insc),
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                    ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}
