import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:subsc_management/data/app_database.dart';
import 'package:subsc_management/data/repository.dart';
import 'package:subsc_management/data/seed.dart';

Future<SubscriptionRepository> openRepo() async {
  final db = await AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    schemaSql: File('docs/db/schema.sql').readAsStringSync(),
  );
  addTearDown(db.close);
  return SubscriptionRepository(db);
}

void main() {
  sqfliteFfiInit();

  test('schema.sql をテーブル・トリガー・ビュー単位に分割できる', () {
    final statements = splitSqlStatements(File('docs/db/schema.sql').readAsStringSync());
    expect(statements.where((s) => s.startsWith('CREATE TABLE')), hasLength(6));
    expect(statements.where((s) => s.startsWith('CREATE TRIGGER')), hasLength(3));
    expect(statements.where((s) => s.startsWith('CREATE VIEW')), hasLength(3));
    expect(statements.any((s) => s.startsWith('PRAGMA')), isFalse);
    expect(statements.where((s) => s.startsWith('CREATE TRIGGER')).every((s) => s.endsWith('END;')), isTrue);
  });

  test('マスタデータが投入され、サービスとプランを取得できる', () async {
    final repo = await openRepo();
    final services = await repo.services();
    expect(services.map((s) => s.name), containsAll(['Netflix', 'Spotify', 'Google One', 'ChatGPT']));
    expect(services.firstWhere((s) => s.name == 'ChatGPT').hasForeignCurrency, isTrue);

    final netflix = services.firstWhere((s) => s.name == 'Netflix');
    final plans = await repo.plans(netflix.id);
    expect(plans.map((p) => p.name), ['広告つきスタンダード', 'スタンダード', 'プレミアム']);
  });

  test('新規インストールでは Hulu と Google AI Pro も入っている', () async {
    final repo = await openRepo();
    final services = await repo.services();
    final hulu = services.firstWhere((s) => s.name == 'Hulu');
    final aiPro = services.firstWhere((s) => s.name == 'Google AI Pro');
    expect(hulu.category, '動画');
    expect(aiPro.category, 'AI');
    expect((await repo.plans(hulu.id)).single.price, 1026);
    expect((await repo.plans(aiPro.id)).single.price, 2900);
  });

  test('新規インストールでは Claude Code（月額 \$22）と Cloudflare（年額 \$12）も入っている', () async {
    final repo = await openRepo();
    final services = await repo.services();
    final claude = services.firstWhere((s) => s.name == 'Claude Code');
    final cloudflare = services.firstWhere((s) => s.name == 'Cloudflare');
    expect(claude.hasForeignCurrency, isTrue);
    final claudePlan = (await repo.plans(claude.id)).single;
    expect((claudePlan.currencyCode, claudePlan.price, claudePlan.intervalMonths), ('USD', 2200, 1));
    final cfPlan = (await repo.plans(cloudflare.id)).single;
    expect((cfPlan.currencyCode, cfPlan.price, cfPlan.intervalMonths), ('USD', 1200, 12));

    // 1 ドル 150 円なら Cloudflare は月 150 円（$12 × 150 ÷ 12）
    await repo.saveRate('USD', 150.0, '2026-09-01');
    final id = await repo.addSubscription(planId: cfPlan.id, customPrice: null, startDate: '2026-09-01', billingDay: 1);
    final sub = (await repo.subscription(id))!;
    expect(sub.monthlyCostJpy, 150);
    expect(sub.yearlyCostJpy, 1800);
  });

  test('バージョン 1 の DB を開くと以降に追加したサービスが入り、同名のユーザー追加サービスは重複しない', () async {
    final dir = Directory.systemTemp.createTempSync('subsc_db_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.db';
    final schemaSql = File('docs/db/schema.sql').readAsStringSync();

    // バージョン 1 の状態を作り、ユーザーが Hulu を自分で追加していたことにする
    final v1 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            final batch = db.batch();
            for (final s in splitSqlStatements(schemaSql)) {
              batch.execute(s);
            }
            seedMasterData(batch);
            await batch.commit(noResult: true);
          },
        ));
    await SubscriptionRepository(v1).addCustomService(
        name: 'Hulu', category: '動画', planName: '自分で追加', currencyCode: 'JPY', price: 1000, intervalMonths: 1);
    await SubscriptionRepository(v1).saveRate('USD', 140.0, '2026-08-01');
    await v1.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path, schemaSql: schemaSql);
    addTearDown(db.close);
    final repo = SubscriptionRepository(db);
    final services = await repo.services();
    expect(services.where((s) => s.name == 'Hulu'), hasLength(1));
    final hulu = services.firstWhere((s) => s.name == 'Hulu');
    expect((await repo.plans(hulu.id)).single.name, '自分で追加');
    // ユーザーが登録済みのレートは初期レートで上書きしない
    expect((await repo.rates('USD')).map((r) => r.rateToJpy), [140.0]);
    expect(services.map((s) => s.name), containsAll(['Google AI Pro', 'Claude Code', 'Cloudflare', 'Moises', 'Amazon Prime', 'スマホ・ネット通信量', 'U-FRET']));
  });

  test('新規インストールでは Moises Premium の月額払いと年額払いが入っている', () async {
    final repo = await openRepo();
    final moises = (await repo.services()).firstWhere((s) => s.name == 'Moises');
    expect(moises.category, '音楽');
    final plans = await repo.plans(moises.id);
    expect(plans.map((p) => (p.name, p.price, p.intervalMonths)), [('Premium', 1180, 1), ('Premium', 11800, 12)]);
  });

  test('新規インストールでは Amazon Prime の月額プランと年額プランが入っている', () async {
    final repo = await openRepo();
    final prime = (await repo.services()).firstWhere((s) => s.name == 'Amazon Prime');
    final plans = await repo.plans(prime.id);
    expect(plans.map((p) => (p.name, p.price, p.intervalMonths)), [('月額プラン', 600, 1), ('年額プラン', 5900, 12)]);
  });

  test('新規インストールでは スマホ・ネット通信量（月額 12,000 円）が入っている', () async {
    final repo = await openRepo();
    final mobile = (await repo.services()).firstWhere((s) => s.name == 'スマホ・ネット通信量');
    expect(mobile.category, '通信');
    final plan = (await repo.plans(mobile.id)).single;
    expect((plan.name, plan.price, plan.intervalMonths), ('月額プラン', 12000, 1));
  });

  test('新規インストールでは U-FRET（月額 650 円）が入っている', () async {
    final repo = await openRepo();
    final ufret = (await repo.services()).firstWhere((s) => s.name == 'U-FRET');
    expect(ufret.category, '音楽');
    final plan = (await repo.plans(ufret.id)).single;
    expect((plan.name, plan.price, plan.intervalMonths), ('月額プラン', 650, 1));
  });

  test('月額・年額・ドル建て・手動金額を円に換算して集計する', () async {
    final repo = await openRepo();
    await repo.saveRate('USD', 150.0, '2026-09-01');

    Future<int> planId(String service, String plan, int months) async {
      final s = (await repo.services()).firstWhere((x) => x.name == service);
      return (await repo.plans(s.id)).firstWhere((p) => p.name == plan && p.intervalMonths == months).id;
    }

    await repo.addSubscription(planId: await planId('Netflix', 'スタンダード', 1), customPrice: null, startDate: '2025-04-01', billingDay: 1);
    await repo.addSubscription(planId: await planId('Spotify', 'Individual', 1), customPrice: 1180, startDate: '2024-10-15', billingDay: 15);
    await repo.addSubscription(planId: await planId('Google One', '100GB', 12), customPrice: null, startDate: '2026-01-10', billingDay: 10);
    await repo.addSubscription(planId: await planId('ChatGPT', 'Plus', 1), customPrice: null, startDate: '2025-06-01', billingDay: 1);

    final subs = await repo.activeSubscriptions();
    expect(subs.map((s) => s.serviceName), ['ChatGPT', 'Netflix', 'Spotify', 'Google One']);

    final monthly = subs.fold<double>(0, (sum, s) => sum + s.monthlyCostJpy!);
    expect(monthly.round(), 5978);
    final yearly = subs.fold<double>(0, (sum, s) => sum + s.yearlyCostJpy!);
    expect(yearly.round(), 71740);

    final spotify = subs.firstWhere((s) => s.serviceName == 'Spotify');
    expect(spotify.isManual, isTrue);
    expect(spotify.effectivePrice, 1180);

    // 手動金額を解除するとプラン金額に戻る
    await repo.updateCustomPrice(spotify.id, null);
    expect((await repo.subscription(spotify.id))!.effectivePrice, 1080);
  });

  test('初期レート（1 ドル 150 円）が入っていて、ドル建ても最初から円で換算される', () async {
    final repo = await openRepo();
    final rates = await repo.rates('USD');
    expect(rates.single.rateToJpy, initialUsdRate);

    final claude = (await repo.services()).firstWhere((s) => s.name == 'Claude Code');
    final plan = (await repo.plans(claude.id)).single;
    final id = await repo.addSubscription(planId: plan.id, customPrice: null, startDate: '2026-09-01', billingDay: 1);
    final sub = (await repo.subscription(id))!;
    expect(sub.hasRate, isTrue);
    expect(sub.monthlyCostJpy, 3300); // $22 × 150
    expect(sub.yearlyCostJpy, 39600);
  });

  test('レート未登録のドル建ては円換算されず、月次記録にも含まれない', () async {
    final repo = await openRepo();
    await repo.db.delete('exchange_rates');
    final chatgpt = (await repo.services()).firstWhere((s) => s.name == 'ChatGPT');
    final plan = (await repo.plans(chatgpt.id)).single;
    final id = await repo.addSubscription(planId: plan.id, customPrice: null, startDate: '2026-09-01', billingDay: 1);

    final sub = (await repo.subscription(id))!;
    expect(sub.hasRate, isFalse);
    expect(sub.monthlyCostJpy, isNull);

    await repo.recordMonthly('2026-09');
    expect(await repo.recordsOfSubscription(id), isEmpty);
  });

  test('月次記録: 開かなかった月を現在の金額で埋め、当月は上書き、既存の記録は変えない', () async {
    final repo = await openRepo();
    final netflix = (await repo.services()).firstWhere((s) => s.name == 'Netflix');
    final plan = (await repo.plans(netflix.id)).firstWhere((p) => p.name == 'スタンダード');
    final id = await repo.addSubscription(planId: plan.id, customPrice: null, startDate: '2026-06-01', billingDay: 1);

    // 2026-06 に登録し、その月に記録した状態を作る
    await repo.db.update('subscriptions', {'created_at': '2026-06-01 09:00:00'}, where: 'id = ?', whereArgs: [id]);
    await repo.updateCustomPrice(id, 1490);
    await repo.recordMonthly('2026-06');

    // 金額が変わり、9 月まで開かなかった
    await repo.updateCustomPrice(id, null);
    await repo.recordMonthly('2026-09');
    await repo.recordMonthly('2026-09'); // 2 回実行しても重複しない

    final records = await repo.recordsOfSubscription(id);
    expect(records.map((r) => r.yearMonth), ['2026-09', '2026-08', '2026-07', '2026-06']);
    expect(records.map((r) => r.price), [1590, 1590, 1590, 1490]);

    final totals = await repo.monthlyTotals();
    expect(totals.first.yearMonth, '2026-09');
    expect(totals.first.totalJpy, 1590);
  });

  test('解約すると一覧から外れ、以降の月は記録されない', () async {
    final repo = await openRepo();
    final spotify = (await repo.services()).firstWhere((s) => s.name == 'Spotify');
    final plan = (await repo.plans(spotify.id)).first;
    final id = await repo.addSubscription(planId: plan.id, customPrice: null, startDate: '2026-09-01', billingDay: 1);
    await repo.recordMonthly('2026-09');

    await repo.cancelSubscription(id, '2026-09-30');
    expect(await repo.activeSubscriptions(), isEmpty);

    await repo.recordMonthly('2026-11');
    expect((await repo.recordsOfSubscription(id)).map((r) => r.yearMonth), ['2026-09']);
  });

  test('一覧にないサービスをプランと一緒に追加できる', () async {
    final repo = await openRepo();
    final id = await repo.addCustomService(
      name: 'Notion',
      category: '仕事',
      planName: 'Plus',
      currencyCode: 'USD',
      price: 1000,
      intervalMonths: 1,
    );
    expect(await repo.serviceNameExists('notion'), isTrue);
    final plans = await repo.plans(id);
    expect(plans.single.currencySymbol, r'$');
    expect(plans.single.price, 1000);
  });
}
