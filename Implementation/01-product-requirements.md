# jerry — Product Requirements (Implementation Track)

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Executable product requirements for engineering, derived from PRD, Architecture, MVP-Tech-Doc, and Design.  
**Version:** 1.0 (MVP)  
**Sources:** `documentation/PRD (2).md`, `documentation/Architecture (2).md`, `documentation/MVP-Tech-Doc (2).md`, `documentation/Design (2).md`

---

## 1. Product overview

### 1.1 Vision

When someone in India needs quick legal advice, **jerry** is the mobile app they open to find **verified lawyers** and consult in real time via **chat, voice, or video**. The MVP is **free** for clients and lawyers; monetization (pay-per-consult, platform fee) is designed in but **not** shipped in MVP.

### 1.2 Problem being solved

- **Clients:** Hard to find the right lawyer, slow to get an appointment, unclear pricing, geography limits access to specialists, emergencies lack a fast channel.  
- **Lawyers:** Client acquisition is referral-heavy; low-value questions could be handled remotely; practice is geographically capped.

### 1.3 Product promise (MVP)

- **On-demand** connection to lawyers who match **language, specialty, and location** preferences.  
- **Verified** lawyers (manual license review before full access).  
- **Real-time** chat with offline delivery via push + server queue; voice/video via **Agora**.  
- **Trust:** ratings after consultations, verified badge, transparent profiles.

### 1.4 Explicit non-goals (MVP)

- Full case representation, document drafting, contract review, case management.  
- Payments, invoicing, lawyer payouts.  
- Chat attachments, group consults, calendar booking.  
- Web client; multi-language **UI** (English UI only; languages used for **matching**).  
- End-to-end encrypted chat on server; long-term server-side chat/call content retention.

---

## 2. Roles and actors

| Role | Description |
|------|-------------|
| **User (client)** | Registers as client; browses lawyers; chats/calls; rates consultations. |
| **Lawyer** | Registers as lawyer; uploads license; after **APPROVED**, manages profile, availability, consults. |
| **Admin** | Reviews licenses; approves/rejects; suspends users/lawyers; browses accounts. Created only by SuperAdmin. |
| **SuperAdmin** | Seeded at deploy; creates admins; full platform dashboard; all admin capabilities. |

**Immutable rule:** Signup **role** (User vs Lawyer) is fixed per account; no role switch later.

---

## 3. Functional requirements by domain

### 3.1 Authentication and account security

| ID | Requirement |
|----|----------------|
| PR-AUTH-01 | Email + password signup with **role** (User or Lawyer), plus profile fields: full name, preferred language, city, state (aligned with PRD F-AUTH-01). |
| PR-AUTH-02 | Password policy: ≥8 characters, uppercase, number, special character. |
| PR-AUTH-03 | Email **unique across** User, Lawyer, Admin, and SuperAdmin tables; duplicate returns generic message without disclosing which role holds the email. |
| PR-AUTH-04 | After signup, send **6-digit OTP** by email; OTP TTL **10 minutes**; max **5** failed attempts; resend available after **30 seconds**. |
| PR-AUTH-05 | Login with email + password for User/Lawyer; **email must be verified** before full access. |
| PR-AUTH-06 | **Lawyer** login: if verification status ≠ **APPROVED**, block full app except license upload / status (per MVP-Tech-Doc `LAWYER_PENDING` scope). |
| PR-AUTH-07 | **Suspended** accounts cannot log in; show suspension message. |
| PR-AUTH-08 | **Single active device** per account: concurrent login returns **DEVICE_CONFLICT**; user may confirm **force logout** of other device; old device receives Socket.IO `auth:force_logout` + FCM. |
| PR-AUTH-09 | Forgot password: always acknowledge request; reset link **30 min**; reset invalidates all sessions. |
| PR-AUTH-10 | JWT: access **15 min**, refresh **30 days**, rotation on refresh; implementation per Architecture / MVP-Tech-Doc. |
| PR-AUTH-11 | Admin login uses **separate** endpoint from User/Lawyer; session inactivity timeout **1 hour** for admins (PRD F-ADMIN-01). |

### 3.2 User (client) capabilities

| ID | Requirement |
|----|----------------|
| PR-USER-01 | Home: list **approved** lawyers; default sort **online first**, then **rating** descending; pagination **20**; pull-to-refresh. |
| PR-USER-02 | Lawyer card: photo, name, top specialties, avg rating, rating count, city, languages, **online** indicator. |
| PR-USER-03 | Filters: specialty (multi), city/state, languages (multi, OR within), online-only, min rating; combined with **AND**; sort: rating, consultation count, experience; **persist filter state locally**; clear-all when any filter active. |
| PR-USER-04 | Lawyer detail: full profile, bio, specialties, experience, languages, location, ratings breakdown, recent public ratings (paginated). |
| PR-USER-05 | Actions: **Chat** (anytime), **Voice/Video** only when lawyer **online** and not in conflicting state; if offline, calls unavailable with clear copy. |
| PR-USER-06 | Chat: thread in app; statuses **Sending / Delivered / Read**; typing indicator when other party types; offline recipient: server **pending queue** + FCM; **full history on device (SQLite)** — not server-authoritative archive. |
| PR-USER-07 | Voice/video: ringing **45 s** timeout → missed; in-call controls per PRD; on end → **rating prompt** (can skip). |
| PR-USER-08 | Consultation history: list with type, date, duration, rating given; detail view; re-rate only if not yet rated (per PRD). |
| PR-USER-09 | Rating: **one per consultation** after **ENDED**; **5 stars** + optional text (max 500 chars); **cannot edit** after submit; updates lawyer aggregates immediately. |
| PR-USER-10 | Profile: edit name, photo (R2 presigned upload), preferred language, city, state, phone; **not** email or role. |
| PR-USER-11 | FCM: new message (background), incoming call, approval/rating prompts as applicable; categories/mute where specified in PRD; deep links to correct screen. |

### 3.3 Lawyer capabilities

| ID | Requirement |
|----|----------------|
| PR-LAW-01 | Post-OTP flow: **license upload** required before full access; states: **PENDING_UPLOAD → PENDING_REVIEW → APPROVED/REJECTED** (with reason). |
| PR-LAW-02 | License: PDF/JPG/PNG, **max 5 MB**; license number captured; stored **BYTEA** in Postgres; admin-only read via streaming endpoint. |
| PR-LAW-03 | Approved lawyer: edit bio (max 1000 in PRD; Design mentions 300 preview — **engineering should align copy limits** with PRD unless product revises), specialties (≥1), years, languages, photo, city, state, **rate per session** (stored, not charged in MVP). |
| PR-LAW-04 | Availability: manual **online/offline** toggle; when offline, excluded from “online only” and calls blocked; chat still queued + push. **Auto-offline** after **5 min** background without heartbeat (PRD). |
| PR-LAW-05 | Incoming call UI: accept/reject; reject/timeout behaviors per PRD; FCM + in-app signaling. |
| PR-LAW-06 | Consultation history + stats: counts, avg rating, by type; **no earnings** in MVP. |
| PR-LAW-07 | Chat: thread list; **lawyers do not initiate** threads—clients start; same delivery/read rules as user side. |

### 3.4 Admin and SuperAdmin

| ID | Requirement |
|----|----------------|
| PR-ADM-01 | Approval queue: **FIFO** by submission; list pending **PENDING_REVIEW** lawyers. |
| PR-ADM-02 | Review: inline license view (PDF/image); **no download** button; license number visible; **audit log** on view/approve/reject/suspend. |
| PR-ADM-03 | Approve: status **APPROVED**, FCM to lawyer; Reject: **required reason** (min 10 chars), FCM with reason, lawyer may re-upload. |
| PR-ADM-04 | Suspend/unsuspend user or lawyer with reason; force logout; hide suspended lawyers from listings. |
| PR-ADM-05 | Browse users/lawyers: search by email/name/phone; filter lawyer status; view-only except suspend actions. |
| PR-SA-01 | SuperAdmin: seed via env on first deploy; create/deactivate admins; dashboard aggregates (users, lawyers, consultations, breakdowns, active 24h, avg rating). |

### 3.5 Cross-cutting product rules

| ID | Requirement |
|----|----------------|
| PR-X-01 | **Languages (matching):** English, Hindi, Punjabi, Tamil, Bengali, Marathi, Telugu, Gujarati, Kannada, Malayalam, Odia, Urdu — user has one preferred; lawyer has many. |
| PR-X-02 | **Specialties:** fixed MVP list (15 areas in MVP-Tech-Doc seed); lawyer ≥1; user filter multi-select. |
| PR-X-03 | **Timezone:** IST; date/time display India locale (DD/MM/YYYY, 24h where specified). |
| PR-X-04 | **Consultation** is a logged **metadata** record (who, type, status, duration, Agora channel name); **no** chat/call content on server beyond transient pending messages for delivery. |

---

## 4. Experience and design constraints (product-level)

These are binding for implementation consistency with **Design.md**:

- **Calm UI**, **bento** cards, selective **glass** for overlays (filters, rating, incoming call).  
- **Inter** typography, **4pt** spacing grid, tokenized colors (slate/blue/sage).  
- Bottom **floating** tab bar (User/Lawyer): Home/Dashboard, Chats, History, Profile.  
- **Minimum** tap targets **48dp**; WCAG AA contrast; screen reader labels on interactive elements.  
- **Portrait** everywhere except **video call** may use landscape.  
- **No emojis** in product copy per Design.md.

---

## 5. Non-functional requirements (product-facing)

| Area | MVP target |
|------|------------|
| API latency | p95 &lt; 300 ms (excluding third-party token generation) |
| Socket delivery | p95 &lt; 500 ms within India |
| Call connect (signaling) | User tap to both connected &lt; 4 s (PRD) / &lt; 3 s (Architecture) — **align in test plan** toward stricter of staged milestones |
| Uptime | 99% API |
| Call drops | &lt; 5% |
| Chat loss | 0% (queue + client persistence) |
| FCM | 95%+ within 5 s |
| Android | 8.0+ (API 26+); cold start &lt; 2 s on mid-range device (PRD) |
| iOS | 14+ |
| Security | TLS 1.3; bcrypt cost 12; JWT rotation; license BYTEA admin-only |

---

## 6. Success metrics (MVP)

| Metric | Target |
|--------|--------|
| Successful consultations | 100 |
| Verified lawyers | 50 |
| Registered users | 1,000 |
| Call drop rate | &lt; 5% |
| Chat delivery failure | &lt; 2% |
| Average rating | ≥ 4.0 stars |

**Star metrics post-launch:** consultations/week, lawyer utilization, repeat consultation rate (30 days).

---

## 7. Dependencies and integrations (product)

| Dependency | Use in MVP |
|------------|------------|
| **Agora** | Voice/video RTC + tokens from backend |
| **FCM** | Push: messages, calls, approvals, force logout |
| **Brevo** | OTP and password-reset email |
| **Cloudflare R2** | Profile photos (presigned upload) |
| **PostgreSQL** | Primary data + license BYTEA |
| **Redis** | OTP, refresh allow-list, presence, rate limits, Socket.IO adapter |

---

## 8. Compliance and trust (MVP)

- Terms and privacy accessible in-app; lawyer verification is **manual** against Bar Council expectations (process, not automated API).  
- Chat/call content not retained server-side for audit (per scope); dispute-handling enhancements deferred.  
- Marketing positioning should follow legal review (“directory” framing vs advertising) per PRD risk table.

---

## 9. Open product decisions to track in build

1. **Client visibility to lawyer:** PRD lists “full name vs anonymous” as open—implementation should follow a single rule documented in API/UI (default in PRD: lawyer sees client name).  
2. **Rating moderation:** immediate publish in MVP; future delay possible.  
3. **PRD vs Design** on lawyer bio length during signup—align with single max length before release.

---

## 10. Traceability

| This doc section | Primary source sections |
|------------------|-------------------------|
| §3.1 | PRD §5.1; MVP-Tech-Doc §4.3–4.6, §6 |
| §3.2 | PRD §5.2 |
| §3.3 | PRD §5.3 |
| §3.4 | PRD §5.4–5.5 |
| §3.5 | PRD §5.6; Architecture §7 |
| §4 | Design §3–6 |
| §5 | PRD §7; Architecture §13 |
| §6 | PRD §3.2, §8 |
| §7 | PRD §9.3; Architecture §12 |

---

*End of `01-product-requirements.md`. Say **next** when you want `02-user-stories-and-acceptance-criteria.md`.*
