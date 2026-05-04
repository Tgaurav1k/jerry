# jerry — Environment and DevOps

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Environments, configuration, secrets, CI/CD, and deployment patterns for MVP.  
**Version:** 1.0 (MVP)  
**Sources:** Architecture §11–12, MVP-Tech-Doc §2–3

---

## 1. Environments

| Env | Purpose | Data | Third parties |
|-----|-----------|------|---------------|
| **local** | Developer machines | Docker Postgres/Redis | Optional mocks; real keys in local `.env` (never commit) |
| **staging** | Pre-prod QA | Managed Postgres/Redis snapshot | Agora/Brevo/FCM **sandbox/test** |
| **production** | Live users | Managed Postgres/Redis backups | Production keys, monitoring |

---

## 2. Local development

### 2.1 Prerequisites

- Node.js **20 LTS**, npm 10+ or pnpm 9+  
- Flutter **3.24+**  
- Docker + Docker Compose  
- Android Studio / Xcode for mobile builds

### 2.2 Bring-up sequence

1. `docker compose up -d` (Postgres, Redis).  
2. `cd backend && cp .env.example .env` — fill secrets.  
3. `npx prisma migrate dev` + `npx prisma db seed`.  
4. `npm run start:dev`.  
5. `cd mobile && cp .env.example .env` — point to `http://localhost:3000` (Android emulator may need `10.0.2.2`).  
6. `flutter run`.

### 2.3 Ports (default)

| Service | Port |
|---------|------|
| NestJS | 3000 |
| PostgreSQL | 5432 |
| Redis | 6379 |

---

## 3. Configuration and secrets

### 3.1 Backend (from `.env.example` in MVP-Tech-Doc)

**Categories:**

- **Server:** `NODE_ENV`, `PORT`, `API_BASE_URL`  
- **Database:** `DATABASE_URL`  
- **Redis:** host, port, password  
- **JWT:** access/refresh secrets, expiry  
- **Brevo:** API key, sender, template id for OTP  
- **FCM:** service account fields  
- **Agora:** app id, certificate, token expiry  
- **Supabase:** `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (backend only — NEVER in Flutter), `SUPABASE_STORAGE_BUCKET_PHOTOS=profile-photos`, `SUPABASE_STORAGE_BUCKET_LICENSES=licenses` (not used — BYTEA in DB)  
- **SuperAdmin seed:** email + password (rotate after first login)  
- **Throttling:** TTL/limit  
- **Logging:** `LOG_LEVEL`

### 3.2 Mobile

- `API_BASE_URL`, `SOCKET_URL`, `AGORA_APP_ID`, `ENVIRONMENT`  
- **Never** embed JWT secrets, Supabase service role key, or Agora **certificate** in the client.

### 3.3 Secret storage

| Location | Use |
|----------|-----|
| GitHub **Actions** secrets | CI deploy, store credentials |
| Hosting provider vault / env | Production runtime |
| `flutter` — `--dart-define` or env files | Non-secret + public App ID only |

---

## 4. Database lifecycle

| Command | When |
|---------|------|
| `prisma migrate dev` | Local feature development |
| `prisma migrate deploy` | Staging/production release |
| `prisma db seed` | First env setup + specialty refresh (idempotent where possible) |

**Backups:** Automated daily snapshots on managed Postgres; test restore quarterly.

---

## 5. CI/CD pipeline (recommended)

```
on: pull_request, push to main

jobs:
  backend:
    - checkout
    - install deps
    - eslint + prettier check
    - tsc --noEmit
    - unit tests (Jest)
    - prisma validate
    - optional: integration tests with service containers (Postgres/Redis)

  mobile:
    - flutter pub get
    - dart analyze
    - flutter test

  on main merge:
    - build Docker image → push to GHCR
    - deploy staging via SSH or kubectl
    - prisma migrate deploy on target
    - smoke test health + login
```

**Flutter release:**

- `flutter build apk --release` / `flutter build ipa` on tags or manual workflow.  
- **Signing:** Android keystore + Play App Signing; iOS certificates via Fastlane/Match (team choice).

---

## 6. Runtime topology (MVP staging/prod)

```
Internet → TLS (NGINX or cloud LB) → NestJS container(s)
                    ↓
            Postgres (managed) + Redis (managed)
                    ↓
        Object storage Supabase Storage (presigned URL from NestJS)
```

- **Horizontal scaling:** Multiple NestJS replicas + **Socket.IO Redis adapter** (required before multi-node).  
- **PgBouncer:** Recommended before high replica count (Architecture §8.3).

---

## 7. Observability

| Layer | Tooling |
|-------|---------|
| Logs | Pino JSON → stdout → aggregator (CloudWatch/Datadog/self-hosted) |
| Metrics | Prometheus endpoint or hosted APM |
| Mobile crashes | Firebase Crashlytics (optional but PRD mentions crash-free rate) |
| Uptime | HTTP health check on `/health` or `/api/v1/health` |

**Alerts (minimum):** API 5xx rate, DB connection errors, Redis down, queue backup for `PendingMessage` (row count threshold).

---

## 8. Network and security

- **TLS 1.3** end-to-end external.  
- **CORS** restricted to known origins if web added later; mobile uses API keys in headers only where appropriate.  
- **Rate limiting** on `/auth/*` and global user throttle (Architecture §9.5).

---

## 9. Disaster recovery (MVP level)

- **RPO/RTO:** Align with provider defaults (e.g. daily backup, &lt; 1 h restore goal).  
- **Runbook:** Steps to rotate JWT keys, revoke all refresh tokens (flush Redis prefix), disable SuperAdmin if leaked.

---

## 10. Android APK / iOS build notes

- **APK/AAB:** Build release AAB for Play Console; APK for side-load QA.  
- **Deep links:** Configure for password reset and notification targets.  
- **Proguard/R8:** Standard Flutter Android; keep rules for Agora/FCM if required by vendor docs.

---

*End of `11-environment-and-devops.md`. See `12-testing-strategy.md`.*
