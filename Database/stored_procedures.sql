-- ============================================================
--  STORED PROCEDURES (Functions) — PostgreSQL (Supabase)
--  Subscription Management & Hidden Charges Tracker
-- ============================================================

-- ── SP 1 ──────────────────────────────────────────────────────
-- sp_monthly_expense_report
-- Returns per-subscription breakdown for a given user and month/year
-- Usage: SELECT * FROM sp_monthly_expense_report(1, 4, 2026);
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_monthly_expense_report(
    p_user_id INT,
    p_month INT,
    p_year INT
)
RETURNS TABLE (
    subscription_id INT,
    service_name VARCHAR,
    plan_name VARCHAR,
    category VARCHAR,
    category_icon VARCHAR,
    color_hex CHAR(7),
    amount_paid DECIMAL,
    tx_count BIGINT,
    currency CHAR(3)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.subscription_id,
        COALESCE(s.custom_name, p.service_name)::VARCHAR AS service_name,
        p.plan_name::VARCHAR,
        c.name::VARCHAR AS category,
        c.icon::VARCHAR AS category_icon,
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


-- ── SP 2 ──────────────────────────────────────────────────────
-- sp_generate_renewal_alerts
-- Inserts renewal alerts for active subscriptions due within p_days_ahead days
-- Usage: SELECT * FROM sp_generate_renewal_alerts(7);
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_generate_renewal_alerts(
    p_days_ahead INT
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
        (COALESCE(s.custom_name, p.service_name) || ' renews in ' ||
            (s.next_billing_date - CURRENT_DATE) ||
            CASE WHEN (s.next_billing_date - CURRENT_DATE) = 1 THEN ' day' ELSE ' days' END)::VARCHAR(200),
        (COALESCE(s.custom_name, p.service_name) || ' will be charged ' ||
            s.currency || ' ' || s.amount || ' on ' || s.next_billing_date || '.')::TEXT,
        CASE WHEN (s.next_billing_date - CURRENT_DATE) <= 1 THEN 'warning' ELSE 'info' END
    FROM subscriptions s
    JOIN plans p ON p.plan_id = s.plan_id
    WHERE s.status = 'active'
      AND s.auto_renew = true
      AND s.next_billing_date BETWEEN CURRENT_DATE AND CURRENT_DATE + (p_days_ahead || ' days')::INTERVAL
      AND NOT EXISTS (
          SELECT 1 FROM alerts a
          WHERE a.subscription_id = s.subscription_id
            AND a.alert_type = 'renewal_reminder'
            AND a.created_at::DATE = CURRENT_DATE
      )
    RETURNING alerts.alert_id, alerts.user_id, alerts.subscription_id,
              alerts.title::VARCHAR, alerts.severity::VARCHAR;
END;
$$ LANGUAGE plpgsql;


-- ── SP 3 ──────────────────────────────────────────────────────
-- sp_check_expired_subscriptions
-- Marks subscriptions as 'expired' if end_date has passed
-- and generates expiry alerts
-- Usage: SELECT * FROM sp_check_expired_subscriptions();
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_check_expired_subscriptions()
RETURNS TABLE (
    expired_subscription_id INT,
    expired_user_id INT,
    service_name VARCHAR
) AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT s.subscription_id, s.user_id,
               COALESCE(s.custom_name, p.service_name) AS svc_name
        FROM subscriptions s
        JOIN plans p ON p.plan_id = s.plan_id
        WHERE s.status = 'active'
          AND s.end_date IS NOT NULL
          AND s.end_date < CURRENT_DATE
    LOOP
        UPDATE subscriptions
           SET status = 'expired', updated_at = NOW()
         WHERE subscriptions.subscription_id = rec.subscription_id;

        INSERT INTO alerts (user_id, subscription_id, alert_type, title, message, severity)
        VALUES (
            rec.user_id,
            rec.subscription_id,
            'subscription_expired',
            rec.svc_name || ' subscription expired',
            'Your ' || rec.svc_name || ' subscription has expired. Renew to continue service.',
            'warning'
        );

        expired_subscription_id := rec.subscription_id;
        expired_user_id := rec.user_id;
        service_name := rec.svc_name::VARCHAR;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- ── SP 4 ──────────────────────────────────────────────────────
-- sp_generate_transaction
-- Manually trigger a billing transaction for a subscription
-- Usage: SELECT * FROM sp_generate_transaction(1, 'Visa *4242');
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_generate_transaction(
    p_subscription_id INT,
    p_payment_method VARCHAR(80)
)
RETURNS TABLE (
    transaction_id INT
) AS $$
DECLARE
    v_user_id     INT;
    v_amount      DECIMAL(10,2);
    v_currency    CHAR(3);
    v_cycle       VARCHAR(10);
    v_next_bill   DATE;
    v_period_end  DATE;
    v_ref_no      VARCHAR(100);
    v_txn_id      INT;
BEGIN
    SELECT s.user_id, s.amount, s.currency, p.billing_cycle, s.next_billing_date
      INTO v_user_id, v_amount, v_currency, v_cycle, v_next_bill
      FROM subscriptions s
      JOIN plans p ON p.plan_id = s.plan_id
     WHERE s.subscription_id = p_subscription_id
       AND s.status = 'active';

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Subscription not found or not active';
    END IF;

    v_period_end := CASE v_cycle
        WHEN 'daily'   THEN (v_next_bill + INTERVAL '1 day'   - INTERVAL '1 day')::DATE
        WHEN 'weekly'  THEN (v_next_bill + INTERVAL '7 days'  - INTERVAL '1 day')::DATE
        WHEN 'monthly' THEN (v_next_bill + INTERVAL '1 month' - INTERVAL '1 day')::DATE
        WHEN 'yearly'  THEN (v_next_bill + INTERVAL '1 year'  - INTERVAL '1 day')::DATE
        ELSE                (v_next_bill + INTERVAL '1 month' - INTERVAL '1 day')::DATE
    END;

    v_ref_no := 'TXN-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' || p_subscription_id;

    INSERT INTO transactions
        (subscription_id, user_id, amount, currency,
         transaction_date, billing_period_start, billing_period_end,
         status, payment_method, reference_no)
    VALUES
        (p_subscription_id, v_user_id, v_amount, v_currency,
         CURRENT_DATE, v_next_bill, v_period_end,
         'completed', p_payment_method, v_ref_no)
    RETURNING transactions.transaction_id INTO v_txn_id;

    transaction_id := v_txn_id;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;


-- ── SP 5 ──────────────────────────────────────────────────────
-- sp_spending_by_category
-- Returns spending totals grouped by category for a user
-- Usage: SELECT * FROM sp_spending_by_category(1, 2026);
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_spending_by_category(
    p_user_id INT,
    p_year INT
)
RETURNS TABLE (
    category VARCHAR,
    icon VARCHAR,
    color CHAR(7),
    total_spent DECIMAL,
    sub_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        cat.name::VARCHAR AS category,
        cat.icon::VARCHAR AS icon,
        cat.color_hex AS color,
        SUM(t.amount) AS total_spent,
        COUNT(DISTINCT s.subscription_id) AS sub_count
    FROM transactions t
    JOIN subscriptions s ON s.subscription_id = t.subscription_id
    JOIN plans p ON p.plan_id = s.plan_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE t.user_id = p_user_id
      AND EXTRACT(YEAR FROM t.transaction_date) = p_year
      AND t.status = 'completed'
    GROUP BY cat.category_id, cat.name, cat.icon, cat.color_hex
    ORDER BY total_spent DESC;
END;
$$ LANGUAGE plpgsql;


-- ── SP 6 ──────────────────────────────────────────────────────
-- sp_resolve_hidden_charge
-- Marks a hidden charge as resolved and notes the reason
-- Usage: SELECT * FROM sp_resolve_hidden_charge(2, 'Disputed and refunded');
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sp_resolve_hidden_charge(
    p_hidden_charge_id INT,
    p_reason VARCHAR(255)
)
RETURNS TABLE (
    result TEXT
) AS $$
DECLARE
    v_rows INT;
BEGIN
    UPDATE hidden_charges
       SET is_resolved = true,
           resolved_at = NOW(),
           description = COALESCE(description, '') || ' | Resolved: ' || p_reason
     WHERE hidden_charge_id = p_hidden_charge_id;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Hidden charge not found';
    END IF;

    -- Auto-mark linked alert as read (also handled by trigger 4)
    UPDATE alerts
       SET is_read = true, read_at = NOW()
     WHERE hidden_charge_id = p_hidden_charge_id
       AND is_read = false;

    result := 'Resolved successfully';
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;
