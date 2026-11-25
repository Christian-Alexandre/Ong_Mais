import 'package:flutter_test/flutter_test.dart';
import 'package:ong_mais/core/catalogo.dart';
import 'package:ong_mais/core/utils.dart';

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
}
