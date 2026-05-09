// ============================================================
//  validate.js — Input validation rules (express-validator)
// ============================================================

const { body, param, query, validationResult } = require('express-validator');

// ── Shared error handler ─────────────────────────────────────
const handleValidation = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            message: 'Validation failed.',
            errors: errors.array().map(e => ({ field: e.path, message: e.msg }))
        });
    }
    next();
};

// ── Auth Validators ──────────────────────────────────────────
const registerRules = [
    body('full_name')
        .trim()
        .notEmpty().withMessage('Full name is required.')
        .isLength({ min: 2, max: 100 }).withMessage('Full name must be 2-100 characters.'),
    body('email')
        .trim()
        .notEmpty().withMessage('Email is required.')
        .isEmail().withMessage('Must be a valid email address.')
        .normalizeEmail(),
    body('password')
        .notEmpty().withMessage('Password is required.')
        .isLength({ min: 8 }).withMessage('Password must be at least 8 characters.')
        .matches(/[A-Z]/).withMessage('Password must contain at least one uppercase letter.')
        .matches(/[0-9]/).withMessage('Password must contain at least one number.'),
    body('phone')
        .optional({ values: 'falsy' })
        .trim()
        .isMobilePhone('any').withMessage('Invalid phone number.'),
    body('currency')
        .optional({ values: 'falsy' })
        .isLength({ min: 3, max: 3 }).withMessage('Currency must be a 3-letter code.')
        .isAlpha().withMessage('Currency must contain only letters.')
        .toUpperCase(),
    handleValidation
];

const loginRules = [
    body('email')
        .trim()
        .notEmpty().withMessage('Email is required.')
        .isEmail().withMessage('Must be a valid email address.')
        .normalizeEmail(),
    body('password')
        .notEmpty().withMessage('Password is required.'),
    handleValidation
];

// ── Subscription Validators ──────────────────────────────────
const createSubscriptionRules = [
    body('amount')
        .notEmpty().withMessage('Amount is required.')
        .isFloat({ min: 0.01 }).withMessage('Amount must be a positive number.'),
    body('start_date')
        .notEmpty().withMessage('Start date is required.')
        .isISO8601().withMessage('Start date must be a valid date (YYYY-MM-DD).'),
    body('end_date')
        .optional({ values: 'falsy' })
        .isISO8601().withMessage('End date must be a valid date (YYYY-MM-DD).'),
    body('billing_cycle')
        .optional({ values: 'falsy' })
        .isIn(['daily', 'weekly', 'monthly', 'yearly']).withMessage('Billing cycle must be daily, weekly, monthly, or yearly.'),
    body('currency')
        .optional({ values: 'falsy' })
        .isLength({ min: 3, max: 3 }).withMessage('Currency must be a 3-letter code.')
        .toUpperCase(),
    body('service_name')
        .optional({ values: 'falsy' })
        .trim()
        .isLength({ max: 100 }).withMessage('Service name max 100 characters.'),
    body('plan_name')
        .optional({ values: 'falsy' })
        .trim()
        .isLength({ max: 100 }).withMessage('Plan name max 100 characters.'),
    body('auto_renew')
        .optional()
        .isBoolean().withMessage('auto_renew must be true or false.'),
    handleValidation
];

const updateSubscriptionRules = [
    param('id').isInt({ min: 1 }).withMessage('Invalid subscription ID.'),
    body('amount')
        .optional()
        .isFloat({ min: 0.01 }).withMessage('Amount must be a positive number.'),
    body('status')
        .optional()
        .isIn(['active', 'paused', 'cancelled', 'expired']).withMessage('Invalid status.'),
    body('billing_cycle')
        .optional({ values: 'falsy' })
        .isIn(['daily', 'weekly', 'monthly', 'yearly']).withMessage('Invalid billing cycle.'),
    handleValidation
];

// ── Transaction Validators ───────────────────────────────────
const createTransactionRules = [
    body('subscription_id')
        .notEmpty().withMessage('Subscription ID is required.')
        .isInt({ min: 1 }).withMessage('Invalid subscription ID.'),
    body('amount')
        .notEmpty().withMessage('Amount is required.')
        .isFloat({ min: 0.01 }).withMessage('Amount must be a positive number.'),
    body('transaction_date')
        .notEmpty().withMessage('Transaction date is required.')
        .isISO8601().withMessage('Must be a valid date.'),
    body('status')
        .optional()
        .isIn(['completed', 'pending', 'failed', 'refunded']).withMessage('Invalid status.'),
    body('payment_method')
        .optional({ values: 'falsy' })
        .trim()
        .isLength({ max: 50 }).withMessage('Payment method max 50 characters.'),
    handleValidation
];

const generateTransactionRules = [
    body('subscription_id')
        .notEmpty().withMessage('Subscription ID is required.')
        .isInt({ min: 1 }).withMessage('Invalid subscription ID.'),
    body('payment_method')
        .optional({ values: 'falsy' })
        .trim()
        .isLength({ max: 50 }).withMessage('Payment method max 50 characters.'),
    handleValidation
];

// ── Hidden Charge Validators ─────────────────────────────────
const createHiddenChargeRules = [
    body('subscription_id')
        .notEmpty().withMessage('Subscription ID is required.')
        .isInt({ min: 1 }).withMessage('Invalid subscription ID.'),
    body('charge_type')
        .notEmpty().withMessage('Charge type is required.')
        .isIn(['price_increase', 'duplicate_charge', 'unexpected_fee', 'early_renewal', 'currency_change'])
        .withMessage('Invalid charge type.'),
    body('expected_amount')
        .notEmpty().withMessage('Expected amount is required.')
        .isFloat({ min: 0 }).withMessage('Expected amount must be a number.'),
    body('actual_amount')
        .notEmpty().withMessage('Actual amount is required.')
        .isFloat({ min: 0 }).withMessage('Actual amount must be a number.'),
    body('description')
        .optional({ values: 'falsy' })
        .trim()
        .isLength({ max: 500 }).withMessage('Description max 500 characters.'),
    handleValidation
];

// ── Alert Validators ─────────────────────────────────────────
const createAlertRules = [
    body('alert_type')
        .notEmpty().withMessage('Alert type is required.')
        .isIn(['renewal_reminder', 'overcharge_detected', 'duplicate_detected', 'subscription_expired', 'payment_failed', 'price_increased'])
        .withMessage('Invalid alert type.'),
    body('title')
        .trim()
        .notEmpty().withMessage('Title is required.')
        .isLength({ max: 200 }).withMessage('Title max 200 characters.'),
    body('message')
        .trim()
        .notEmpty().withMessage('Message is required.')
        .isLength({ max: 1000 }).withMessage('Message max 1000 characters.'),
    body('severity')
        .optional()
        .isIn(['info', 'warning', 'critical']).withMessage('Severity must be info, warning, or critical.'),
    handleValidation
];

// ── ID Param Validator ───────────────────────────────────────
const idParamRule = [
    param('id').isInt({ min: 1 }).withMessage('Invalid ID.'),
    handleValidation
];

module.exports = {
    registerRules,
    loginRules,
    createSubscriptionRules,
    updateSubscriptionRules,
    createTransactionRules,
    generateTransactionRules,
    createHiddenChargeRules,
    createAlertRules,
    idParamRule
};
