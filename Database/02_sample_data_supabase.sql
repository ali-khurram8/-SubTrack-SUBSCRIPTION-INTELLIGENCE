-- ============================================================
--  SAMPLE DATA — PostgreSQL (Supabase)
-- ============================================================

INSERT INTO categories (name, icon, color_hex) VALUES
('Streaming',     'bi-play-circle-fill',   '#e50914'),
('Music',         'bi-music-note-beamed',  '#1db954'),
('Productivity',  'bi-briefcase-fill',     '#0078d4'),
('Cloud Storage', 'bi-cloud-fill',         '#ff9500'),
('Gaming',        'bi-controller',         '#7b2fff'),
('Fitness',       'bi-heart-pulse-fill',   '#ff3b30'),
('News & Media',  'bi-newspaper',          '#34c759'),
('Security',      'bi-shield-lock-fill',   '#ff6b35'),
('Design',        'bi-palette-fill',       '#ff2d55'),
('AI & SaaS',     'bi-robot',              '#5ac8fa');

INSERT INTO plans (service_name, plan_name, category_id, billing_cycle, base_price, currency, logo_url, website_url) VALUES
('Netflix',     'Standard',        1, 'monthly',  15.49, 'USD', NULL, 'https://netflix.com'),
('Netflix',     'Premium',         1, 'monthly',  22.99, 'USD', NULL, 'https://netflix.com'),
('Spotify',     'Individual',      2, 'monthly',   9.99, 'USD', NULL, 'https://spotify.com'),
('Spotify',     'Family',          2, 'monthly',  15.99, 'USD', NULL, 'https://spotify.com'),
('Notion',      'Plus',            3, 'monthly',  10.00, 'USD', NULL, 'https://notion.so'),
('Notion',      'Plus',            3, 'yearly',   96.00, 'USD', NULL, 'https://notion.so'),
('Google Drive','100GB',           4, 'monthly',   1.99, 'USD', NULL, 'https://one.google.com'),
('Google Drive','2TB',             4, 'monthly',   9.99, 'USD', NULL, 'https://one.google.com'),
('Xbox Game Pass','Ultimate',      5, 'monthly',  14.99, 'USD', NULL, 'https://xbox.com'),
('Peloton',     'App Membership',  6, 'monthly',  12.99, 'USD', NULL, 'https://peloton.com'),
('NY Times',    'Digital Access',  7, 'monthly',  17.00, 'USD', NULL, 'https://nytimes.com'),
('NordVPN',     '2-Year Plan',     8, 'yearly',   89.00, 'USD', NULL, 'https://nordvpn.com'),
('Figma',       'Professional',    9, 'monthly',  15.00, 'USD', NULL, 'https://figma.com'),
('ChatGPT Plus','Plus',           10, 'monthly',  20.00, 'USD', NULL, 'https://openai.com'),
('Adobe CC',    'All Apps',        9, 'monthly',  59.99, 'USD', NULL, 'https://adobe.com'),
('Dropbox',     'Plus',            4, 'yearly',   99.99, 'USD', NULL, 'https://dropbox.com'),
('Hulu',        'No Ads',          1, 'monthly',  17.99, 'USD', NULL, 'https://hulu.com'),
('GitHub',      'Pro',             3, 'monthly',   4.00, 'USD', NULL, 'https://github.com');

-- Passwords are bcrypt hashes of 'Password123!'
INSERT INTO users (full_name, email, password_hash, phone, currency) VALUES
('Ali Khurram',   'ali@example.com',   '$2a$10$RtV66nKVksWY5BPoIP8YtOCsTZlLxiZNz6M8toEMdVtkWwx.covCC', '+92-300-1234567', 'USD'),
('Mohsin Hassan', 'mohsin@example.com','$2a$10$RtV66nKVksWY5BPoIP8YtOCsTZlLxiZNz6M8toEMdVtkWwx.covCC', '+92-321-9876543', 'USD'),
('Abuzar Mehdi',  'abuzar@example.com','$2a$10$RtV66nKVksWY5BPoIP8YtOCsTZlLxiZNz6M8toEMdVtkWwx.covCC', '+92-333-1122334', 'USD'),
('Sara Ahmed',    'sara@example.com',  '$2a$10$RtV66nKVksWY5BPoIP8YtOCsTZlLxiZNz6M8toEMdVtkWwx.covCC', NULL,              'USD');

INSERT INTO subscriptions (user_id, plan_id, amount, currency, start_date, next_billing_date, status, auto_renew) VALUES
(1,  1,  15.49, 'USD', '2024-01-15', '2026-05-15', 'active', true),
(1,  3,   9.99, 'USD', '2023-11-01', '2026-05-01', 'active', true),
(1, 14,  20.00, 'USD', '2025-03-10', '2026-05-10', 'active', true),
(1,  5,  10.00, 'USD', '2024-06-20', '2026-06-20', 'active', true),
(1,  7,   1.99, 'USD', '2023-08-05', '2026-05-05', 'active', true),
(1, 18,   4.00, 'USD', '2024-09-15', '2026-05-15', 'active', true),
(2,  2,  22.99, 'USD', '2024-02-01', '2026-05-01', 'active', true),
(2,  4,  15.99, 'USD', '2024-03-15', '2026-05-15', 'active', true),
(2, 15,  59.99, 'USD', '2023-12-10', '2026-05-10', 'active', true),
(3,  9,  14.99, 'USD', '2025-01-01', '2026-05-01', 'active', true),
(3, 13,  15.00, 'USD', '2024-04-22', '2026-05-22', 'active', true);

INSERT INTO transactions (subscription_id, user_id, amount, currency, transaction_date, billing_period_start, billing_period_end, status, payment_method, reference_no) VALUES
(1, 1, 15.49, 'USD', '2026-04-15', '2026-04-15', '2026-05-14', 'completed', 'Visa *4242', 'TXN-2604-0001'),
(1, 1, 15.49, 'USD', '2026-03-15', '2026-03-15', '2026-04-14', 'completed', 'Visa *4242', 'TXN-2603-0001'),
(1, 1, 13.99, 'USD', '2026-02-15', '2026-02-15', '2026-03-14', 'completed', 'Visa *4242', 'TXN-2602-0001'),
(2, 1,  9.99, 'USD', '2026-04-01', '2026-04-01', '2026-04-30', 'completed', 'PayPal',     'TXN-2604-0002'),
(2, 1,  9.99, 'USD', '2026-03-01', '2026-03-01', '2026-03-31', 'completed', 'PayPal',     'TXN-2603-0002'),
(3, 1, 20.00, 'USD', '2026-04-10', '2026-04-10', '2026-05-09', 'completed', 'Visa *4242', 'TXN-2604-0003'),
(3, 1, 20.00, 'USD', '2026-03-10', '2026-03-10', '2026-04-09', 'completed', 'Visa *4242', 'TXN-2603-0003'),
(1, 1, 15.49, 'USD', '2026-04-15', '2026-04-15', '2026-05-14', 'completed', 'Visa *4242', 'TXN-2604-0009'),
(9, 2, 59.99, 'USD', '2026-04-10', '2026-04-10', '2026-05-09', 'completed', 'Mastercard *8888', 'TXN-2604-0004'),
(9, 2, 54.99, 'USD', '2026-03-10', '2026-03-10', '2026-04-09', 'completed', 'Mastercard *8888', 'TXN-2603-0004');

INSERT INTO hidden_charges (transaction_id, subscription_id, user_id, charge_type, expected_amount, actual_amount, description) VALUES
(3, 1, 1, 'price_increase', 13.99, 15.49, 'Netflix Standard plan price increased from $13.99 to $15.49 (+$1.50)'),
(8, 1, 1, 'duplicate_charge', 0.00, 15.49, 'Duplicate transaction detected for Netflix on 2026-04-15. Same billing period as TXN-2604-0001'),
(10, 9, 2, 'price_increase', 54.99, 59.99, 'Adobe Creative Cloud All Apps increased from $54.99 to $59.99 (+$5.00)');

INSERT INTO alerts (user_id, subscription_id, hidden_charge_id, alert_type, title, message, severity) VALUES
(1, 1,    3, 'price_increased',    'Netflix Price Increase Detected',   'Your Netflix Standard plan went up by $1.50. New price: $15.49/month.', 'warning'),
(1, 1,    2, 'duplicate_detected', 'Duplicate Netflix Charge Found',    'A duplicate charge of $15.49 was detected for Netflix on Apr 15. Review and dispute if needed.', 'critical'),
(1, 1, NULL, 'renewal_reminder',   'Netflix Renews in 20 Days',         'Your Netflix Standard subscription renews on May 15, 2026 for $15.49.', 'info'),
(1, 3, NULL, 'renewal_reminder',   'ChatGPT Plus Renews in 15 Days',    'Your ChatGPT Plus subscription renews on May 10, 2026 for $20.00.', 'info'),
(2, 9,    3, 'price_increased',    'Adobe CC Price Increase Detected',  'Adobe Creative Cloud All Apps went up by $5.00. New price: $59.99/month.', 'warning'),
(2, 7, NULL, 'renewal_reminder',   'Netflix Premium Renews in 6 Days',  'Your Netflix Premium subscription renews on May 1, 2026 for $22.99.', 'info');

INSERT INTO price_history (subscription_id, old_amount, new_amount, changed_by, reason) VALUES
(1, 13.99, 15.49, 'trigger', 'Auto-detected price change on billing cycle'),
(9, 54.99, 59.99, 'trigger', 'Auto-detected price change on billing cycle');
