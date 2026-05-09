const db = require('../config/db');

class SubscriptionModel {
    static async getAllByUser(user_id) {
        const { rows } = await db.query(`
            SELECT
                s.subscription_id,
                COALESCE(s.custom_name, p.service_name) AS service_name,
                p.service_name AS original_service,
                p.plan_name,
                p.billing_cycle,
                s.amount,
                s.currency,
                s.start_date,
                s.next_billing_date,
                s.end_date,
                s.status,
                s.auto_renew,
                s.notes,
                c.name       AS category,
                c.icon       AS category_icon,
                c.color_hex,
                (s.next_billing_date - CURRENT_DATE) AS days_until_renewal
            FROM subscriptions s
            JOIN plans      p ON p.plan_id     = s.plan_id
            JOIN categories c ON c.category_id = p.category_id
            WHERE s.user_id = $1
            ORDER BY s.next_billing_date ASC
        `, [user_id]);
        return rows;
    }

    static async getById(subscription_id, user_id) {
        const { rows } = await db.query(`
            SELECT
                s.*,
                COALESCE(s.custom_name, p.service_name) AS service_name,
                p.service_name AS original_service,
                p.plan_name,
                p.billing_cycle,
                c.name  AS category,
                c.icon  AS category_icon,
                c.color_hex
            FROM subscriptions s
            JOIN plans      p ON p.plan_id     = s.plan_id
            JOIN categories c ON c.category_id = p.category_id
            WHERE s.subscription_id = $1 AND s.user_id = $2
        `, [subscription_id, user_id]);
        return rows[0] || null;
    }

    static async create({ user_id, plan_id, custom_name, amount, currency, start_date, end_date, auto_renew, notes }) {
        const { rows } = await db.query(`
            INSERT INTO subscriptions
                (user_id, plan_id, custom_name, amount, currency, start_date, next_billing_date, end_date, auto_renew, notes)
            SELECT $1, $2, $3, $4, $5, $6::date,
                CASE billing_cycle
                    WHEN 'daily'   THEN $6::date + INTERVAL '1 day'
                    WHEN 'weekly'  THEN $6::date + INTERVAL '7 days'
                    WHEN 'monthly' THEN $6::date + INTERVAL '1 month'
                    WHEN 'yearly'  THEN $6::date + INTERVAL '1 year'
                END,
                $7, $8, $9
            FROM plans WHERE plan_id = $2
            RETURNING subscription_id
        `, [user_id, plan_id, custom_name || null, amount, currency || 'USD',
            start_date, end_date || null, auto_renew ?? true, notes || null]);
        return rows[0].subscription_id;
    }

    static async update(subscription_id, user_id, fields) {
        const allowed = ['custom_name', 'amount', 'currency', 'end_date', 'status', 'auto_renew', 'notes'];
        const setClauses = [];
        const values = [];
        let paramIndex = 1;
        for (const key of allowed) {
            if (fields[key] !== undefined) {
                setClauses.push(`${key} = $${paramIndex}`);
                values.push(fields[key]);
                paramIndex++;
            }
        }
        if (!setClauses.length) throw new Error('No valid fields to update');
        values.push(subscription_id, user_id);
        const { rowCount } = await db.query(
            `UPDATE subscriptions SET ${setClauses.join(', ')} WHERE subscription_id = $${paramIndex} AND user_id = $${paramIndex + 1}`,
            values
        );
        return rowCount;
    }

    static async delete(subscription_id, user_id) {
        const { rowCount } = await db.query(
            `UPDATE subscriptions SET status = 'cancelled', updated_at = NOW()
             WHERE subscription_id = $1 AND user_id = $2`,
            [subscription_id, user_id]
        );
        return rowCount;
    }

    static async getPlans() {
        const { rows } = await db.query(`
            SELECT p.*, c.name AS category, c.icon, c.color_hex
              FROM plans p
              JOIN categories c ON c.category_id = p.category_id
             ORDER BY c.name, p.service_name, p.plan_name
        `);
        return rows;
    }

    static async getPriceHistory(subscription_id, user_id) {
        const { rows } = await db.query(`
            SELECT ph.*
              FROM price_history ph
              JOIN subscriptions s ON s.subscription_id = ph.subscription_id
             WHERE ph.subscription_id = $1 AND s.user_id = $2
             ORDER BY ph.changed_at DESC
        `, [subscription_id, user_id]);
        return rows;
    }
}

module.exports = SubscriptionModel;
