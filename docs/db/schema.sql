-- =============================================================
-- subsc_management  SQLite スキーマ定義
--
-- 前提:
--   - 端末内 SQLite（sqflite）で利用する
--   - Android 標準の SQLite でも動くよう、STRICT テーブルや
--     生成列などの新しめの機能は使わない
--   - 金額は通貨の最小単位の整数（INTEGER）で保持する
--       JPY: 1 円単位（¥1,590 → 1590） / USD: セント単位（$19.99 → 1999）
--   - 円換算は exchange_rates の最新レートで行い、月次記録にはその時点のレートを保存する
--   - 日付は ISO 8601 形式の TEXT（'YYYY-MM-DD' / 'YYYY-MM' / 'YYYY-MM-DD HH:MM:SS'）
--   - 外部キーは接続ごとに有効化が必要（sqflite では onConfigure で実行）
-- =============================================================

PRAGMA foreign_keys = ON;

-- -------------------------------------------------------------
-- currencies: 通貨マスタ
-- -------------------------------------------------------------
CREATE TABLE currencies (
    code              TEXT    PRIMARY KEY,             -- ISO 4217（JPY / USD）
    symbol            TEXT    NOT NULL,                -- ¥ / $
    minor_unit_factor INTEGER NOT NULL
                      CHECK (minor_unit_factor > 0)    -- 最小単位 → 主単位の係数（JPY: 1 / USD: 100）
);

-- -------------------------------------------------------------
-- exchange_rates: 円換算レート（1 通貨単位あたりの円）
--   - ユーザーが手入力する。最新の rate_date のレートを換算に使う
--   - JPY は常に 1.0 として扱うため登録不要
-- -------------------------------------------------------------
CREATE TABLE exchange_rates (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    currency_code TEXT    NOT NULL REFERENCES currencies (code),
    rate_to_jpy   REAL    NOT NULL CHECK (rate_to_jpy > 0),  -- 例: 1 USD = 148.5 円 → 148.5
    rate_date     TEXT    NOT NULL,                          -- レートの適用日 'YYYY-MM-DD'
    created_at    TEXT    NOT NULL DEFAULT (datetime('now', 'localtime')),
    UNIQUE (currency_code, rate_date),
    CHECK (currency_code <> 'JPY')
);

-- -------------------------------------------------------------
-- services: アプリ / Web サービスのマスタ
-- -------------------------------------------------------------
CREATE TABLE services (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT    NOT NULL UNIQUE,              -- サービス名（例: Netflix）
    service_type TEXT    NOT NULL DEFAULT 'app'
                 CHECK (service_type IN ('app', 'web', 'both')),
    category     TEXT,                                 -- 動画 / 音楽 / クラウド など
    icon         TEXT,                                 -- アイコンのアセットパス or URL
    url          TEXT,                                 -- 公式サイト / 解約ページなど
    is_preset    INTEGER NOT NULL DEFAULT 1
                 CHECK (is_preset IN (0, 1)),          -- 1: 初期データ / 0: ユーザー追加
    created_at   TEXT    NOT NULL DEFAULT (datetime('now', 'localtime')),
    updated_at   TEXT    NOT NULL DEFAULT (datetime('now', 'localtime'))
);

-- -------------------------------------------------------------
-- plans: サービスに紐づくプランのマスタ（1 サービスに複数）
--   同じプランでも月額 / 年額で別レコードにする（契約形態 = billing_interval_months）
-- -------------------------------------------------------------
CREATE TABLE plans (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    service_id              INTEGER NOT NULL
                            REFERENCES services (id) ON DELETE CASCADE,
    name                    TEXT    NOT NULL,          -- プラン名（例: スタンダード）
    currency_code           TEXT    NOT NULL DEFAULT 'JPY'
                            REFERENCES currencies (code),
    price                   INTEGER NOT NULL CHECK (price >= 0),  -- 請求 1 回あたりの金額（最小単位）
    billing_interval_months INTEGER NOT NULL DEFAULT 1
                            CHECK (billing_interval_months > 0),  -- 1: 月額 / 12: 年額 など
    is_active               INTEGER NOT NULL DEFAULT 1
                            CHECK (is_active IN (0, 1)),          -- 0: 提供終了（新規登録の選択肢に出さない）
    sort_order              INTEGER NOT NULL DEFAULT 0,
    created_at              TEXT    NOT NULL DEFAULT (datetime('now', 'localtime')),
    updated_at              TEXT    NOT NULL DEFAULT (datetime('now', 'localtime')),
    UNIQUE (service_id, name, billing_interval_months)
);

CREATE INDEX idx_plans_service_id ON plans (service_id);

-- -------------------------------------------------------------
-- subscriptions: ユーザーが契約中（または過去に契約）のサブスク
--   - サービス・通貨・契約形態は plan_id → plans で辿る（二重管理しない）
--   - custom_price が NULL ならプランの price を使う（通貨はプランと同じ）
-- -------------------------------------------------------------
CREATE TABLE subscriptions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id       INTEGER NOT NULL
                  REFERENCES plans (id) ON DELETE RESTRICT,   -- 契約中のプランは削除させない
    custom_price  INTEGER CHECK (custom_price IS NULL OR custom_price >= 0),  -- 手動で書き換えた金額（最小単位）
    start_date    TEXT    NOT NULL DEFAULT (date('now', 'localtime')),
    billing_day   INTEGER CHECK (billing_day IS NULL OR billing_day BETWEEN 1 AND 31),  -- 毎回の請求日
    status        TEXT    NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'cancelled')),
    cancelled_at  TEXT,
    memo          TEXT,
    created_at    TEXT    NOT NULL DEFAULT (datetime('now', 'localtime')),
    updated_at    TEXT    NOT NULL DEFAULT (datetime('now', 'localtime')),
    CHECK (status = 'active' OR cancelled_at IS NOT NULL)
);

CREATE INDEX idx_subscriptions_plan_id ON subscriptions (plan_id);
CREATE INDEX idx_subscriptions_status  ON subscriptions (status);

-- -------------------------------------------------------------
-- subscription_monthly_records: 月ごとの金額記録（変更履歴）
--   - 契約中のサブスクについて 1 か月に 1 レコード記録する
--   - 記録時点の金額・契約形態・為替レートを保存するため、
--     後から金額やレートが変わっても過去の記録は変わらない
--   - 同じ月は上書き（その月の最終値を残す）
--   - アプリを開かなかった月は、次に開いたときに現在の金額・レートで埋める
-- -------------------------------------------------------------
CREATE TABLE subscription_monthly_records (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    subscription_id         INTEGER NOT NULL
                            REFERENCES subscriptions (id) ON DELETE CASCADE,
    year_month              TEXT    NOT NULL
                            CHECK (year_month GLOB '[0-9][0-9][0-9][0-9]-[0-1][0-9]'),  -- 'YYYY-MM'
    price                   INTEGER NOT NULL,          -- その月の請求 1 回あたりの金額（最小単位）
    currency_code           TEXT    NOT NULL REFERENCES currencies (code),
    billing_interval_months INTEGER NOT NULL,          -- その月の契約形態
    rate_to_jpy             REAL    NOT NULL,          -- 適用した為替レート（JPY は 1.0）
    price_jpy               INTEGER NOT NULL,          -- 請求 1 回あたりの円換算額
    monthly_cost_jpy        REAL    NOT NULL,          -- 月額換算（円）
    recorded_at             TEXT    NOT NULL DEFAULT (datetime('now', 'localtime')),
    UNIQUE (subscription_id, year_month)
);

CREATE INDEX idx_monthly_records_year_month ON subscription_monthly_records (year_month);

-- -------------------------------------------------------------
-- updated_at 自動更新トリガー
-- -------------------------------------------------------------
CREATE TRIGGER trg_services_updated_at AFTER UPDATE ON services
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE services SET updated_at = datetime('now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER trg_plans_updated_at AFTER UPDATE ON plans
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE plans SET updated_at = datetime('now', 'localtime') WHERE id = NEW.id;
END;

CREATE TRIGGER trg_subscriptions_updated_at AFTER UPDATE ON subscriptions
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE subscriptions SET updated_at = datetime('now', 'localtime') WHERE id = NEW.id;
END;

-- -------------------------------------------------------------
-- v_latest_exchange_rates: 通貨ごとの最新レート（JPY は 1.0）
-- -------------------------------------------------------------
CREATE VIEW v_latest_exchange_rates AS
SELECT
    c.code AS currency_code,
    CASE
        WHEN c.code = 'JPY' THEN 1.0
        ELSE (SELECT er.rate_to_jpy FROM exchange_rates er
              WHERE er.currency_code = c.code
              ORDER BY er.rate_date DESC LIMIT 1)
    END AS rate_to_jpy,
    CASE
        WHEN c.code = 'JPY' THEN NULL
        ELSE (SELECT er.rate_date FROM exchange_rates er
              WHERE er.currency_code = c.code
              ORDER BY er.rate_date DESC LIMIT 1)
    END AS rate_date
FROM currencies c;

-- -------------------------------------------------------------
-- v_subscriptions: 一覧表示・集計用ビュー
--   contract_label   : 自分の契約形態（月額 / 年額 / Nか月ごと）
--   effective_price  : 表示・集計に使う金額（手動金額 > プラン金額、元通貨の最小単位）
--   price_jpy        : 請求 1 回あたりの円換算額
--   monthly_cost_jpy : 月表示用（年額なら ÷12）
--   yearly_cost_jpy  : 年表示用（月額なら ×12）
--   ※ 外貨でレート未登録の場合、円換算の列は NULL になる
-- -------------------------------------------------------------
CREATE VIEW v_subscriptions AS
SELECT
    sub.id                                        AS subscription_id,
    svc.id                                        AS service_id,
    svc.name                                      AS service_name,
    svc.service_type,
    svc.category,
    svc.icon,
    pl.id                                         AS plan_id,
    pl.name                                       AS plan_name,
    pl.billing_interval_months,
    CASE pl.billing_interval_months
        WHEN 1  THEN '月額'
        WHEN 12 THEN '年額'
        ELSE pl.billing_interval_months || 'か月ごと'
    END                                           AS contract_label,
    pl.currency_code,
    cur.symbol                                    AS currency_symbol,
    cur.minor_unit_factor,
    pl.price                                      AS plan_price,
    sub.custom_price,
    COALESCE(sub.custom_price, pl.price)          AS effective_price,
    rt.rate_to_jpy,
    rt.rate_date,
    CAST(ROUND(COALESCE(sub.custom_price, pl.price) * 1.0
          / cur.minor_unit_factor * rt.rate_to_jpy) AS INTEGER) AS price_jpy,
    COALESCE(sub.custom_price, pl.price) * 1.0
        / cur.minor_unit_factor * rt.rate_to_jpy
        / pl.billing_interval_months                            AS monthly_cost_jpy,
    COALESCE(sub.custom_price, pl.price) * 1.0
        / cur.minor_unit_factor * rt.rate_to_jpy
        * 12 / pl.billing_interval_months                       AS yearly_cost_jpy,
    sub.start_date,
    sub.billing_day,
    sub.status,
    sub.cancelled_at,
    sub.memo
FROM subscriptions sub
JOIN plans                   pl  ON pl.id  = sub.plan_id
JOIN services                svc ON svc.id = pl.service_id
JOIN currencies              cur ON cur.code = pl.currency_code
JOIN v_latest_exchange_rates rt  ON rt.currency_code = pl.currency_code;

-- -------------------------------------------------------------
-- v_monthly_totals: 月ごとの合計（履歴画面の推移表示用）
-- -------------------------------------------------------------
CREATE VIEW v_monthly_totals AS
SELECT
    year_month,
    COUNT(*)              AS subscription_count,
    SUM(monthly_cost_jpy) AS monthly_total_jpy
FROM subscription_monthly_records
GROUP BY year_month;
