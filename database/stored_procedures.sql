-- ============================================================
--  SubTrack Stored Procedures (PostgreSQL Functions)
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- PROCEDURE 1: Monthly Expense Report
-- Returns spending breakdown by subscription for a given month
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_monthly_expense_report(
    p_user_id INT,
    p_month INT,
    p_year INT
)
RETURNS TABLE (
    subscription_id INT,
    service_name TEXT,
    plan_name VARCHAR,
    category VARCHAR,
    category_icon VARCHAR,
    color_hex VARCHAR,
    amount_paid DECIMAL,
    tx_count BIGINT,
    currency VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.subscription_id,
        COALESCE(s.custom_name, p.service_name)::TEXT AS service_name,
        p.plan_name,
        c.name AS category,
        c.icon AS category_icon,
        c.color_hex,
        SUM(t.amount) AS amount_paid,
        COUNT(t.transaction_id) AS tx_count,
        s.currency
    FROM transactions t
    JOIN subscriptions s ON s.subscription_id = t.subscription_id
    JOIN plans p ON p.plan_id = s.plan_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE t.user_id = p_user_id
      AND EXTRACT(MONTH FROM t.transaction_date) = p_month
      AND EXTRACT(YEAR FROM t.transaction_date) = p_year
      AND t.status = 'completed'
    GROUP BY s.subscription_id, service_name, p.plan_name, c.name, c.icon, c.color_hex, s.currency
    ORDER BY amount_paid DESC;
END;
$$ LANGUAGE plpgsql;


-- ──────────────────────────────────────────────────────────────
-- PROCEDURE 2: Generate Renewal Alerts
-- Creates alerts for subscriptions renewing within N days
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_generate_renewal_alerts(
    p_days_ahead INT DEFAULT 7
)
RETURNS TABLE (
    alert_id INT,
    user_id INT,
    subscription_id INT,
    title VARCHAR,
    severity VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    INSERT INTO alerts (user_id, subscription_id, alert_type, title, message, severity)
    SELECT
        s.user_id,
        s.subscription_id,
        'renewal_reminder',
        COALESCE(s.custom_name, p.service_name) || ' renews in ' ||
            (s.next_billing_date - CURRENT_DATE) ||
            CASE WHEN (s.next_billing_date - CURRENT_DATE) = 1 THEN ' day' ELSE ' days' END,
        COALESCE(s.custom_name, p.service_name) || ' will be charged ' ||
            s.currency || ' ' || s.amount || ' on ' || s.next_billing_date || '.',
        CASE WHEN (s.next_billing_date - CURRENT_DATE) <= 1 THEN 'warning' ELSE 'info' END
    FROM subscriptions s
    JOIN plans p ON p.plan_id = s.plan_id
    WHERE s.status = 'active'
      AND s.auto_renew = true
      AND s.next_billing_date BETWEEN CURRENT_DATE AND CURRENT_DATE + (p_days_ahead || ' days')::interval
      AND NOT EXISTS (
          SELECT 1 FROM alerts a
          WHERE a.subscription_id = s.subscription_id
            AND a.alert_type = 'renewal_reminder'
            AND a.created_at::date = CURRENT_DATE
      )
    RETURNING alerts.alert_id, alerts.user_id, alerts.subscription_id, alerts.title, alerts.severity;
END;
$$ LANGUAGE plpgsql;


-- ──────────────────────────────────────────────────────────────
-- PROCEDURE 3: Check Expired Subscriptions
-- Marks subscriptions past their end_date as expired
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_check_expired_subscriptions()
RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE subscriptions
       SET status = 'expired', updated_at = NOW()
     WHERE status = 'active'
       AND end_date IS NOT NULL
       AND end_date < CURRENT_DATE;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;


-- ──────────────────────────────────────────────────────────────
-- PROCEDURE 4: Generate Transaction
-- Creates a transaction for a subscription with billing period calculation
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_generate_transaction(
    p_subscription_id INT,
    p_payment_method VARCHAR DEFAULT 'Auto-Generated'
)
RETURNS INT AS $$
DECLARE
    v_user_id INT;
    v_amount DECIMAL(10,2);
    v_currency VARCHAR(3);
    v_billing_cycle VARCHAR(10);
    v_next_billing DATE;
    v_interval INTERVAL;
    v_txn_id INT;
    v_ref_no VARCHAR(100);
BEGIN
    -- Get subscription details
    SELECT s.user_id, s.amount, s.currency, p.billing_cycle, s.next_billing_date
      INTO v_user_id, v_amount, v_currency, v_billing_cycle, v_next_billing
      FROM subscriptions s
      JOIN plans p ON p.plan_id = s.plan_id
     WHERE s.subscription_id = p_subscription_id
       AND s.status = 'active';

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Subscription not found or not active';
    END IF;

    -- Determine interval
    v_interval := CASE v_billing_cycle
        WHEN 'daily'   THEN INTERVAL '1 day'
        WHEN 'weekly'  THEN INTERVAL '7 days'
        WHEN 'monthly' THEN INTERVAL '1 month'
        WHEN 'yearly'  THEN INTERVAL '1 year'
        ELSE INTERVAL '1 month'
    END;

    -- Generate reference number
    v_ref_no := 'TXN-SP-' || TO_CHAR(NOW(), 'YYYYMMDDHHMMSS') || '-' || p_subscription_id;

    -- Insert transaction
    INSERT INTO transactions
        (subscription_id, user_id, amount, currency,
         transaction_date, billing_period_start, billing_period_end,
         status, payment_method, reference_no)
    VALUES
        (p_subscription_id, v_user_id, v_amount, v_currency,
         CURRENT_DATE, v_next_billing, v_next_billing,
         'completed', p_payment_method, v_ref_no)
    RETURNING transaction_id INTO v_txn_id;

    -- Note: next_billing_date is advanced by the trigger (fn_after_transaction_insert)

    RETURN v_txn_id;
END;
$$ LANGUAGE plpgsql;


-- ──────────────────────────────────────────────────────────────
-- PROCEDURE 5: Spending By Category
-- Aggregates spending by category for a given year
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_spending_by_category(
    p_user_id INT,
    p_year INT
)
RETURNS TABLE (
    category VARCHAR,
    icon VARCHAR,
    color VARCHAR,
    total_spent DECIMAL,
    sub_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.name AS category,
        c.icon,
        c.color_hex AS color,
        SUM(t.amount) AS total_spent,
        COUNT(DISTINCT s.subscription_id) AS sub_count
    FROM transactions t
    JOIN subscriptions s ON s.subscription_id = t.subscription_id
    JOIN plans p ON p.plan_id = s.plan_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE t.user_id = p_user_id
      AND EXTRACT(YEAR FROM t.transaction_date) = p_year
      AND t.status = 'completed'
    GROUP BY c.category_id, c.name, c.icon, c.color_hex
    ORDER BY total_spent DESC;
END;
$$ LANGUAGE plpgsql;


-- ──────────────────────────────────────────────────────────────
-- PROCEDURE 6: Resolve Hidden Charge
-- Marks a hidden charge as resolved and cascades to alerts
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_resolve_hidden_charge(
    p_charge_id INT,
    p_reason VARCHAR DEFAULT 'Resolved by user'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_found BOOLEAN;
BEGIN
    UPDATE hidden_charges
       SET is_resolved = true,
           resolved_at = NOW(),
           description = COALESCE(description, '') || ' | Resolved: ' || p_reason
     WHERE hidden_charge_id = p_charge_id
       AND is_resolved = false;

    GET DIAGNOSTICS v_found = ROW_COUNT;

    IF v_found THEN
        -- Cascade: mark linked alerts as read
        UPDATE alerts
           SET is_read = true, read_at = NOW()
         WHERE hidden_charge_id = p_charge_id
           AND is_read = false;
    END IF;

    RETURN v_found;
END;
$$ LANGUAGE plpgsql;
