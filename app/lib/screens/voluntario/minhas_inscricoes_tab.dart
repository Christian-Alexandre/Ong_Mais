import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class MinhasInscricoesTab extends StatelessWidget {
  final List<Inscricao>? inscricoes;
  final String? erro;
  final Future<void> Function() onRecarregar;
  final void Function(Inscricao) onCancelar;

  const MinhasInscricoesTab({super.key, required this.inscricoes, required this.erro, required this.onRecarregar, required this.onCancelar});

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
                if (insc.status == 'CONCLUIDO') ...[
                  const SizedBox(height: 6),
                  Text('${insc.horas}h registradas', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                ],
                if (insc.pendente) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onCancelar(insc),
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                      label: const Text('Cancelar Inscrição', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}
