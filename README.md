# QueueLess

QueueLess is an efficient, resilient clinic appointment and real-time queue management system designed for healthcare environments with unpredictable arrival patterns, walk-ins, and potential connectivity constraints.

> [!CAUTION]
> **SRS Status & Compliance Notice**:
> This project is currently in **DRAFT / DEMO** status. It is configured exclusively for **synthetic data only** and is **NOT approved for real patient data** or clinical production use. Ensure all testing adheres strictly to synthetic data generators.

---

## Technical Stack

- **Frontend**: Plain HTML5, CSS3, vanilla JavaScript (native ES modules). Zero frontend frameworks, zero build step, zero CDN dependencies, zero external web fonts, zero analytics trackers.
- **Backend**: Node.js (LTS), Express.js, REST API served under `/api/v1`.
- **Database**: PostgreSQL with plain SQL numbered migrations (no ORM), using the native `pg` client library.
- **Testing & Quality**: Jest, Supertest, ESLint (flat config), Prettier.
- **CI / CD**: GitHub Actions using a PostgreSQL service container.
- **Container Policy**: No Docker, Docker Compose, or container runtimes inside application code or development environments.

---

## Core System Architectural Rules

1. **Multi-tenancy Readiness**: One clinic initially, but all clinic-owned tables carry a mandatory `clinic_id` column.
2. **Timezone Discipline**: The server stores all timestamps strictly in UTC (`TZ=UTC`), and converts to `Africa/Addis_Ababa` for presentation and localized business day boundaries.
3. **Localization (i18n)**: All user-facing strings live in locale files (`frontend/locales/en.json`, `am.json`, `om.json`) and must never be hardcoded in application markup.
4. **Layered Backend**: Strict unidirectional data flow: `Routes -> Controllers -> Services -> Repositories`. Core business rules (queue ordering, No-Show thresholds, dynamic ETAs) reside exclusively in services.
5. **Cross-Cutting Middleware**: Enforces session auth, role-based access control (RBAC with deny-by-default), sliding-window rate limiting, CSRF validation, input validation, HTTP security headers, error normalization, and request idempotency keys (`Idempotency-Key`).
6. **Data Privacy & Auditing**: System activity log is append-only. Application logs and URLs must never contain personal data (PII) or patient health information.
7. **Secret Management**: Configuration secrets must remain strictly in `.env`. Never commit `.env` to Git repository history.

---

## Prerequisites

- **Node.js**: LTS version 20.x or higher (tested on Node v24 LTS).
- **PostgreSQL**: Locally installed and running instance (v14+ recommended).
- **Git**: v2.30+

---

## Quickstart & Local Setup

### 1. Clone & Install Dependencies

```bash
git clone <repository-url> queueless
cd queueless
npm install
```

### 2. Configure Environment

Copy the example environment template:

```bash
cp .env.example .env
```

Edit `.env` to match your local PostgreSQL credentials:

```ini
PORT=3000
NODE_ENV=development
APP_MODE=demo
TZ=UTC
DISPLAY_TIMEZONE=Africa/Addis_Ababa
DATABASE_URL=postgres://queueless:queueless@localhost:5432/queueless_dev
SESSION_SECRET=a-secure-random-64-character-secret-key
```

### 3. Setup Database & Run Migrations

Ensure your local PostgreSQL service is running, then initialize the database and apply the plain SQL schema:

```bash
# Provision database and schema
npm run migrate

# Optional: Load synthetic seed data
npm run seed
```

### 4. Start Development Server

```bash
npm run dev
```

Visit the application:

- **Public Portal**: `http://localhost:3000`
- **Staff Portal**: `http://localhost:3000/staff/login.html`
- **Health Check API**: `http://localhost:3000/api/v1/health`

---

## Monorepo Folder Overview

```
queueless/
├── README.md               # Project documentation & guidelines
├── LICENSE                 # Project license
├── .env.example            # Environment variable template
├── .gitignore              # Git ignore rules
├── .editorconfig           # Editor indentation and formatting standards
├── .prettierrc             # Code formatting rules
├── eslint.config.js        # Linter rules for backend, tests, and frontend
├── package.json            # Root workspaces configuration & task runner
├── .github/
│   ├── workflows/ci.yml    # GitHub Actions automated CI workflow
│   ├── pull_request_template.md
│   └── ISSUE_TEMPLATE/     # Standard bug and feature issue templates
├── docs/                   # System design, architecture, API, and outage docs
├── database/
│   ├── migrations/         # Plain SQL numbered schema migrations (001 - 007)
│   ├── seeds/              # Synthetic seed data files
│   └── README.md           # Database setup documentation
├── backend/
│   ├── package.json        # Backend package definition & test runner
│   ├── src/                # Express API source code (layered architecture)
│   └── tests/              # Jest unit & supertest integration tests
├── frontend/
│   ├── public/             # Public-facing HTML pages (vanilla)
│   ├── staff/              # Staff management pages (vanilla)
│   ├── css/                # Plain CSS stylesheets
│   ├── js/                 # ES module JavaScript (api, i18n, pages, utils)
│   └── locales/            # JSON translation bundles (en, am, om)
└── scripts/                # Database initialization and maintenance shell scripts
```

---

## Available Scripts

| Script                 | Purpose                                                      |
| ---------------------- | ------------------------------------------------------------ |
| `npm run dev`          | Runs backend API server in development mode with auto-reload |
| `npm run start`        | Runs backend API in standard production mode                 |
| `npm run lint`         | Checks code against ESLint rules                             |
| `npm run lint:fix`     | Automatically fixes autofixable ESLint errors                |
| `npm run format`       | Formats all files with Prettier                              |
| `npm run format:check` | Verifies whether codebase complies with Prettier formatting  |
| `npm test`             | Runs Jest integration and unit test suites                   |
| `npm run migrate`      | Executes unapplied plain SQL database migrations             |
| `npm run seed`         | Seeds database with synthetic sample data                    |

---

## Team & Git Workflow

- **Branching Model**:
  - `main`: Production-ready releases. Direct pushes are disabled.
  - `develop`: Integration branch for completed and approved features.
  - `feature/<name>`: Short-lived branches created from `develop` for new capabilities.
  - `fix/<name>`: Bug fix branches created from `develop` (or `hotfix/*` from `main`).
- **Commit Conventions**: All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):
  - `feat: add walk-in check-in endpoint`
  - `fix: correct queue ETA calculation offset`
  - `docs: update outage recovery procedure`
  - `chore: bump dependencies`
- **Pull Requests**:
  - All pull requests require at least one peer approval and must pass GitHub Actions CI checks (`npm run lint` and `npm test`).
  - Refer to [docs/git-workflow.md](file:///home/maraki/queueless/docs/git-workflow.md) for full details.
