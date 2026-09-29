import 'package:sqflite/sqflite.dart';

import '../util/format.dart';

/// 初回起動時に投入するマスタデータ（DB バージョン 1）。
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

/// ドル建てを最初から円で表示・合計できるようにするための初期レート（1 ドルあたりの円）。
const initialUsdRate = 150.0;

/// DB バージョン 8: USD のレートが 1 件もなければ初期レートを登録する。
/// ユーザーが登録済みのレートは上書きしない。以降は為替レート画面で手入力して更新する。
Future<void> seedMasterDataV8(DatabaseExecutor db) async {
  final count = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM exchange_rates WHERE currency_code = 'USD'"));
  if (count != 0) return;
  await db.insert('exchange_rates', {
    'currency_code': 'USD',
    'rate_to_jpy': initialUsdRate,
    'rate_date': isoDate(DateTime.now()),
  });
}

typedef _PresetPlan = (String name, String currency, int price, int intervalMonths);
typedef _PresetService = (String name, String serviceType, String category, List<_PresetPlan> plans);

/// DB バージョン 2 で追加したマスタデータ。新規インストール時と、バージョン 1 からの更新時に投入する。
/// ※ 金額は追加時点の公式価格（税込）。リリース前に最新価格を確認すること。
Future<void> seedMasterDataV2(DatabaseExecutor db) => _addPresetServices(db, const [
      ('Hulu', 'both', '動画', [('月額プラン', 'JPY', 1026, 1)]),
      ('Google AI Pro', 'both', 'AI', [('月額プラン', 'JPY', 2900, 1)]),
    ]);

/// DB バージョン 3 で追加したマスタデータ。新規インストール時と、バージョン 2 以前からの更新時に投入する。
/// 金額はドル建て（セント単位）。
Future<void> seedMasterDataV3(DatabaseExecutor db) => _addPresetServices(db, const [
      ('Claude Code', 'both', 'AI', [('月額プラン', 'USD', 2200, 1)]),
      ('Cloudflare', 'web', 'インフラ', [('年額プラン', 'USD', 1200, 12)]),
    ]);

/// DB バージョン 4 で追加したマスタデータ。同じ Premium の月額払いと年額払いを別プランとして持つ。
Future<void> seedMasterDataV4(DatabaseExecutor db) => _addPresetServices(db, const [
      ('Moises', 'app', '音楽', [('Premium', 'JPY', 1180, 1), ('Premium', 'JPY', 11800, 12)]),
    ]);

/// DB バージョン 5 で追加したマスタデータ。
Future<void> seedMasterDataV5(DatabaseExecutor db) => _addPresetServices(db, const [
      ('Amazon Prime', 'both', 'ショッピング', [('月額プラン', 'JPY', 600, 1), ('年額プラン', 'JPY', 5900, 12)]),
    ]);

/// DB バージョン 6 で追加したマスタデータ。
Future<void> seedMasterDataV6(DatabaseExecutor db) => _addPresetServices(db, const [
      ('スマホ・ネット通信量', 'both', '通信', [('月額プラン', 'JPY', 12000, 1)]),
    ]);

/// DB バージョン 7 で追加したマスタデータ。
Future<void> seedMasterDataV7(DatabaseExecutor db) => _addPresetServices(db, const [
      ('U-FRET', 'app', '音楽', [('月額プラン', 'JPY', 650, 1)]),
    ]);

/// プリセットのサービスとプランを追加する。
/// 同名のサービスをユーザーが追加済みの場合は、そのサービスには何もしない。
Future<void> _addPresetServices(DatabaseExecutor db, List<_PresetService> services) async {
  for (final (name, type, category, plans) in services) {
    final serviceId = await db.insert(
      'services',
      {'name': name, 'service_type': type, 'category': category},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (serviceId == 0) continue;
    for (final (i, (planName, currency, price, months)) in plans.indexed) {
      await db.insert('plans', {
        'service_id': serviceId,
        'name': planName,
        'currency_code': currency,
        'price': price,
        'billing_interval_months': months,
        'sort_order': i + 1,
      });
    }
  }
}
