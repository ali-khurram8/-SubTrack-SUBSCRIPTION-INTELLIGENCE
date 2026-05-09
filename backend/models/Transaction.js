const db = require('../config/db');

class TransactionModel {
    static async getAllByUser(user_id, filters = {}) {
        let query = `
            SELECT
                t.*,
                COALESCE(s.custom_name, p.service_name) AS service_name,
                p.plan_name,
                c.name      AS category,
                c.color_hex
            FROM transactions  t
            JOIN subscriptions s ON s.subscription_id = t.subscription_id
            JOIN plans         p ON p.plan_id         = s.plan_id
            JOIN categories    c ON c.category_id     = p.category_id
            WHERE t.user_id = $1
        `;
        const params = [user_id];
        let paramIndex = 2;

        if (filters.month && filters.year) {
            query += ` AND EXTRACT(MONTH FROM t.transaction_date) = $${paramIndex} AND EXTRACT(YEAR FROM t.transaction_date) = $${paramIndex + 1}`;
            params.push(filters.month, filters.year);
            paramIndex += 2;
        }
        if (filters.subscription_id) {
            query += ` AND t.subscription_id = $${paramIndex}`;
            params.push(filters.subscription_id);
            paramIndex++;
        }
        query += ' ORDER BY t.transaction_date DESC LIMIT 100';

        const { rows } = await db.query(query, params);
        return rows;
    }

    static async getMonthlyReport(user_id, month, year) {
        const breakdown = await db.query(`
            SELECT
                s.subscription_id,
                COALESCE(s.custom_name, p.service_name) AS service_name,
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
            WHERE t.user_id = $1
              AND EXTRACT(MONTH FROM t.transaction_date) = $2
              AND EXTRACT(YEAR FROM t.transaction_date) = $3
              AND t.status = 'completed'
            GROUP BY s.subscription_id, service_name, p.plan_name, c.name, c.icon, c.color_hex, s.currency
            ORDER BY amount_paid DESC
        `, [user_id, month, year]);

        const total = await db.query(`
            SELECT COALESCE(SUM(amount), 0) AS total_spent
            FROM transactions
            WHERE user_id = $1
              AND EXTRACT(MONTH FROM transaction_date) = $2
              AND EXTRACT(YEAR FROM transaction_date) = $3
              AND status = 'completed'
        `, [user_id, month, year]);

        return { breakdown: breakdown.rows, total: total.rows };
    }

    static async generateTransaction(subscription_id, payment_method) {
        const sub = await db.query(`
            SELECT s.user_id, s.amount, s.currency, p.billing_cycle, s.next_billing_date
            FROM subscriptions s
            JOIN plans p ON p.plan_id = s.plan_id
            WHERE s.subscription_id = $1 AND s.status = 'active'
        `, [subscription_id]);

        if (sub.rows.length === 0) throw new Error('Subscription not found or not active');

        const { user_id, amount, currency, billing_cycle, next_billing_date } = sub.rows[0];

        const intervalMap = {
            daily: '1 day',
            weekly: '7 days',
            monthly: '1 month',
            yearly: '1 year'
        };
        const interval = intervalMap[billing_cycle] || '1 month';

        const ref_no = `TXN-${new Date().toISOString().replace(/[-T:.Z]/g, '').slice(0, 14)}-${subscription_id}`;

        const { rows } = await db.query(`
            INSERT INTO transactions
                (subscription_id, user_id, amount, currency,
                 transaction_date, billing_period_start, billing_period_end,
                 status, payment_method, reference_no)
            VALUES ($1, $2, $3, $4, CURRENT_DATE, $5, ($5::date + $6::interval - INTERVAL '1 day')::date, 'completed', $7, $8)
            RETURNING transaction_id
        `, [subscription_id, user_id, amount, currency, next_billing_date, interval, payment_method, ref_no]);

        await db.query(`
            UPDATE subscriptions SET next_billing_date = next_billing_date + $1::interval, updated_at = NOW()
            WHERE subscription_id = $2
        `, [interval, subscription_id]);

        return rows[0].transaction_id;
    }

    static async getSpendingByCategory(user_id, year) {
        const { rows } = await db.query(`
            SELECT
                cat.name AS category,
                cat.icon AS icon,
                cat.color_hex AS color,
                SUM(t.amount) AS total_spent,
                COUNT(DISTINCT s.subscription_id) AS sub_count
            FROM transactions t
            JOIN subscriptions s ON s.subscription_id = t.subscription_id
            JOIN plans p ON p.plan_id = s.plan_id
            JOIN categories cat ON cat.category_id = p.category_id
            WHERE t.user_id = $1
              AND EXTRACT(YEAR FROM t.transaction_date) = $2
              AND t.status = 'completed'
            GROUP BY cat.category_id, cat.name, cat.icon, cat.color_hex
            ORDER BY total_spent DESC
        `, [user_id, year]);
        return rows;
    }

    static async getMonthlyTrend(user_id) {
        const { rows } = await db.query(`
            SELECT
                TO_CHAR(transaction_date, 'YYYY-MM') AS month,
                SUM(amount)  AS total,
                COUNT(*)     AS tx_count
            FROM transactions
            WHERE user_id = $1
              AND status   = 'completed'
              AND transaction_date >= CURRENT_DATE - INTERVAL '12 months'
            GROUP BY month
            ORDER BY month ASC
        `, [user_id]);
        return rows;
    }
}

class HiddenChargeModel {
    static async getAllByUser(user_id, onlyUnresolved = false) {
        let query = `
            SELECT
                hc.*,
                COALESCE(s.custom_name, p.service_name) AS service_name,
                p.plan_name,
                c.name      AS category,
                c.color_hex,
                t.transaction_date,
                t.reference_no
            FROM hidden_charges hc
            JOIN subscriptions  s ON s.subscription_id = hc.subscription_id
            JOIN plans          p ON p.plan_id         = s.plan_id
            JOIN categories     c ON c.category_id     = p.category_id
            JOIN transactions   t ON t.transaction_id  = hc.transaction_id
            WHERE hc.user_id = $1
        `;
        const params = [user_id];
        if (onlyUnresolved) { query += ' AND hc.is_resolved = false'; }
        query += ' ORDER BY hc.detected_at DESC';
        const { rows } = await db.query(query, params);
        return rows;
    }

    static async resolve(hidden_charge_id, user_id, reason) {
        const { rows } = await db.query(`
            UPDATE hidden_charges
            SET is_resolved = true,
                resolved_at = NOW(),
                description = COALESCE(description, '') || ' | Resolved: ' || $2
            WHERE hidden_charge_id = $1
            RETURNING *
        `, [hidden_charge_id, reason]);
        if (rows.length === 0) throw new Error('Hidden charge not found');

        await db.query(`
            UPDATE alerts SET is_read = true, read_at = NOW()
            WHERE hidden_charge_id = $1 AND is_read = false
        `, [hidden_charge_id]);

        return rows;
    }
}

class AlertModel {
    static async getAllByUser(user_id) {
        const { rows } = await db.query(`
            SELECT
                a.*,
                COALESCE(s.custom_name, p.service_name) AS service_name,
                c.icon AS category_icon,
                c.color_hex
            FROM alerts       a
            LEFT JOIN subscriptions  s ON s.subscription_id = a.subscription_id
            LEFT JOIN plans          p ON p.plan_id         = s.plan_id
            LEFT JOIN categories     c ON c.category_id     = p.category_id
            WHERE a.user_id = $1
            ORDER BY a.created_at DESC
            LIMIT 50
        `, [user_id]);
        return rows;
    }

    static async markRead(alert_id, user_id) {
        const { rowCount } = await db.query(
            `UPDATE alerts SET is_read = true, read_at = NOW()
             WHERE alert_id = $1 AND user_id = $2`,
            [alert_id, user_id]
        );
        return rowCount;
    }

    static async markAllRead(user_id) {
        const { rowCount } = await db.query(
            `UPDATE alerts SET is_read = true, read_at = NOW()
             WHERE user_id = $1 AND is_read = false`,
            [user_id]
        );
        return rowCount;
    }

    static async generateRenewalAlerts(daysAhead = 7) {
        const { rows } = await db.query(`
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
              AND s.next_billing_date BETWEEN CURRENT_DATE AND CURRENT_DATE + ($1 || ' days')::interval
              AND NOT EXISTS (
                  SELECT 1 FROM alerts
                  WHERE subscription_id = s.subscription_id
                    AND alert_type = 'renewal_reminder'
                    AND created_at::date = CURRENT_DATE
              )
            RETURNING *
        `, [daysAhead]);
        return rows;
    }
}

module.exports = { TransactionModel, HiddenChargeModel, AlertModel };
