import 'package:flutter_test/flutter_test.dart';
import 'package:subsc_management/util/format.dart';

void main() {
  test('円表示', () {
    expect(yen(5978.33), '¥5,978');
    expect(yen(71740), '¥71,740');
    expect(yen(0), '¥0');
    expect(signedYen(100), '+¥100');
    expect(signedYen(-1200), '−¥1,200');
  });

  test('通貨の最小単位からの表示と入力の変換', () {
    expect(money(2000, r'$', 100), r'$20.00');
    expect(money(123456, r'$', 100), r'$1,234.56');
    expect(money(1590, '¥', 1), '¥1,590');
    expect(moneyInput(1999, 100), '19.99');
    expect(parseMoney('19.99', 100), 1999);
    expect(parseMoney('¥1,180', 1), 1180);
    expect(parseMoney('', 1), isNull);
    expect(parseMoney('abc', 1), isNull);
  });

  test('契約形態と年月', () {
    expect(contractLabel(1), '月額');
    expect(contractLabel(12), '年額');
    expect(contractLabel(3), '3か月ごと');
    expect(yearMonthLabel('2026-09'), '2026年9月');
    expect(yearMonthShort('2026-09'), '2026/09');
  });
}
