-- ============================================================
--  SubTrack Database Schema (PostgreSQL / Supabase)
-- ============================================================

-- 1. Users
CREATE TABLE users (
    user_id       SERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    phone         VARCHAR(20),
    currency      VARCHAR(3) DEFAULT 'USD',
    is_active     BOOLEAN DEFAULT true,
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

-- 2. Categories
CREATE TABLE categories (
    category_id  SERIAL PRIMARY KEY,
    name         VARCHAR(50) NOT NULL UNIQUE,
    icon         VARCHAR(50) DEFAULT 'bi-tag',
    color_hex    VARCHAR(7) DEFAULT '#7c5cfc',
    description  VARCHAR(200)
);

-- 3. Plans
CREATE TABLE plans (
    plan_id        SERIAL PRIMARY KEY,
    service_name   VARCHAR(100) NOT NULL,
    plan_name      VARCHAR(100) NOT NULL,
    category_id    INT REFERENCES categories(category_id),
    billing_cycle  VARCHAR(10) NOT NULL CHECK (billing_cycle IN ('daily','weekly','monthly','yearly')),
    base_price     DECIMAL(10,2) NOT NULL,
    currency       VARCHAR(3) DEFAULT 'USD',
    description    VARCHAR(300),
    website_url    VARCHAR(255),
    created_at     TIMESTAMP DEFAULT NOW()
);

-- 4. Subscriptions
CREATE TABLE subscriptions (
    subscription_id   SERIAL PRIMARY KEY,
    user_id           INT NOT NULL REFERENCES users(user_id),
    plan_id           INT NOT NULL REFERENCES plans(plan_id),
    custom_name       VARCHAR(100),
    amount            DECIMAL(10,2) NOT NULL,
    currency          VARCHAR(3) DEFAULT 'USD',
    start_date        DATE NOT NULL,
    next_billing_date DATE,
    end_date          DATE,
    status            VARCHAR(10) DEFAULT 'active' CHECK (status IN ('active','paused','cancelled','expired')),
    auto_renew        BOOLEAN DEFAULT true,
    notes             TEXT,
    created_at        TIMESTAMP DEFAULT NOW(),
    updated_at        TIMESTAMP DEFAULT NOW()
);

-- 5. Transactions
CREATE TABLE transactions (
    transaction_id      SERIAL PRIMARY KEY,
    subscription_id     INT NOT NULL REFERENCES subscriptions(subscription_id),
    user_id             INT NOT NULL REFERENCES users(user_id),
    amount              DECIMAL(10,2) NOT NULL,
    currency            VARCHAR(3) DEFAULT 'USD',
    transaction_date    DATE NOT NULL,
    billing_period_start DATE,
    billing_period_end   DATE,
    status              VARCHAR(10) DEFAULT 'completed' CHECK (status IN ('completed','pending','failed','refunded')),
    payment_method      VARCHAR(50),
    reference_no        VARCHAR(100),
    created_at          TIMESTAMP DEFAULT NOW()
);

-- 6. Hidden Charges
CREATE TABLE hidden_charges (
    hidden_charge_id  SERIAL PRIMARY KEY,
    transaction_id    INT REFERENCES transactions(transaction_id),
    subscription_id   INT NOT NULL REFERENCES subscriptions(subscription_id),
    user_id           INT NOT NULL REFERENCES users(user_id),
    charge_type       VARCHAR(20) NOT NULL CHECK (charge_type IN ('price_increase','duplicate_charge','unexpected_fee','early_renewal','currency_change')),
    expected_amount   DECIMAL(10,2),
    actual_amount     DECIMAL(10,2),
    description       TEXT,
    is_resolved       BOOLEAN DEFAULT false,
    resolved_at       TIMESTAMP,
    detected_at       TIMESTAMP DEFAULT NOW()
);

-- 7. Alerts
CREATE TABLE alerts (
    alert_id          SERIAL PRIMARY KEY,
    user_id           INT NOT NULL REFERENCES users(user_id),
    subscription_id   INT REFERENCES subscriptions(subscription_id),
    hidden_charge_id  INT REFERENCES hidden_charges(hidden_charge_id),
    alert_type        VARCHAR(25) NOT NULL CHECK (alert_type IN ('renewal_reminder','overcharge_detected','duplicate_detected','subscription_expired','payment_failed','price_increased')),
    title             VARCHAR(200) NOT NULL,
    message           TEXT,
    severity          VARCHAR(10) DEFAULT 'info' CHECK (severity IN ('info','warning','critical')),
    is_read           BOOLEAN DEFAULT false,
    read_at           TIMESTAMP,
    created_at        TIMESTAMP DEFAULT NOW()
);

-- 8. Price History
CREATE TABLE price_history (
    history_id       SERIAL PRIMARY KEY,
    subscription_id  INT NOT NULL REFERENCES subscriptions(subscription_id),
    old_amount       DECIMAL(10,2) NOT NULL,
    new_amount       DECIMAL(10,2) NOT NULL,
    changed_by       VARCHAR(50) DEFAULT 'user',
    reason           VARCHAR(200),
    changed_at       TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_hidden_charges_user ON hidden_charges(user_id);
CREATE INDEX idx_alerts_user ON alerts(user_id);
CREATE INDEX idx_alerts_unread ON alerts(user_id, is_read);
