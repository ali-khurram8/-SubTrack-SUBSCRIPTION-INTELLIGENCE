-- ============================================================
--  SubTrack Sample Data (PostgreSQL / Supabase)
-- ============================================================

-- Categories
INSERT INTO categories (name, icon, color_hex, description) VALUES
('Streaming',    'bi-play-circle-fill',   '#e50914', 'Video & audio streaming services'),
('Music',        'bi-music-note-beamed',  '#1db954', 'Music streaming platforms'),
('Productivity', 'bi-kanban-fill',        '#7c5cfc', 'Work and productivity tools'),
('Cloud Storage','bi-cloud-fill',         '#4285f4', 'Cloud storage and backup'),
('Development',  'bi-code-slash',         '#333333', 'Developer tools and platforms'),
('AI & ML',      'bi-robot',              '#10a37f', 'Artificial intelligence services'),
('Fitness',      'bi-heart-pulse-fill',   '#ff6b6b', 'Health and fitness apps'),
('Education',    'bi-mortarboard-fill',   '#fbbf24', 'Learning platforms'),
('Security',     'bi-shield-lock-fill',   '#22d3ee', 'VPN and security tools'),
('Other',        'bi-tag-fill',           '#9494a8', 'Uncategorized subscriptions');

-- Plans
INSERT INTO plans (service_name, plan_name, category_id, billing_cycle, base_price, currency) VALUES
('Netflix',       'Standard',     1, 'monthly', 15.49, 'USD'),
('Netflix',       'Premium',      1, 'monthly', 22.99, 'USD'),
('Spotify',       'Individual',   2, 'monthly',  9.99, 'USD'),
('Spotify',       'Family',       2, 'monthly', 16.99, 'USD'),
('ChatGPT',       'Plus',         6, 'monthly', 20.00, 'USD'),
('Google Drive',  '100GB',        4, 'monthly',  1.99, 'USD'),
('Google Drive',  '2TB',          4, 'monthly',  9.99, 'USD'),
('GitHub',        'Pro',          5, 'monthly',  4.00, 'USD'),
('Notion',        'Plus',         3, 'monthly', 10.00, 'USD'),
('Adobe CC',      'All Apps',     3, 'monthly', 54.99, 'USD'),
('YouTube',       'Premium',      1, 'monthly', 13.99, 'USD'),
('iCloud',        '200GB',        4, 'monthly',  2.99, 'USD'),
('NordVPN',       '2-Year',       9, 'yearly',  83.88, 'USD'),
('Coursera',      'Plus',         8, 'yearly', 399.00, 'USD'),
('Disney+',       'Standard',     1, 'monthly', 13.99, 'USD'),
('Slack',         'Pro',          3, 'monthly',  8.75, 'USD'),
('Figma',         'Professional', 3, 'monthly', 15.00, 'USD'),
('AWS',           'Pay-as-you-go',5, 'monthly', 25.00, 'USD');

-- Users (password: Password123!)
-- bcrypt hash for Password123!
INSERT INTO users (full_name, email, password_hash, phone, currency) VALUES
('Ali Khurram', 'ali@example.com', '$2a$10$RtV66nKVksWY5BPoIP8YtOCsTZlLxiZNz6M8toEMdVtkWwx.covCC', '+92-300-1234567', 'USD');

-- Subscriptions for Ali
INSERT INTO subscriptions (user_id, plan_id, custom_name, amount, currency, start_date, next_billing_date, status, auto_renew) VALUES
(1, 2,  NULL,    17.99, 'USD', '2025-12-01', '2026-06-01', 'active', true),
(1, 3,  NULL,     9.99, 'USD', '2025-11-15', '2026-06-15', 'active', true),
(1, 5,  NULL,    20.00, 'USD', '2026-01-01', '2026-06-01', 'active', true),
(1, 9,  NULL,    10.00, 'USD', '2026-02-01', '2026-06-01', 'active', false),
(1, 6,  NULL,     1.99, 'USD', '2025-10-01', '2026-06-01', 'active', true),
(1, 8,  NULL,     4.00, 'USD', '2026-01-15', '2026-06-15', 'active', true);

-- Transactions
INSERT INTO transactions (subscription_id, user_id, amount, currency, transaction_date, billing_period_start, billing_period_end, status, payment_method, reference_no) VALUES
(1, 1, 15.99, 'USD', '2026-04-01', '2026-04-01', '2026-04-01', 'completed', 'Visa *4242', 'TXN-20260401-001'),
(1, 1, 15.99, 'USD', '2026-05-01', '2026-05-01', '2026-05-01', 'completed', 'Visa *4242', 'TXN-20260501-001'),
(2, 1,  9.99, 'USD', '2026-04-15', '2026-04-15', '2026-04-15', 'completed', 'Visa *4242', 'TXN-20260415-002'),
(2, 1,  9.99, 'USD', '2026-05-15', '2026-05-15', '2026-05-15', 'completed', 'Visa *4242', 'TXN-20260515-002'),
(3, 1, 20.00, 'USD', '2026-04-01', '2026-04-01', '2026-04-01', 'completed', 'Mastercard *8888', 'TXN-20260401-003'),
(3, 1, 20.00, 'USD', '2026-05-01', '2026-05-01', '2026-05-01', 'completed', 'Mastercard *8888', 'TXN-20260501-003'),
(5, 1,  1.99, 'USD', '2026-05-01', '2026-05-01', '2026-05-01', 'completed', 'Visa *4242', 'TXN-20260501-005'),
(6, 1,  4.00, 'USD', '2026-05-15', '2026-05-15', '2026-05-15', 'completed', 'Visa *4242', 'TXN-20260515-006');

-- Hidden Charges (sample detections)
INSERT INTO hidden_charges (transaction_id, subscription_id, user_id, charge_type, expected_amount, actual_amount, description, is_resolved) VALUES
(2, 1, 1, 'price_increase', 15.49, 15.99, 'Netflix price increased from $15.49 to $15.99 (+$0.50)', false),
(4, 2, 1, 'duplicate_charge', 0.00, 9.99, 'Duplicate charge detected for Spotify billing period', false);

-- Alerts
INSERT INTO alerts (user_id, subscription_id, alert_type, title, message, severity, is_read) VALUES
(1, 1, 'price_increased', 'Price Increase Detected', 'Netflix charge increased from $15.49 to $15.99', 'warning', false),
(1, 2, 'duplicate_detected', 'Duplicate Charge Detected!', 'A duplicate charge of $9.99 was detected for Spotify.', 'critical', false),
(1, 3, 'renewal_reminder', 'ChatGPT Plus renews in 5 days', 'ChatGPT Plus will be charged USD 20.00 on 2026-06-01.', 'info', false),
(1, 5, 'renewal_reminder', 'Google Drive renews in 5 days', 'Google Drive will be charged USD 1.99 on 2026-06-01.', 'info', true);
