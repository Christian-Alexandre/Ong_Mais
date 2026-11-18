import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../ong/perfil_publico_screen.dart';
import 'minhas_inscricoes_tab.dart';

/// Feed do voluntário: abas Explorar Ações (n) / Minhas Inscrições (n).
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _busca = TextEditingController();
  Timer? _debounce;

  List<Campanha>? _campanhas;
  List<Inscricao>? _inscricoes;
  String? _erro;
  String _filtroTipo = ''; // '' = Todos
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _busca.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await Future.wait([
        ApiService.instance.feed(tipo: _filtroTipo, q: _busca.text),
        ApiService.instance.minhasInscricoes(),
      ]);
      if (!mounted) return;
      setState(() {
        _campanhas = r[0] as List<Campanha>;
        _inscricoes = r[1] as List<Inscricao>;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _aoDigitar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _carregar);
  }

  Future<void> _curtir(Campanha c) async {
    final antes = (c.curtiu, c.curtidas);
    setState(() {
      c.curtiu = !c.curtiu;
      c.curtidas += c.curtiu ? 1 : -1;
    });
    try {
      final (curtiu, total) = await ApiService.instance.curtir(c.id);
      if (mounted) {
        setState(() {
          c.curtiu = curtiu;
          c.curtidas = total;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          c.curtiu = antes.$1;
          c.curtidas = antes.$2;
        });
        mostrarSnack(context, 'Erro ao curtir: $e', erro: true);
      }
    }
  }

  /// Quero Ajudar: Voluntariado → inscrição Pendente + WhatsApp; Doação/Financeiro → só WhatsApp.
  Future<void> _queroAjudar(Campanha c) async {
    final msg = 'Olá, ${c.ongNome}! Vi a campanha "${c.titulo}" no ONG Mais e quero ajudar.';
    if (c.tipo == TipoCampanha.voluntariado) {
      if (c.minhaInscricao != null) {
        mostrarSnack(context, 'Você já está inscrito nesta campanha (${StatusInscricao.rotulo(c.minhaInscricao!.status)}).');
        await abrirWhatsApp(c.ongWhatsapp, msg);
        return;
      }
      try {
        final insc = await ApiService.instance.inscrever(c.id);
        if (!mounted) return;
        setState(() => c.minhaInscricao = insc);
        mostrarSnack(context, 'Inscrição confirmada na campanha "${c.titulo}"!');
        unawaited(_carregar());
      } catch (e) {
        if (mounted) mostrarSnack(context, 'Erro ao se inscrever: $e', erro: true);
        return;
      }
    }
    final ok = await abrirWhatsApp(c.ongWhatsapp, msg);
    if (!ok && mounted) mostrarSnack(context, 'Não foi possível abrir o WhatsApp da ONG.', erro: true);
  }

  Future<void> _cancelarInscricao(Inscricao i) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar inscrição?'),
        content: Text('Sua inscrição em "${i.campanhaTitulo}" será removida.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar inscrição', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirma != true) return;
    try {
      await ApiService.instance.cancelarInscricao(i.id);
      if (mounted) mostrarSnack(context, 'Inscrição cancelada.');
      await _carregar();
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao cancelar: $e', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nExplorar = _campanhas?.length ?? 0;
    final nInsc = _inscricoes?.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const MarcaOngMais(),
        actions: [IconButton(onPressed: _carregando ? null : _carregar, icon: const Icon(Icons.refresh_rounded), tooltip: 'Atualizar')],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [Tab(text: 'Explorar Ações ($nExplorar)'), Tab(text: 'Minhas Inscrições ($nInsc)')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _explorar(),
          MinhasInscricoesTab(
            inscricoes: _inscricoes,
            erro: _erro,
            onRecarregar: _carregar,
            onCancelar: _cancelarInscricao,
          ),
        ],
      ),
    );
  }

  Widget _explorar() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _busca,
          onChanged: _aoDigitar,
          decoration: InputDecoration(
            hintText: 'Pesquisar campanhas...',
            prefixIcon: const Icon(Icons.search, color: AppColors.textGrey),
            fillColor: const Color(0xFFF1F3F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            suffixIcon: _busca.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.close), onPressed: () {
                    _busca.clear();
                    _carregar();
                  }),
          ),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _chip('Todos', ''),
            _chip('Voluntariado', TipoCampanha.voluntariado),
            _chip('Doações', TipoCampanha.doacao),
            _chip('Financeiro', TipoCampanha.financeiro),
          ],
        ),
      ),
      Expanded(child: _lista()),
    ]);
  }

  Widget _chip(String rotulo, String tipo) {
    final ativo = _filtroTipo == tipo;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(rotulo),
        selected: ativo,
        showCheckmark: false,
        labelStyle: TextStyle(color: ativo ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
        onSelected: (_) {
          setState(() => _filtroTipo = tipo);
          _carregar();
        },
      ),
    );
  }

  Widget _lista() {
    if (_erro != null && _campanhas == null) return ErroCarregamento(mensagem: _erro!, onTentar: _carregar);
    if (_campanhas == null) return const Center(child: CircularProgressIndicator());
    if (_campanhas!.isEmpty) {
      return const ListaVazia(icone: Icons.campaign_outlined, titulo: 'Nenhuma campanha encontrada', subtitulo: 'Tente outro filtro ou volte mais tarde.');
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: _campanhas!.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE9ECEF)),
        itemBuilder: (_, i) => _CardCampanha(
          campanha: _campanhas![i],
          onCurtir: () => _curtir(_campanhas![i]),
          onAjudar: () => _queroAjudar(_campanhas![i]),
          onVerOng: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PerfilPublicoScreen(ongId: _campanhas![i].ongId))),
        ),
      ),
    );
  }
}

class _CardCampanha extends StatelessWidget {
  final Campanha campanha;
  final VoidCallback onCurtir;
  final VoidCallback onAjudar;
  final VoidCallback onVerOng;
  const _CardCampanha({required this.campanha, required this.onCurtir, required this.onAjudar, required this.onVerOng});

  @override
  Widget build(BuildContext context) {
    final c = campanha;
    final inscrito = c.minhaInscricao != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabeçalho: avatar + nome ONG + tipo • tempo relativo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: onVerOng,
            child: Row(children: [
              AvatarBase64(base64: c.ongLogoBase64, raio: 22, fallback: Icons.apartment_rounded, fundo: AppColors.primary.withValues(alpha: 0.15), corIcone: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.ongNome ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
                  Text('${TipoCampanha.rotulo(c.tipo)} • ${tempoRelativo(c.criadoEm)}', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                ]),
              ),
              Icon(TipoCampanha.icone(c.tipo), color: TipoCampanha.cor(c.tipo)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        if (c.fotoBase64 != null && c.fotoBase64!.isNotEmpty) FotoBase64(base64: c.fotoBase64, altura: 260),
        // Ações
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
          child: Row(children: [
            IconButton(
              onPressed: onCurtir,
              icon: Icon(c.curtiu ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: c.curtiu ? AppColors.danger : AppColors.textDark, size: 28),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.mode_comment_outlined, size: 26)), // visual apenas
            IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined, size: 26)), // visual apenas
            const Spacer(),
            ElevatedButton.icon(
              onPressed: onAjudar,
              icon: Icon(inscrito ? Icons.check_rounded : Icons.handshake_outlined, size: 20),
              label: Text(inscrito ? 'Inscrito' : 'Quero Ajudar'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: inscrito ? AppColors.primaryDark : AppColors.primary,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              c.curtidas == 1 ? '1 pessoa apoia esta causa' : '${c.curtidas} pessoas apoiam esta causa',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.textDark, fontSize: 15, height: 1.35),
                children: [
                  TextSpan(text: '${c.titulo}\n', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (c.descricao != null) TextSpan(text: c.descricao, style: const TextStyle(color: Color(0xFF3B4252))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(formatarDataHora(c.criadoEm), style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
