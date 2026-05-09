const SubscriptionModel = require('../models/Subscription');

// GET /api/subscriptions
exports.getAll = async (req, res) => {
    try {
        const subs = await SubscriptionModel.getAllByUser(req.user.user_id);
        res.json({ success: true, data: subs });
    } catch (err) {
        console.error(err);
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// GET /api/subscriptions/plans
exports.getPlans = async (req, res) => {
    try {
        const plans = await SubscriptionModel.getPlans();
        res.json({ success: true, data: plans });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// GET /api/subscriptions/:id
exports.getOne = async (req, res) => {
    try {
        const sub = await SubscriptionModel.getById(req.params.id, req.user.user_id);
        if (!sub) return res.status(404).json({ success: false, message: 'Subscription not found.' });
        res.json({ success: true, data: sub });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// POST /api/subscriptions
exports.create = async (req, res) => {
    try {
        let { plan_id, service_name, plan_name, category, billing_cycle, custom_name, amount, currency, start_date, end_date, auto_renew, notes } = req.body;
        if (!amount || !start_date)
            return res.status(400).json({ success: false, message: 'amount and start_date are required.' });

        if (!plan_id && service_name && plan_name) {
            const db = require('../config/db');
            let catId = 10;
            if (category) {
                const catRes = await db.query('SELECT category_id FROM categories WHERE name = $1', [category]);
                if (catRes.rows.length > 0) catId = catRes.rows[0].category_id;
                else {
                    const insCat = await db.query('INSERT INTO categories (name) VALUES ($1) RETURNING category_id', [category]);
                    catId = insCat.rows[0].category_id;
                }
            }

            const existingPlan = await db.query('SELECT plan_id FROM plans WHERE service_name = $1 AND plan_name = $2 AND billing_cycle = $3', [service_name, plan_name, billing_cycle || 'monthly']);
            if (existingPlan.rows.length > 0) {
                plan_id = existingPlan.rows[0].plan_id;
            } else {
                const insPlan = await db.query('INSERT INTO plans (service_name, plan_name, category_id, billing_cycle, base_price, currency) VALUES ($1, $2, $3, $4, $5, $6) RETURNING plan_id',
                [service_name, plan_name, catId, billing_cycle || 'monthly', amount, currency || 'USD']);
                plan_id = insPlan.rows[0].plan_id;
            }
        }

        if (!plan_id)
            return res.status(400).json({ success: false, message: 'plan_id or service details are required.' });

        const id = await SubscriptionModel.create({
            user_id: req.user.user_id,
            plan_id, custom_name, amount, currency, start_date, end_date, auto_renew, notes
        });
        const sub = await SubscriptionModel.getById(id, req.user.user_id);
        res.status(201).json({ success: true, message: 'Subscription added.', data: sub });
    } catch (err) {
        console.error(err);
        res.status(500).json({ success: false, message: err.message || 'Server error.' });
    }
};

// PATCH /api/subscriptions/:id
exports.update = async (req, res) => {
    try {
        const affected = await SubscriptionModel.update(req.params.id, req.user.user_id, req.body);
        if (!affected) return res.status(404).json({ success: false, message: 'Subscription not found.' });
        const sub = await SubscriptionModel.getById(req.params.id, req.user.user_id);
        res.json({ success: true, message: 'Subscription updated.', data: sub });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message || 'Server error.' });
    }
};

// DELETE /api/subscriptions/:id  (soft delete → cancelled)
exports.cancel = async (req, res) => {
    try {
        const affected = await SubscriptionModel.delete(req.params.id, req.user.user_id);
        if (!affected) return res.status(404).json({ success: false, message: 'Subscription not found.' });
        res.json({ success: true, message: 'Subscription cancelled.' });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// GET /api/subscriptions/:id/price-history
exports.getPriceHistory = async (req, res) => {
    try {
        const history = await SubscriptionModel.getPriceHistory(req.params.id, req.user.user_id);
        res.json({ success: true, data: history });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};
