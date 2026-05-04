# jerry — Scoring Engine Specification

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Define deterministic **ranking**, **rating aggregation**, and **ordering** rules for MVP. There is **no ML-based recommendation engine** in MVP (explicitly out of scope in PRD). This document names the “scoring-like” behaviors so engineering and QA share one spec.

**Version:** 1.0 (MVP)  
**Sources:** PRD F-USER-01/02, F-USER-07, MVP-Tech-Doc, Architecture

---

## 1. Scope: what “scoring” means in jerry

| Concept | In MVP? | Notes |
|---------|---------|--------|
| Lawyer **average star rating** | Yes | Stored denormalized on `Lawyer` |
| **Total ratings** count | Yes | Denormalized |
| **Lawyer list ordering** | Yes | Sort + filter; no personalized ML score |
| **User trust / fraud score** | No | Deferred |
| **Consultation “quality score”** | No | Only star rating + optional text |
| **Platform health composite** | Dashboard only | Simple sums/averages — not a client-visible score |

---

## 2. Rating aggregation (lawyer-level)

### 2.1 Inputs

- Each **Rating** row: `stars` ∈ {1, 2, 3, 4, 5}, optional `reviewText`, linked to exactly one **ENDED** consultation.  
- At most **one** rating per `consultationId` (DB unique constraint).

### 2.2 Update rules (transactional)

On successful `POST /ratings`:

1. Insert `Rating`.  
2. Recompute for associated `lawyerId`:

\[
\text{newTotal} = \text{oldTotalRatings} + 1
\]

\[
\text{newAvg} = \frac{\text{oldAvg} \times \text{oldTotalRatings} + \text{stars}}{\text{newTotal}}
\]

3. Persist `lawyer.totalRatings = newTotal`, `lawyer.avgRating = newAvg` (use decimal precision consistent with DB — e.g. **float** with rounding to **2** decimal places on **read** if needed for display).

### 2.3 Invariants

- Ratings **cannot** be edited or deleted by end users in MVP → aggregates **never decrease** except via admin correction scripts (out of normal flow).  
- If a rating insert fails, **no** partial update to lawyer aggregates (single DB transaction).

### 2.4 Edge cases

| Case | Behavior |
|------|----------|
| First rating for lawyer | `avgRating = stars`, `totalRatings = 1` |
| Duplicate rating for same consultation | Reject with conflict/validation error |

---

## 3. Lawyer list ranking (default ordering)

### 3.1 Default sort (User home — PRD)

**Primary:** Lawyers who are **online** appear **before** offline.  
**Secondary:** **Average rating** descending.  
**Tertiary (tie-break):** **Higher `totalRatings`** first (more established), then **lawyer id** UUID lexicographic **ascending** for stable ordering.

### 3.2 API `sortBy` parameter

Map query param to SQL `ORDER BY`:

| `sortBy` value | Order |
|----------------|--------|
| `rating` (default secondary) | `avgRating DESC`, `totalRatings DESC`, `id ASC` — still apply **online first** if product flag `onlineBoost=true` default (see §3.3) |
| `consultations` | `totalConsultations DESC`, `avgRating DESC`, `id ASC` |
| `experience` | `yearsExperience DESC`, `avgRating DESC`, `id ASC` |

**Online-first rule:** When `online=true` filter is **not** set, PRD still wants **online first** in default view. Implementation options (pick one and document in code):

- **A (recommended):** Single query with `ORDER BY isOnline DESC, <secondary columns>…`  
- **B:** Two-phase merge (online page + offline page) — more complex; avoid unless needed.

### 3.3 Language “boost” (matching)

PRD: default discovery should prefer lawyers who speak the user’s **preferred language**.

**Rule:** When no explicit language filter is set, add filter:

- `preferredLanguage` ∈ `Lawyer.languagesSpoken` **OR** user has chosen “Any” in UI (implementation detail).

If this yields **zero** results, fall back to **broadened** list (same filters minus language constraint) and show subtle empty-state hint (“No lawyers speak {lang}; showing all matches”) — **optional UX**; minimum viable is **strict filter** only.

---

## 4. Filters vs scoring

Filters are **binary** (pass/fail), not weighted scores:

- Specialty: lawyer must have **one of** selected specialties (multi-select = OR within group — align with PRD: multi-select specialties typically means **match any** or **match all** — PRD says filters combined with **AND** across **categories**; within specialty multi-select, use **OR**: lawyer has **any** selected specialty).  
- Location: city/state match per API.  
- Languages: **OR** within selected languages.  
- Online only: `isOnline = true`.  
- Min rating: `avgRating >= minRating`.

**No numeric “match score”** is exposed to the client in MVP.

---

## 5. Consultation and call state “scores”

Not user-visible scores — **state machine** only:

`RINGING` → `ACTIVE` | `MISSED` | `REJECTED_BY_LAWYER` | `DROPPED` → `ENDED`

Ringing timeout: **45 seconds** → `MISSED`.  
No separate “priority score” for queue position beyond **FIFO** for admin approval.

---

## 6. SuperAdmin dashboard metrics (aggregate, not ranking)

Computed from SQL aggregates / cached rollups:

- Counts: users, lawyers, admins, consultations.  
- Consultations by type: `CHAT`, `VOICE`, `VIDEO`.  
- Lawyers by verification status.  
- **Average platform rating:** average of all `Rating.stars` **or** average of `Lawyer.avgRating` weighted — **pick one definition**:

**Recommended:** Mean of all `Rating.stars` rows (simple global mean). Document in API response as `avgPlatformRating`.

---

## 7. Future (explicitly not MVP)

- ML-based lawyer recommendation  
- Weighted ranking using response time, acceptance rate, or revenue  
- Fraud risk scoring for users/lawyers  
- Dynamic surge pricing

---

## 8. Testing obligations for this spec

- Unit tests for **avg/total** recompute with integer stars edge cases.  
- Integration test: default lawyer list ordering with mixed online/offline and tied ratings.  
- Contract test: `GET /lawyers` documents `sortBy` and ordering for each value.

---

*End of `08-scoring-engine-spec.md`. See `09-engineering-scope-definition.md`.*
