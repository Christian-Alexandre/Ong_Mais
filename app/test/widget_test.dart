import 'package:flutter_test/flutter_test.dart';
import 'package:ong_mais/core/catalogo.dart';
import 'package:ong_mais/core/certificado.dart';
import 'package:ong_mais/core/utils.dart';
import 'package:ong_mais/models/models.dart';
import 'package:ong_mais/widgets/campanha_extras.dart';

void main() {
  test('CNPJ do seed é válido e um inválido é rejeitado', () {
    expect(cnpjValido('12.345.678/0001-95'), isTrue);
    expect(cnpjValido('12.345.678/0001-90'), isFalse);
    expect(cnpjValido('11.111.111/1111-11'), isFalse);
  });

  test('Data UTC do servidor nunca vira tempo relativo negativo', () {
    final futuro = DateTime.now().toUtc().add(const Duration(hours: 3)).toIso8601String();
    expect(tempoRelativo(parseUtc(futuro)), 'agora');
  });

  test('Telefone exige DDD válido e formato de celular/fixo', () {
    expect(telefoneErro('(11) 98765-4321'), isNull);
    expect(telefoneErro('(21) 3456-7890'), isNull);
    expect(telefoneErro('+55 (11) 98765-4321'), isNull);
    expect(telefoneErro('(20) 98765-4321'), contains('DDD 20'));
    expect(telefoneErro('(11) 88765-4321'), contains('começar com 9'));
    expect(telefoneErro('98765-4321'), isNotNull);
    expect(telefoneErro('(11) 99999-9999'), 'Número inválido');
  });

  test('Máscara de telefone', () {
    String mascara(String t) => TelefoneFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: t)).text;
    expect(mascara('11987654321'), '(11) 98765-4321');
    expect(mascara('1134567890'), '(11) 3456-7890');
    expect(mascara('119'), '(11) 9');
  });

  test('Pontos em comum entre voluntário e ONG', () {
    final ong = tagsDaOng('Animais', ['Adoção', 'Resgate de animais']);
    expect(emComum(['animais', 'Adoção', 'Reciclagem'], ong), ['animais', 'Adoção']);
    expect(emComum([], ong), isEmpty);
    // todas as áreas do catálogo pertencem a uma única categoria
    final todas = areasPorCategoria.values.expand((l) => l).toList();
    expect(todas.toSet().length, todas.length);
  });

  test('Turnos, vagas e itens de doação vindos da API', () {
    final c = Campanha.fromJson({
      'id': 1,
      'ong_id': 2,
      'tipo': 'VOLUNTARIADO',
      'titulo': 'Mutirão',
      'turnos': [
        {'id': 5, 'inicio': '2030-01-05T12:00:00Z', 'fim': '2030-01-05T15:00:00Z', 'vagas': 2, 'ocupadas': 2, 'horas': 3, 'encerrado': false},
        {'id': 6, 'inicio': '2020-01-05T12:00:00Z', 'fim': '2020-01-05T15:00:00Z', 'vagas': 2, 'ocupadas': 0, 'horas': 3, 'encerrado': true},
      ],
      'itens': [
        {'id': 1, 'nome': 'Ração', 'unidade': 'kg', 'meta': 100, 'arrecadado': 40},
      ],
    });
    expect(c.turnosAbertos.length, 1);
    expect(c.turnosAbertos.first.lotado, isTrue);
    expect(rotuloVagas(c.turnosAbertos.first), 'Lotado');
    expect(c.itens.first.progresso, closeTo(0.4, 1e-9));
    expect(formatarQuantidade(2.5), '2,5');
    expect(c.turnos.first.toJson()['inicio'], '2030-01-05T12:00:00.000Z');
  });

  test('Certificado em PDF (com acentos) é gerado', () async {
    final v = Voluntario.fromJson({'id': 2, 'nome_completo': 'João Ação', 'horas_trabalhadas': 7, 'acoes_apoiadas': 2});
    final insc = [
      Inscricao.fromJson({'id': 1, 'campanha_id': 1, 'voluntario_id': 2, 'status': 'CONCLUIDO', 'horas': 3, 'campanha_titulo': 'Mutirão de Limpeza', 'ong_nome': 'Instituto Patinhas Carentes'}),
      Inscricao.fromJson({'id': 2, 'campanha_id': 2, 'voluntario_id': 2, 'status': 'CONCLUIDO', 'horas': 4, 'campanha_titulo': 'Feira de Adoção', 'ong_nome': 'Instituto Patinhas Carentes'}),
    ];
    final bytes = await gerarCertificadoPdf(v, insc);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(somenteLetras('João Ação'), 'joao');
  });
}
