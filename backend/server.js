require('dotenv').config();
const express    = require('express');
const path       = require('path');
const cors       = require('cors');
const helmet     = require('helmet');
const rateLimit  = require('express-rate-limit');
const cron       = require('node-cron');
const { AlertModel } = require('./models/Transaction');

const app = express();

// ── Security Middleware ──────────────────────────────────────
app.use(helmet({
    contentSecurityPolicy: false,   // disabled so inline <script> in frontend pages works
    crossOriginEmbedderPolicy: false
}));

// ── Rate Limiting ────────────────────────────────────────────
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,      // 15-minute window
    max: 100,                       // limit each IP to 100 requests per window
    standardHeaders: true,          // Return rate limit info in `RateLimit-*` headers
    legacyHeaders: false,
    message: { success: false, message: 'Too many requests, please try again after 15 minutes.' }
});

const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 20,                        // stricter limit for auth endpoints
    message: { success: false, message: 'Too many login attempts, please try again later.' }
});

// ── General Middleware ────────────────────────────────────────
app.use(cors({
    origin: process.env.CLIENT_URL || '*',
    methods: ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true }));

// ── Serve Frontend Static Files ──────────────────────────────
app.use(express.static(path.join(__dirname, '..', 'frontend')));

// ── API Routes ───────────────────────────────────────────────
app.use('/api/auth/login',    authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api', apiLimiter, require('./routes/index'));

// ── 404 handler ───────────────────────────────────────────────
app.use((req, res) => {
    res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` });
});

// ── Global error handler ──────────────────────────────────────
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
});

// ── Scheduled Jobs (node-cron) ────────────────────────────────
// Every day at 00:00 — generate renewal alerts for next 7 days
cron.schedule('0 0 * * *', async () => {
    console.log('🕐 Running daily renewal alert generation...');
    try {
        await AlertModel.generateRenewalAlerts(7);
        console.log('✅ Renewal alerts generated');
    } catch (err) {
        console.error('❌ Cron job failed:', err.message);
    }
});

// ── Start Server ──────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`\n🚀 Server running on http://localhost:${PORT}`);
    console.log(`📡 API Base: http://localhost:${PORT}/api`);
    console.log(`🌐 Accepting requests from: ${process.env.CLIENT_URL || '*'}\n`);
});
