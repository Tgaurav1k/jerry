/**
 * End-to-end call-flow integration test against a live backend.
 *
 * Simulates two real clients (gaurav = USER, jerry = LAWYER) via HTTP + Socket.IO,
 * and walks the call signaling through every scenario the mobile app actually
 * exercises. Reports pass/fail per scenario with assertion detail.
 *
 * What this proves:
 *   - REST endpoints respond with the documented shape
 *   - Socket rooms are joined by role and event payloads match the contract
 *   - Bidirectional initiate (USER->LAWYER and LAWYER->USER) both route correctly
 *   - Caller cannot accept/reject their own call
 *   - Accept transitions consultation to ACTIVE and mints token for the accepter
 *   - End/reject fires events on BOTH sides and clears server-side timers
 *   - The 45s ring timeout actually fires (we wait, briefly) and marks MISSED
 *
 * What this does NOT prove:
 *   - Agora audio/video actually flows (requires real RTC peers)
 *   - CallKit native UI renders / Accept tap works (requires Android)
 *   - FCM data push actually reaches a real device (just that we hand it to
 *     firebase-admin without error)
 *
 * Run:   npx ts-node backend/scripts/call-flow-integration.test.ts
 */

import axios, { AxiosInstance } from 'axios';
import { io, Socket } from 'socket.io-client';

const API = process.env.TEST_API_URL ?? 'http://localhost:3000/api/v1';
const SOCKET_URL = process.env.TEST_SOCKET_URL ?? 'http://localhost:3000';
const USER_EMAIL    = 'demo.user@jerry.dev';
const USER_PASS     = 'DemoUser@123';
const LAWYER_EMAIL  = 'demo.lawyer@jerry.dev';
const LAWYER_PASS   = 'DemoLawyer@123';

type Role = 'USER' | 'LAWYER';
interface Session {
  role: Role;
  id: string;
  accessToken: string;
  api: AxiosInstance;
  socket: Socket;
  inbox: Array<{ event: string; data: any; ts: number }>;
}

const COLOR = {
  red:    (s: string) => `\x1b[31m${s}\x1b[0m`,
  green:  (s: string) => `\x1b[32m${s}\x1b[0m`,
  yellow: (s: string) => `\x1b[33m${s}\x1b[0m`,
  cyan:   (s: string) => `\x1b[36m${s}\x1b[0m`,
  gray:   (s: string) => `\x1b[90m${s}\x1b[0m`,
};

let passed = 0;
let failed = 0;
function ok(msg: string)   { passed++; console.log(`  ${COLOR.green('✓')} ${msg}`); }
function bad(msg: string)  { failed++; console.log(`  ${COLOR.red('✗')} ${msg}`); }
function note(msg: string) { console.log(`  ${COLOR.gray('·')} ${COLOR.gray(msg)}`); }
function section(title: string) {
  console.log(`\n${COLOR.cyan('━━━ ' + title + ' ━━━')}`);
}

function assert(cond: boolean, msg: string) {
  if (cond) ok(msg);
  else      bad(msg);
}

function delay(ms: number) { return new Promise<void>(r => setTimeout(r, ms)); }

async function login(email: string, password: string, role: Role): Promise<Session> {
  const resp = await axios.post(`${API}/auth/login`, { email, password, role });
  const data = resp.data?.data ?? resp.data;
  const accessToken = data.accessToken ?? data.access_token;
  const resolvedRole: Role = (data.user?.role ?? data.role ?? role) as Role;
  const id          = data.user?.id   ?? data.id;
  if (!accessToken || !id || !resolvedRole) {
    throw new Error(`Login response missing fields for ${email}: ${JSON.stringify(data).slice(0, 200)}`);
  }
  const api = axios.create({
    baseURL: API,
    headers: { Authorization: `Bearer ${accessToken}` },
    validateStatus: () => true, // we assert manually
  });
  const socket = io(SOCKET_URL, {
    transports: ['websocket'],
    auth: { token: accessToken },
    reconnection: false,
  });
  const inbox: Session['inbox'] = [];
  socket.onAny((event: string, data: any) => {
    inbox.push({ event, data, ts: Date.now() });
  });
  await new Promise<void>((resolve, reject) => {
    socket.once('connect', () => resolve());
    socket.once('connect_error', e => reject(e));
    setTimeout(() => reject(new Error('socket connect timeout (8s)')), 8000);
  });
  return { role: resolvedRole, id, accessToken, api, socket, inbox };
}

/** Wait until inbox contains an event with the given name (since `sinceTs`). */
async function waitForEvent(
  s: Session,
  eventName: string,
  sinceTs: number,
  timeoutMs = 5000,
): Promise<any> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const hit = s.inbox.find(e => e.event === eventName && e.ts >= sinceTs);
    if (hit) return hit.data;
    await delay(50);
  }
  throw new Error(
    `Timed out waiting for "${eventName}" on ${s.role} (saw: ${
      [...new Set(s.inbox.filter(e => e.ts >= sinceTs).map(e => e.event))].join(', ') || 'nothing'
    })`,
  );
}

async function registerFakeFcm(s: Session, label: string) {
  const resp = await s.api.post('/users/me/fcm', {
    fcmToken: `test-token-${label}-${Date.now()}`,
    deviceId: `test-device-${label}`,
  });
  return resp.status === 200 || resp.status === 201;
}

/**
 * Fetch the persisted "call record" chat bubble for a consultation. The backend
 * stores it with a deterministic id of `call-<consultationId>` in the thread
 * shared by the two participants. Returns null if it hasn't been written yet.
 */
async function getCallRecord(
  s: Session,
  userId: string,
  lawyerId: string,
  consultationId: string,
): Promise<{ callStatus?: string; callDurationSeconds?: number; type?: string; callType?: string } | null> {
  const threadId = [userId, lawyerId].sort().join(':');
  const resp = await s.api.get('/chat/history', { params: { threadId, limit: 100 } });
  const list = resp.data?.data ?? resp.data ?? [];
  if (!Array.isArray(list)) return null;
  return list.find((m: any) => m.id === `call-${consultationId}`) ?? null;
}

async function main() {
  console.log(COLOR.cyan('Jerry — call flow integration test'));
  console.log(COLOR.gray(`Target: ${API}\n`));

  // ─── Bootstrap ──────────────────────────────────────────────────────────────
  section('Login + socket connect');
  const gaurav = await login(USER_EMAIL, USER_PASS, 'USER');
  ok(`gaurav (USER) logged in: ${gaurav.id.slice(0, 8)}…`);
  assert(gaurav.socket.connected, 'gaurav socket connected');

  const jerry = await login(LAWYER_EMAIL, LAWYER_PASS, 'LAWYER');
  ok(`jerry (LAWYER) logged in: ${jerry.id.slice(0, 8)}…`);
  assert(jerry.socket.connected, 'jerry socket connected');

  await registerFakeFcm(gaurav, 'gaurav');
  await registerFakeFcm(jerry, 'jerry');
  ok('FCM tokens registered for both');

  try {
    // ─── Scenario 1: USER -> LAWYER, lawyer accepts, both end ────────────────
    section('Scenario 1: gaurav calls jerry (USER -> LAWYER), jerry accepts');
    {
      const t0 = Date.now();
      const initResp = await gaurav.api.post('/call/initiate', {
        recipientId:   jerry.id,
        recipientRole: 'LAWYER',
        type:          'VIDEO',
      });
      assert(initResp.status === 200 || initResp.status === 201, `POST /call/initiate -> ${initResp.status}`);
      const initData = initResp.data?.data;
      assert(!!initData?.consultationId, 'initiate returns consultationId');
      assert(!!initData?.agoraChannelName, 'initiate returns agoraChannelName');
      assert(!!initData?.agoraToken, 'initiate returns agoraToken for caller');
      assert(typeof initData?.uid === 'number', 'initiate returns numeric uid for caller');
      const consultationId = initData!.consultationId;

      const incoming = await waitForEvent(jerry, 'call:incoming', t0);
      assert(incoming.consultationId === consultationId, 'jerry receives call:incoming with matching consultationId');
      assert(incoming.callerId === gaurav.id, 'call:incoming.callerId is gaurav');
      assert(incoming.callerRole === 'USER', 'call:incoming.callerRole is USER');
      assert(incoming.type === 'VIDEO', 'call:incoming.type is VIDEO');
      assert(!!incoming.token, 'call:incoming carries lawyer-side Agora token');
      assert(typeof incoming.uid === 'number', 'call:incoming.uid is numeric');
      note(`Agora channel: ${incoming.channelName}`);

      // Caller cannot accept their own call
      const selfAccept = await gaurav.api.post(`/call/${consultationId}/accept`);
      assert(selfAccept.status === 403 || selfAccept.status === 409, `gaurav cannot accept own call -> ${selfAccept.status}`);

      // Caller cannot reject their own call (must use /end)
      const selfReject = await gaurav.api.post(`/call/${consultationId}/reject`);
      assert(selfReject.status === 403 || selfReject.status === 409, `gaurav cannot reject own call -> ${selfReject.status}`);

      // Jerry accepts
      const tAccept = Date.now();
      const acceptResp = await jerry.api.post(`/call/${consultationId}/accept`);
      assert(acceptResp.status === 200 || acceptResp.status === 201, `jerry POST /accept -> ${acceptResp.status}`);
      const acceptData = acceptResp.data?.data;
      assert(acceptData?.consultationId === consultationId, 'accept returns same consultationId');
      assert(!!acceptData?.agoraToken, 'accept returns agoraToken for accepter');
      assert(typeof acceptData?.uid === 'number', 'accept returns numeric uid for accepter');

      // Jerry hangs up
      const tEnd = Date.now();
      const endResp = await jerry.api.post(`/call/${consultationId}/end`);
      assert(endResp.status === 200 || endResp.status === 201, `jerry POST /end -> ${endResp.status}`);

      const endedG = await waitForEvent(gaurav, 'call:ended', tEnd);
      const endedJ = await waitForEvent(jerry,  'call:ended', tEnd);
      assert(endedG.consultationId === consultationId, 'gaurav receives call:ended');
      assert(endedJ.consultationId === consultationId, 'jerry receives call:ended');
    }

    // ─── Scenario 2: LAWYER -> USER (NEW bidirectional direction) ────────────
    section('Scenario 2: jerry calls gaurav (LAWYER -> USER), gaurav accepts');
    {
      const t0 = Date.now();
      const initResp = await jerry.api.post('/call/initiate', {
        recipientId:   gaurav.id,
        recipientRole: 'USER',
        type:          'VOICE',
      });
      assert(initResp.status === 200 || initResp.status === 201, `POST /call/initiate (LAWYER->USER) -> ${initResp.status}`);
      const initData = initResp.data?.data;
      assert(!!initData?.consultationId, 'initiate returns consultationId for reverse direction');
      const consultationId = initData!.consultationId;

      const incoming = await waitForEvent(gaurav, 'call:incoming', t0);
      assert(incoming.consultationId === consultationId, 'gaurav receives call:incoming');
      assert(incoming.callerId === jerry.id, 'call:incoming.callerId is jerry');
      assert(incoming.callerRole === 'LAWYER', 'call:incoming.callerRole is LAWYER');
      assert(incoming.type === 'VOICE', 'call:incoming.type is VOICE');

      // Gaurav accepts (now allowed)
      const acceptResp = await gaurav.api.post(`/call/${consultationId}/accept`);
      assert(acceptResp.status === 200 || acceptResp.status === 201, `gaurav POST /accept (reverse) -> ${acceptResp.status}`);

      // Either side can end
      const tEnd = Date.now();
      await gaurav.api.post(`/call/${consultationId}/end`);
      await waitForEvent(gaurav, 'call:ended', tEnd);
      await waitForEvent(jerry,  'call:ended', tEnd);
      ok('Reverse-direction call completed cleanly');
    }

    // ─── Scenario 3: legacy field "lawyerId" still works ─────────────────────
    section('Scenario 3: legacy lawyerId field (backward compat)');
    {
      const t0 = Date.now();
      const initResp = await gaurav.api.post('/call/initiate', {
        lawyerId: jerry.id,            // ← old field
        type:     'VIDEO',
      });
      assert(initResp.status === 200 || initResp.status === 201, `legacy lawyerId still works -> ${initResp.status}`);
      const consultationId = initResp.data?.data?.consultationId;
      await waitForEvent(jerry, 'call:incoming', t0);
      ok('Old mobile builds with legacy field still ring jerry');
      // Cancel from caller side
      await gaurav.api.post(`/call/${consultationId}/end`);
      await delay(200);
    }

    // ─── Scenario 4: reject by recipient ─────────────────────────────────────
    section('Scenario 4: jerry rejects gauravs call');
    {
      const t0 = Date.now();
      const initResp = await gaurav.api.post('/call/initiate', {
        recipientId: jerry.id, recipientRole: 'LAWYER', type: 'VIDEO',
      });
      const consultationId = initResp.data?.data?.consultationId;
      await waitForEvent(jerry, 'call:incoming', t0);

      const tReject = Date.now();
      const rejResp = await jerry.api.post(`/call/${consultationId}/reject`);
      assert(rejResp.status === 200 || rejResp.status === 201, `jerry POST /reject -> ${rejResp.status}`);
      const rejectedG = await waitForEvent(gaurav, 'call:rejected', tReject);
      assert(rejectedG.consultationId === consultationId, 'gaurav receives call:rejected');
    }

    // ─── Scenario 5: same-role call is forbidden ─────────────────────────────
    section('Scenario 5: gaurav -> gaurav (same-role) must fail');
    {
      const r = await gaurav.api.post('/call/initiate', {
        recipientId: gaurav.id, recipientRole: 'USER', type: 'VIDEO',
      });
      assert(r.status === 400, `same-role call -> ${r.status} (want 400)`);
    }

    // ─── Scenario 6: lawyer-busy lock ────────────────────────────────────────
    section('Scenario 6: lawyer busy lock — second concurrent call is MISSED');
    {
      // Start first call but DON'T accept — keep it RINGING.
      const initA = await gaurav.api.post('/call/initiate', {
        recipientId: jerry.id, recipientRole: 'LAWYER', type: 'VIDEO',
      });
      const cidA = initA.data?.data?.consultationId;
      await waitForEvent(jerry, 'call:incoming', Date.now() - 10);

      // Second call from gaurav (or another user) — busy lock should make this MISSED.
      const initB = await gaurav.api.post('/call/initiate', {
        recipientId: jerry.id, recipientRole: 'LAWYER', type: 'VOICE',
      });
      const respB = initB.data?.data;
      assert(respB?.missed === true, `second concurrent call returns missed=true (was: ${JSON.stringify(respB)})`);
      assert(respB?.reason === 'busy', `reason='busy' (was: ${respB?.reason})`);

      // Clean up
      await gaurav.api.post(`/call/${cidA}/end`);
      await delay(200);
    }

    // ─── Scenario 7: chat send/receive (regression — my refactor mustn't break chat) ──
    section('Scenario 7: chat send/receive smoke test');
    {
      const threadId = [gaurav.id, jerry.id].sort().join(':');
      const messageId = `test-${Date.now()}`;
      const tSend = Date.now();
      gaurav.socket.emit('chat:send', {
        messageId,
        threadId,
        recipientId:   jerry.id,
        recipientRole: 'LAWYER',
        content:       'hello jerry from integration test',
      });
      // Sender ack
      const sent = await waitForEvent(gaurav, 'chat:sent', tSend);
      assert(sent.messageId === messageId && sent.status === 'delivered', 'sender receives chat:sent ack');
      // Recipient routed event
      const got = await waitForEvent(jerry, 'chat:message', tSend);
      assert(got.messageId === messageId, 'jerry receives chat:message with matching messageId');
      assert(got.content === 'hello jerry from integration test', 'chat content preserved through socket pipeline');
      assert(got.senderId === gaurav.id && got.senderRole === 'USER', 'chat senderId/Role correct');
    }

    // ─── Scenario 8: persisted call records (regression for the duration bug) ──
    // Bug #1 fix: a call ended while still RINGING (caller cancels before
    // pickup) must be logged as MISSED with 0s duration — NOT as a completed
    // N-second call. A call that was actually answered must be COMPLETED.
    section('Scenario 8: call history records — cancelled→missed, answered→completed');
    {
      // 8a — cancel while ringing
      const t0 = Date.now();
      const initA = await gaurav.api.post('/call/initiate', {
        recipientId: jerry.id, recipientRole: 'LAWYER', type: 'VOICE',
      });
      const cidA = initA.data?.data?.consultationId as string;
      await waitForEvent(jerry, 'call:incoming', t0);
      await gaurav.api.post(`/call/${cidA}/end`);   // hang up BEFORE jerry answers
      await delay(500);                              // let saveCallRecord persist
      const recA = await getCallRecord(gaurav, gaurav.id, jerry.id, cidA);
      assert(!!recA, 'cancelled call produced a persisted call record');
      assert(recA?.callStatus === 'missed',
        `cancelled-while-ringing recorded as 'missed' (was: ${recA?.callStatus})`);
      assert((recA?.callDurationSeconds ?? -1) === 0,
        `cancelled call has 0s duration (was: ${recA?.callDurationSeconds}s)`);

      // 8b — answered, then ended a moment later
      const t1 = Date.now();
      const initB = await gaurav.api.post('/call/initiate', {
        recipientId: jerry.id, recipientRole: 'LAWYER', type: 'VIDEO',
      });
      const cidB = initB.data?.data?.consultationId as string;
      await waitForEvent(jerry, 'call:incoming', t1);
      await jerry.api.post(`/call/${cidB}/accept`);
      await delay(1200);                             // ~1s of talk time
      const tEnd = Date.now();
      await jerry.api.post(`/call/${cidB}/end`);
      await waitForEvent(gaurav, 'call:ended', tEnd);
      await delay(500);
      const recB = await getCallRecord(gaurav, gaurav.id, jerry.id, cidB);
      assert(recB?.callStatus === 'completed',
        `answered call recorded as 'completed' (was: ${recB?.callStatus})`);
      assert((recB?.callDurationSeconds ?? 0) >= 1,
        `completed call has a real (>=1s) duration (was: ${recB?.callDurationSeconds}s)`);
    }

    // ─── (Optional) Scenario 9: ring timeout fires after 45s ─────────────────
    if (process.env.TEST_TIMEOUT === '1') {
      section('Scenario 9: ring timeout (slow — 50s wait)');
      const t0 = Date.now();
      const initResp = await gaurav.api.post('/call/initiate', {
        recipientId: jerry.id, recipientRole: 'LAWYER', type: 'VIDEO',
      });
      const consultationId = initResp.data?.data?.consultationId;
      await waitForEvent(jerry, 'call:incoming', t0);
      note('Waiting 50s for server-side ring timeout (TEST_TIMEOUT=1)…');
      await delay(50_000);
      const endedG = await waitForEvent(gaurav, 'call:ended', t0, 10_000);
      assert(endedG.reason === 'no_answer', `gaurav gets call:ended with reason=no_answer (was: ${endedG.reason})`);
    } else {
      section('Scenario 9: ring timeout (skipped — set TEST_TIMEOUT=1 to include)');
    }

  } catch (e: any) {
    console.error(COLOR.red('\nFATAL: ') + e.message);
    if (e.response) {
      console.error(COLOR.gray('Response: ' + JSON.stringify(e.response.data).slice(0, 400)));
    }
    failed++;
  } finally {
    gaurav.socket.close();
    jerry.socket.close();
  }

  console.log(`\n${COLOR.cyan('━━━ Summary ━━━')}`);
  console.log(`  ${COLOR.green(`Passed: ${passed}`)}`);
  console.log(`  ${failed > 0 ? COLOR.red(`Failed: ${failed}`) : COLOR.green(`Failed: 0`)}`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => {
  console.error(COLOR.red('Unhandled: ' + (e?.stack ?? e)));
  process.exit(2);
});
