# jerry — User Stories and Acceptance Criteria

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Agile-ready stories with testable acceptance criteria, aligned to PRD feature IDs and MVP-Tech-Doc behavior.  
**Version:** 1.0 (MVP)  
**Sources:** PRD §5–6, MVP-Tech-Doc, Architecture §7, Design §6

---

## 1. Conventions

- **Roles:** User (client), Lawyer, Admin, SuperAdmin.  
- **Story format:** As a \<role\>, I want \<capability\>, so that \<outcome\>.  
- **Acceptance criteria (AC):** Numbered, testable; **Given / When / Then** where helpful.  
- **Maps to:** PRD feature IDs (e.g. F-AUTH-01) where applicable.

---

## 2. Epic: Authentication and session security

### US-AUTH-01 — Sign up with role and profile basics

**As a** new visitor, **I want** to create an account with my role and basic profile, **so that** I can access the correct experience (client vs lawyer).

**Maps to:** F-AUTH-01, F-AUTH-02

**AC:**

1. Form collects full name, email, password, **role** (User or Lawyer), preferred language, city, state.  
2. Password meets policy: ≥8 chars, ≥1 uppercase, ≥1 number, ≥1 special character.  
3. Submitting valid data sends a 6-digit OTP to email and shows OTP entry screen.  
4. Email already present in any identity table returns a **generic** error: “This email is already registered.” (no role leak).  
5. OTP expires in 10 minutes; user can resend after 30 seconds; max 5 wrong attempts before lockout until a new OTP is requested.

### US-AUTH-02 — Verify email with OTP

**As a** registrant, **I want** to enter the OTP to activate my account, **so that** my email is verified.

**Maps to:** F-AUTH-02, MVP-Tech-Doc `/auth/verify-otp`

**AC:**

1. Entering correct 6-digit OTP completes verification.  
2. **User:** receives tokens and lands in client flow (permissions, then lawyer list per Design).  
3. **Lawyer:** receives **limited** token until license workflow completes; `verificationStatus` reflects `PENDING_UPLOAD` / next step per tech doc.  
4. Wrong OTP increments attempt count; after 5 failures, verification is blocked until new OTP.

### US-AUTH-03 — Log in on mobile

**As a** User or Lawyer, **I want** to log in with email and password, **so that** I can use the app on my device.

**Maps to:** F-AUTH-03, F-LAWYER-01

**AC:**

1. Unverified email cannot log in; message indicates verification required.  
2. Suspended account cannot log in; shows suspension copy per PRD.  
3. Lawyer with status not **APPROVED** cannot access full lawyer features; may only access routes allowed for pending state (license upload, status).  
4. Successful login returns access + refresh tokens and registers device id + FCM token as per API.

### US-AUTH-04 — Single-device session and conflict resolution

**As a** account holder, **I want** only one active session unless I choose to move it, **so that** my account stays secure.

**Maps to:** F-AUTH-04

**AC:**

1. Login from a new device while another session exists returns **409** with `DEVICE_CONFLICT` and existing device label + last active time.  
2. User can cancel and stay on old device, or confirm **log out other device**.  
3. On confirm, login is retried with `forceLogout: true`; old device receives `auth:force_logout` and optional FCM; local tokens cleared; UI returns to login.  
4. New device receives tokens and continues to home.

### US-AUTH-05 — Reset forgotten password

**As a** user, **I want** to reset my password via email, **so that** I can regain access.

**Maps to:** F-AUTH-05

**AC:**

1. Forgot password flow always shows success after submit (no email enumeration).  
2. Email contains time-limited link (30 min); opening deep link allows setting new password.  
3. After reset, **all** sessions are invalid; user must log in again.

### US-AUTH-06 — Admin login (isolated)

**As an** Admin or SuperAdmin, **I want** a dedicated admin login entry, **so that** admin traffic is isolated from public auth.

**Maps to:** F-ADMIN-01

**AC:**

1. Admin login uses separate endpoint from User/Lawyer.  
2. No public self-signup for admin accounts.  
3. Admin session expires after **1 hour** of inactivity (tighter than end users).

---

## 3. Epic: Client — discover and consult

### US-CLIENT-01 — Browse and search lawyers

**As a** client, **I want** to see a list of lawyers with trust signals, **so that** I can choose someone suitable.

**Maps to:** F-USER-01, F-USER-02

**AC:**

1. Default list shows **approved** lawyers; default ordering: **online first**, then **rating** descending.  
2. Each row/card shows photo, name, top specialties, avg rating, rating count, city, languages, online indicator.  
3. List supports infinite scroll (e.g. 20 per page) and pull-to-refresh.  
4. Filters: specialty (multi), city/state, languages (multi, OR within languages), online-only, min rating; filters combine with **AND**; languages OR-group behaves as PRD.  
5. Sort options: rating (high→low), most consultations, most experience.  
6. Filter state persists across app restarts locally; “Clear all” visible when any filter active.

### US-CLIENT-02 — View lawyer profile

**As a** client, **I want** a detailed lawyer profile, **so that** I can decide how to contact them.

**Maps to:** F-USER-03

**AC:**

1. Detail shows photo, bio, specialties, years of experience, languages, location, aggregate rating and breakdown, recent public ratings (paginated).  
2. Primary actions: Chat, Voice, Video — **disabled with “Unavailable”** when lawyer offline; voice/video also disabled if lawyer ineligible for calls per PRD.

### US-CLIENT-03 — Chat with a lawyer

**As a** client, **I want** to send and receive messages with delivery states, **so that** I can communicate asynchronously.

**Maps to:** F-USER-04, Architecture §7.3–7.4

**AC:**

1. Chat opens a thread; messages show Sending → Delivered → Read as implemented.  
2. Typing indicator shows when other party types (when online).  
3. If lawyer offline, client can still send; server queues + FCM; messages appear in lawyer app when they reconnect.  
4. Full history is available from **local SQLite** on device after sync rules in tech doc.

### US-CLIENT-04 — Voice or video call

**As a** client, **I want** to start a voice or video call with an available lawyer, **so that** I can talk in real time.

**Maps to:** F-USER-05

**AC:**

1. Call buttons unavailable when lawyer offline or already in another call (server-enforced).  
2. Outgoing UI shows ringing state with cancel.  
3. Timeout **45 s** → missed for callee; caller sees appropriate outcome.  
4. On connect, Agora session matches initiated type; in-call controls per PRD (mute, camera, flip, end).  
5. On end, consultation metadata saved and rating prompt appears (skippable).

### US-CLIENT-05 — History and ratings

**As a** client, **I want** to see past consultations and rate completed ones, **so that** I can track activity and give feedback.

**Maps to:** F-USER-06, F-USER-07

**AC:**

1. History lists consultations with lawyer, type, date, duration, rating given; sort recent first; pagination.  
2. Detail view allows rating only if not yet submitted; one rating per consultation; stars required; optional text max 500 chars; cannot edit after submit.  
3. Lawyer aggregate `avgRating` / `totalRatings` update immediately after rating submit.

### US-CLIENT-06 — Profile and notifications

**As a** client, **I want** to edit my profile and receive timely notifications, **so that** the app stays useful and trustworthy.

**Maps to:** F-USER-08, F-USER-09

**AC:**

1. Editable: name, photo (presigned R2 upload path), preferred language, city, state, phone; not email or role.  
2. FCM permission requested during onboarding; categories allow muting chat vs call per PRD where specified.  
3. Notification tap deep-links to relevant screen (thread, call, rating, etc.).

---

## 4. Epic: Lawyer — verification and practice

### US-LAWYER-01 — Complete verification path

**As a** lawyer, **I want** to upload my license and know my status, **so that** I can be verified to practice on the platform.

**Maps to:** F-LAWYER-01, F-LAWYER-02

**AC:**

1. After OTP, lawyer cannot skip license upload screen until file + license number submitted (where required by product).  
2. Accept PDF, JPG, PNG ≤ 5 MB; stored server-side as BYTEA; status moves to **PENDING_REVIEW**.  
3. **Under review** screen shows expectation (24–48h) and blocks rest of app.  
4. **Rejected** shows reason and allows re-upload.  
5. **Approved** unlocks full lawyer UI; FCM notification sent.

### US-LAWYER-02 — Professional profile and availability

**As an** approved lawyer, **I want** to present my practice and control availability, **so that** clients reach me when appropriate.

**Maps to:** F-LAWYER-03, F-LAWYER-04

**AC:**

1. Can edit bio, specialties (≥1), years, languages, photo, city, state, rate field (stored, not billed in MVP).  
2. Online/offline toggle prominent; offline hides from “online only” and blocks incoming calls; chat still queues.  
3. Auto-offline after 5 min background without heartbeat per PRD.

### US-LAWYER-03 — Incoming calls and consults

**As a** lawyer, **I want** to accept or reject calls and see my history, **so that** I can manage consultations.

**Maps to:** F-LAWYER-05, F-LAWYER-06

**AC:**

1. Incoming call UI: caller identity, type; accept/reject; ignore → missed after 45s.  
2. Reject surfaces “declined” to caller; missed surfaces “no answer” per PRD.  
3. History shows client identifier per product decision (name vs anonymous — **document single rule** in release).  
4. Stats show totals and averages; **no** earnings in MVP.

### US-LAWYER-04 — Chat with clients

**As a** lawyer, **I want** to read and reply in chat threads, **so that** I can respond to clients.

**Maps to:** F-LAWYER-07

**AC:**

1. Thread list sorted by recent activity.  
2. Lawyer **cannot** start a thread; only reply after user initiates.  
3. Same delivery/read/typing behavior as client side.

---

## 5. Epic: Admin operations

### US-ADMIN-01 — Review pending lawyers

**As an** admin, **I want** to review applications in FIFO order, **so that** verification is fair and timely.

**Maps to:** F-ADMIN-01 — F-ADMIN-05

**AC:**

1. Queue lists **PENDING_REVIEW** lawyers oldest first with key fields visible.  
2. Detail shows profile + **inline** license stream (no download); viewing logged in audit.  
3. Approve: one action → **APPROVED**, FCM to lawyer, audit log.  
4. Reject: requires reason ≥10 chars; **REJECTED**, FCM with reason, audit log.  
5. Suspend/unsuspend: forces logout when suspending; suspended lawyers hidden from public lists; audit log.

### US-ADMIN-02 — Directory lookup

**As an** admin, **I want** to search users and lawyers, **so that** I can investigate issues.

**Maps to:** F-ADMIN-07

**AC:**

1. Search by email, name, phone.  
2. Filter lawyer by status.  
3. View account details; cannot edit arbitrary profile fields—only moderation actions defined.

---

## 6. Epic: SuperAdmin

### US-SA-01 — Manage admins and view health

**As a** SuperAdmin, **I want** to create admins and see platform metrics, **so that** I can operate the product.

**Maps to:** F-SA-01 — F-SA-03

**AC:**

1. Can create admin with email + temp password; deactivate admins; deactivation invalidates sessions.  
2. Dashboard shows totals, consultation breakdown by type, lawyers by status, active 24h, avg platform rating per API contract.  
3. SuperAdmin can perform all admin moderation actions.

---

## 7. Cross-cutting stories

### US-X-01 — Language matching

**As a** client, **I want** my preferred language considered when browsing, **so that** I see relevant lawyers.

**Maps to:** F-X-01

**AC:**

1. User has one `preferredLanguage`; lawyer has many `languagesSpoken`.  
2. Default browse behavior applies language matching per PRD (overridable via filters).  
3. UI copy remains English in MVP.

### US-X-02 — Specialties

**As a** lawyer, **I want** to tag my practice areas, **so that** clients can filter accurately.

**Maps to:** F-X-02

**AC:**

1. Lawyer selects ≥1 from MVP specialty list.  
2. Client can multi-select specialty filters.

---

## 8. Negative and edge cases (must pass QA)

| Scenario | Expected behavior |
|----------|-------------------|
| Token expired mid-request | Refresh flow or logout per interceptor spec |
| Socket disconnect | Reconnect + `chat:sync` pulls pending |
| Lawyer double call attempt | Server returns conflict / unavailable |
| OTP brute force | Lockout per PRD |
| Admin views license | No client-side caching of sensitive stream; audit logged |
| User rates twice same consultation | Second submit rejected by API |

---

*End of `02-user-stories-and-acceptance-criteria.md`. See `03-information-architecture.md`.*
