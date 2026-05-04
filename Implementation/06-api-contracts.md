# jerry — API Contracts

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** REST + Socket.IO contracts for client and backend implementation.  
**Version:** 1.0 (MVP)  
**Sources:** MVP-Tech-Doc §4–5, PRD §5

---

## 1. Base URLs

| Environment | REST base | Socket |
|-------------|-----------|--------|
| Development | `http://localhost:3000/api/v1` | `ws://localhost:3000` |
| Production | `https://api.jerry.in/api/v1` | `wss://api.jerry.in` |

Flutter `.env`: `API_BASE_URL`, `SOCKET_URL` per MVP-Tech-Doc.

---

## 2. Response envelope

### 2.1 Success

```json
{
  "success": true,
  "data": {},
  "meta": { "timestamp": "2026-04-19T10:30:00.000Z" }
}
```

### 2.2 Error

```json
{
  "success": false,
  "error": {
    "code": "EMAIL_ALREADY_EXISTS",
    "message": "An account with this email already exists.",
    "details": {}
  },
  "meta": { "timestamp": "2026-04-19T10:30:00.000Z" }
}
```

---

## 3. Standard error codes

| Code | HTTP | Meaning |
|------|------|---------|
| `VALIDATION_ERROR` | 400 | DTO validation failed |
| `UNAUTHORIZED` | 401 | Missing/invalid token |
| `TOKEN_EXPIRED` | 401 | Access JWT expired |
| `FORBIDDEN` | 403 | Role or state forbidden |
| `NOT_FOUND` | 404 | Resource missing |
| `CONFLICT` | 409 | Duplicate / illegal state |
| `RATE_LIMITED` | 429 | Throttled |
| `OTP_INVALID` | 400 | Wrong OTP |
| `OTP_EXPIRED` | 400 | OTP window passed |
| `OTP_ATTEMPTS_EXCEEDED` | 400 | Too many tries |
| `LAWYER_NOT_APPROVED` | 403 | Lawyer not approved |
| `USER_SUSPENDED` | 403 | Account suspended |
| `DEVICE_CONFLICT` | 409 | Active session on another device |
| `LAWYER_UNAVAILABLE` | 409 | Offline or busy |
| `INTERNAL_ERROR` | 500 | Unexpected |

---

## 4. Authentication

| Method | Path | Notes |
|--------|------|--------|
| POST | `/auth/signup` | Body: email, password, fullName, role `USER`/`LAWYER`, preferredLanguage, city, state → 202 + OTP sent |
| POST | `/auth/verify-otp` | email, otp, deviceId, deviceInfo, fcmToken → 201 + tokens + user payload |
| POST | `/auth/login` | email, password, deviceId, deviceInfo, fcmToken, forceLogout? |
| POST | `/auth/refresh` | refreshToken → new access + refresh (rotation) |
| POST | `/auth/logout` | Auth header → 204, revoke refresh for device |
| POST | `/auth/forgot-password` | email → 202 always |
| POST | `/auth/reset-password` | token, newPassword |

**Headers:** `Authorization: Bearer <accessToken>` on protected routes.

**Lawyer pending token:** Limited to `GET /lawyers/me`, `POST /license/upload`, `GET /license/status` until approved (per MVP-Tech-Doc §6.6).

---

## 5. Users (client)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/users/me` | Current user profile |
| PATCH | `/users/me` | Partial update |
| POST | `/users/me/profile-photo/presign` | Presigned PUT URL |
| PATCH | `/users/me/profile-photo` | Save final `profilePhotoUrl` |

---

## 6. Lawyers (public search + self)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/lawyers` | Query: specialty, city, languages, online, page, limit, sortBy, minRating, state |
| GET | `/lawyers/:id` | Public profile + bio |
| GET | `/specialties` | All specialties |
| GET | `/lawyers/me` | Lawyer self |
| PATCH | `/lawyers/me` | Profile fields |
| PATCH | `/lawyers/me/specialties` | `{ specialtyIds: [] }` replace |
| PATCH | `/lawyers/me/availability` | `{ isOnline: boolean }` |
| GET | `/lawyers/me/stats` | Aggregates |
| GET | `/lawyers/:id/ratings` | Paginated public reviews |

---

## 7. License

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/license/upload` | Multipart: file + licenseNumber (Lawyer) |
| GET | `/license/status` | Status + notes + timestamps |

---

## 8. Admin

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/admin/login` | Admin credentials |
| GET | `/admin/approval-queue` | Pending review lawyers |
| GET | `/admin/lawyer/:id` | Full lawyer + license meta |
| GET | `/admin/lawyer/:id/license` | Raw binary stream |
| POST | `/admin/lawyer/:id/approve` | Approve |
| POST | `/admin/lawyer/:id/reject` | `{ reason }` |
| POST | `/admin/user/:id/suspend` | `{ reason }` |
| POST | `/admin/user/:id/unsuspend` | |
| POST | `/admin/lawyer/:id/suspend` | `{ reason }` |
| POST | `/admin/lawyer/:id/unsuspend` | |
| GET | `/admin/users` | search, page |
| GET | `/admin/lawyers` | status, page |

---

## 9. SuperAdmin

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/superadmin/admins` | Create admin |
| GET | `/superadmin/admins` | List |
| PATCH | `/superadmin/admins/:id/deactivate` | Soft deactivate |
| GET | `/superadmin/dashboard` | Platform metrics JSON per tech doc |

---

## 10. Calls and consultations

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/call/initiate` | `{ lawyerId, type: VOICE\|VIDEO }` → consultation + Agora token |
| POST | `/call/:consultationId/accept` | Lawyer accepts |
| POST | `/call/:consultationId/reject` | Lawyer rejects |
| POST | `/call/:consultationId/end` | Either party ends |
| GET | `/consultations/my` | Paginated history |
| GET | `/consultations/:id` | Metadata detail |

---

## 11. Ratings

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/ratings` | `{ consultationId, stars, reviewText? }` — user only, consultation ended |

---

## 12. Notifications

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/notifications/device-token` | Register/update FCM token |

---

## 13. Socket.IO

### 13.1 Connection

```javascript
io(SOCKET_URL, {
  auth: { token: '<access JWT>' },
  transports: ['websocket']
})
```

Invalid token → disconnect.

### 13.2 Server → client events

| Event | Payload (shape) | Purpose |
|-------|-------------------|---------|
| `chat:receive` | messageId, fromId, fromRole, content, clientMessageId, timestamp | Inbound message |
| `chat:delivered` | clientMessageId, serverMessageId | Ack to sender |
| `chat:read` | messageId, readAt | Read receipt |
| `chat:typing` | fromId, isTyping | Typing |
| `presence:online` | userId, role | Presence |
| `presence:offline` | userId, role | Presence |
| `call:incoming` | consultationId, callerId, callerName, callerPhotoUrl, type, channelName, token, uid | Incoming call |
| `call:accepted` | consultationId | Callee joined |
| `call:rejected` | consultationId | Declined |
| `call:ended` | consultationId, endedBy, durationSeconds | End |
| `call:missed` | consultationId | Timeout |
| `rating:prompt` | consultationId, lawyerId, lawyerName | Prompt user |
| `auth:force_logout` | reason | Session revoked |

### 13.3 Client → server events

| Event | Payload | Purpose |
|-------|---------|---------|
| `chat:send` | toId, toRole, content, clientMessageId | Send |
| `chat:ack` | messageId | Pending cleanup |
| `chat:mark-read` | messageId | Read |
| `chat:typing` | toId, toRole, isTyping | Typing |
| `chat:sync` | {} | Pull pending |
| `heartbeat` | {} | Presence TTL |

---

## 14. Swagger

- Host **OpenAPI** at `/api/docs` (NestJS Swagger plugin) — **deliverable** per MVP-Tech-Doc §11.

---

*End of `06-api-contracts.md`. See `07-monorepo-structure.md`.*
