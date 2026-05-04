# jerry — Development Phases

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Phased delivery plan with milestones aligned to MVP-Tech-Doc and Architecture implementation order.  
**Version:** 1.0 (MVP)  
**Sources:** MVP-Tech-Doc §10, Architecture §16

---

## 1. Timeline assumptions

- **~12 weeks** to MVP with a **2-person** team (MVP-Tech-Doc).  
- Phases may overlap slightly (e.g. Flutter scaffolding parallel to API after Auth).

---

## 2. Phase 0 — Foundation (Week 1)

**Goals:** Repo structure, CI skeleton, databases running locally.

| Deliverable | Done when |
|-------------|-----------|
| Monorepo folders `backend/`, `mobile/` | Pushed to main |
| Docker Compose: Postgres 16 + Redis 7 | `docker compose up` works |
| NestJS app boots, health endpoint | OK |
| Prisma schema committed | `prisma validate` passes |
| Flutter app runs on emulator | Blank themed shell |
| GitHub Actions: lint/test placeholders | Green on PR |

**Exit criteria:** New machine can follow README and reach running API + DB + Flutter skeleton in &lt; 1 hour (target).

---

## 3. Phase 1 — Auth and user profile (Weeks 2–3)

**Goals:** End-to-end signup, OTP, login, refresh, logout, user profile PATCH; Flutter auth UI.

| Backend | Mobile |
|---------|--------|
| Signup, verify-otp, login, refresh, logout | Onboarding + signup + OTP + login |
| Forgot/reset password | Forgot flow |
| Device conflict 409 + force logout path | Conflict dialog + retry |
| bcrypt + Redis OTP + Brevo | Secure token storage + Dio interceptors |

**Exit criteria:** User can register as client, verify, log out, log in on **one** device; token refresh works.

---

## 4. Phase 2 — Lawyer verification and admin (Weeks 4–5)

**Goals:** License upload BYTEA, admin queue, approve/reject, FCM on outcome; lawyer gated UI.

| Backend | Mobile |
|---------|--------|
| License upload + status | Lawyer license + waiting + rejected screens |
| Admin login + approval endpoints + audit | Admin queue + review + inline viewer |
| SuperAdmin seed | N/A (CLI seed) |
| Notification FCM wiring for approval | Push opens correct screen |

**Exit criteria:** Lawyer can submit license; admin can approve; lawyer receives push and can log in as **APPROVED**.

---

## 5. Phase 3 — Lawyer discovery (Week 6)

**Goals:** Public lawyer list, filters, detail, specialties endpoint; Redis presence for `isOnline` on API responses.

| Deliverable | Done when |
|-------------|-----------|
| `GET /lawyers` with filters + pagination | Matches contract |
| `GET /lawyers/:id`, `GET /specialties` | Used by UI |
| Lawyer aggregates visible | Cards match Design |
| Presence hooks | Online dot reflects test heartbeat |

**Exit criteria:** User can find and open a lawyer profile with accurate metadata.

---

## 6. Phase 4 — Chat (Weeks 7–8)

**Goals:** Socket.IO chat, pending queue, SQLite persistence, typing + read receipts, FCM for offline.

| Deliverable | Done when |
|-------------|-----------|
| Chat gateway + JWT socket auth | Connected |
| Online + offline send paths | No message loss in test matrix |
| `chat:sync` + ack deletes pending | DB queue drains |
| Flutter SQLite schema | Threads + messages survive restart |

**Exit criteria:** Two emulators: user ↔ lawyer chat with delivery states; offline recipient receives push and sync.

---

## 7. Phase 5 — Calling (Weeks 9–10)

**Goals:** Agora token issuance, consultation lifecycle, ringing timeout, incoming call UI + FCM.

| Deliverable | Done when |
|-------------|-----------|
| `/call/initiate`, accept, reject, end | State machine correct |
| Agora join on both sides | Audio/video smoke test passes |
| Lawyer busy / offline rules | Correct errors |
| Post-call `rating:prompt` | User sees modal |

**Exit criteria:** Completed voice + video calls on staging with &lt; 5% drop rate in informal testing.

---

## 8. Phase 6 — Ratings, history, polish (Week 11)

**Goals:** `POST /ratings`, history screens, aggregate updates, consultation list; UI polish per Design.

| Deliverable | Done when |
|-------------|-----------|
| Rating creation + lawyer aggregate recompute | Verified in DB |
| History lists both roles | Pagination works |
| Profile photo R2 presign | End-to-end upload |
| UX pass | Tokens, spacing, skeletons |

**Exit criteria:** Full consultation journey demo-ready: discover → consult → rate → see history.

---

## 9. Phase 7 — Pre-launch (Week 12)

**Goals:** Hardening, load smoke tests, store readiness.

| Workstream | Tasks |
|------------|--------|
| QA | Full manual matrix (`12-testing-strategy.md`) |
| Performance | API k6 smoke; Socket latency spot-check |
| Security | Rate limits, JWT revocation, dependency audit |
| Release | Internal testing track (Play), TestFlight |
| Docs | README, env setup, runbooks |

**Exit criteria:** Stakeholder sign-off; no open P1 bugs; monitoring/logging verified.

---

## 10. Dependency graph (simplified)

```
Phase0 → Phase1 → Phase2 → Phase3 → Phase4 → Phase5 → Phase6 → Phase7
                         ↘ (Flutter shell) ↗
```

**Rule:** Do **not** start Phase 5 until Phase 4 chat signaling is stable (shared socket layer).

---

## 11. Post-MVP mapping (from PRD roadmap)

Not scheduled here — reference PRD §12 for v1.1+ (support chat, reports, payments, attachments, web admin, etc.).

---

*End of `10-development-phases.md`. See `11-environment-and-devops.md`.*
