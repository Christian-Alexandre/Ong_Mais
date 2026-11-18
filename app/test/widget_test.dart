import 'package:flutter_test/flutter_test.dart';
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
}
