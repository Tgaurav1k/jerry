# jerry — System Architecture

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Implementation-facing system design: components, boundaries, flows, and NFR mapping.  
**Version:** 1.0 (MVP)  
**Sources:** Architecture (2).md, MVP-Tech-Doc (2).md, PRD (2).md

---

## 1. Executive summary

**jerry** is a **mobile-first** system: **Flutter** clients talk to a **stateless NestJS** API over **HTTPS** and **WebSocket (Socket.IO)**. Persistent business data lives in **PostgreSQL**; **Redis** backs OTP/sessions/presence/rate limits and **Socket.IO scaling**. Real-time media uses **Agora**; push uses **FCM**; email uses **Brevo**; profile images use **Supabase Storage**. Chat **content** is primarily **on-device (SQLite)**; the server holds **pending_messages** for offline delivery and **consultation metadata** for history/ratings.

---

## 2. Logical architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter app (iOS / Android)               │
│  go_router · Riverpod · Dio · socket_io_client · sqflite     │
│  Agora RTC · FCM · secure storage                            │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS  REST  /api/v1
                            │ WSS    Socket.IO
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Edge: TLS termination / rate limit (NGINX)     │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 NestJS application cluster                   │
│  Modules: Auth, User, Lawyer, License, Admin, SuperAdmin,   │
│  Chat (gateway), Call, Consultation, Media, Rating,          │
│  Notification, Payment (stub)                                │
└───────┬─────────────────┬─────────────────┬─────────────────┘
        │                 │                 │
        ▼                 ▼                 ▼
 ┌─────────────┐   ┌─────────────┐   ┌──────────────────────┐
 │ PostgreSQL  │   │   Redis     │   │ External services     │
 │ 16          │   │   7         │   │ Agora, FCM, Brevo, Supabase Storage │
 └─────────────┘   └─────────────┘   └──────────────────────┘
```

---

## 3. Architectural principles (enforced)

1. **Stateless API** — session state in Redis + JWT claims; any node can serve any request.  
2. **Client-heavy chat persistence** — full history on device; server queue only for undelivered payloads.  
3. **Separate identity tables** — `User`, `Lawyer`, `Admin`, `SuperAdmin` (no unified `users` + role enum as single table).  
4. **Provider abstractions** — `CallService`, `PushService`, `StorageService` as interfaces; concrete vendors behind them.  
5. **Payment-ready schema** — `PaymentModule` stub; monetary fields default to free/zero in MVP.  
6. **Security by default** — TLS 1.3, bcrypt passwords, RS256 JWT, BYTEA license only via admin-authenticated stream.

---

## 4. Component responsibilities

| Component | Responsibility |
|-----------|----------------|
| **AuthModule** | Signup, OTP, login, refresh rotation, device conflict, password reset, role-scoped tokens |
| **UserModule** | Client profile; consumes lawyer search APIs |
| **LawyerModule** | Lawyer profile, specialties join, availability, public search DTOs, stats |
| **LicenseModule** | Multipart upload → BYTEA, status transitions |
| **AdminModule** | Queue, approve/reject, suspend, directory reads |
| **SuperAdminModule** | Admin CRUD, dashboard aggregates |
| **ChatModule** | Socket.IO: messages, typing, read receipts, pending queue drain |
| **CallModule** | Initiate call, Agora tokens, signaling events, ring timeout |
| **ConsultationModule** | Metadata CRUD, history queries |
| **MediaModule** | Supabase Storage presigned URLs |
| **RatingModule** | Create rating, recompute lawyer aggregates |
| **NotificationModule** | FCM send, device token registry |
| **PaymentModule** | Stub — no live payments |

---

## 5. Data flow summaries

### 5.1 Signup + OTP

Flutter → `POST /auth/signup` → Redis (pending signup, OTP hash) + Brevo email → `POST /auth/verify-otp` → create row in `User` or `Lawyer` → issue JWT + refresh in Redis allow-list.

### 5.2 Lawyer verification

Lawyer → `POST /license/upload` → BYTEA in Postgres → `PENDING_REVIEW` → Admin stream + approve/reject → FCM to lawyer.

### 5.3 Chat (online)

Flutter → `chat:send` → validate → if recipient socket online → `chat:receive` + `chat:delivered`; else → insert `PendingMessage` + FCM.

### 5.4 Chat (offline sync)

On connect → `chat:sync` → pending rows emitted → `chat:ack` deletes pending.

### 5.5 Voice/video call

`POST /call/initiate` → create `Consultation` RINGING → Agora channel + tokens → Redis flag lawyer busy → `call:incoming` + FCM → accept/reject/end endpoints update status and duration → `rating:prompt` to user.

### 5.6 Presence

Socket connect + periodic `heartbeat` → Redis keys with TTL; lawyer `isOnline` combined with manual toggle per product rules.

### 5.7 Multi-device login

Login sees existing refresh/session → 409 → retry with `forceLogout` → revoke old refresh, emit `auth:force_logout`, issue new tokens.

---

## 6. Redis usage (canonical)

| Key pattern | Purpose |
|-------------|---------|
| `otp:*` | OTP hash + attempt counts |
| `pending_signup:*` | Signup payload before user row (per Architecture narrative) |
| `refresh:*` / allow-list | Refresh token rotation and revocation |
| `presence:*` | Online presence TTL |
| `lawyer:*:in_call` | Busy flag for call routing |
| Throttler keys | Rate limits |

Exact key naming should stay consistent in one module to avoid split-brain.

---

## 7. Scalability and deployment posture

| Phase | Infra |
|-------|--------|
| **MVP / pre-launch** | Single or few NestJS containers; managed Postgres + Redis; Docker Compose locally |
| **Growth** | Horizontal NestJS; Socket.IO Redis adapter; read replica optional |
| **Scale** | Kubernetes, PgBouncer, partition hot tables, optional separate realtime tier |

---

## 8. Non-functional targets

| Concern | Target |
|---------|--------|
| API p95 | &lt; 300 ms |
| Socket p95 | &lt; 500 ms (India) |
| Call signaling | &lt; 3–4 s to connected |
| Availability | 99% MVP |
| Observability | Structured logs (Pino); Prometheus-compatible metrics recommended |

---

## 9. Security architecture

- **JWT:** Access 15m, refresh 30d, rotation; RS256 per tech doc.  
- **RBAC:** Guards + `@Roles()` on controllers; Socket middleware validates JWT.  
- **License:** No CDN cache; stream through authenticated admin handler.  
- **Rate limits:** Stricter on `/auth/*`; chat message rate per user.  
- **Audit:** `AuditLog` for admin actions.

---

## 10. Deferred / out of scope (architecture)

- Razorpay and billing workers  
- Web admin SPA  
- E2EE chat with server-blind content  
- ML ranking service  
- Multi-region active-active (single region MVP)

---

*End of `04-system-architecture.md`. See `05-database-schema.md`.*
