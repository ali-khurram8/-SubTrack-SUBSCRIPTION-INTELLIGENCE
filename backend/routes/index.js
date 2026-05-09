const express = require('express');
const router  = express.Router();
const auth    = require('../middleware/auth');
const v       = require('../middleware/validate');

const authCtrl = require('../controllers/authController');
const subCtrl  = require('../controllers/subscriptionController');
const dataCtrl = require('../controllers/dataController');

// ── Auth ─────────────────────────────────────────────────────
router.post('/auth/register', v.registerRules, authCtrl.register);
router.post('/auth/login',    v.loginRules,    authCtrl.login);
router.get ('/auth/me',  auth, authCtrl.me);

// ── Subscriptions ─────────────────────────────────────────────
router.get   ('/subscriptions/plans',               auth, subCtrl.getPlans);
router.get   ('/subscriptions',                     auth, subCtrl.getAll);
router.get   ('/subscriptions/:id',                 auth, v.idParamRule, subCtrl.getOne);
router.post  ('/subscriptions',                     auth, v.createSubscriptionRules, subCtrl.create);
router.patch ('/subscriptions/:id',                 auth, v.updateSubscriptionRules, subCtrl.update);
router.delete('/subscriptions/:id',                 auth, v.idParamRule, subCtrl.cancel);
router.get   ('/subscriptions/:id/price-history',   auth, v.idParamRule, subCtrl.getPriceHistory);

// ── Transactions ──────────────────────────────────────────────
router.get ('/transactions',          auth, dataCtrl.getTransactions);
router.post('/transactions',          auth, v.createTransactionRules, dataCtrl.createTransaction);
router.post('/transactions/generate', auth, v.generateTransactionRules, dataCtrl.generateTransaction);
router.get ('/transactions/report',   auth, dataCtrl.getMonthlyReport);
router.get ('/transactions/analytics',auth, dataCtrl.getAnalytics);

// ── Hidden Charges ────────────────────────────────────────────
router.get  ('/hidden-charges',            auth, dataCtrl.getHiddenCharges);
router.post ('/hidden-charges',            auth, v.createHiddenChargeRules, dataCtrl.createHiddenCharge);
router.patch('/hidden-charges/:id/resolve',auth, v.idParamRule, dataCtrl.resolveHiddenCharge);

// ── Alerts ────────────────────────────────────────────────────
router.get  ('/alerts',                    auth, dataCtrl.getAlerts);
router.post ('/alerts',                    auth, v.createAlertRules, dataCtrl.createAlert);
router.patch('/alerts/read-all',           auth, dataCtrl.markAllRead);
router.patch('/alerts/:id/read',           auth, v.idParamRule, dataCtrl.markRead);
router.post ('/alerts/generate-renewals',  auth, dataCtrl.generateRenewals);

module.exports = router;
