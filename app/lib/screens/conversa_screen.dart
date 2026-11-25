import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../widgets/campanha_extras.dart';
import '../widgets/common.dart';
import 'ong/perfil_voluntario_publico_screen.dart';

/// Conversa entre o voluntário e a ONG sobre uma inscrição.
/// O voluntário tem sempre a opção de continuar pelo WhatsApp.
class ConversaScreen extends StatefulWidget {
  final int inscricaoId;
  final bool souOng;
  final String? tituloInicial;
  const ConversaScreen({super.key, required this.inscricaoId, required this.souOng, this.tituloInicial});

  @override
  State<ConversaScreen> createState() => _ConversaScreenState();
}

class _ConversaScreenState extends State<ConversaScreen> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  Inscricao? _insc;
  List<Mensagem>? _msgs;
  String? _erro;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    // "Tempo real" simples: busca novas mensagens a cada 4 segundos enquanto a tela está aberta.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    try {
      final (insc, msgs) = await ApiService.instance.conversa(widget.inscricaoId);
      if (!mounted) return;
      final chegouNova = _msgs == null || msgs.length != _msgs!.length;
      setState(() {
        _insc = insc;
        _msgs = msgs;
        _erro = null;
      });
      if (chegouNova) _rolarParaFim();
      if (insc.conversaEncerrada) _timer?.cancel(); // nada mais vai chegar
    } catch (e) {
      if (mounted && !silencioso) setState(() => _erro = e.toString());
    }
  }

  void _rolarParaFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final m = await ApiService.instance.enviarMensagem(widget.inscricaoId, t);
      if (!mounted) return;
      _texto.clear();
      setState(() => _msgs = [...?_msgs, m]);
      _rolarParaFim();
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Erro ao enviar: $e', erro: true);
      unawaited(_carregar(silencioso: true)); // a ONG pode ter encerrado a conversa
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _whatsApp() async {
    final i = _insc;
    if (i == null) return;
    final ok = await abrirWhatsApp(i.ongWhatsapp, 'Olá, ${i.ongNome}! Sou voluntário inscrito na campanha "${i.campanhaTitulo}" pelo ONG Mais.');
    if (!ok && mounted) mostrarSnack(context, 'Não foi possível abrir o WhatsApp da ONG.', erro: true);
  }

  @override
  Widget build(BuildContext context) {
    final i = _insc;
    final nome = i == null ? (widget.tituloInicial ?? 'Conversa') : (widget.souOng ? (i.voluntarioNome ?? 'Voluntário') : (i.ongNome ?? 'ONG'));
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F5),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          if (i != null)
            widget.souOng
                ? AvatarVoluntario(fotoBase64: i.voluntarioFotoBase64, nome: nome, raio: 18)
                : AvatarBase64(base64: i.ongLogoBase64, raio: 18, fallback: Icons.apartment_rounded, fundo: AppColors.primary.withValues(alpha: 0.15), corIcone: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (i != null)
                Text(i.campanhaTitulo ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ]),
          ),
        ]),
        actions: [
          if (i != null && !widget.souOng)
            IconButton(tooltip: 'Continuar pelo WhatsApp', onPressed: _whatsApp, icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366))),
          if (i != null && widget.souOng)
            IconButton(
              tooltip: 'Ver perfil',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PerfilVoluntarioPublicoScreen(voluntarioId: i.voluntarioId, nomeInicial: i.voluntarioNome))),
              icon: const Icon(Icons.person_outline_rounded),
            ),
        ],
      ),
      body: Column(children: [
        if (i != null) _faixaStatus(i),
        Expanded(child: _lista()),
        if (i != null && i.conversaEncerrada) _avisoEncerrada(i) else _campoTexto(),
      ]),
    );
  }

  Widget _faixaStatus(Inscricao i) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Etiqueta(texto: StatusInscricao.rotulo(i.status), cor: StatusInscricao.cor(i.status), icone: StatusInscricao.icone(i.status)),
        if (i.turno != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_rounded, size: 16, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Text(formatarTurno(i.turno!), style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
          ]),
      ]),
    );
  }

  Widget _lista() {
    if (_erro != null && _msgs == null) return ErroCarregamento(mensagem: _erro!, onTentar: _carregar);
    if (_msgs == null) return const Center(child: CircularProgressIndicator());
    if (_msgs!.isEmpty) {
      return const ListaVazia(icone: Icons.forum_outlined, titulo: 'Nenhuma mensagem ainda', subtitulo: 'Mande um oi para começar a conversa.');
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: _msgs!.length,
      itemBuilder: (context, idx) {
        final m = _msgs![idx];
        final anterior = idx > 0 ? _msgs![idx - 1] : null;
        final novoDia = anterior == null || formatarData(anterior.criadoEm) != formatarData(m.criadoEm);
        return Column(children: [
          if (novoDia)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(formatarData(m.criadoEm), style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
            ),
          _Bolha(m: m),
        ]);
      },
    );
  }

  Widget _avisoEncerrada(Inscricao i) {
    final concluida = i.status == 'CONCLUIDO';
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textGrey),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                concluida ? 'Conversa encerrada: participação concluída.' : 'Conversa encerrada: inscrição recusada.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          if (!widget.souOng) ...[
            const SizedBox(height: 8),
            BotaoWhatsApp(
              numero: i.ongWhatsapp,
              rotulo: 'Ainda precisa falar com a ONG? WhatsApp',
              mensagem: 'Olá, ${i.ongNome}! Participei da campanha "${i.campanhaTitulo}" pelo ONG Mais.',
            ),
          ],
        ]),
      ),
    );
  }

  Widget _campoTexto() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _texto,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escreva uma mensagem...',
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF1F3F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _enviar(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    );
  }
}

class _Bolha extends StatelessWidget {
  final Mensagem m;
  const _Bolha({required this.m});

  @override
  Widget build(BuildContext context) {
    final minha = m.minha;
    return Align(
      alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
        decoration: BoxDecoration(
          color: minha ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(minha ? 16 : 4),
            bottomRight: Radius.circular(minha ? 4 : 16),
          ),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(m.texto, style: TextStyle(color: minha ? Colors.white : AppColors.textDark, fontSize: 15, height: 1.3)),
          ),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(m.criadoEm == null ? '' : formatarHora(m.criadoEm!), style: TextStyle(fontSize: 11, color: minha ? Colors.white70 : AppColors.textGrey)),
            if (minha) ...[
              const SizedBox(width: 3),
              Icon(m.lida ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: m.lida ? const Color(0xFFB2F2BB) : Colors.white70),
            ],
          ]),
        ]),
      ),
    );
  }
}
