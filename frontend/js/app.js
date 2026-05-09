// ============================================================
//  app.js — Global JavaScript for Subscription Tracker
// ============================================================

// ── API Configuration ─────────────────────────────────────────
const API_BASE = window.location.origin + '/api';

// ── Auth Helpers ──────────────────────────────────────────────
const Auth = {
    getToken:  () => localStorage.getItem('st_token'),
    getUser:   () => JSON.parse(localStorage.getItem('st_user') || 'null'),
    setSession: (token, user) => {
        localStorage.setItem('st_token', token);
        localStorage.setItem('st_user', JSON.stringify(user));
    },
    clearSession: () => {
        localStorage.removeItem('st_token');
        localStorage.removeItem('st_user');
    },
    isLoggedIn: () => !!localStorage.getItem('st_token'),
    requireAuth: () => {
        if (!Auth.isLoggedIn()) {
            window.location.href = '/index.html';
            return false;
        }
        return true;
    }
};

// ── API Helper ────────────────────────────────────────────────
const Api = {
    async request(method, path, body = null) {
        const opts = {
            method,
            headers: {
                'Content-Type': 'application/json',
                ...(Auth.getToken() ? { 'Authorization': `Bearer ${Auth.getToken()}` } : {})
            }
        };
        if (body) opts.body = JSON.stringify(body);

        const res = await fetch(`${API_BASE}${path}`, opts);
        const data = await res.json();

        if (res.status === 401 || res.status === 403) {
            Auth.clearSession();
            window.location.href = '/index.html';
            return;
        }

        if (!res.ok) throw new Error(data.message || 'Request failed');
        return data;
    },

    get:    (path)        => Api.request('GET',    path),
    post:   (path, body)  => Api.request('POST',   path, body),
    patch:  (path, body)  => Api.request('PATCH',  path, body),
    delete: (path)        => Api.request('DELETE', path),
};

// ── Toast Notifications ───────────────────────────────────────
const Toast = {
    container: null,
    init() {
        this.container = document.createElement('div');
        this.container.className = 'toast-container';
        document.body.appendChild(this.container);
    },
    show(message, type = 'info', duration = 3500) {
        if (!this.container) this.init();

        const icons = { success: 'bi-check-circle-fill', error: 'bi-x-circle-fill',
                        warning: 'bi-exclamation-triangle-fill', info: 'bi-info-circle-fill' };
        const colors = { success: 'var(--accent-green)', error: 'var(--accent-red)',
                         warning: 'var(--accent-orange)', info: 'var(--accent-cyan)' };

        const t = document.createElement('div');
        t.className = `toast ${type}`;
        t.innerHTML = `
            <i class="bi ${icons[type]}" style="color:${colors[type]};font-size:18px;flex-shrink:0;margin-top:1px"></i>
            <div style="flex:1">
                <div style="font-weight:600;font-size:13px;color:var(--text-primary)">${message}</div>
            </div>
            <button onclick="this.closest('.toast').remove()"
                style="background:none;border:none;color:var(--text-muted);cursor:pointer;font-size:16px;padding:0">
                <i class="bi bi-x"></i>
            </button>`;
        this.container.appendChild(t);
        setTimeout(() => t.remove(), duration);
    },
    success: (msg) => Toast.show(msg, 'success'),
    error:   (msg) => Toast.show(msg, 'error'),
    warning: (msg) => Toast.show(msg, 'warning'),
    info:    (msg) => Toast.show(msg, 'info'),
};
Toast.init();

// ── Formatting Helpers ────────────────────────────────────────
const Fmt = {
    currency: (amount, currency = 'USD') =>
        new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount),

    date: (d) => new Date(d).toLocaleDateString('en-US', { year:'numeric', month:'short', day:'numeric' }),

    relativeDate: (d) => {
        const diff = Math.ceil((new Date(d) - new Date()) / 86400000);
        if (diff < 0)  return `${Math.abs(diff)}d ago`;
        if (diff === 0) return 'Today';
        if (diff === 1) return 'Tomorrow';
        return `in ${diff} days`;
    },

    cycle: (c) => ({ daily:'day', weekly:'week', monthly:'month', yearly:'year' }[c] || c),

    chargeType: (t) => ({
        price_increase:    '📈 Price Increase',
        duplicate_charge:  '⚠️ Duplicate Charge',
        unexpected_fee:    '❓ Unexpected Fee',
        early_renewal:     '🔄 Early Renewal',
        currency_change:   '💱 Currency Change'
    }[t] || t),

    alertType: (t) => ({
        renewal_reminder:   '🔔',
        overcharge_detected:'💸',
        duplicate_detected: '⚠️',
        subscription_expired:'❌',
        payment_failed:     '💳',
        price_increased:    '📈'
    }[t] || '🔔'),

    statusBadge: (status) => {
        const map = {
            active:    'badge-active',
            paused:    'badge-paused',
            cancelled: 'badge-cancelled',
            expired:   'badge-expired'
        };
        return `<span class="badge-status ${map[status] || ''}">${status}</span>`;
    }
};

// ── Sidebar / Nav helpers ─────────────────────────────────────
function initSidebar() {
    const user = Auth.getUser();
    const pages = [
        { href:'dashboard.html',   icon:'bi-grid-fill',         label:'Dashboard' },
        { href:'subscriptions.html',icon:'bi-collection-fill',  label:'Subscriptions' },
        { href:'transactions.html', icon:'bi-credit-card-2-back-fill', label:'Transactions' },
        { href:'hidden-charges.html',icon:'bi-shield-exclamation',label:'Hidden Charges' },
        { href:'alerts.html',       icon:'bi-bell-fill',         label:'Alerts' },
        { href:'analytics.html',    icon:'bi-bar-chart-fill',    label:'Analytics' },
    ];

    const currentPage = window.location.pathname.split('/').pop();

    const nav = document.getElementById('sidebar-nav');
    if (!nav) return;

    nav.innerHTML = pages.map(p => `
        <a href="${p.href}" class="nav-link ${currentPage === p.href ? 'active' : ''}">
            <i class="bi ${p.icon}"></i>
            <span>${p.label}</span>
            ${p.href === 'alerts.html' ? '<span class="nav-badge" id="alert-count" style="display:none">0</span>' : ''}
        </a>
    `).join('');

    // Load unread alert count
    Api.get('/alerts').then(data => {
        const unread = data.data.filter(a => !a.is_read).length;
        const badge = document.getElementById('alert-count');
        if (badge && unread > 0) {
            badge.textContent = unread;
            badge.style.display = 'inline';
        }
    }).catch(() => {});

    // User info in sidebar footer
    const footer = document.getElementById('sidebar-user');
    if (footer && user) {
        footer.innerHTML = `
            <div style="display:flex;align-items:center;gap:10px;padding:8px 12px;border-radius:8px;cursor:pointer"
                 onclick="logout()">
                <div style="width:32px;height:32px;border-radius:8px;background:linear-gradient(135deg,var(--accent-cyan),#0056ff);
                    display:flex;align-items:center;justify-content:center;font-weight:700;font-size:14px;color:#000">
                    ${user.full_name[0].toUpperCase()}
                </div>
                <div style="flex:1;min-width:0">
                    <div style="font-size:13px;font-weight:600;color:var(--text-primary);overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${user.full_name}</div>
                    <div style="font-size:11px;color:var(--text-muted)">Logout</div>
                </div>
            </div>`;
    }
}

function logout() {
    Auth.clearSession();
    window.location.href = 'index.html';
}

// ── Loading skeleton ─────────────────────────────────────────
function loadingHTML(rows = 4) {
    return `<div class="loading"><i class="bi bi-arrow-repeat" style="animation:spin 1s linear infinite;font-size:24px"></i>&nbsp;Loading...</div>`;
}

// ── Spin animation ────────────────────────────────────────────
const style = document.createElement('style');
style.textContent = `@keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}`;
document.head.appendChild(style);
