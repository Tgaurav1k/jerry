# jerry — Database Schema

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Authoritative data model for MVP implementation (Prisma + PostgreSQL 16).  
**Version:** 1.0 (MVP)  
**Sources:** MVP-Tech-Doc §3, Architecture §8

---

## 1. Design principles

- **Separate identity tables** per role with **email unique** in each; application layer enforces **global email uniqueness** across tables.  
- **Lawyer license** stored as **BYTEA** in Postgres (sensitive, low read volume).  
- **Profile photos** stored as **URLs** pointing to Supabase Storage (public bucket for photos, private bucket for licenses).  
- **Chat body** not stored long-term server-side; **`PendingMessage`** is a **transient queue**.  
- **Denormalized aggregates** on `Lawyer`: `avgRating`, `totalRatings`, `totalConsultations` for fast list reads.  
- **Payment fields** exist but default to **FREE** / zero amounts in MVP.

---

## 2. Entity-relationship overview

```
User ─────┬──── Consultation ────┬──── Lawyer
          │         │           │
          │         └──── Rating (1:1 per consultation)
          │
          ├──── DeviceSession
          ├──── PendingMessage (as sender/recipient)
          └──── Rating (as rater)

Lawyer ───┬──── LawyerSpecialty ──── Specialty
          ├──── DeviceSession
          ├──── PendingMessage
          └──── Rating (received)

Admin ──── AuditLog
SuperAdmin (standalone)

AuditLog (optional adminId / superAdminId)
```

---

## 3. Prisma models (authoritative)

The MVP schema matches **`MVP-Tech-Doc.md` §3**. Models:

| Model | Purpose |
|-------|---------|
| `User` | Client identity + profile + suspension |
| `Lawyer` | Lawyer identity + license BYTEA + verification + aggregates + availability |
| `Admin` | Admin accounts |
| `SuperAdmin` | SuperAdmin accounts |
| `Specialty` | Catalog row per practice area |
| `LawyerSpecialty` | M:N lawyer ↔ specialty |
| `Consultation` | Chat/voice/video session metadata + Agora channel + payment stub |
| `Rating` | One row per consultation (unique on `consultationId`) |
| `DeviceSession` | Device binding + FCM token for notifications |
| `PendingMessage` | Offline delivery queue |
| `AuditLog` | Admin actions |

---

## 4. Enumerations

| Enum | Values |
|------|--------|
| `VerificationStatus` | `PENDING_UPLOAD`, `PENDING_REVIEW`, `APPROVED`, `REJECTED` |
| `ConsultationType` | `CHAT`, `VOICE`, `VIDEO` |
| `ConsultationStatus` | `RINGING`, `ACTIVE`, `ENDED`, `MISSED`, `REJECTED_BY_LAWYER`, `DROPPED` |
| `PaymentStatus` | `FREE`, `PENDING`, `PAID`, `REFUNDED` |

---

## 5. Indexing strategy

| Table / area | Index | Rationale |
|--------------|-------|-----------|
| `User.email`, `Lawyer.email` | Unique B-tree | Login lookup |
| `Lawyer.verificationStatus` | B-tree | Admin queue |
| `Lawyer (city, state)` | Composite | Geo filters |
| `Lawyer.isOnline` | B-tree | Online filter |
| `LawyerSpecialty.specialtyId` | B-tree | Join/filter by specialty |
| `Consultation (userId, startedAt DESC)` | Composite | Client history |
| `Consultation (lawyerId, startedAt DESC)` | Composite | Lawyer history |
| `Consultation.status` | B-tree | State queries |
| `PendingMessage (recipientUserId, createdAt)` | Composite | User inbox sync |
| `PendingMessage (recipientLawyerId, createdAt)` | Composite | Lawyer inbox sync |
| `Rating.lawyerId` | B-tree | Profile ratings list |
| `AuditLog (targetId, targetType)` | Composite | Investigations |
| `AuditLog.createdAt DESC` | B-tree | Recent audits |

**Architecture note:** `languages_spoken` filtering may use **GIN** on `text[]` when query plans require it — add in migration after profiling.

---

## 6. Constraints and invariants

1. **Rating:** `consultationId` **unique** — at most one rating per consultation.  
2. **Rating stars:** 1–5 (enforce in app + DB check optional).  
3. **DeviceSession:** Unique `(userId, deviceId)` and `(lawyerId, deviceId)` — one row per device per identity.  
4. **PendingMessage:** Exactly one sender id (user XOR lawyer) and one recipient id (user XOR lawyer) — validated in service layer.  
5. **Consultation:** `userId` and `lawyerId` must reference valid rows; **ended** consultations have `endedAt` and `durationSeconds` populated.

---

## 7. Seed data

- **SuperAdmin** from environment variables on first deploy.  
- **Specialties** — static list of **15** names in MVP-Tech-Doc §3.1.  
- Optional: demo users/lawyers for **dev** only (never production).

---

## 8. Migrations and environments

- **Prisma migrate** is source of truth; all environments run `prisma migrate deploy`.  
- **Never** hand-edit production DB without a migration.  
- **BYTEA** growth: monitor DB size; license uploads capped at 5 MB each.

---

## 9. PII and retention

| Data | MVP retention |
|------|----------------|
| Chat text (pending) | Deleted on `chat:ack` / delivery |
| Consultation meta | Kept for product history |
| License BYTEA | Kept until lawyer deleted (deletion policy v2) |
| Audit logs | Kept for compliance operations |
| Profile photos | Stored in Supabase Storage public bucket |
| License BYTEA | Kept in PostgreSQL (admin-only, not in Storage) |

---

## 10. Future schema extensions (non-MVP)

- `Attachment` table for chat files  
- `Payment`, `Invoice`, `Payout` tables  
- `Report` / `ModerationQueue`  
- Optional unified `Account` view via DB view only — **not** required for MVP

---

*End of `05-database-schema.md`. See `06-api-contracts.md`.*
