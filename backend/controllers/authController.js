const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const UserModel = require('../models/User');

const generateToken = (user) =>
    jwt.sign(
        { user_id: user.user_id, email: user.email, full_name: user.full_name },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

// POST /api/auth/register
exports.register = async (req, res) => {
    try {
        const { full_name, email, password, phone, currency } = req.body;
        if (!full_name || !email || !password)
            return res.status(400).json({ success: false, message: 'full_name, email and password are required.' });

        if (password.length < 8)
            return res.status(400).json({ success: false, message: 'Password must be at least 8 characters.' });

        const existing = await UserModel.findByEmail(email);
        if (existing)
            return res.status(409).json({ success: false, message: 'Email already registered.' });

        const password_hash = await bcrypt.hash(password, 10);
        const user_id = await UserModel.create({ full_name, email, password_hash, phone, currency });

        const user = { user_id, email, full_name };
        res.status(201).json({
            success: true,
            message: 'Account created successfully.',
            token: generateToken(user),
            user
        });
    } catch (err) {
        console.error('Register error:', err);
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// POST /api/auth/login
exports.login = async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password)
            return res.status(400).json({ success: false, message: 'Email and password required.' });

        const user = await UserModel.findByEmail(email);
        if (!user)
            return res.status(401).json({ success: false, message: 'Invalid credentials.' });

        const valid = await bcrypt.compare(password, user.password_hash);
        if (!valid)
            return res.status(401).json({ success: false, message: 'Invalid credentials.' });

        const payload = { user_id: user.user_id, email: user.email, full_name: user.full_name };
        res.json({
            success: true,
            message: 'Login successful.',
            token: generateToken(payload),
            user: payload
        });
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};

// GET /api/auth/me
exports.me = async (req, res) => {
    try {
        const user = await UserModel.findById(req.user.user_id);
        if (!user) return res.status(404).json({ success: false, message: 'User not found.' });
        const stats = await UserModel.getDashboardStats(req.user.user_id);
        res.json({ success: true, user, stats });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server error.' });
    }
};
