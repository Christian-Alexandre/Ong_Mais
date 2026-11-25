import 'package:flutter/material.dart';

import '../core/catalogo.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// Texto escuro e legível para os chips de interesse (o tema não define cor e ficava claro demais).
const _textoChip = Color(0xFF0B3B35);
const _labelNormal = TextStyle(color: _textoChip, fontWeight: FontWeight.w600);
const _labelSelecionado = TextStyle(color: Colors.white, fontWeight: FontWeight.bold);

/// Chips de interesses/áreas. Os que estão em [emComum] aparecem destacados com coração
/// (estilo Tinder); os demais ficam neutros.
class ChipsInteresses extends StatelessWidget {
  final List<String> itens;
  final List<String> emComum;
  final String vazio;
  const ChipsInteresses({super.key, required this.itens, this.emComum = const [], this.vazio = 'Nenhum interesse informado.'});

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return Text(vazio, style: const TextStyle(color: AppColors.textGrey));
    final comum = emComum.map((e) => e.toLowerCase()).toSet();
    // pontos em comum primeiro
    final ordenados = [...itens.where((i) => comum.contains(i.toLowerCase())), ...itens.where((i) => !comum.contains(i.toLowerCase()))];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final i in ordenados) _chip(i, comum.contains(i.toLowerCase())),
    ]);
  }

  Widget _chip(String texto, bool destaque) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: destaque ? AppColors.primary : const Color(0xFFE9F5F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: destaque ? AppColors.primary : const Color(0xFFB7DDD5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (destaque) ...[const Icon(Icons.favorite_rounded, size: 14, color: Colors.white), const SizedBox(width: 5)],
        Text(texto, style: TextStyle(fontWeight: destaque ? FontWeight.bold : FontWeight.w600, color: destaque ? Colors.white : _textoChip, fontSize: 13.5)),
      ]),
    );
  }
}

/// Faixa "N em comum" com os nomes, para o topo de um perfil.
class FaixaEmComum extends StatelessWidget {
  final List<String> emComum;
  final String com; // "com você" / "com sua ONG"
  const FaixaEmComum({super.key, required this.emComum, required this.com});

  @override
  Widget build(BuildContext context) {
    final n = emComum.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: n > 0 ? const LinearGradient(colors: [Color(0xFFE6FAF4), Color(0xFFD5F3EA)]) : null,
        color: n > 0 ? null : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: n > 0 ? AppColors.primary : AppColors.textGrey, shape: BoxShape.circle),
          child: Center(child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              n == 0 ? 'Nenhum ponto em comum $com' : (n == 1 ? '1 ponto em comum $com' : '$n pontos em comum $com'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: n > 0 ? AppColors.primaryDark : AppColors.textGrey),
            ),
            if (n > 0) Text(emComum.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
          ]),
        ),
        if (n > 0) const Icon(Icons.favorite_rounded, color: AppColors.primary),
      ]),
    );
  }
}

/// Selo pequeno "❤ N em comum" para cards.
class SeloEmComum extends StatelessWidget {
  final int quantidade;
  const SeloEmComum({super.key, required this.quantidade});

  @override
  Widget build(BuildContext context) {
    if (quantidade == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.favorite_rounded, size: 13, color: AppColors.primary),
        const SizedBox(width: 4),
        Text('$quantidade em comum', style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}

/// Escolha das áreas de atuação de uma categoria (cadastro/edição da ONG).
class SeletorAreas extends StatelessWidget {
  final String categoria;
  final List<String> selecionadas;
  final ValueChanged<List<String>> onChanged;
  const SeletorAreas({super.key, required this.categoria, required this.selecionadas, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final areas = areasPorCategoria[categoria] ?? const [];
    return Wrap(spacing: 8, runSpacing: 4, children: [
      for (final a in areas)
        FilterChip(
          label: Text(a),
          selected: selecionadas.contains(a),
          labelStyle: selecionadas.contains(a) ? _labelSelecionado : _labelNormal,
          backgroundColor: Colors.white,
          selectedColor: AppColors.primary,
          checkmarkColor: Colors.white,
          onSelected: (sel) {
            final nova = [...selecionadas];
            sel ? nova.add(a) : nova.remove(a);
            // mantém a ordem do catálogo
            onChanged(areas.where(nova.contains).toList());
          },
        ),
    ]);
  }
}

/// Folha para o voluntário escolher interesses (causas e áreas). Retorna a nova lista.
Future<List<String>?> escolherInteresses(BuildContext context, List<String> atuais) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _SeletorInteresses(atuais: atuais),
  );
}

class _SeletorInteresses extends StatefulWidget {
  final List<String> atuais;
  const _SeletorInteresses({required this.atuais});
  @override
  State<_SeletorInteresses> createState() => _SeletorInteressesState();
}

class _SeletorInteressesState extends State<_SeletorInteresses> {
  late final Set<String> _sel = {...widget.atuais};

  void _alternar(String x) => setState(() => _sel.contains(x) ? _sel.remove(x) : _sel.add(x));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Seus interesses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textDark)),
                Text('Escolha causas e áreas. Mostramos o que você tem em comum com cada ONG.', style: TextStyle(color: AppColors.textGrey)),
              ]),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), children: [
            for (final e in areasPorCategoria.entries) ...[
              const SizedBox(height: 8),
              // a categoria inteira também é um interesse ("Animais")
              FilterChip(
                avatar: Text(emojiCategoria(e.key)),
                label: Text(e.key),
                labelStyle: (_sel.contains(e.key) ? _labelSelecionado : _labelNormal).copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                selected: _sel.contains(e.key),
                showCheckmark: false,
                backgroundColor: Colors.white,
                selectedColor: AppColors.primaryDark,
                side: BorderSide(color: _sel.contains(e.key) ? AppColors.primaryDark : const Color(0xFFB7DDD5)),
                onSelected: (_) => _alternar(e.key),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final a in e.value)
                  FilterChip(
                    label: Text(a),
                    labelStyle: _sel.contains(a) ? _labelSelecionado : _labelNormal,
                    selected: _sel.contains(a),
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    onSelected: (_) => _alternar(a),
                  ),
              ]),
              const SizedBox(height: 8),
              const Divider(height: 1),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton.icon(
            onPressed: () {
              // ordem do catálogo; interesses antigos fora do catálogo são mantidos no fim
              final catalogo = [for (final e in areasPorCategoria.entries) ...[e.key, ...e.value]];
              final lista = [...catalogo.where(_sel.contains), ..._sel.where((x) => !catalogo.contains(x))];
              Navigator.pop(context, lista);
            },
            icon: const Icon(Icons.check_rounded),
            label: Text('Salvar (${_sel.length} selecionado${_sel.length == 1 ? '' : 's'})'),
          ),
        ),
      ]),
    );
  }
}
