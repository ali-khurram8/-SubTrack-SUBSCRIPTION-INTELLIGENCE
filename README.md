# SubTrack — Subscription Management & Hidden Charges Tracker

A full-stack web application for tracking recurring subscriptions, detecting hidden charges, and analysing spending patterns. Built with **Node.js / Express** on the backend, **PostgreSQL (Supabase)** for data, and a vanilla **HTML / CSS / JS** frontend with **Chart.js** analytics.

---

## Architecture

```
subscription-system-main/
├── backend/
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── models/
│   ├── routes/
│   └── server.js
├── frontend/
│   ├── css/style.css
│   ├── js/app.js
│   ├── index.html
│   ├── dashboard.html
│   ├── subscriptions.html
│   ├── transactions.html
│   ├── hidden-charges.html
│   ├── alerts.html
│   └── analytics.html
└── database/
    ├── schema.sql
    ├── sample_data.sql
    ├── triggers.sql
    └── stored_procedures.sql
```

---

## Features

| Area | Details |
|------|---------|
| **Auth** | JWT-based register / login with bcrypt password hashing |
| **Subscriptions** | CRUD, status management (active / paused / cancelled / expired), auto-renew tracking |
| **Transactions** | Manual + auto-generated billing, monthly reports |
| **Hidden Charges** | Detect price increases, duplicate charges, unexpected fees |
| **Alerts** | Renewal reminders, overcharge notifications, severity levels |
| **Analytics** | Chart.js line chart (monthly trend) + doughnut (category split), category breakdown table |
| **Security** | helmet HTTP headers, express-rate-limit (100 req/15 min API, 20 req/15 min auth) |
| **Validation** | express-validator on all write endpoints with structured error responses |
| **Cron** | Daily renewal alert generation via node-cron |
| **Database** | PostgreSQL triggers for price-change detection, duplicate-charge flagging, billing-date advancement |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Node.js 18+ |
| Framework | Express 4 |
| Database | PostgreSQL 15 (Supabase) |
| Auth | JSON Web Tokens + bcryptjs |
| Security | helmet, express-rate-limit, express-validator |
| Charts | Chart.js 4 |
| Styling | Custom CSS (Inter + Space Grotesk fonts) |
| Scheduling | node-cron |

---

## Prerequisites

- **Node.js** v18 or higher
- A **Supabase** project (free tier works) or any PostgreSQL 15+ instance
- **npm** (comes with Node.js)

---

## Setup

### 1. Clone the repository

```bash
git clone <repo-url>
cd subscription-system-main
```

### 2. Install dependencies

```bash
cd backend
npm install
```

### 3. Configure environment variables

Create `backend/.env`:

```env
DATABASE_URL=postgresql://<user>:<password>@<host>:6543/postgres
JWT_SECRET=change_this_to_a_random_string
JWT_EXPIRES_IN=7d
PORT=5001
CLIENT_URL=*
```

Replace the `DATABASE_URL` with your Supabase connection string (found under **Project Settings > Database > Connection string > URI**).

### 4. Set up the database

Run these SQL files **in order** in the Supabase SQL Editor (or any PostgreSQL client):

1. `database/schema.sql` — creates all tables
2. `database/sample_data.sql` — inserts demo data
3. `database/triggers.sql` — creates trigger functions
4. `database/stored_procedures.sql` — creates stored procedures

### 5. Start the server

```bash
cd backend
npm start        # production
# or
npm run dev      # with nodemon auto-reload
```

The app will be available at **http://localhost:5001**.

### 6. Demo login

If you loaded the sample data:

| Email | Password |
|-------|----------|
| `ali@example.com` | `Password123!` |

---

## Database Design

**8 tables** with foreign-key relationships:

```
users ──┬── subscriptions ──┬── transactions
        │                   ├── hidden_charges
        │                   └── price_history
        └── alerts
categories ── plans ── subscriptions
```

**4 triggers** handle automatic side-effects (billing-date advancement, price-change detection, duplicate-charge flagging, alert cleanup on cancellation).

**6 stored procedures** provide complex operations (monthly reports, renewal alerts, expired-subscription checks, spending breakdowns).

---

## License

This project is for educational purposes.
