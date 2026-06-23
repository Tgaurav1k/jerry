# Jerry — Call & Chat Test Guide

End-to-end test that simulates two real clients (a USER and a LAWYER) over HTTP +
Socket.IO and walks **chat, voice call, and video call** through every path the
mobile app exercises. It proves the *signaling + persistence* layer works; it
does **not** prove Agora media actually flows (that needs two real devices).

## What it checks

| Feature        | Verified by | What it proves |
|----------------|-------------|----------------|
| **Chat**       | Scenario 7  | send → sender ack → recipient receives → content/sender preserved |
| **Video call** | Scenario 1, 8b | USER→LAWYER ring → accept → both get `call:ended`; answered call logged `completed` |
| **Voice call** | Scenario 2  | LAWYER→USER ring → accept → clean end (reverse direction) |
| Legacy clients | Scenario 3  | old `lawyerId` field still rings the lawyer |
| Reject         | Scenario 4  | recipient rejects → caller gets `call:rejected` |
| Same-role block| Scenario 5  | USER→USER (or LAWYER→LAWYER) is rejected (400) |
| Busy lock      | Scenario 6  | 2nd concurrent call to a busy lawyer → `missed` / `busy` |
| **Call history**| Scenario 8 | **cancel-while-ringing → `missed` 0s** (not a fake "completed"); answered → `completed` |
| Ring timeout   | Scenario 9  | (opt-in) 45s no-answer → `call:ended` with `reason: no_answer` |

Scenario 8 is the regression test for the duration bug: a call hung up before the
other side picks up is now recorded as **missed**, not as a completed N-second call.

## Prerequisites

- Backend running (`npm run start:dev`) against a reachable Postgres + Redis
  (`docker compose up -d` from the repo root starts both).
- Demo accounts seeded (`npm run prisma:seed`):
  `demo.user@jerry.dev` / `DemoUser@123` and `demo.lawyer@jerry.dev` / `DemoLawyer@123`.

## Run

```bash
cd backend

# against a local backend (default http://localhost:3000)
npm run test:calls

# against the deployed backend (or any host)
TEST_API_URL=https://jerry-backend.onrender.com/api/v1 \
TEST_SOCKET_URL=https://jerry-backend.onrender.com \
npm run test:calls

# include the slow 45s ring-timeout scenario
TEST_TIMEOUT=1 npm run test:calls
```

Output is a per-scenario ✓/✗ list and a final pass/fail summary; the process
exits non-zero if anything failed (CI-friendly).

> Note: against Render's free tier the backend sleeps after inactivity and takes
> 30–60s to wake — the first call in a cold run may be slow or time out. Re-run
> once it's warm.
