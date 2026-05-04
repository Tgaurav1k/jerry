# `jerry` — Product Requirements Document

**Project:** jerry — Lawyer-Client Consultation Platform
**Document Purpose:** Define WHAT the product does, WHO it serves, and WHY. Business-focused companion to Architecture.md and MVP-Tech-Doc.md.
**Version:** 1.0 (MVP)
**Last Updated:** April 2026

---

## 1. Executive Summary

`jerry` is a mobile-first consultation platform that connects legal clients in India with verified lawyers for real-time advice through **chat, voice call, and video call**. The platform solves two core problems: (a) clients struggle to find and quickly reach qualified lawyers for everyday legal questions, and (b) lawyers struggle to build a direct client book outside of traditional word-of-mouth referrals.

The MVP is free to use for both sides during a testing phase, with a pay-per-consult monetization model designed into the architecture for a later phase.

---

## 2. Problem Statement & Background

### 2.1 Why This Product Exists

Legal consultation in India today is:
- **Gatekept** — most clients don't know how to find a lawyer for a specific problem (criminal vs civil vs family law)
- **Slow** — typical path requires in-person visits, appointments, waiting
- **Opaque on pricing** — clients don't know what a consultation will cost until they're in the lawyer's office
- **Geographically limited** — a client in a small town may not have access to specialists
- **Unavailable for emergencies** — legal emergencies (arrest, notice, accident) have no fast channel

For lawyers — especially early-career or solo practitioners — there's a parallel problem:
- **Client acquisition is hard** — dependent on referrals or expensive advertising
- **Low-value queries clog schedules** — many consultations could be handled in 15 min remotely
- **Geographic ceiling** — their practice is limited to their physical location

### 2.2 Product Opportunity

A real-time app-based platform can:
- Make legal consultation **on-demand** (like Uber for legal advice)
- Enable **language + specialty + location matching**
- Give lawyers a **new client pipeline** without marketing spend
- Support **quick consultations** that don't need an office visit

India has 1.5M+ registered advocates and 650M+ smartphone users — the TAM is massive. This product targets the overlap: lawyers wanting digital clients, and clients needing fast, affordable legal advice.

---

## 3. Vision & Goals

### 3.1 Product Vision (3-year)
*"When any Indian needs legal advice, `jerry` is the first app they open — like BYJU'S for education or 1mg for medicine."*

### 3.2 MVP Goals (6-month horizon)

| Goal | Metric |
|---|---|
| Prove the core flow works | 100 successful consultations completed |
| Validate lawyer supply side | 50 verified lawyers onboarded |
| Validate client demand side | 1,000 registered users |
| Prove call/chat quality | <5% call drop rate, <2% chat delivery failure |
| Establish trust | Avg rating 4.0+ stars across consultations |

### 3.3 Non-Goals (for MVP)
- Not trying to replace physical lawyers for complex cases (this is for consultation, not full representation)
- Not trying to handle document drafting, contract review (these are v2+)
- Not trying to build a case management system
- Not trying to be a marketplace outside India (language + jurisdiction constraints)

---

## 4. Target Users & Personas

### 4.1 Persona A — "Priya the Confused Client"
- **Age:** 28, marketing professional, Mumbai
- **Tech:** Comfortable with apps, uses Zomato/Swiggy/Urban Company daily
- **Problem:** Got a consumer court notice from e-commerce dispute. Doesn't know if she needs a lawyer, what it costs, or where to start.
- **Today's alternative:** Googles → confused by SEO-spam websites, asks in family WhatsApp groups
- **Goals in `jerry`:** Find a lawyer who speaks her language, quick call, clear pricing

### 4.2 Persona B — "Rajesh the Emergency Client"
- **Age:** 42, small business owner, Tier-2 city
- **Tech:** Uses WhatsApp extensively, less comfortable with English-only apps
- **Problem:** Police notice issued to his business; needs immediate advice
- **Today's alternative:** Calls a distant relative who knows a lawyer
- **Goals in `jerry`:** Find any available lawyer right now who speaks Hindi or his regional language

### 4.3 Persona C — "Advocate Meera the New Lawyer"
- **Age:** 29, 3 years post-enrollment, Bangalore
- **Tech:** Heavy smartphone user, active on LinkedIn
- **Problem:** Trying to build her own practice — struggles with consistent client flow
- **Today's alternative:** Hustles referrals from senior advocates; takes low-paying matters
- **Goals in `jerry`:** Earn supplemental income through quick consultations, build ratings/reputation

### 4.4 Persona D — "Advocate Suresh the Established Practitioner"
- **Age:** 48, 20+ years in practice, Delhi
- **Tech:** Uses smartphone but prefers simplicity
- **Problem:** Has free hours between court dates; could help clients remotely
- **Today's alternative:** Waits for referrals
- **Goals in `jerry`:** Monetize idle time, preserve brand credibility via verified badge

### 4.5 Persona E — "The Verifier Admin"
- **Role:** Internal team member approving lawyer licenses
- **Volume expected:** 20-50 approvals/week at MVP scale
- **Goals:** Quickly review incoming lawyer applications, verify license authenticity, approve/reject with reasons

### 4.6 Persona F — "The Platform SuperAdmin"
- **Role:** Founder / operations head
- **Goals:** Oversee platform health, create admin accounts, see macro metrics, investigate disputes

---

## 5. Feature Requirements

### 5.1 Authentication & Onboarding

#### F-AUTH-01 — Email Signup with Role Selection
Users and Lawyers sign up with email + password. During signup, they explicitly select their role (`User` or `Lawyer`). The chosen role is immutable — a user cannot later become a lawyer in the same account.

**Acceptance Criteria:**
- Signup form collects: full name, email, password, role, preferred language, city, state
- Password must be ≥8 chars, include uppercase, number, special char
- Email uniqueness enforced across all 4 role tables (users, lawyers, admins, super_admins)
- Rejection messaging: "This email is already registered." (without revealing which role it's registered as)

#### F-AUTH-02 — Email OTP Verification
After signup form submission, a 6-digit numeric OTP is emailed. User enters it to activate the account.

**Acceptance Criteria:**
- OTP expires in 10 minutes
- Max 5 incorrect attempts before lockout (retry allowed after new OTP request)
- User sees resend button after 30 seconds
- OTP email includes brand name, expiry info, "if this wasn't you, ignore" footer

#### F-AUTH-03 — Login with Email + Password
Same login endpoint for users and lawyers. Admins use a separate login URL for security isolation.

**Acceptance Criteria:**
- Login enforces email verification (unverified accounts get "verify email first" error)
- Lawyers with verification status ≠ APPROVED get login-blocked (except to check status / upload license)
- Suspended users cannot log in

#### F-AUTH-04 — Multi-Device Conflict Handling
A user can only be actively logged in on one device at a time. Logging in on a new device triggers a confirmation to log out the other.

**Acceptance Criteria:**
- When login attempted while another device is active → API returns DEVICE_CONFLICT with existing device info
- Flutter shows: "Already logged in on {device} (last active {time}). Log out that device and continue here?"
- On confirm: old device gets force-logout Socket.IO event + FCM push, new device gets tokens
- Old device clears local tokens and routes to login screen on receiving force-logout event

#### F-AUTH-05 — Forgot Password Flow
Standard email-link reset flow.

**Acceptance Criteria:**
- "Forgot password" link on login screen
- User enters email → always returns success (prevents email enumeration)
- Email sent with reset link containing time-limited (30 min) token
- Reset link opens app via deep link → new password form → password updated
- All existing sessions invalidated after password reset

### 5.2 User (Client) Features

#### F-USER-01 — Browse Available Lawyers
User lands on home screen which shows a filtered, sorted list of lawyers.

**Acceptance Criteria:**
- Default view shows online lawyers first, sorted by rating descending
- Each lawyer card shows: photo, name, specialties (top 2), avg rating, total ratings, city, languages spoken, online dot indicator
- Tap card → opens Lawyer Detail screen
- Infinite scroll pagination (20 per page)
- Pull-to-refresh supported

#### F-USER-02 — Filter Lawyers
User can filter the lawyer list by multiple criteria.

**Acceptance Criteria:**
- Filters available: Specialty (multi-select), City/State, Languages (multi-select), Online only (toggle), Min Rating
- Filters are combined with AND (all must match)
- Languages uses OR within — "matches if lawyer speaks any of selected languages"
- Sort options: Rating (high to low), Most consultations, Most experienced
- Filter state persists across app sessions (stored locally)
- "Clear all filters" button visible when any filter is active

#### F-USER-03 — View Lawyer Detail
Full lawyer profile page.

**Acceptance Criteria:**
- Shows: large photo, name, bio, all specialties, years of experience, languages, location, avg rating with breakdown, list of recent public ratings
- Prominent action buttons: "Chat Now", "Voice Call", "Video Call"
- Buttons disabled (with "Unavailable" label) if lawyer is offline
- Ratings list is scrollable, paginated separately

#### F-USER-04 — Initiate Chat
User starts a chat thread with any lawyer (even if lawyer is offline).

**Acceptance Criteria:**
- "Chat Now" opens chat screen
- If lawyer offline, user can still send messages — stored in pending queue, delivered when lawyer online + push notification sent
- User sees thread with full history from local SQLite
- Message statuses visible: Sending, Delivered, Read
- Typing indicator shown when lawyer is typing (real-time)

#### F-USER-05 — Initiate Voice/Video Call
User starts a real-time call with an online lawyer.

**Acceptance Criteria:**
- Call button disabled if lawyer offline or already in another call
- Tap → "Calling..." screen with cancel button
- Ringing timeout at 45 seconds → marked as missed
- If lawyer accepts → Agora call session starts (voice OR video per button tapped)
- In-call UI: mute toggle, camera toggle (video only), flip camera, end call button, call duration timer
- On call end → rating prompt

#### F-USER-06 — Consultation History
User sees list of all past consultations.

**Acceptance Criteria:**
- Sorted by most recent
- Each item shows: lawyer name, photo, type icon (chat/voice/video), date, duration, rating given
- Tap → full detail view with option to re-rate (only if no rating given yet)
- Pagination supported

#### F-USER-07 — Rate Consultation
After any ended consultation, user can rate the lawyer.

**Acceptance Criteria:**
- Rating prompt shown immediately after call end (or on next app open for missed/dropped calls)
- 5-star rating (required) + optional text review (max 500 chars)
- One rating per consultation (cannot change after submission)
- Rating updates lawyer's aggregated avgRating and totalRatings immediately
- User can skip rating (no penalty)

#### F-USER-08 — Manage Profile
User can edit their own profile info.

**Acceptance Criteria:**
- Editable: full name, profile photo, preferred language, city, state, phone
- Not editable: email, role
- Profile photo uploaded directly to R2 via presigned URL
- Changes take effect immediately

#### F-USER-09 — Receive Push Notifications
User gets FCM pushes for: new chat messages (when app closed/backgrounded), incoming calls, rating prompts, admin messages.

**Acceptance Criteria:**
- Permission requested at onboarding
- Different notification categories (user can mute chat but keep call alerts)
- Tap notification → deep-links to relevant screen in app

### 5.3 Lawyer Features

#### F-LAWYER-01 — Separate Signup Path
Lawyer selects "I am a Lawyer" at signup. After email OTP verification, they land on a license upload screen — cannot access main lawyer UI until verified.

**Acceptance Criteria:**
- After OTP verification, lawyer sees onboarding flow: (1) upload license, (2) wait for approval
- During PENDING_UPLOAD → only license upload screen available
- During PENDING_REVIEW → "Your license is being reviewed. We'll notify you within 48 hours." screen
- During REJECTED → rejection reason shown with re-upload option
- During APPROVED → full lawyer UI unlocked

#### F-LAWYER-02 — License Upload
Lawyer uploads their license document for verification.

**Acceptance Criteria:**
- Accepts PDF, JPG, PNG (max 5 MB)
- Lawyer enters license number (e.g., Bar Council registration number)
- Upload saved as BYTEA in PostgreSQL (admin-only access)
- Lawyer sees upload confirmation + expected review time (24-48 hrs)
- Can re-upload if rejected

#### F-LAWYER-03 — Manage Professional Profile
Once approved, lawyer can edit their professional info.

**Acceptance Criteria:**
- Editable: bio (max 1000 chars), specialties (multi-select, min 1), years of experience, languages spoken (multi-select), profile photo, city, state, rate per session (MVP: stored but not enforced)
- Preview of how profile appears to users
- Changes take effect immediately

#### F-LAWYER-04 — Toggle Availability
Lawyer can set themselves as online/offline manually, in addition to auto-detection from app presence.

**Acceptance Criteria:**
- Prominent online/offline toggle on home screen
- When offline: does not appear in user lawyer search filtered by "online only"
- When offline: cannot receive call attempts (user sees "Unavailable")
- Chat still delivered via push when offline (no lost messages)
- Auto-set to offline after 5 min of app background + no heartbeat

#### F-LAWYER-05 — Incoming Call Handling
Lawyer receives real-time incoming call notification when user initiates.

**Acceptance Criteria:**
- Full-screen incoming call UI with caller name, photo, type (voice/video)
- Options: Accept, Reject
- Reject → user sees "Call declined"
- Accept → Agora session starts
- If lawyer ignores for 45 sec → auto-marked missed, user sees "No answer"
- Works even when app backgrounded (via FCM push with high priority + CallKit/ConnectionService integration if time permits in MVP)

#### F-LAWYER-06 — View Consultation History & Stats
Lawyer sees their past consultations and performance metrics.

**Acceptance Criteria:**
- Consultations list: client name (or "Anonymous Client #123" — TBD in Design), date, type, duration, rating received
- Stats dashboard: total consultations, avg rating, breakdown by type, active days this month
- No earnings data shown in MVP (since free)

#### F-LAWYER-07 — Chat with Client
Same chat experience as client side — real-time + offline queue + read receipts.

**Acceptance Criteria:**
- Lawyer sees list of threads sorted by most recent message
- Can reply to any incoming message
- Cannot initiate chat with a client (users initiate first; lawyers respond)

### 5.4 Admin Features

#### F-ADMIN-01 — Admin Login
Separate login endpoint for admin accounts; no public signup.

**Acceptance Criteria:**
- Admin account created only by SuperAdmin
- 2FA optional in MVP (password only acceptable for MVP; 2FA in v2)
- Admin sessions time out after 1 hour of inactivity (tighter than user sessions)

#### F-ADMIN-02 — Lawyer Approval Queue
Admin sees list of pending lawyer applications.

**Acceptance Criteria:**
- List shows: lawyer name, email, license number, city, submitted date, "Awaiting Review" badge
- Sorted by submission time (oldest first — FIFO queue)
- Tap → opens lawyer detail view with license document viewable inline
- Action buttons: Approve, Reject (with required reason)

#### F-ADMIN-03 — Review License Document
Admin can view uploaded license document.

**Acceptance Criteria:**
- Document streams inline (PDF viewer for PDFs, image viewer for JPG/PNG)
- License number shown alongside document
- No download button (reduces data leakage risk)
- Session logged in audit_logs table ("Admin X viewed License Y at time Z")

#### F-ADMIN-04 — Approve Lawyer
Admin approves a lawyer, granting them full access.

**Acceptance Criteria:**
- One-click approve
- Lawyer's status changes to APPROVED immediately
- FCM push notification sent to lawyer: "Your account is approved. You can now log in."
- Admin action logged in audit_logs

#### F-ADMIN-05 — Reject Lawyer
Admin rejects a lawyer with a reason.

**Acceptance Criteria:**
- Required reason text (min 10 chars)
- Lawyer's status changes to REJECTED
- FCM push notification sent to lawyer with reason
- Lawyer can re-upload license and re-submit
- Admin action logged

#### F-ADMIN-06 — User/Lawyer Suspension
Admin can suspend a user or lawyer for policy violations.

**Acceptance Criteria:**
- Suspend action requires reason
- Suspended account: existing sessions force-logged-out immediately, login blocked, message "Your account has been suspended. Contact support."
- Suspended lawyers removed from public listings
- Unsuspend reverses all effects
- Audit logged

#### F-ADMIN-07 — Browse Users and Lawyers
Admin can search and view all accounts.

**Acceptance Criteria:**
- Search by email, name, phone
- Filter by status (active, suspended, pending review for lawyers)
- View details of any account
- Cannot edit account info (only suspend/unsuspend)

### 5.5 SuperAdmin Features

#### F-SA-01 — Admin Management
SuperAdmin creates and manages admin accounts.

**Acceptance Criteria:**
- SuperAdmin credentials seeded at first deploy via env vars + migration
- Only SuperAdmin can create admins
- Creates admin with email + temp password (admin prompted to change on first login)
- Can deactivate (soft delete) admins
- Deactivating an admin invalidates their sessions

#### F-SA-02 — Platform Dashboard
High-level metrics dashboard.

**Acceptance Criteria:**
- Shows: total users, lawyers, admins, consultations
- Breakdown of consultations by type (chat/voice/video)
- Lawyers by status (approved/pending/rejected)
- Active-in-last-24h counts
- Avg platform rating across all consultations

#### F-SA-03 — All Admin Permissions
SuperAdmin can do everything admins can do (approve, reject, suspend, etc.), plus admin management.

### 5.6 Cross-Cutting Features

#### F-X-01 — Language Support for Matching
User sets preferred language; lawyer declares languages spoken.

**Acceptance Criteria:**
- Language options (MVP): English, Hindi, Punjabi, Tamil, Bengali, Marathi, Telugu, Gujarati, Kannada, Malayalam, Odia, Urdu
- User profile: single preferred_language
- Lawyer profile: multi-select languages_spoken
- Lawyer search default: show lawyers who speak user's preferred language (can be overridden by filter)
- UI itself remains English-only in MVP

#### F-X-02 — Specialties
Pre-defined set of legal specialties.

**MVP List:** Criminal Law, Civil Law, Corporate Law, Family Law, Property Law, Labour & Employment, Tax Law, Intellectual Property, Consumer Protection, Cyber Law, Constitutional Law, Immigration Law, Banking & Finance, Environmental Law, Insurance Law.

**Acceptance Criteria:**
- Lawyer must select ≥1 specialty
- User can filter by specialty (multi-select)
- Admin can add/edit specialties via SuperAdmin panel (v1.1, not MVP)

---

## 6. Key User Flows

### 6.1 First-Time User Flow

```
Open App
  → Welcome Screen ("Legal help, instantly")
  → Sign Up tab
  → Fill form (email, password, name, role=User, language, city)
  → Submit
  → OTP screen → enter 6-digit code
  → Permission prompts (notifications, microphone, camera)
  → Land on Lawyer List screen
  → Browse or filter lawyers
  → Tap a lawyer → Detail page
  → Tap "Video Call"
  → Calling screen
  → Lawyer accepts → Video call begins
  → Call ends → Rating prompt → Submit rating
  → Back to Lawyer List
```

### 6.2 First-Time Lawyer Flow

```
Open App
  → Welcome Screen
  → Sign Up tab
  → Fill form (role=Lawyer)
  → Submit
  → OTP screen → enter code
  → License Upload screen (cannot skip)
  → Pick PDF/JPG + enter license number
  → Upload → "Under review" screen
  → [Wait 24-48 hrs]
  → Receive FCM push: "Approved!"
  → Open app → Login
  → Land on Lawyer Home (incoming call queue, stats, toggle)
  → Set online
  → User calls → Accept → Video consultation
  → Call ends → Consultation saved
```

### 6.3 Admin Approval Flow

```
Admin opens app (admin-only login URL)
  → Login with admin credentials
  → Dashboard: "12 pending reviews"
  → Tap → Approval Queue
  → Tap first lawyer → See profile + view license document inline
  → If valid → Tap Approve → Confirmation dialog → Confirmed
  → Lawyer gets push notification
  → Queue count decreases to 11
  → Repeat
```

### 6.4 Multi-Device Login Flow

```
User is logged in on Phone A
  → User attempts login on Phone B
  → Server: Device Conflict (409)
  → Phone B shows dialog: "Logged in on iPhone 13 · Mumbai (2 min ago). Log out?"
  → User taps "Log Out Other Device"
  → Phone B retries login with forceLogout=true
  → Phone A receives socket event 'auth:force_logout' → clears tokens → routes to login
  → Phone A shows toast: "You've been logged out — signed in from another device"
  → Phone B receives tokens → lands on home screen
```

---

## 7. Non-Functional Requirements

### 7.1 Performance
- **API latency** — p95 < 300ms (excluding external calls like Agora token gen)
- **Socket.IO message delivery** — p95 < 500ms within India
- **Call connect time** — user taps call → both parties connected < 4 seconds
- **App launch (cold)** — under 2 seconds on mid-range Android (Redmi Note 10)
- **Lawyer list scroll** — 60 FPS, no jank

### 7.2 Reliability
- **API availability** — 99.0% uptime for MVP
- **Call drop rate** — < 5% (Agora SLA)
- **Chat message loss** — 0% (pending queue + local SQLite ensures delivery)
- **FCM push delivery** — 95%+ within 5 seconds

### 7.3 Security & Privacy
- TLS 1.3 everywhere
- Passwords bcrypt-hashed (cost 12)
- License documents stored in Postgres BYTEA, served only to admins via authenticated endpoints
- JWT rotation on refresh
- Device session enforcement (single device per user)
- No chat/call content stored server-side (meta only)

### 7.4 Platform Support
- **Android:** 8.0+ (API 26+), tested on Redmi Note 10, OnePlus 10, Samsung Galaxy A series
- **iOS:** 14+, tested on iPhone 11 and newer
- **Network:** Works on 4G/5G/WiFi; graceful degradation on 3G (chat works, video calls warn about bandwidth)

### 7.5 Localization (MVP Scope)
- UI language: English only
- Lawyer/User language field: 12 languages supported for matching
- Date/time formats: India locale (DD/MM/YYYY, 24-hour in UI)
- Currency: INR (in payment fields, stored but not displayed in MVP)

### 7.6 Accessibility
- Text scales with system font size
- Color contrast meets WCAG AA
- Screen reader labels on all interactive elements
- Minimum tap target 48dp

---

## 8. Success Metrics

### 8.1 Primary (Star Metrics)
- **Consultations completed per week** — primary health indicator
- **Lawyer utilization rate** — average consultations per approved lawyer per week
- **User retention** — % of users who do ≥2 consultations in 30 days

### 8.2 Supporting Metrics
- Approved lawyer count growth week-over-week
- Registered user count growth week-over-week
- Call completion rate (not dropped) — target >90%
- Avg rating across all consultations — target 4.0+
- 7-day retention for newly registered users — target 30%+
- Time-from-signup-to-first-consultation — target <1 hour for users

### 8.3 Quality Metrics
- Crash-free users (Firebase Crashlytics) — target 99.5%+
- Time-to-first-byte on API — target <200ms
- User-reported issues per 1000 sessions — target <5

---

## 9. Assumptions, Constraints, Dependencies

### 9.1 Assumptions
- Indian lawyers are willing to do mobile consultations (validated by existing competitors like Vakilsearch, LawRato)
- Users are comfortable with video calls on their phones (validated by widespread adoption of WhatsApp video, Google Meet)
- Free-tier MVP will attract sufficient supply + demand without monetization
- Agora's India-based TURN servers provide acceptable call quality in Tier-2/3 cities
- 5 MB is sufficient for license document files (Bar Council certificates are typically 200KB-2MB)

### 9.2 Constraints
- Mobile-only (no web client in MVP)
- India-only (jurisdiction, Bar Council validation)
- English UI only (languages are for matching, not UI localization)
- No payment processing in MVP (free for all; Razorpay integration is a later phase)
- Single timezone handling (IST)

### 9.3 External Dependencies
- **Agora** — video/voice infrastructure (SLA: 99.9%, India data centers)
- **Firebase Cloud Messaging** — push notifications (Google infrastructure)
- **Brevo** — email OTP delivery
- **Cloudflare R2** — profile photo storage
- **PostgreSQL** — primary data store (managed by cloud provider)
- **Bar Council of India registry** — manual lookup by admins during license verification (not automated in MVP)

---

## 10. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Fake lawyer applications | Medium | High | Manual admin review of every license; cross-reference with Bar Council registry |
| Platform misused for illegal advice | Low | High | Terms of service explicit; audit logs for admin investigation; report feature in v2 |
| Low lawyer supply early on | High | High | Direct outreach to law colleges and young advocates; zero fees during MVP |
| Agora costs spiral at scale | Low (MVP) | Medium | Architecture has provider abstraction; migration path to LiveKit documented |
| User uploads inappropriate content in chat | Medium | Medium | Report feature in v2; chat content NOT server-stored, limits liability |
| Admin approves fraudulent lawyer | Low | High | SuperAdmin audit log reviews; two-admin approval for high-risk regions (v2) |
| FCM push unreliable on some Android OEMs (Xiaomi, Oppo) | High | Medium | In-app polling fallback every 30s when app foregrounded; socket.io persistent connection when active |
| User loses phone → loses chat history | Certain | Low | Documented in onboarding; v2 can add optional encrypted server backup |
| Compliance challenge from Bar Council (lawyer advertising rules) | Medium | High | Legal review before launch; frame as "directory" not "advertising"; lawyer profiles factual only |

---

## 11. Out of Scope (Explicitly Deferred to Post-MVP)

- Payment integration (Razorpay)
- Session billing logic (block-based, per-minute, flat-fee)
- Chat attachments (images, documents inside chat)
- Group consultations (multiple lawyers, or multiple clients)
- Lawyer calendar / appointment scheduling
- Web-based admin panel
- SMS notification fallback
- End-to-end encryption of chat content
- Multi-language UI (Hindi, regional languages)
- Lawyer onboarding automation (Bar Council registry API integration)
- Advanced matching ML (recommended lawyer based on past consultations)
- User-to-user referral / invite program
- Lawyer subscription tiers (featured listing, etc.)
- Case-file / document storage per client
- In-app dispute resolution
- Reviews moderation / flagging workflow
- Tax invoice generation
- Withdrawal/payout for lawyers (ties to payments)
- Public lawyer profiles via web URL (shareable)
- Deep linking from external sites
- Customer support chat (intercom-style) inside the app
- Real-time call transcription or recording

---

## 12. Product Roadmap

### MVP — Month 0-3
Everything in Section 5. Free for all. 50 lawyers, 1,000 users, 100 consultations target.

### v1.1 — Month 4
- In-app support chat with admin team
- Report user/lawyer feature
- Review flagging & moderation
- Admin 2FA

### v1.2 — Month 5
- Razorpay integration (test mode first)
- Pay-per-consult with lawyer-set rates
- Platform commission (configurable, default 15%)
- Payout dashboard for lawyers

### v1.3 — Month 6
- Chat attachments (images, PDFs)
- SMS notification fallback
- Offline message pre-queue (send while offline, auto-flush when online)

### v2.0 — Month 7-9
- Web-based admin panel
- Multi-language UI (Hindi first)
- Lawyer availability calendar / booking
- User-to-lawyer favorites / "My Lawyer" pre-assignment
- Invite / referral program
- Case-file repository

### v3.0 — Month 10+
- Document drafting assistance (with lawyer)
- AI-powered question-triage ("Do I even need a lawyer?")
- Expansion to other countries (language/jurisdiction work)
- Group consultations
- Case management dashboard for lawyers

---

## 13. Open Questions & Decisions to Revisit

These items are decided for MVP but may need revisiting post-launch:

1. **Should client be anonymous to lawyer?** — Currently: lawyer sees client's full name. Debate: privacy-conscious clients may want "Anonymous Client #123". Likely revisit in v1.2.
2. **Should lawyer see client's consultation history with other lawyers?** — Currently: No. May be valuable for context in v2.
3. **Should ratings be moderated before going public?** — Currently: Published immediately. May add a 24-hour delay + moderation in v1.1.
4. **Emergency flag on consultations?** — User said no special feature, but a post-launch survey could validate demand for this.
5. **Referral bonus structure** — Designed in for later; specifics deferred.
6. **Should admin be able to read chat content in dispute cases?** — Currently: No (content not server-stored). In v2, may need optional "preserve for dispute" flag that stores last X messages server-side when either party disputes.

---

## 14. Glossary

- **User** — A client seeking legal advice on the platform
- **Lawyer** — A verified legal practitioner providing consultations
- **Admin** — Platform team member approving lawyers, handling moderation
- **SuperAdmin** — Platform owner with full administrative control
- **Consultation** — A single chat, voice call, or video call session between a user and lawyer
- **Pending Messages** — Transient server-side queue for messages whose recipient was offline at send time
- **Presence** — Online/offline status tracked via socket connection heartbeats
- **BYTEA** — PostgreSQL binary data column type used for license documents
- **Agora** — Third-party video/voice infrastructure provider
- **FCM** — Firebase Cloud Messaging, for push notifications
- **Bar Council of India** — Regulatory body governing lawyers in India; registration is the primary verification check

---

*End of PRD.md — ready for review.*
