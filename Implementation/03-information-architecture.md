# jerry — Information Architecture

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Map content, screens, navigation, and deep links for the MVP Flutter app (single binary, role-based root).  
**Version:** 1.0 (MVP)  
**Sources:** Design §5–6, PRD §6, Architecture §5.1

---

## 1. Principles

- **Single app:** After authentication, **root navigation** depends on JWT `role` (and lawyer `verificationStatus` for gating).  
- **Mobile-first:** Primary navigation is **bottom tabs** for User and Lawyer; Admin/SuperAdmin use stacked flows from their home.  
- **English UI** only; language fields are **data** for matching, not UI locale.  
- **IST** for all timestamps in UI unless noted.

---

## 2. Global navigation model

### 2.1 Unauthenticated stack

| Screen / route | Purpose |
|----------------|---------|
| Splash | Brand, max ~1.5s; then onboarding or auth |
| Onboarding carousel | 3 slides + Skip / Get Started |
| Welcome / role chooser | “I need legal help” vs “I am a lawyer” |
| Sign up (User) | Fields per Design §6.4 |
| Sign up (Lawyer) | Extra fields per Design §6.5 |
| Login | Email + password + forgot password |
| OTP verification | 6-digit entry, resend |
| Forgot password | Request + deep link to reset |
| Multi-device conflict | Modal / glass sheet per Design §6.8 |

### 2.2 User (client) — authenticated

**Bottom tabs (4):** Home | Chats | History | Profile  

| Tab | Primary content |
|-----|-----------------|
| Home | Lawyer list, specialty chips, search, filters, featured hero card |
| Chats | Thread list (SQLite-backed previews) |
| History | Consultation list + filters by type |
| Profile | User profile, settings blocks, logout |

**Modal / push overlays:** Lawyer detail, Chat thread, Outgoing/incoming call, Rating sheet, Filter sheet.

### 2.3 Lawyer — authenticated (approved)

**Bottom tabs (4):** Dashboard | Chats | History | Profile  

| Tab | Primary content |
|-----|-----------------|
| Dashboard | Greeting, **online toggle**, snapshot metrics, recent messages, weekly chart placeholder |
| Chats | Threads (reply-only initiation rule enforced in product logic) |
| History | Consultations + stats entry |
| Profile | Professional info, availability card, verification badge |

**Overlays:** Incoming call full-screen, Active voice/video, Rating not shown to lawyer as rater (client rates lawyer).

### 2.4 Lawyer — pending states

| State | Allowed screens |
|-------|------------------|
| `PENDING_UPLOAD` | License upload only (logout) |
| `PENDING_REVIEW` | Waiting screen + logout |
| `REJECTED` | Rejection reason + re-upload path |

Navigation guards **must** block tab access until `APPROVED` (except limited token scope for upload/status).

### 2.5 Admin

**Entry:** Separate login route (not linked from public welcome).

Suggested IA:

| Area | Screens |
|------|---------|
| Home / Dashboard | Pending review count, shortcuts |
| Approval queue | FIFO list |
| Lawyer review | Profile + inline license + Approve / Reject |
| Directory | Users list, Lawyers list (search/filter) |
| Account detail | Read-only + suspend actions |

### 2.6 SuperAdmin

| Area | Screens |
|------|---------|
| Dashboard | Metric bentos per Design §6.26 |
| Admin management | List + create admin + deactivate |

---

## 3. Screen inventory (MVP)

| # | Screen | Role | Design § |
|---|--------|------|----------|
| 1 | Splash | All | 6.1 |
| 2 | Onboarding carousel | Pre-auth | 6.2 |
| 3 | Role selection | Pre-auth | 6.3 |
| 4 | Sign up User | Pre-auth | 6.4 |
| 5 | Sign up Lawyer | Pre-auth | 6.5 |
| 6 | OTP | Pre-auth | 6.6 |
| 7 | Login | Pre-auth | 6.7 |
| 8 | Multi-device dialog | Pre-auth / auth | 6.8 |
| 9 | License upload | Lawyer pending | 6.9 |
| 10 | Under review | Lawyer pending | 6.10 |
| 11 | User home (lawyer list) | User | 6.11 |
| 12 | Filter sheet | User | 6.12 |
| 13 | Lawyer detail | User | 6.13 |
| 14 | Chat thread | User, Lawyer | 6.14 |
| 15 | Chats list | User, Lawyer | 6.15 |
| 16 | Incoming call | Lawyer (also caller UX for outgoing) | 6.16 |
| 17 | Active video call | Both | 6.17 |
| 18 | Active voice call | Both | 6.18 |
| 19 | Post-call rating | User | 6.19 |
| 20 | Consultation history | User, Lawyer | 6.20 |
| 21 | Profile User | User | 6.21 |
| 22 | Profile Lawyer | Lawyer | 6.22 |
| 23 | Lawyer dashboard | Lawyer | 6.23 |
| 24 | Admin queue | Admin | 6.24 |
| 25 | Admin lawyer review | Admin | 6.25 |
| 26 | SuperAdmin dashboard | SuperAdmin | 6.26 |
| 27 | SuperAdmin admin list | SuperAdmin | 6.27 |

---

## 4. Content hierarchy

### 4.1 Lawyer list (User home)

1. **App bar:** Title “Find a lawyer”, search, filter.  
2. **Specialty chips:** Horizontal scroll; “All” + specialties from API.  
3. **Featured hero:** One prominent lawyer (e.g. top-rated online matching preferred language).  
4. **All lawyers:** Paginated cards.

### 4.2 Lawyer detail

1. **Hero:** Photo + identity + verified + online + rating.  
2. **Bio** (bento).  
3. **Quick facts:** Experience, languages (paired cards).  
4. **Specialties** (chips).  
5. **Recent reviews** (list).  
6. **Sticky actions:** Chat | Voice | Video.

### 4.3 Chat thread

1. **Header:** Peer avatar, name, presence, call shortcuts.  
2. **Body:** Messages + date separators + typing.  
3. **Composer:** Text only in MVP (no attachments).

---

## 5. Deep links and notification routing

| Notification / event type | Target screen |
|---------------------------|---------------|
| New chat (background) | Chat thread with counterparty |
| Incoming call | Incoming / active call flow |
| Lawyer approved | Login or lawyer home with success state |
| Force logout | Login + toast reason |
| Rating prompt | Rating modal for `consultationId` |

**Implementation note:** Payloads should carry stable IDs (`consultationId`, peer ids, thread key) consistent with Socket and REST models in MVP-Tech-Doc.

---

## 6. Search and filter behavior

- **Lawyer list search** (if implemented as local filter vs server): product should specify; PRD implies browse + filters — **server-side** `GET /lawyers` with query params is canonical per tech doc.  
- **Filter sheet** writes to local state + refetches list.  
- **Persisted state:** Serialize active filters and sort to local storage; restore on next launch.

---

## 7. Empty states (copy architecture)

| Context | Headline direction |
|---------|-------------------|
| No lawyers match filters | Widen filters / clear |
| No chats | Conversations appear when you start |
| No history | Start a consultation |
| No network | Retry + offline messaging hints |

Illustrations: Design §11.1.

---

## 8. IA exclusions (MVP)

- No web marketing pages inside app.  
- No public lawyer URL sharing.  
- No in-app customer support chat (deferred per PRD).

---

*End of `03-information-architecture.md`. See `04-system-architecture.md`.*
