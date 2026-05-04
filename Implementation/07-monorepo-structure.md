# jerry — Monorepo Structure

**Project:** jerry — Lawyer-Client Consultation Platform (India)  
**Document purpose:** Repository layout, ownership boundaries, and local development entry points.  
**Version:** 1.0 (MVP)  
**Sources:** MVP-Tech-Doc §2, Architecture §5

---

## 1. Top-level layout (target)

```
jerry/
├── backend/                 # NestJS API
│   ├── src/
│   │   ├── common/          # guards, filters, interceptors, pipes, decorators
│   │   ├── config/          # configuration + env validation
│   │   └── modules/         # feature modules (see §3)
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── seed.ts
│   │   └── migrations/
│   ├── test/
│   ├── docker/
│   ├── .env.example
│   ├── package.json
│   └── tsconfig.json
├── mobile/                  # Flutter app
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   └── shared/
│   ├── android/
│   ├── ios/
│   ├── test/
│   ├── .env.example
│   └── pubspec.yaml
├── documentation/           # Product & design source docs (existing)
├── Implementation/          # This implementation spec set
├── docker-compose.yml         # Postgres + Redis (dev)
├── .gitignore
└── README.md
```

**Note:** MVP-Tech-Doc references `docs/` for Architecture/PRD; this repo may use `documentation/` — keep **one canonical docs path** and update README accordingly.

---

## 2. Backend (`backend/`)

### 2.1 `src/modules/` — feature modules

| Path | Responsibility |
|------|----------------|
| `auth/` | REST auth, JWT, OTP, device conflict |
| `user/` | User profile |
| `lawyer/` | Lawyer profile, search, stats |
| `license/` | Upload + status |
| `admin/` | Admin REST |
| `superadmin/` | SuperAdmin REST |
| `chat/` | Socket.IO gateway + pending message service |
| `call/` | Initiate, accept, reject, end + Agora |
| `consultation/` | History, detail |
| `media/` | R2 presign |
| `rating/` | Ratings + aggregate updates |
| `notification/` | FCM + email (Brevo) |
| `payment/` | Stub module |

Each module typically contains: `*.module.ts`, `*.controller.ts`, `*.service.ts`, `*.gateway.ts` (if realtime), `dto/`.

### 2.2 `prisma/`

- **`schema.prisma`** — single source of truth for DB.  
- **`migrations/`** — versioned SQL.  
- **`seed.ts`** — SuperAdmin + specialties.

### 2.3 `test/`

- Unit tests co-located or under `test/` — **Jest** per MVP-Tech-Doc.  
- Integration/E2E: Supertest against app with test DB.

---

## 3. Mobile (`mobile/`)

### 3.1 `lib/core/`

- `constants/` — API base URL, Agora app id, env  
- `errors/` — failures  
- `network/` — Dio + interceptors  
- `storage/` — secure storage + sqflite init  
- `router/` — go_router tables

### 3.2 `lib/features/`

Feature-first folders: `auth`, `home`, `lawyer_list`, `lawyer_detail`, `chat`, `call`, `history`, `profile`, `admin`, `superadmin` — each with `data/`, `domain/`, `presentation/` as needed.

### 3.3 `lib/shared/`

- `widgets/` — BentoCard, buttons, inputs, glass sheet  
- `theme/` — tokens from Design.md  
- `animations/` — shared transitions

---

## 4. Configuration files

| File | Purpose |
|------|---------|
| `backend/.env.example` | All server secrets and URLs (MVP-Tech-Doc §2.3) |
| `mobile/.env.example` | API + socket + environment flag |
| `docker-compose.yml` | Postgres 16 + Redis 7 for local dev |

---

## 5. CI placement (recommended)

```
.github/
└── workflows/
    ├── backend-ci.yml      # lint, test, prisma validate
    ├── mobile-ci.yml       # analyze, test
    └── release-mobile.yml  # optional: build apk/ipa on tags
```

---

## 6. Boundaries and imports

- **Backend:** No cross-feature imports except through **public** service interfaces or shared `common/`.  
- **Mobile:** Features depend **downward** (presentation → domain → data); shared widgets have no feature imports.  
- **Docs:** Implementation markdown is **spec** only — not imported by runtime code.

---

## 7. Environment matrix

| Variable class | Backend | Mobile |
|----------------|---------|--------|
| Public | `API_BASE_URL` (server’s own public URL) | `API_BASE_URL` pointing to server |
| Secrets | JWT keys, DB, Redis, Brevo, FCM, Agora, R2 | Only Agora App ID (public); no private keys in app |
| Build | `NODE_ENV` | `ENVIRONMENT` = development/staging/production |

---

*End of `07-monorepo-structure.md`. See `08-scoring-engine-spec.md`.*
