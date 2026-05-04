# jerry — Engineering Scope Definition

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Clear **in / out / stub** boundaries for MVP engineering to avoid scope creep.  
**Version:** 1.0 (MVP)  
**Sources:** PRD §3.3, §11; MVP-Tech-Doc §1; Architecture §15

---

## 1. MVP objective

Deliver a **production-capable** mobile marketplace for **verified** lawyer-client consultations via **chat, voice, and video**, with **admin verification**, **offline-capable chat delivery**, and **ratings** — **without** payments or web clients.

---

## 2. In scope (must ship)

### 2.1 Backend (NestJS)

- All **13 modules** listed in Architecture: Auth, User, Lawyer, License, Admin, SuperAdmin, Chat, Call, Consultation, Media, Rating, Notification, Payment (**stub**).  
- **40+ REST endpoints** per MVP-Tech-Doc with standard envelope and error codes.  
- **Socket.IO** gateway: events in §5 MVP-Tech-Doc.  
- **Prisma** schema + migrations + seed (SuperAdmin + specialties).  
- **Redis** for OTP, refresh rotation, presence, throttling, Socket adapter.  
- Integrations: **Brevo** (email), **FCM** (push), **Agora** (tokens + channel naming), **R2** (presigned uploads).  
- **Swagger** at `/api/docs`.  
- **Audit logs** for admin actions touching lawyers/users.

### 2.2 Mobile (Flutter)

- Single app, **role-based** navigation after login.  
- Flows: onboarding, auth (signup, OTP, login, forgot password, device conflict), user browse/filter/detail, chat + SQLite, calls (Agora), history, rating, profiles.  
- Lawyer: license upload path, approval gating, dashboard, availability, incoming call UX.  
- Admin/SuperAdmin: screens per Design (queue, review, dashboard, admin CRUD).  
- **Design system** tokens and core widgets per Design.md.

### 2.3 Infrastructure (minimal)

- **Docker Compose** for Postgres + Redis local.  
- `.env.example` for backend and mobile.  
- Documented **staging** deploy path (single VPS acceptable).

---

## 3. Out of scope (must not block MVP)

| Area | Excluded |
|------|----------|
| Payments | Razorpay, checkout, invoices, payouts |
| Rich chat | Attachments, server-side chat history archive |
| Scheduling | Lawyer calendar, bookings |
| Web | Public site, web admin |
| ML | Recommended lawyer, ranking model |
| Localization | Non-English UI strings |
| E2EE | Server-blind message content |
| Compliance automation | Bar Council API integration |
| Moderation | Public review flagging workflow (v1.1 in PRD roadmap) |

---

## 4. Stubs (present but non-functional)

| Item | Behavior |
|------|----------|
| **PaymentModule** | Endpoints return “free” / zero amounts; no external payment API calls |
| **Consultation billing fields** | Persisted default `FREE`, `amountPaid = 0` |
| **Lawyer ratePerSession** | Editable, displayed/stored, **not charged** |

---

## 5. Quality bar

- **Security:** bcrypt 12, RS256 JWT, admin-only license stream, rate limits on auth.  
- **Reliability:** No silent message loss (pending queue + client DB).  
- **Observability:** Structured logs for auth, chat, call, admin.  
- **Performance:** Meet NFR table in `01-product-requirements.md` / Architecture.

---

## 6. Dependencies on external teams / assets

- **Legal review** before public marketing claims (directory vs advertising).  
- **App store** assets: icons, screenshots, privacy policy URLs.  
- **Firebase** project + Android/iOS app registration for FCM.  
- **Agora** + **Brevo** + **Cloudflare** accounts.

---

## 7. Acceptance of “done” for engineering

Cross-check **MVP-Tech-Doc §11 Deliverables Checklist** and:

- [ ] Critical user journeys pass manual QA (see `12-testing-strategy.md`)  
- [ ] Staging environment runs full stack with real third-party sandboxes  
- [ ] No P1 open bugs on auth, call, chat sync, admin approval

---

*End of `09-engineering-scope-definition.md`. See `10-development-phases.md`.*
