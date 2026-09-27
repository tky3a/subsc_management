import 'package:sqflite/sqflite.dart';

/// 初回起動時に投入するマスタデータ。
/// ※ サービス・プランの金額は docs/db/seed_sample.sql と同じダミー値。
///   リリース前に各サービスの最新価格を確認して差し替えること。
void seedMasterData(Batch batch) {
  batch.insert('currencies', {'code': 'JPY', 'symbol': '¥', 'minor_unit_factor': 1});
  batch.insert('currencies', {'code': 'USD', 'symbol': r'$', 'minor_unit_factor': 100});

  const services = [
    (1, 'Netflix', 'both', '動画'),
    (2, 'Spotify', 'app', '音楽'),
    (3, 'Google One', 'both', 'クラウド'),
    (4, 'ChatGPT', 'both', 'AI'),
  ];
  for (final (id, name, type, category) in services) {
    batch.insert('services', {'id': id, 'name': name, 'service_type': type, 'category': category});
  }

  const plans = [
    // (service_id, name, currency, price（最小単位）, interval_months, sort_order)
    (1, '広告つきスタンダード', 'JPY', 890, 1, 1),
    (1, 'スタンダード', 'JPY', 1590, 1, 2),
    (1, 'プレミアム', 'JPY', 2290, 1, 3),
    (2, 'Individual', 'JPY', 1080, 1, 1),
    (2, 'Duo', 'JPY', 1480, 1, 2),
    (3, '100GB', 'JPY', 250, 1, 1),
    (3, '100GB', 'JPY', 2500, 12, 2),
    (4, 'Plus', 'USD', 2000, 1, 1),
  ];
  for (final (serviceId, name, currency, price, months, order) in plans) {
    batch.insert('plans', {
      'service_id': serviceId,
      'name': name,
      'currency_code': currency,
      'price': price,
      'billing_interval_months': months,
      'sort_order': order,
    });
  }
}
