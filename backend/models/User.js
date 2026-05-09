const db = require('../config/db');

class UserModel {
    static async findByEmail(email) {
        const { rows } = await db.query(
            'SELECT * FROM users WHERE email = $1 AND is_active = true', [email]
        );
        return rows[0] || null;
    }

    static async findById(user_id) {
        const { rows } = await db.query(
            'SELECT user_id, full_name, email, phone, currency, created_at FROM users WHERE user_id = $1',
            [user_id]
        );
        return rows[0] || null;
    }

    static async create({ full_name, email, password_hash, phone, currency }) {
        const { rows } = await db.query(
            `INSERT INTO users (full_name, email, password_hash, phone, currency)
             VALUES ($1, $2, $3, $4, $5) RETURNING user_id`,
            [full_name, email, password_hash, phone || null, currency || 'USD']
        );
        return rows[0].user_id;
    }

    static async getDashboardStats(user_id) {
        const { rows } = await db.query(`
            SELECT
                (SELECT COUNT(*) FROM subscriptions WHERE user_id = $1 AND status = 'active') AS active_subscriptions,
                (SELECT COALESCE(SUM(amount),0) FROM transactions
                  WHERE user_id = $1
                    AND EXTRACT(MONTH FROM transaction_date) = EXTRACT(MONTH FROM CURRENT_DATE)
                    AND EXTRACT(YEAR FROM transaction_date)  = EXTRACT(YEAR FROM CURRENT_DATE)
                    AND status = 'completed')                                                   AS monthly_spend,
                (SELECT COUNT(*) FROM hidden_charges WHERE user_id = $1 AND is_resolved = false) AS unresolved_hidden_charges,
                (SELECT COUNT(*) FROM alerts WHERE user_id = $1 AND is_read = false)             AS unread_alerts
        `, [user_id]);
        return rows[0];
    }
}

module.exports = UserModel;
