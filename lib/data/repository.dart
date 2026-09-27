import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// DB への読み書きをまとめたリポジトリ。SQL は docs/db/queries.sql と対応している。
class SubscriptionRepository {
  SubscriptionRepository(this.db);

  final Database db;

  // ---------------------------------------------------------------------------
  // サービス・プラン
  // ---------------------------------------------------------------------------

  Future<List<Service>> services() async {
    final rows = await db.rawQuery('''
      SELECT s.id, s.name, s.category,
             COUNT(p.id) AS plan_count,
             SUM(CASE WHEN p.currency_code <> 'JPY' THEN 1 ELSE 0 END) AS foreign_count
      FROM services s
      JOIN plans p ON p.service_id = s.id AND p.is_active = 1
      GROUP BY s.id
      ORDER BY s.name COLLATE NOCASE
    ''');
    return rows.map(Service.fromMap).toList();
  }

  Future<List<Plan>> plans(int serviceId) async {
    final rows = await db.rawQuery('''
      SELECT p.*, c.symbol, c.minor_unit_factor
      FROM plans p
      JOIN currencies c ON c.code = p.currency_code
      WHERE p.service_id = ? AND p.is_active = 1
      ORDER BY p.sort_order, p.id
    ''', [serviceId]);
    return rows.map(Plan.fromMap).toList();
  }

  /// マスタにないサービスをプラン 1 つと一緒に追加し、サービス ID を返す。
  Future<int> addCustomService({
    required String name,
    required String? category,
    required String planName,
    required String currencyCode,
    required int price,
    required int intervalMonths,
  }) {
    return db.transaction((txn) async {
      final serviceId = await txn.insert('services', {
        'name': name,
        'service_type': 'both',
        'category': category,
        'is_preset': 0,
      });
      await txn.insert('plans', {
        'service_id': serviceId,
        'name': planName,
        'currency_code': currencyCode,
        'price': price,
        'billing_interval_months': intervalMonths,
      });
      return serviceId;
    });
  }

  Future<bool> serviceNameExists(String name) async {
    final rows = await db.query('services',
        columns: ['id'], where: 'name = ? COLLATE NOCASE', whereArgs: [name.trim()], limit: 1);
    return rows.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // 契約
  // ---------------------------------------------------------------------------

  Future<List<Subscription>> activeSubscriptions() async {
    final rows = await db.rawQuery(
        "SELECT * FROM v_subscriptions WHERE status = 'active' ORDER BY monthly_cost_jpy IS NULL, monthly_cost_jpy DESC");
    return rows.map(Subscription.fromMap).toList();
  }

  Future<Subscription?> subscription(int id) async {
    final rows = await db.rawQuery('SELECT * FROM v_subscriptions WHERE subscription_id = ?', [id]);
    return rows.isEmpty ? null : Subscription.fromMap(rows.first);
  }

  Future<int> addSubscription({
    required int planId,
    required int? customPrice,
    required String startDate,
    required int? billingDay,
  }) {
    return db.insert('subscriptions', {
      'plan_id': planId,
      'custom_price': customPrice,
      'start_date': startDate,
      'billing_day': billingDay,
    });
  }

  /// 手動金額を更新する。null ならプラン金額に戻す。
  Future<void> updateCustomPrice(int subscriptionId, int? customPrice) {
    return db.update('subscriptions', {'custom_price': customPrice},
        where: 'id = ?', whereArgs: [subscriptionId]);
  }

  Future<void> cancelSubscription(int subscriptionId, String cancelledAt) {
    return db.update('subscriptions', {'status': 'cancelled', 'cancelled_at': cancelledAt},
        where: 'id = ?', whereArgs: [subscriptionId]);
  }

  // ---------------------------------------------------------------------------
  // 為替レート
  // ---------------------------------------------------------------------------

  Future<List<ExchangeRate>> rates(String currencyCode) async {
    final rows = await db.query('exchange_rates',
        where: 'currency_code = ?', whereArgs: [currencyCode], orderBy: 'rate_date DESC');
    return rows.map(ExchangeRate.fromMap).toList();
  }

  /// 同じ日付のレートは上書きする。
  Future<void> saveRate(String currencyCode, double rateToJpy, String rateDate) {
    return db.insert(
      'exchange_rates',
      {'currency_code': currencyCode, 'rate_to_jpy': rateToJpy, 'rate_date': rateDate},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // 月次記録
  // ---------------------------------------------------------------------------

  /// 未記録の月を現在の金額・レートで埋め、当月分を記録 / 上書きする。
  /// アプリ起動時と、金額・契約・レートを変更したときに呼ぶ。
  Future<void> recordMonthly(String yearMonth) {
    return db.transaction((txn) async {
      await txn.rawInsert('''
        WITH RECURSIVE
        targets (subscription_id, from_month) AS (
            SELECT
                s.id,
                COALESCE(
                    (SELECT strftime('%Y-%m', date(MAX(r.year_month) || '-01', '+1 month'))
                     FROM subscription_monthly_records r
                     WHERE r.subscription_id = s.id),
                    strftime('%Y-%m', s.created_at)
                )
            FROM subscriptions s
            WHERE s.status = 'active'
        ),
        months (subscription_id, year_month) AS (
            SELECT subscription_id, from_month FROM targets WHERE from_month <= ?1
            UNION ALL
            SELECT subscription_id, strftime('%Y-%m', date(year_month || '-01', '+1 month'))
            FROM months
            WHERE year_month < ?1
        )
        INSERT OR IGNORE INTO subscription_monthly_records
            (subscription_id, year_month, price, currency_code, billing_interval_months,
             rate_to_jpy, price_jpy, monthly_cost_jpy)
        SELECT
            v.subscription_id, m.year_month, v.effective_price, v.currency_code, v.billing_interval_months,
            v.rate_to_jpy, v.price_jpy, v.monthly_cost_jpy
        FROM months m
        JOIN v_subscriptions v ON v.subscription_id = m.subscription_id
        WHERE v.rate_to_jpy IS NOT NULL
      ''', [yearMonth]);

      // 当月分は現在値で上書き（解約した契約の当月分は残す）
      await txn.rawInsert('''
        INSERT OR REPLACE INTO subscription_monthly_records
            (subscription_id, year_month, price, currency_code, billing_interval_months,
             rate_to_jpy, price_jpy, monthly_cost_jpy)
        SELECT
            subscription_id, ?, effective_price, currency_code, billing_interval_months,
            rate_to_jpy, price_jpy, monthly_cost_jpy
        FROM v_subscriptions
        WHERE status = 'active'
          AND rate_to_jpy IS NOT NULL
      ''', [yearMonth]);
    });
  }

  Future<List<MonthlyTotal>> monthlyTotals() async {
    final rows = await db.rawQuery('SELECT * FROM v_monthly_totals ORDER BY year_month DESC');
    return rows.map(MonthlyTotal.fromMap).toList();
  }

  static const _recordSelect = '''
    SELECT r.*, c.symbol, c.minor_unit_factor,
           svc.id AS service_id, svc.name AS service_name, p.name AS plan_name
    FROM subscription_monthly_records r
    JOIN currencies    c   ON c.code  = r.currency_code
    JOIN subscriptions sub ON sub.id  = r.subscription_id
    JOIN plans         p   ON p.id    = sub.plan_id
    JOIN services      svc ON svc.id  = p.service_id
  ''';

  /// 指定月の内訳（月額換算の高い順）。
  Future<List<MonthlyRecord>> recordsOfMonth(String yearMonth) async {
    final rows = await db.rawQuery(
        '$_recordSelect WHERE r.year_month = ? ORDER BY r.monthly_cost_jpy DESC', [yearMonth]);
    return rows.map(MonthlyRecord.fromMap).toList();
  }

  /// サブスクごとの記録（新しい順）。
  Future<List<MonthlyRecord>> recordsOfSubscription(int subscriptionId) async {
    final rows = await db.rawQuery(
        '$_recordSelect WHERE r.subscription_id = ? ORDER BY r.year_month DESC', [subscriptionId]);
    return rows.map(MonthlyRecord.fromMap).toList();
  }
}
