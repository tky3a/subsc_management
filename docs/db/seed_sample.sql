-- =============================================================
-- 動作確認用サンプルデータ
-- ※ 金額・レートはダミーです。実際の初期データは各サービスの最新価格を確認して作成すること
-- =============================================================

INSERT INTO currencies (code, symbol, minor_unit_factor) VALUES
    ('JPY', '¥', 1),
    ('USD', '$', 100);

INSERT INTO exchange_rates (currency_code, rate_to_jpy, rate_date) VALUES
    ('USD', 145.0, '2026-08-01'),
    ('USD', 150.0, '2026-09-01');

INSERT INTO services (id, name, service_type, category) VALUES
    (1, 'Netflix',    'both', '動画'),
    (2, 'Spotify',    'app',  '音楽'),
    (3, 'Google One', 'both', 'クラウド'),
    (4, 'ChatGPT',    'both', 'AI'),
    (5, 'Hulu',          'both', '動画'),
    (6, 'Google AI Pro', 'both', 'AI'),
    (7, 'Claude Code',   'both', 'AI'),
    (8, 'Cloudflare',    'web',  'インフラ'),
    (9, 'Moises',        'app',  '音楽'),
    (10, 'Amazon Prime', 'both', 'ショッピング'),
    (11, 'スマホ・ネット通信量', 'both', '通信'),
    (12, 'U-FRET',       'app',  '音楽');

INSERT INTO plans (id, service_id, name, currency_code, price, billing_interval_months, sort_order) VALUES
    (1, 1, '広告つきスタンダード', 'JPY',  890,  1, 1),
    (2, 1, 'スタンダード',         'JPY', 1590,  1, 2),
    (3, 1, 'プレミアム',           'JPY', 2290,  1, 3),
    (4, 2, 'Individual',           'JPY', 1080,  1, 1),
    (5, 2, 'Duo',                  'JPY', 1480,  1, 2),
    (6, 3, '100GB',                'JPY',  250,  1, 1),
    (7, 3, '100GB',                'JPY', 2500, 12, 2),
    (8, 4, 'Plus',                 'USD', 2000,  1, 1),   -- $20.00
    (9, 5, '月額プラン',           'JPY', 1026,  1, 1),
    (10, 6, '月額プラン',          'JPY', 2900,  1, 1),
    (11, 7, '月額プラン',          'USD', 2200,  1, 1),   -- $22.00
    (12, 8, '年額プラン',          'USD', 1200, 12, 1),   -- $12.00 / 年
    (13, 9, 'Premium',             'JPY', 1180,  1, 1),
    (14, 9, 'Premium',             'JPY', 11800, 12, 2),
    (15, 10, '月額プラン',         'JPY',  600,  1, 1),
    (16, 10, '年額プラン',         'JPY', 5900, 12, 2),
    (17, 11, '月額プラン',         'JPY', 12000, 1, 1),
    (18, 12, '月額プラン',         'JPY',  650,  1, 1);

-- 契約例: Netflix スタンダード（月額） / Spotify Individual（値上げ分を手動で書き換え）
--         Google One 100GB（年額） / ChatGPT Plus（ドル払い・月額）
INSERT INTO subscriptions (id, plan_id, custom_price, start_date, billing_day) VALUES
    (1, 2, NULL, '2025-04-01',  1),
    (2, 4, 1180, '2024-10-15', 15),
    (3, 7, NULL, '2026-01-10', 10),
    (4, 8, NULL, '2025-06-01',  1);

-- 過去の月次記録の例（8 月は Spotify が値上げ前、USD レートも 145 円）
INSERT INTO subscription_monthly_records
    (subscription_id, year_month, price, currency_code, billing_interval_months, rate_to_jpy, price_jpy, monthly_cost_jpy)
VALUES
    (1, '2026-08', 1590, 'JPY',  1,   1.0, 1590, 1590.0),
    (2, '2026-08', 1080, 'JPY',  1,   1.0, 1080, 1080.0),
    (3, '2026-08', 2500, 'JPY', 12,   1.0, 2500, 208.333333333333),
    (4, '2026-08', 2000, 'USD',  1, 145.0, 2900, 2900.0);
