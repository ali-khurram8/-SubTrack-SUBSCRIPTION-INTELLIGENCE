-- ============================================================
--  SUBSCRIPTION MANAGEMENT & HIDDEN CHARGES TRACKER SYSTEM
--  Database Schema | PostgreSQL (Supabase)
-- ============================================================

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_currency CHECK (LENGTH(currency) = 3)
);

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    icon VARCHAR(50) NOT NULL DEFAULT 'bi-tag',
    color_hex CHAR(7) NOT NULL DEFAULT '#6c757d'
);

CREATE TABLE plans (
    plan_id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    plan_name VARCHAR(100) NOT NULL,
    category_id INT NOT NULL REFERENCES categories(category_id),
    billing_cycle VARCHAR(10) NOT NULL DEFAULT 'monthly'
        CHECK (billing_cycle IN ('daily','weekly','monthly','yearly')),
    base_price DECIMAL(10, 2) NOT NULL CHECK (base_price >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    logo_url VARCHAR(255),
    website_url VARCHAR(255),
    CONSTRAINT uq_plan UNIQUE (service_name, plan_name, billing_cycle)
);

CREATE TABLE subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    plan_id INT NOT NULL REFERENCES plans(plan_id),
    custom_name VARCHAR(150),
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    start_date DATE NOT NULL,
    next_billing_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','paused','cancelled','expired')),
    auto_renew BOOLEAN NOT NULL DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sub_next_billing ON subscriptions (next_billing_date, status);
CREATE INDEX idx_sub_user ON subscriptions (user_id);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    subscription_id INT NOT NULL REFERENCES subscriptions(subscription_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    transaction_date DATE NOT NULL,
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'completed'
        CHECK (status IN ('pending','completed','failed','refunded')),
    payment_method VARCHAR(80),
    reference_no VARCHAR(100) UNIQUE,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_txn_user_date ON transactions (user_id, transaction_date);
CREATE INDEX idx_txn_sub ON transactions (subscription_id);

CREATE TABLE hidden_charges (
    hidden_charge_id SERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    subscription_id INT NOT NULL REFERENCES subscriptions(subscription_id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    charge_type VARCHAR(30) NOT NULL
        CHECK (charge_type IN ('price_increase','duplicate_charge','unexpected_fee','early_renewal','currency_change')),
    expected_amount DECIMAL(10, 2) NOT NULL,
    actual_amount DECIMAL(10, 2) NOT NULL,
    difference DECIMAL(10, 2) GENERATED ALWAYS AS (actual_amount - expected_amount) STORED,
    description TEXT,
    detected_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_resolved BOOLEAN NOT NULL DEFAULT false,
    resolved_at TIMESTAMP
);

CREATE INDEX idx_hc_user ON hidden_charges (user_id, is_resolved);
CREATE INDEX idx_hc_sub ON hidden_charges (subscription_id);

CREATE TABLE alerts (
    alert_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    subscription_id INT REFERENCES subscriptions(subscription_id) ON DELETE SET NULL,
    hidden_charge_id INT REFERENCES hidden_charges(hidden_charge_id) ON DELETE SET NULL,
    alert_type VARCHAR(30) NOT NULL
        CHECK (alert_type IN ('renewal_reminder','overcharge_detected','duplicate_detected','subscription_expired','payment_failed','price_increased')),
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(10) NOT NULL DEFAULT 'info'
        CHECK (severity IN ('info','warning','critical')),
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    read_at TIMESTAMP
);

CREATE INDEX idx_alert_user_read ON alerts (user_id, is_read);

CREATE TABLE price_history (
    history_id SERIAL PRIMARY KEY,
    subscription_id INT NOT NULL REFERENCES subscriptions(subscription_id) ON DELETE CASCADE,
    old_amount DECIMAL(10, 2) NOT NULL,
    new_amount DECIMAL(10, 2) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    changed_by VARCHAR(10) NOT NULL DEFAULT 'system'
        CHECK (changed_by IN ('user','system','trigger')),
    reason VARCHAR(255)
);
