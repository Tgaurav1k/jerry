# jerry — Testing Strategy

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Test pyramid, coverage expectations, suites, and manual QA for MVP release.  
**Version:** 1.0 (MVP)  
**Sources:** MVP-Tech-Doc §9, Architecture testing references

---

## 1. Goals

- Prevent regressions in **auth**, **chat delivery**, **call lifecycle**, and **admin verification**.  
- Keep **fast feedback** in CI (unit + static) and **realistic** checks in staging (integration/E2E).  
- Track **crash-free sessions** and key product metrics post-release.

---

## 2. Test pyramid

```
        /\
       /  \  Manual exploratory + device matrix
      /----\
     / E2E  \  Critical flows (staging, optional Detox/Appium later)
    /--------\
   / Integr. \  API + DB + Redis (Supertest)
  /------------\
 /    Unit      \  Services, pure domain, guards
----------------
```

**Targets (MVP-Tech-Doc):**

- Backend unit coverage **≥ 70%** on services (Auth, Chat, Call prioritized).  
- Flutter: unit tests for domain/notifiers; widget tests for **login**, **lawyer list**, **chat** shell.

---

## 3. Backend testing

### 3.1 Unit tests (Jest)

| Area | Focus |
|------|--------|
| **AuthService** | OTP hash/verify, lockout, signup uniqueness across tables, device conflict |
| **ChatService** | Pending message insert, ack deletion, role validation |
| **CallService** | State transitions, 45s timeout job, busy flags |
| **RatingService** | Aggregate math, duplicate rating rejection |
| **Guards** | JWT payload, role checks |

Use **mocks** for Brevo, FCM, Agora, R2 in unit tests.

### 3.2 Integration tests (Supertest + test DB)

- Spin up **ephemeral Postgres** (Testcontainers or docker service in CI).  
- **Happy paths:** signup → verify → login; lawyer upload → admin approve → lawyer login; send chat message online; initiate call → accept → end.  
- **Failure paths:** wrong OTP, suspended user, lawyer unavailable, duplicate rating.

### 3.3 Socket.IO tests

- Use `socket.io-client` in tests against in-memory or dockerized app.  
- Verify: connect with JWT, `chat:send` → `chat:receive`, `chat:sync` drains DB pending rows.

### 3.4 Contract tests

- Optional: snapshot OpenAPI schema vs responses for key endpoints.  
- Enforce standard **envelope** shape (`success`, `data`/`error`, `meta`).

---

## 4. Mobile testing (Flutter)

### 4.1 Unit tests

- Repositories parsing API envelope and errors (`DEVICE_CONFLICT`, etc.).  
- Thread id sorting / message dedup by `clientMessageId`.

### 4.2 Widget tests

- Auth forms validation messages.  
- Lawyer card renders rating + online dot from mock model.  
- OTP widget advances focus.

### 4.3 Integration tests (`integration_test/`)

- Single flow: launch → login screen (mock API) or **staging** account (nightly).  
- Prefer **mocked HTTP** in CI; real device tests weekly.

### 4.4 Manual device matrix (pre-release)

| Platform | Devices |
|----------|---------|
| Android | Redmi Note 10 class, OnePlus/Samsung mid-range, API 26+ |
| iOS | iPhone 11+, iOS 14+ |

**Cases:** PRD manual QA list in MVP-Tech-Doc §9 — reproduced below as checklist.

---

## 5. Manual QA checklist (from MVP-Tech-Doc)

- [ ] User signup flow on iOS + Android  
- [ ] Lawyer signup + license upload + admin approval + login  
- [ ] Chat between online user + online lawyer  
- [ ] Chat to offline lawyer (FCM arrives)  
- [ ] Voice call connect + disconnect  
- [ ] Video call connect + disconnect  
- [ ] Rating after call completion  
- [ ] Multi-device login → “log out other” works  
- [ ] Forgot password end-to-end  
- [ ] Admin suspends user → user logged out immediately  

**Add:**

- [ ] Lawyer reject path + re-upload  
- [ ] Ringing timeout → missed  
- [ ] JWT refresh on 401 path stress (sequential requests)

---

## 6. Non-functional testing

| Type | Tool / method |
|------|----------------|
| API load smoke | k6 or Artillery — `/lawyers`, `/auth/login` |
| Socket latency | Custom script — measure emit to receive |
| Soak | Long-running chat + presence heartbeat |
| Security | OWASP ZAP baseline on staging; dependency audit `npm audit` / `dart pub outdated` |

---

## 7. Test data management

- **Anonymized** production exports **never** used in dev without approval.  
- **Seed** lawyers/users for staging only; rotate passwords after demos.

---

## 8. Definition of “ready to ship” (testing)

1. All **manual QA** checklist items pass on staging.  
2. Backend **CI green**: lint, typecheck, unit + integration.  
3. No **P1** open bugs in auth/chat/call/admin.  
4. **Crashlytics** enabled (if chosen) with no new fatals in dogfood.

---

## 9. Post-release monitoring

- Dashboard: consultation count, error rate, Agora drop %, FCM delivery failures.  
- Weekly review of top crashes and failed API errors by `code`.

---

*End of `12-testing-strategy.md`. This completes the Implementation folder set (01–12).*
