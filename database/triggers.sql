-- ============================================================
--  SubTrack PostgreSQL Triggers
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- TRIGGER 1: After Transaction Insert
-- Purpose: Advance billing date, detect price changes, detect duplicates
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_after_transaction_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_prev_amount       DECIMAL(10,2);
    v_billing_cycle     VARCHAR(10);
    v_dup_count         INT;
    v_sub_amount        DECIMAL(10,2);
    v_hc_id             INT;
BEGIN
    -- 1. Advance next_billing_date based on billing cycle
    SELECT p.billing_cycle
      INTO v_billing_cycle
      FROM subscriptions s
      JOIN plans p ON p.plan_id = s.plan_id
     WHERE s.subscription_id = NEW.subscription_id;

    UPDATE subscriptions
       SET next_billing_date = CASE v_billing_cycle
               WHEN 'daily'   THEN NEW.billing_period_end + INTERVAL '1 day'
               WHEN 'weekly'  THEN NEW.billing_period_end + INTERVAL '7 days'
               WHEN 'monthly' THEN NEW.billing_period_end + INTERVAL '1 month'
               WHEN 'yearly'  THEN NEW.billing_period_end + INTERVAL '1 year'
               ELSE                NEW.billing_period_end + INTERVAL '1 month'
           END,
           updated_at = NOW()
     WHERE subscription_id = NEW.subscription_id;

    -- 2. Detect price change vs previous transaction
    SELECT amount
      INTO v_prev_amount
      FROM transactions
     WHERE subscription_id = NEW.subscription_id
       AND transaction_id <> NEW.transaction_id
       AND status = 'completed'
     ORDER BY transaction_date DESC
     LIMIT 1;

    SELECT amount INTO v_sub_amount
      FROM subscriptions WHERE subscription_id = NEW.subscription_id;

    IF v_prev_amount IS NOT NULL AND NEW.amount <> v_prev_amount THEN
        INSERT INTO hidden_charges
            (transaction_id, subscription_id, user_id, charge_type,
             expected_amount, actual_amount, description)
        VALUES
            (NEW.transaction_id, NEW.subscription_id, NEW.user_id,
             CASE WHEN NEW.amount > v_prev_amount THEN 'price_increase' ELSE 'unexpected_fee' END,
             v_prev_amount, NEW.amount,
             'Amount changed from $' || v_prev_amount ||
             ' to $' || NEW.amount ||
             ' (' || CASE WHEN NEW.amount > v_prev_amount THEN '+' ELSE '' END ||
             ROUND(NEW.amount - v_prev_amount, 2) || ')')
        RETURNING hidden_charge_id INTO v_hc_id;

        -- Record in price history
        INSERT INTO price_history (subscription_id, old_amount, new_amount, changed_by, reason)
        VALUES (NEW.subscription_id, v_prev_amount, NEW.amount, 'trigger',
                'Auto-detected via transaction comparison');

        -- Update subscription amount to reflect new price
        UPDATE subscriptions
           SET amount = NEW.amount, updated_at = NOW()
         WHERE subscription_id = NEW.subscription_id;

        -- Generate alert
        INSERT INTO alerts
            (user_id, subscription_id, hidden_charge_id, alert_type, title, message, severity)
        VALUES
            (NEW.user_id, NEW.subscription_id, v_hc_id,
             CASE WHEN NEW.amount > v_prev_amount THEN 'price_increased' ELSE 'overcharge_detected' END,
             CASE WHEN NEW.amount > v_prev_amount
                  THEN 'Price Increase Detected'
                  ELSE 'Unexpected Charge Change Detected' END,
             'Your subscription charge changed from $' || v_prev_amount ||
             ' to $' || NEW.amount || ' on ' || NEW.transaction_date || '.',
             CASE WHEN NEW.amount > v_prev_amount THEN 'warning' ELSE 'critical' END);
    END IF;

    -- 3. Detect duplicate charges
    SELECT COUNT(*) INTO v_dup_count
      FROM transactions
     WHERE subscription_id      = NEW.subscription_id
       AND billing_period_start = NEW.billing_period_start
       AND billing_period_end   = NEW.billing_period_end
       AND status               = 'completed'
       AND transaction_id      <> NEW.transaction_id;

    IF v_dup_count > 0 THEN
        INSERT INTO hidden_charges
            (transaction_id, subscription_id, user_id, charge_type,
             expected_amount, actual_amount, description)
        VALUES
            (NEW.transaction_id, NEW.subscription_id, NEW.user_id,
             'duplicate_charge', 0.00, NEW.amount,
             'Duplicate charge detected for billing period ' ||
             NEW.billing_period_start || ' to ' || NEW.billing_period_end)
        RETURNING hidden_charge_id INTO v_hc_id;

        INSERT INTO alerts
            (user_id, subscription_id, hidden_charge_id, alert_type, title, message, severity)
        VALUES
            (NEW.user_id, NEW.subscription_id, v_hc_id,
             'duplicate_detected',
             'Duplicate Charge Detected!',
             'A duplicate charge of $' || NEW.amount ||
             ' was detected. Check your billing statement.',
             'critical');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_after_transaction_insert
    AFTER INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION fn_after_transaction_insert();


-- ──────────────────────────────────────────────────────────────
-- TRIGGER 2: Before Subscription Update (Price History)
-- Purpose: Log price changes to price_history table
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_before_subscription_update()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.amount IS DISTINCT FROM NEW.amount THEN
        INSERT INTO price_history (subscription_id, old_amount, new_amount, changed_by, reason)
        VALUES (NEW.subscription_id, OLD.amount, NEW.amount, 'user',
                'Manual price update');
    END IF;
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_before_subscription_update
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION fn_before_subscription_update();


-- ──────────────────────────────────────────────────────────────
-- TRIGGER 3: After Subscription Status Change
-- Purpose: Clear pending alerts when subscription is cancelled/expired
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_after_subscription_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IN ('cancelled', 'expired') AND OLD.status = 'active' THEN
        UPDATE alerts
           SET is_read = true, read_at = NOW()
         WHERE subscription_id = NEW.subscription_id
           AND is_read = false;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_after_subscription_status_change
    AFTER UPDATE OF status ON subscriptions
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION fn_after_subscription_status_change();


-- ──────────────────────────────────────────────────────────────
-- TRIGGER 4: After Hidden Charge Resolved
-- Purpose: Mark linked alerts as read when charge is resolved
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_after_hidden_charge_resolved()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_resolved = true AND OLD.is_resolved = false THEN
        UPDATE alerts
           SET is_read = true, read_at = NOW()
         WHERE hidden_charge_id = NEW.hidden_charge_id
           AND is_read = false;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_after_hidden_charge_resolved
    AFTER UPDATE OF is_resolved ON hidden_charges
    FOR EACH ROW
    WHEN (NEW.is_resolved = true AND OLD.is_resolved = false)
    EXECUTE FUNCTION fn_after_hidden_charge_resolved();
