# `jerry` — MVP Technical Documentation

**Project:** jerry — Lawyer-Client Consultation Platform
**Document Purpose:** Concrete implementation spec for MVP build. Companion to `Architecture.md`.
**Audience:** Cursor AI / developers implementing the codebase.
**Version:** 1.0 (MVP)

> **How to use this doc:** Architecture.md explains *what* and *why*. This doc explains *how* — exact schemas, endpoints, events, configs. Use both together during implementation.

---

## 1. MVP Scope — The Exact Build List

### 1.1 IN the MVP (Must Have)

**Authentication**
- [x] Signup with email + password + role selection (User / Lawyer)
- [x] Email OTP verification (6-digit, 10-min expiry)
- [x] Login with email + password
- [x] JWT access token (15 min) + refresh token (30 days)
- [x] Logout (server-side refresh token revoke)
- [x] Multi-device handling with "log out other device" confirmation
- [x] Forgot password → email reset link

**User (Client) Features**
- [x] View own profile, edit full name, profile photo, preferred language
- [x] Browse all approved lawyers
- [x] Filter lawyers by: specialty, city/state, languages spoken, online status
- [x] View lawyer detail page (bio, specialties, rating, languages, years exp)
- [x] Initiate chat with any lawyer
- [x] Initiate voice call / video call with online lawyer
- [x] View consultation history (metadata: date, lawyer, duration)
- [x] Rate + review lawyer after each consultation
- [x] Receive push notifications (messages, call incoming)

**Lawyer Features**
- [x] All User features (can also consult other lawyers if needed)
- [x] Separate signup path (selects role=Lawyer)
- [x] Upload license document after signup (pre-login)
- [x] View approval status (pending / approved / rejected with reason)
- [x] Edit professional profile (bio, specialties, years exp, languages, rate placeholder)
- [x] Toggle availability (online / offline)
- [x] Receive incoming call notifications
- [x] View own consultation history
- [x] View own rating aggregate

**Admin Features**
- [x] Login (separate admin login endpoint)
- [x] View approval queue (lawyers with PENDING status)
- [x] View lawyer license document (BYTEA stream)
- [x] Approve lawyer / Reject lawyer with reason
- [x] Suspend user / lawyer
- [x] View all users, all lawyers

**SuperAdmin Features**
- [x] All Admin features
- [x] Create admin accounts
- [x] Revoke admin accounts
- [x] Platform metrics dashboard (total users, lawyers, consultations, avg ratings)

**Real-time**
- [x] Chat via Socket.IO (online delivery + offline queue)
- [x] Read receipts + typing indicators
- [x] Online/offline presence per lawyer
- [x] Agora video/voice call with ringing signaling
- [x] FCM push for incoming call + offline messages

**Chat Storage**
- [x] Server-side pending_messages (transient queue only)
- [x] Client-side SQLite persistence (full history on device)
- [x] Server-side consultation metadata log

### 1.2 NOT in MVP (Deferred)

- ❌ Payment integration (Razorpay) — schema stub only
- ❌ Pay-per-consult session billing logic
- ❌ Chat attachments (images, documents in chat)
- ❌ Group chat / multi-party calls
- ❌ Lawyer appointment booking / calendar
- ❌ Web admin panel
- ❌ SMS fallback notifications
- ❌ Chat content end-to-end encryption
- ❌ Advanced lawyer recommendation ML
- ❌ Multi-language UI (English-only UI text in MVP; languages are only for filtering)

---

## 2. Development Environment Setup

### 2.1 Prerequisites

```
- Node.js 20 LTS
- npm 10+ or pnpm 9+
- Flutter SDK 3.24+
- Docker + Docker Compose
- PostgreSQL 16 (via Docker)
- Redis 7 (via Docker)
- Android Studio + Xcode (for Flutter builds)
- VS Code with Prisma + Flutter + NestJS extensions (recommended)
```

### 2.2 Monorepo Structure

```
jerry/
├── backend/                      # NestJS API
│   ├── src/
│   ├── prisma/
│   ├── test/
│   ├── docker/
│   ├── .env.example
│   ├── package.json
│   └── tsconfig.json
├── mobile/                       # Flutter app
│   ├── lib/
│   ├── android/
│   ├── ios/
│   ├── test/
│   ├── pubspec.yaml
│   └── .env.example
├── docs/
│   ├── Architecture.md
│   ├── MVP-Tech-Doc.md
│   ├── PRD.md
│   └── Design.md
├── docker-compose.yml            # Postgres + Redis for dev
├── .gitignore
└── README.md
```

### 2.3 Backend `.env.example`

```env
# Server
NODE_ENV=development
PORT=3000
API_BASE_URL=http://localhost:3000

# Database
DATABASE_URL=postgresql://jerry:jerry_pass@localhost:5432/jerry_dev

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# JWT
JWT_ACCESS_SECRET=<openssl rand -base64 64>
JWT_REFRESH_SECRET=<openssl rand -base64 64>
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=30d

# Brevo (Email OTP)
BREVO_API_KEY=<from brevo dashboard>
BREVO_SENDER_EMAIL=noreply@jerry.in
BREVO_SENDER_NAME=Jerry

# Firebase Cloud Messaging
FCM_PROJECT_ID=jerry-prod
FCM_PRIVATE_KEY=<service account private key>
FCM_CLIENT_EMAIL=<service account client email>

# Agora
AGORA_APP_ID=<from agora dashboard>
AGORA_APP_CERTIFICATE=<from agora dashboard>
AGORA_TOKEN_EXPIRY=3600

# Cloudflare R2
R2_ACCOUNT_ID=<cloudflare account id>
R2_ACCESS_KEY_ID=<r2 api token key>
R2_SECRET_ACCESS_KEY=<r2 api token secret>
R2_BUCKET_NAME=jerry-media
R2_PUBLIC_URL=https://media.jerry.in

# SuperAdmin Seed (first deploy only)
SUPERADMIN_EMAIL=superadmin@jerry.in
SUPERADMIN_PASSWORD=<strong password, rotate after first login>

# Rate Limits
THROTTLE_TTL=60
THROTTLE_LIMIT=60

# Logging
LOG_LEVEL=debug
```

### 2.4 Flutter `.env.example`

```env
API_BASE_URL=http://localhost:3000
SOCKET_URL=ws://localhost:3000
AGORA_APP_ID=<same as backend>
ENVIRONMENT=development
```

### 2.5 Local Docker Compose

```yaml
version: '3.9'
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: jerry
      POSTGRES_PASSWORD: jerry_pass
      POSTGRES_DB: jerry_dev
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  pg_data:
  redis_data:
```

---

## 3. Database Schema (Prisma)

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// ==========================================
// IDENTITY TABLES (separate per role)
// ==========================================

model User {
  id                String   @id @default(uuid())
  email             String   @unique
  phone             String?
  passwordHash      String
  fullName          String
  preferredLanguage String   @default("English")
  profilePhotoUrl   String?
  city              String?
  state             String?
  isSuspended       Boolean  @default(false)
  suspensionReason  String?
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt

  deviceSessions    DeviceSession[]
  consultationsAsClient Consultation[]    @relation("ClientConsultations")
  ratingsGiven      Rating[]
  pendingMessagesIn PendingMessage[]      @relation("RecipientUser")
  pendingMessagesOut PendingMessage[]     @relation("SenderUser")

  @@index([email])
  @@index([city, state])
}

model Lawyer {
  id                   String                 @id @default(uuid())
  email                String                 @unique
  phone                String?
  passwordHash         String
  fullName             String
  preferredLanguage    String                 @default("English")
  profilePhotoUrl      String?
  bio                  String?                @db.Text
  yearsExperience      Int                    @default(0)
  languagesSpoken      String[]               @default([])
  ratePerSession       Decimal                @default(0) @db.Decimal(10, 2)
  city                 String?
  state                String?

  // License & verification
  licenseDocument      Bytes?                 // BYTEA
  licenseMimeType      String?
  licenseNumber        String?
  verificationStatus   VerificationStatus     @default(PENDING_UPLOAD)
  verificationNotes    String?
  approvedByAdminId    String?
  approvedAt           DateTime?

  // Availability
  isOnline             Boolean                @default(false)
  lastActiveAt         DateTime?

  // Aggregates (denormalized for fast reads)
  avgRating            Float                  @default(0)
  totalRatings         Int                    @default(0)
  totalConsultations   Int                    @default(0)

  isSuspended          Boolean                @default(false)
  suspensionReason     String?
  createdAt            DateTime               @default(now())
  updatedAt            DateTime               @updatedAt

  deviceSessions       DeviceSession[]
  specialties          LawyerSpecialty[]
  consultationsAsLawyer Consultation[]        @relation("LawyerConsultations")
  ratingsReceived      Rating[]
  pendingMessagesIn    PendingMessage[]       @relation("RecipientLawyer")
  pendingMessagesOut   PendingMessage[]       @relation("SenderLawyer")

  @@index([email])
  @@index([verificationStatus])
  @@index([city, state])
  @@index([isOnline])
}

model Admin {
  id                    String   @id @default(uuid())
  email                 String   @unique
  passwordHash          String
  fullName              String
  createdBySuperAdminId String
  isActive              Boolean  @default(true)
  createdAt             DateTime @default(now())
  updatedAt             DateTime @updatedAt

  auditLogs             AuditLog[]

  @@index([email])
}

model SuperAdmin {
  id            String   @id @default(uuid())
  email         String   @unique
  passwordHash  String
  fullName      String
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  @@index([email])
}

// ==========================================
// LAWYER SPECIALTIES
// ==========================================

model Specialty {
  id        String            @id @default(uuid())
  name      String            @unique  // e.g., "Criminal Law"
  slug      String            @unique  // e.g., "criminal-law"
  createdAt DateTime          @default(now())

  lawyers   LawyerSpecialty[]
}

model LawyerSpecialty {
  lawyerId    String
  specialtyId String
  lawyer      Lawyer    @relation(fields: [lawyerId], references: [id], onDelete: Cascade)
  specialty   Specialty @relation(fields: [specialtyId], references: [id], onDelete: Cascade)

  @@id([lawyerId, specialtyId])
  @@index([specialtyId])
}

// ==========================================
// CONSULTATIONS
// ==========================================

model Consultation {
  id              String              @id @default(uuid())
  userId          String
  lawyerId        String
  type            ConsultationType    // CHAT | VOICE | VIDEO
  status          ConsultationStatus  @default(RINGING)
  startedAt       DateTime            @default(now())
  endedAt         DateTime?
  durationSeconds Int?
  agoraChannelName String?

  // Payment fields (stub in MVP)
  amountPaid      Decimal             @default(0) @db.Decimal(10, 2)
  paymentStatus   PaymentStatus       @default(FREE)

  user            User                @relation("ClientConsultations", fields: [userId], references: [id])
  lawyer          Lawyer              @relation("LawyerConsultations", fields: [lawyerId], references: [id])
  rating          Rating?

  @@index([userId, startedAt(sort: Desc)])
  @@index([lawyerId, startedAt(sort: Desc)])
  @@index([status])
}

// ==========================================
// RATINGS
// ==========================================

model Rating {
  id             String       @id @default(uuid())
  consultationId String       @unique
  userId         String
  lawyerId       String
  stars          Int          // 1-5
  reviewText     String?      @db.Text
  createdAt      DateTime     @default(now())

  consultation   Consultation @relation(fields: [consultationId], references: [id])
  user           User         @relation(fields: [userId], references: [id])
  lawyer         Lawyer       @relation(fields: [lawyerId], references: [id])

  @@index([lawyerId])
}

// ==========================================
// DEVICE SESSIONS (multi-device enforcement)
// ==========================================

model DeviceSession {
  id            String   @id @default(uuid())
  userId        String?
  lawyerId      String?
  deviceId      String   // uuid generated on Flutter first launch
  deviceInfo    String   // "iPhone 13 · Mumbai" readable string
  fcmToken      String?
  lastActiveAt  DateTime @default(now())
  createdAt     DateTime @default(now())

  user          User?    @relation(fields: [userId], references: [id], onDelete: Cascade)
  lawyer        Lawyer?  @relation(fields: [lawyerId], references: [id], onDelete: Cascade)

  @@unique([userId, deviceId])
  @@unique([lawyerId, deviceId])
  @@index([userId])
  @@index([lawyerId])
}

// ==========================================
// PENDING MESSAGES (transient offline queue)
// ==========================================

model PendingMessage {
  id                String   @id @default(uuid())
  senderUserId      String?
  senderLawyerId    String?
  recipientUserId   String?
  recipientLawyerId String?
  content           String   @db.Text
  clientMessageId   String   // for dedup on client
  createdAt         DateTime @default(now())

  senderUser        User?    @relation("SenderUser", fields: [senderUserId], references: [id], onDelete: Cascade)
  senderLawyer      Lawyer?  @relation("SenderLawyer", fields: [senderLawyerId], references: [id], onDelete: Cascade)
  recipientUser     User?    @relation("RecipientUser", fields: [recipientUserId], references: [id], onDelete: Cascade)
  recipientLawyer   Lawyer?  @relation("RecipientLawyer", fields: [recipientLawyerId], references: [id], onDelete: Cascade)

  @@index([recipientUserId, createdAt])
  @@index([recipientLawyerId, createdAt])
}

// ==========================================
// AUDIT LOG (admin actions only)
// ==========================================

model AuditLog {
  id          String   @id @default(uuid())
  adminId     String?
  superAdminId String?
  action      String   // "APPROVE_LAWYER", "REJECT_LAWYER", "SUSPEND_USER", etc.
  targetType  String   // "LAWYER", "USER", "ADMIN"
  targetId    String
  metadata    Json?
  createdAt   DateTime @default(now())

  admin       Admin?   @relation(fields: [adminId], references: [id])

  @@index([targetId, targetType])
  @@index([createdAt(sort: Desc)])
}

// ==========================================
// ENUMS
// ==========================================

enum VerificationStatus {
  PENDING_UPLOAD
  PENDING_REVIEW
  APPROVED
  REJECTED
}

enum ConsultationType {
  CHAT
  VOICE
  VIDEO
}

enum ConsultationStatus {
  RINGING
  ACTIVE
  ENDED
  MISSED
  REJECTED_BY_LAWYER
  DROPPED
}

enum PaymentStatus {
  FREE
  PENDING
  PAID
  REFUNDED
}
```

### 3.1 Seed Data (`prisma/seed.ts`)

**SuperAdmin** seeded from env vars on first deploy.

**Specialties** seeded as static list:
```
Criminal Law, Civil Law, Corporate Law, Family Law, Property Law,
Labour & Employment, Tax Law, Intellectual Property, Consumer Protection,
Cyber Law, Constitutional Law, Immigration Law, Banking & Finance,
Environmental Law, Insurance Law
```

---

## 4. REST API Contract

### Base URL Convention
```
Development: http://localhost:3000/api/v1
Production:  https://api.jerry.in/api/v1
```

### 4.1 Response Envelope

All responses follow this standard format:

**Success:**
```json
{
  "success": true,
  "data": { ... },
  "meta": { "timestamp": "2026-04-19T10:30:00Z" }
}
```

**Error:**
```json
{
  "success": false,
  "error": {
    "code": "EMAIL_ALREADY_EXISTS",
    "message": "An account with this email already exists.",
    "details": {}
  },
  "meta": { "timestamp": "2026-04-19T10:30:00Z" }
}
```

### 4.2 Standard Error Codes

| Code | HTTP | Meaning |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Input validation failed |
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `TOKEN_EXPIRED` | 401 | JWT expired, refresh needed |
| `FORBIDDEN` | 403 | Role/permission denied |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Duplicate / state conflict (incl. multi-device) |
| `RATE_LIMITED` | 429 | Too many requests |
| `OTP_INVALID` | 400 | Wrong OTP |
| `OTP_EXPIRED` | 400 | OTP TTL passed |
| `OTP_ATTEMPTS_EXCEEDED` | 400 | >5 attempts on same OTP |
| `LAWYER_NOT_APPROVED` | 403 | Lawyer trying to login before approval |
| `USER_SUSPENDED` | 403 | Account suspended |
| `DEVICE_CONFLICT` | 409 | Already logged in on another device |
| `INTERNAL_ERROR` | 500 | Unexpected server error |

### 4.3 Authentication Endpoints

#### `POST /auth/signup`
```json
// Request
{
  "email": "client@example.com",
  "password": "StrongPass@123",
  "fullName": "Rahul Sharma",
  "role": "USER",                 // or "LAWYER"
  "preferredLanguage": "English",
  "city": "Mumbai",
  "state": "Maharashtra"
}

// Response 202
{
  "success": true,
  "data": { "message": "OTP sent to email", "otpExpiresInSec": 600 }
}
```

#### `POST /auth/verify-otp`
```json
// Request
{ "email": "client@example.com", "otp": "482913", "deviceId": "<uuid>", "deviceInfo": "iPhone 13 · Mumbai", "fcmToken": "<fcm>" }

// Response 201 (User) — account auto-activated
{
  "success": true,
  "data": {
    "accessToken": "...",
    "refreshToken": "...",
    "user": { "id": "...", "email": "...", "fullName": "...", "role": "USER" }
  }
}

// Response 201 (Lawyer) — account created but login-blocked until license uploaded+approved
{
  "success": true,
  "data": {
    "accessToken": "...",                         // limited scope: can only upload license
    "refreshToken": "...",
    "user": { "id": "...", "role": "LAWYER", "verificationStatus": "PENDING_UPLOAD" }
  }
}
```

#### `POST /auth/login`
```json
// Request
{ "email": "...", "password": "...", "deviceId": "<uuid>", "deviceInfo": "...", "fcmToken": "...", "forceLogout": false }

// Response 200
{ "success": true, "data": { "accessToken": "...", "refreshToken": "...", "user": {...} } }

// Response 409 (device conflict)
{
  "success": false,
  "error": {
    "code": "DEVICE_CONFLICT",
    "message": "Already logged in on another device.",
    "details": { "existingDevice": "iPhone 13 · Mumbai", "lastActive": "2026-04-19T09:00Z" }
  }
}
// Client retries with forceLogout:true after user confirmation
```

#### `POST /auth/refresh`
```json
// Request
{ "refreshToken": "..." }
// Response
{ "success": true, "data": { "accessToken": "...", "refreshToken": "..." } }  // new refresh token (rotation)
```

#### `POST /auth/logout`
```json
// Requires Authorization header
// Server invalidates refresh token for current device
// Response 204
```

#### `POST /auth/forgot-password`
```json
// Request
{ "email": "..." }
// Response 202  (always; doesn't leak whether email exists)
```

#### `POST /auth/reset-password`
```json
// Request
{ "token": "<from email link>", "newPassword": "..." }
// Response 200
```

### 4.4 User Endpoints

#### `GET /users/me`
Returns current user profile.

#### `PATCH /users/me`
```json
// Request (any subset)
{ "fullName": "...", "preferredLanguage": "...", "city": "...", "state": "..." }
```

#### `POST /users/me/profile-photo/presign`
Returns R2 presigned upload URL (5-min TTL). Client uploads directly to R2, then sends final URL to backend.

#### `PATCH /users/me/profile-photo`
```json
{ "profilePhotoUrl": "https://media.jerry.in/..." }
```

### 4.5 Lawyer Search Endpoints (called by User)

#### `GET /lawyers`
Query params:
```
?specialty=criminal-law&city=Mumbai&languages=English,Hindi&online=true&page=1&limit=20&sortBy=rating
```
Response: paginated array of `LawyerSummaryDto` (id, fullName, profilePhotoUrl, specialties[], city, state, avgRating, totalRatings, isOnline, languagesSpoken, yearsExperience, ratePerSession).

#### `GET /lawyers/:id`
Full lawyer profile with bio.

#### `GET /specialties`
Returns all specialties (for filter dropdown).

### 4.6 Lawyer Self Endpoints

#### `GET /lawyers/me`
#### `PATCH /lawyers/me`
Fields: `bio`, `yearsExperience`, `languagesSpoken`, `ratePerSession`, `city`, `state`, `preferredLanguage`.

#### `PATCH /lawyers/me/specialties`
```json
{ "specialtyIds": ["<uuid1>", "<uuid2>"] }
```
Replaces full specialty set.

#### `PATCH /lawyers/me/availability`
```json
{ "isOnline": true }
```

#### `GET /lawyers/me/stats`
Returns: `totalConsultations`, `avgRating`, `totalRatings`, `consultationsByType` (chat/voice/video breakdown).

### 4.7 License Endpoints

#### `POST /license/upload` (Lawyer only)
```
Multipart form-data:
  file: <license.pdf or .jpg>
  licenseNumber: "MH/12345/2020"
```
- Max size: 5 MB
- MIME whitelist: `application/pdf`, `image/jpeg`, `image/png`
- Sets `lawyer.licenseDocument` (BYTEA), `lawyer.licenseMimeType`, `lawyer.licenseNumber`, `lawyer.verificationStatus = PENDING_REVIEW`.

#### `GET /license/status` (Lawyer only)
Returns `{ status, rejectionNotes, uploadedAt, reviewedAt }`.

### 4.8 Admin Endpoints (role=ADMIN or SUPER_ADMIN)

#### `POST /admin/login`
Same as `/auth/login` but only for Admin accounts.

#### `GET /admin/approval-queue`
Paginated list of lawyers with `verificationStatus = PENDING_REVIEW`.

#### `GET /admin/lawyer/:id`
Full lawyer data including license metadata.

#### `GET /admin/lawyer/:id/license`
Returns license document as raw binary stream with correct MIME type. Requires auth. **Not** cached by Flutter — displayed ephemerally.

#### `POST /admin/lawyer/:id/approve`
```json
{}
// Response: lawyer.verificationStatus = APPROVED, FCM push sent to lawyer
```

#### `POST /admin/lawyer/:id/reject`
```json
{ "reason": "License number doesn't match Bar Council registry." }
```

#### `POST /admin/user/:id/suspend`
```json
{ "reason": "Abusive behavior reported by multiple lawyers." }
```

#### `POST /admin/user/:id/unsuspend`
#### `POST /admin/lawyer/:id/suspend`
#### `POST /admin/lawyer/:id/unsuspend`

#### `GET /admin/users?search=...&page=1`
#### `GET /admin/lawyers?status=APPROVED&page=1`

### 4.9 SuperAdmin Endpoints (role=SUPER_ADMIN only)

#### `POST /superadmin/admins`
```json
{ "email": "admin1@jerry.in", "password": "...", "fullName": "..." }
```

#### `GET /superadmin/admins`
#### `PATCH /superadmin/admins/:id/deactivate`

#### `GET /superadmin/dashboard`
```json
{
  "totals": { "users": 1243, "lawyers": 87, "admins": 3, "consultations": 5621 },
  "consultationsBreakdown": { "chat": 4200, "voice": 900, "video": 521 },
  "lawyersByStatus": { "approved": 87, "pendingReview": 12, "rejected": 4 },
  "avgPlatformRating": 4.3,
  "activeInLast24h": { "users": 421, "lawyers": 34 }
}
```

### 4.10 Call Endpoints

#### `POST /call/initiate`
```json
// Request
{ "lawyerId": "...", "type": "VIDEO" }  // or "VOICE"

// Response 200
{
  "success": true,
  "data": {
    "consultationId": "...",
    "agoraChannelName": "consult_<id>",
    "agoraToken": "...",   // caller's token
    "uid": 12345           // caller's Agora uid
  }
}

// Response 409 — lawyer already in call or offline
{ "error": { "code": "LAWYER_UNAVAILABLE" } }
```

After this, caller joins the Agora channel. Server sends `call:incoming` socket event + FCM push to lawyer in parallel.

#### `POST /call/:consultationId/accept` (Lawyer)
Returns lawyer's Agora token. Updates `consultation.status = ACTIVE`.

#### `POST /call/:consultationId/reject` (Lawyer)
Sets `status = REJECTED_BY_LAWYER`. Emits socket event to caller.

#### `POST /call/:consultationId/end`
Either party can call. Sets `status = ENDED`, computes `durationSeconds`.

### 4.11 Consultation Endpoints

#### `GET /consultations/my`
Paginated list of user's or lawyer's past consultations (auto-detects based on auth role).
```
?page=1&limit=20&type=VIDEO&status=ENDED
```

#### `GET /consultations/:id`
Full details (metadata only, no chat content).

### 4.12 Rating Endpoints

#### `POST /ratings`
```json
{ "consultationId": "...", "stars": 5, "reviewText": "Excellent advice!" }
```
- Only works if consultation.status = ENDED and rater is the User (not Lawyer)
- One rating per consultation (unique constraint)
- Updates denormalized `lawyer.avgRating` and `lawyer.totalRatings`

#### `GET /lawyers/:id/ratings?page=1`
Paginated public ratings on a lawyer.

### 4.13 Notification Endpoints

#### `POST /notifications/device-token`
```json
{ "fcmToken": "...", "deviceId": "..." }
```
Registers/updates FCM token for current session.

---

## 5. Socket.IO Event Contract

### 5.1 Connection

**Client connects:**
```javascript
io(SOCKET_URL, {
  auth: { token: '<jwt access token>' },
  transports: ['websocket']
})
```

**Server-side JWT validation in `connection` middleware.** Socket disconnected if invalid.

### 5.2 Server → Client Events

| Event | Payload | Purpose |
|---|---|---|
| `chat:receive` | `{ messageId, fromId, fromRole, content, clientMessageId, timestamp }` | New chat message |
| `chat:delivered` | `{ clientMessageId, serverMessageId }` | Ack after server-received |
| `chat:read` | `{ messageId, readAt }` | Receiver marked as read |
| `chat:typing` | `{ fromId, isTyping }` | Typing indicator |
| `presence:online` | `{ userId, role }` | Someone came online |
| `presence:offline` | `{ userId, role }` | Someone went offline |
| `call:incoming` | `{ consultationId, callerId, callerName, callerPhotoUrl, type, channelName, token, uid }` | Incoming call |
| `call:accepted` | `{ consultationId }` | Callee accepted |
| `call:rejected` | `{ consultationId }` | Callee rejected |
| `call:ended` | `{ consultationId, endedBy, durationSeconds }` | Call ended by either side |
| `call:missed` | `{ consultationId }` | Ring timeout reached |
| `rating:prompt` | `{ consultationId, lawyerId, lawyerName }` | Ask user to rate after call |
| `auth:force_logout` | `{ reason }` | Session revoked (new device login) |

### 5.3 Client → Server Events

| Event | Payload | Purpose |
|---|---|---|
| `chat:send` | `{ toId, toRole, content, clientMessageId }` | Send message |
| `chat:ack` | `{ messageId }` | Confirm delivered (for pending queue cleanup) |
| `chat:mark-read` | `{ messageId }` | Mark as read |
| `chat:typing` | `{ toId, toRole, isTyping }` | Typing signal |
| `chat:sync` | `{}` | Pull pending messages on reconnect |
| `heartbeat` | `{}` | Keep presence TTL alive (every 20s) |

### 5.4 Chat Sync Flow on Reconnect

```javascript
// Client
socket.on('connect', () => {
  socket.emit('chat:sync');
});
socket.on('chat:receive', (msg) => {
  saveToLocalSQLite(msg);
  socket.emit('chat:ack', { messageId: msg.messageId });
});

// Server (on chat:sync)
const pending = await prisma.pendingMessage.findMany({
  where: { OR: [{ recipientUserId: userId }, { recipientLawyerId: userId }] },
  orderBy: { createdAt: 'asc' }
});
pending.forEach(m => socket.emit('chat:receive', serialize(m)));
// On chat:ack: delete the message from pending_messages
```

---

## 6. Authentication Implementation Details

### 6.1 Password Hashing
- `bcrypt` with cost factor `12`
- Minimum password requirement: 8 chars, 1 uppercase, 1 number, 1 special

### 6.2 JWT Strategy
- **Access token:** `RS256`, payload `{ sub, role, deviceId, iat, exp }`, TTL 15min
- **Refresh token:** `RS256`, payload `{ sub, role, deviceId, jti, iat, exp }`, TTL 30days
- On each refresh: new access + new refresh (rotation), old refresh `jti` removed from Redis allowlist
- Revocation list in Redis: `refresh:allowed:<userId>:<deviceId>` = `<jti hash>`

### 6.3 OTP Generation
```typescript
// 6-digit numeric
const otp = crypto.randomInt(100000, 999999).toString();
const otpHash = await bcrypt.hash(otp, 10);
await redis.setex(`otp:${email}`, 600, otpHash);
await redis.setex(`otp:attempts:${email}`, 600, 0);
```

### 6.4 OTP Verification
```typescript
const storedHash = await redis.get(`otp:${email}`);
if (!storedHash) throw OtpExpiredException;

const attempts = parseInt(await redis.get(`otp:attempts:${email}`) || '0');
if (attempts >= 5) throw OtpAttemptsExceededException;

const valid = await bcrypt.compare(otp, storedHash);
if (!valid) {
  await redis.incr(`otp:attempts:${email}`);
  throw OtpInvalidException;
}

await redis.del(`otp:${email}`, `otp:attempts:${email}`);
```

### 6.5 Guards & Decorators

```typescript
// Usage
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('USER', 'LAWYER')
@Get('some-protected-endpoint')
findAll(@CurrentUser() user: AuthUser) { ... }
```

`JwtAuthGuard` validates token, attaches `req.user = { id, role, deviceId }`.
`RolesGuard` reads `@Roles()` metadata and compares.

### 6.6 Lawyer Login Gate
- Lawyer signup issues a limited-scope token (payload: `role=LAWYER_PENDING`)
- Full `role=LAWYER` token issued only after `verificationStatus = APPROVED`
- `LAWYER_PENDING` can only access: `GET /lawyers/me`, `POST /license/upload`, `GET /license/status`

---

## 7. Third-Party Integration Setup

### 7.1 Brevo (Email OTP)

1. Sign up at https://brevo.com — free plan: 300 emails/day
2. Create API key: Settings → API Keys → Create
3. Verify sender email domain (add DNS records)
4. Create **transactional template** for OTP email (template ID saved in env)

Implementation (`NotificationService`):
```typescript
await axios.post('https://api.brevo.com/v3/smtp/email', {
  sender: { email: process.env.BREVO_SENDER_EMAIL, name: 'Jerry' },
  to: [{ email }],
  templateId: parseInt(process.env.BREVO_OTP_TEMPLATE_ID),
  params: { otp, expiryMinutes: 10 }
}, { headers: { 'api-key': process.env.BREVO_API_KEY } });
```

### 7.2 Firebase Cloud Messaging (FCM)

1. Create Firebase project at https://console.firebase.google.com
2. Add iOS + Android apps (register bundle IDs)
3. Download `GoogleService-Info.plist` → Flutter `ios/Runner/`
4. Download `google-services.json` → Flutter `android/app/`
5. Create service account: Project Settings → Service Accounts → Generate Private Key
6. Save JSON file; use as `FCM_*` env vars in backend

Backend uses `firebase-admin` SDK:
```typescript
await admin.messaging().send({
  token: fcmToken,
  notification: { title, body },
  data: { type: 'INCOMING_CALL', consultationId, channelName },
  android: { priority: 'high' },
  apns: { headers: { 'apns-priority': '10' }, payload: { aps: { 'content-available': 1 } } }
});
```

### 7.3 Agora

1. Sign up at https://console.agora.io
2. Create Project → App Certificate: Primary + enabled
3. Save `App ID` and `App Certificate` → backend env
4. Flutter installs `agora_rtc_engine` package

Backend token generation (`agora-token` npm package):
```typescript
const token = RtcTokenBuilder.buildTokenWithUid(
  process.env.AGORA_APP_ID,
  process.env.AGORA_APP_CERTIFICATE,
  channelName,
  uid,
  RtcRole.PUBLISHER,
  Math.floor(Date.now() / 1000) + 3600
);
```

### 7.4 Cloudflare R2

1. Cloudflare dashboard → R2 → Create bucket `jerry-media`
2. Bucket settings → Public Access → Enable for profile photos (optional; alternative is signed GET URLs)
3. Create R2 API Token with Object Read + Write on this bucket
4. Custom domain: `media.jerry.in` → point CNAME

Backend uses `@aws-sdk/client-s3` (R2 is S3-compatible):
```typescript
const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: R2_ACCESS_KEY, secretAccessKey: R2_SECRET }
});

// Generate presigned upload URL
const url = await getSignedUrl(s3, new PutObjectCommand({
  Bucket: 'jerry-media',
  Key: `profile-photos/${userId}.jpg`,
  ContentType: 'image/jpeg'
}), { expiresIn: 300 });
```

---

## 8. Flutter Client Implementation Guidelines

### 8.1 Package List (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  socket_io_client: ^2.0.3+1
  agora_rtc_engine: ^6.3.0
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.9
  sqflite: ^2.3.0
  flutter_secure_storage: ^9.0.0
  flutter_riverpod: ^2.5.0
  go_router: ^13.0.0
  cached_network_image: ^3.3.1
  permission_handler: ^11.1.0
  image_picker: ^1.0.7
  uuid: ^4.2.2
  intl: ^0.19.0
  flutter_dotenv: ^5.1.0
  connectivity_plus: ^5.0.2
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  build_runner: ^2.4.8
  freezed: ^2.4.7
  json_serializable: ^6.7.1
  mocktail: ^1.0.3
```

### 8.2 Local SQLite Schema (Flutter)

```sql
CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,              -- server messageId
  client_message_id TEXT UNIQUE,    -- for dedup during sync
  thread_id TEXT,                   -- userId:lawyerId sorted
  from_id TEXT NOT NULL,
  from_role TEXT NOT NULL,
  to_id TEXT NOT NULL,
  to_role TEXT NOT NULL,
  content TEXT NOT NULL,
  status TEXT DEFAULT 'SENDING',    -- SENDING | DELIVERED | READ | FAILED
  timestamp INTEGER NOT NULL,
  is_mine INTEGER NOT NULL          -- 1 if current user sent it
);

CREATE INDEX idx_messages_thread ON messages(thread_id, timestamp DESC);

CREATE TABLE IF NOT EXISTS threads (
  thread_id TEXT PRIMARY KEY,
  other_party_id TEXT NOT NULL,
  other_party_role TEXT NOT NULL,
  other_party_name TEXT,
  other_party_photo_url TEXT,
  last_message_preview TEXT,
  last_message_timestamp INTEGER,
  unread_count INTEGER DEFAULT 0
);

CREATE INDEX idx_threads_recent ON threads(last_message_timestamp DESC);
```

### 8.3 Auth Interceptor Logic (Dio)

```
On every request:
  → Attach Authorization: Bearer <accessToken>

On 401 TOKEN_EXPIRED:
  → POST /auth/refresh with refreshToken
  → If success: retry original request with new accessToken
  → If fail: clear tokens, navigate to login

On 409 DEVICE_CONFLICT:
  → Show dialog "Already logged in on {device}. Log out?"
  → On confirm: retry login with forceLogout=true
```

---

## 9. Testing Strategy for MVP

### Backend (Jest)
- **Unit tests** — services (especially Auth, Chat, Call) — 70%+ coverage target
- **Integration tests** — controllers with real Postgres (test DB) via Supertest
- **E2E flows** — key paths: signup → OTP → login, lawyer upload → admin approve → login, send chat online/offline, initiate + accept video call

### Flutter
- **Unit tests** — domain logic, state controllers
- **Widget tests** — key screens (login, lawyer list, chat)
- **Integration test** — signup → OTP flow on emulator

### Manual QA Checklist (pre-launch)
- [ ] User signup flow on iOS + Android
- [ ] Lawyer signup + license upload + admin approval + login
- [ ] Chat between online user + online lawyer
- [ ] Chat to offline lawyer (FCM push arrives)
- [ ] Voice call connect + disconnect
- [ ] Video call connect + disconnect
- [ ] Rating after call completion
- [ ] Multi-device login → "log out other" prompt works
- [ ] Forgot password end-to-end
- [ ] Admin can suspend user, user immediately logged out

---

## 10. Development Phases & Milestones

### Phase 0 — Setup (Week 1)
Monorepo, Docker Compose, Prisma schema, NestJS skeleton, Flutter skeleton, CI basic.

### Phase 1 — Auth + User (Weeks 2-3)
Complete signup/login/OTP flows. User profile CRUD. Flutter auth screens.

### Phase 2 — Lawyer + License + Admin (Weeks 4-5)
Lawyer signup, license upload, admin approval queue, FCM push on approval.

### Phase 3 — Lawyer Discovery (Week 6)
Lawyer list + filters, specialties endpoint, lawyer detail page, presence via Redis.

### Phase 4 — Chat (Weeks 7-8)
Socket.IO gateway, online flow, offline flow, pending_messages, SQLite on Flutter, FCM push.

### Phase 5 — Calling (Weeks 9-10)
Agora integration on backend (token gen) + Flutter (RTC engine), call lifecycle, incoming call UI.

### Phase 6 — Ratings + Polish (Week 11)
Rating flow, consultation history screens, UI polish per Design.md.

### Phase 7 — Pre-launch (Week 12)
Bug fixes, load testing (Artillery/k6 for API, Socket.IO simulator), store submission (TestFlight + Play internal).

**Total estimate: ~12 weeks from zero to MVP with a 2-person team.**

---

## 11. Deliverables Checklist

When MVP is considered "done":

- [ ] All 13 NestJS modules implemented + tested
- [ ] All 40+ REST endpoints returning correct responses per this doc
- [ ] All Socket.IO events functional
- [ ] Flutter app builds to iOS + Android
- [ ] Docker Compose works end-to-end on a fresh machine
- [ ] Prisma migrations applied cleanly on fresh DB
- [ ] Seed data includes SuperAdmin + 15 specialties
- [ ] All env variables documented in `.env.example`
- [ ] Agora, FCM, Brevo, R2 integrations verified with real credentials in staging
- [ ] API docs auto-generated (Swagger) at `/api/docs`
- [ ] README with setup instructions

---

*End of MVP-Tech-Doc.md — ready for review.*
