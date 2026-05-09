const { TransactionModel, HiddenChargeModel, AlertModel } = require('../models/Transaction');

// ── Transaction Controllers ────────────────────────────────────

// GET /api/transactions?month=4&year=2026&subscription_id=1
exports.getTransactions = async (req, res) => {
    try {
        const { month, year, subscription_id } = req.query;
        const data = await TransactionModel.getAllByUser(req.user.user_id, { month, year, subscription_id });
        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// POST /api/transactions/generate
exports.generateTransaction = async (req, res) => {
    try {
        const { subscription_id, payment_method } = req.body;
        if (!subscription_id)
            return res.status(400).json({ success: false, message: 'subscription_id required.' });
        const txn_id = await TransactionModel.generateTransaction(subscription_id, payment_method || 'Manual');
        res.status(201).json({ success: true, message: 'Transaction generated.', transaction_id: txn_id });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message || 'Server error.' });
    }
};

// POST /api/transactions
exports.createTransaction = async (req, res) => {
    try {
        const { subscription_id, amount, transaction_date, status, payment_method } = req.body;
        const db = require('../config/db');
        const { rows } = await db.query(`
            INSERT INTO transactions (subscription_id, user_id, amount, transaction_date, billing_period_start, billing_period_end, status, payment_method, reference_no)
            VALUES ($1, $2, $3, $4, $4, $4, $5, $6, $7)
            RETURNING transaction_id
        `, [subscription_id, req.user.user_id, amount, transaction_date, status || 'completed', payment_method, 'TXN-MANUAL-' + Date.now()]);

        res.status(201).json({ success: true, message: 'Transaction created.', transaction_id: rows[0].transaction_id });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message || 'Server error.' });
    }
};

// GET /api/transactions/report?month=4&year=2026
exports.getMonthlyReport = async (req, res) => {
    try {
        const month = req.query.month || new Date().getMonth() + 1;
        const year  = req.query.year  || new Date().getFullYear();
        const report = await TransactionModel.getMonthlyReport(req.user.user_id, month, year);
        res.json({ success: true, data: report });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// GET /api/transactions/analytics
exports.getAnalytics = async (req, res) => {
    try {
        const year  = req.query.year || new Date().getFullYear();
        const [trend, byCategory] = await Promise.all([
            TransactionModel.getMonthlyTrend(req.user.user_id),
            TransactionModel.getSpendingByCategory(req.user.user_id, year)
        ]);
        res.json({ success: true, data: { trend, byCategory } });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// ── Hidden Charge Controllers ─────────────────────────────────

// GET /api/hidden-charges?unresolved=true
exports.getHiddenCharges = async (req, res) => {
    try {
        const onlyUnresolved = req.query.unresolved === 'true';
        const data = await HiddenChargeModel.getAllByUser(req.user.user_id, onlyUnresolved);
        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// POST /api/hidden-charges
exports.createHiddenCharge = async (req, res) => {
    try {
        const { subscription_id, transaction_id, charge_type, expected_amount, actual_amount, description } = req.body;
        const db = require('../config/db');
        const { rows } = await db.query(`
            INSERT INTO hidden_charges (transaction_id, subscription_id, user_id, charge_type, expected_amount, actual_amount, description)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING hidden_charge_id
        `, [transaction_id, subscription_id, req.user.user_id, charge_type, expected_amount, actual_amount, description]);

        res.status(201).json({ success: true, message: 'Hidden charge created.', hidden_charge_id: rows[0].hidden_charge_id });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message || 'Server error.' });
    }
};

// PATCH /api/hidden-charges/:id/resolve
exports.resolveHiddenCharge = async (req, res) => {
    try {
        const { reason } = req.body;
        await HiddenChargeModel.resolve(req.params.id, req.user.user_id, reason || 'Resolved by user');
        res.json({ success: true, message: 'Hidden charge resolved.' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message || 'Server error.' });
    }
};

// ── Alert Controllers ─────────────────────────────────────────

// GET /api/alerts
exports.getAlerts = async (req, res) => {
    try {
        const data = await AlertModel.getAllByUser(req.user.user_id);
        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// POST /api/alerts
exports.createAlert = async (req, res) => {
    try {
        const { subscription_id, alert_type, title, message, severity } = req.body;
        const db = require('../config/db');
        const { rows } = await db.query(`
            INSERT INTO alerts (user_id, subscription_id, alert_type, title, message, severity)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING alert_id
        `, [req.user.user_id, subscription_id || null, alert_type, title, message, severity || 'info']);

        res.status(201).json({ success: true, message: 'Alert created.', alert_id: rows[0].alert_id });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message || 'Server error.' });
    }
};

// PATCH /api/alerts/:id/read
exports.markRead = async (req, res) => {
    try {
        await AlertModel.markRead(req.params.id, req.user.user_id);
        res.json({ success: true, message: 'Alert marked as read.' });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// PATCH /api/alerts/read-all
exports.markAllRead = async (req, res) => {
    try {
        const count = await AlertModel.markAllRead(req.user.user_id);
        res.json({ success: true, message: `${count} alerts marked as read.` });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// POST /api/alerts/generate-renewals
exports.generateRenewals = async (req, res) => {
    try {
        const { days_ahead } = req.body;
        const result = await AlertModel.generateRenewalAlerts(days_ahead || 7);
        res.json({ success: true, message: 'Renewal alerts generated.', data: result });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};
