-- =============================================================
-- アプリから実行する主なクエリ
-- :name はアプリ側で渡すパラメータ
-- =============================================================

-- -------------------------------------------------------------
-- 一覧（月表示 / 年表示）
--   :period = 'month' → 月額換算 / 'year' → 年間金額
-- -------------------------------------------------------------
SELECT
    subscription_id,
    service_name,
    plan_name,
    contract_label,                              -- 自分の契約形態（月額 / 年額）
    currency_symbol,
    effective_price * 1.0 / minor_unit_factor AS price,   -- 元通貨での請求額（$20.00 など）
    price_jpy,                                   -- 請求 1 回あたりの円換算
    ROUND(CASE :period WHEN 'year' THEN yearly_cost_jpy ELSE monthly_cost_jpy END) AS display_cost_jpy
FROM v_subscriptions
WHERE status = 'active'
ORDER BY display_cost_jpy DESC;

-- -------------------------------------------------------------
-- 合計（月表示 / 年表示）
-- -------------------------------------------------------------
SELECT
    ROUND(SUM(CASE :period WHEN 'year' THEN yearly_cost_jpy ELSE monthly_cost_jpy END)) AS total_jpy,
    SUM(CASE WHEN monthly_cost_jpy IS NULL THEN 1 ELSE 0 END) AS missing_rate_count  -- 1 以上ならレート未登録の外貨あり
FROM v_subscriptions
WHERE status = 'active';

-- -------------------------------------------------------------
-- 月次記録
--   アプリ起動時・金額編集時に、以下の 2 つを 1 トランザクションで実行する
--   :year_month = 当月 'YYYY-MM'
-- -------------------------------------------------------------

-- (1) 未記録の月を現在の金額・レートで埋める（当月まで。既存の記録は変更しない）
--     起点: そのサブスクの最終記録月の翌月。記録が 1 件もなければ登録月（created_at）
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
    SELECT subscription_id, from_month FROM targets WHERE from_month <= :year_month
    UNION ALL
    SELECT subscription_id, strftime('%Y-%m', date(year_month || '-01', '+1 month'))
    FROM months
    WHERE year_month < :year_month
)
INSERT OR IGNORE INTO subscription_monthly_records
    (subscription_id, year_month, price, currency_code, billing_interval_months,
     rate_to_jpy, price_jpy, monthly_cost_jpy)
SELECT
    v.subscription_id, m.year_month, v.effective_price, v.currency_code, v.billing_interval_months,
    v.rate_to_jpy, v.price_jpy, v.monthly_cost_jpy
FROM months m
JOIN v_subscriptions v ON v.subscription_id = m.subscription_id
WHERE v.rate_to_jpy IS NOT NULL;

-- (2) 当月分を現在の値で記録 / 上書き
--   ※ INSERT OR REPLACE は Android の古い SQLite（UPSERT 非対応）でも動く
INSERT OR REPLACE INTO subscription_monthly_records
    (subscription_id, year_month, price, currency_code, billing_interval_months,
     rate_to_jpy, price_jpy, monthly_cost_jpy)
SELECT
    subscription_id, :year_month, effective_price, currency_code, billing_interval_months,
    rate_to_jpy, price_jpy, monthly_cost_jpy
FROM v_subscriptions
WHERE status = 'active'
  AND rate_to_jpy IS NOT NULL;

-- -------------------------------------------------------------
-- 履歴: サブスクごとの金額推移
-- -------------------------------------------------------------
SELECT
    r.year_month,
    r.price * 1.0 / c.minor_unit_factor AS price,
    c.symbol                            AS currency_symbol,
    r.rate_to_jpy,
    r.price_jpy,
    ROUND(r.monthly_cost_jpy)           AS monthly_cost_jpy
FROM subscription_monthly_records r
JOIN currencies c ON c.code = r.currency_code
WHERE r.subscription_id = :subscription_id
ORDER BY r.year_month DESC;

-- -------------------------------------------------------------
-- 履歴: 月ごとの合計推移
-- -------------------------------------------------------------
SELECT year_month, subscription_count, ROUND(monthly_total_jpy) AS monthly_total_jpy
FROM v_monthly_totals
ORDER BY year_month DESC;
