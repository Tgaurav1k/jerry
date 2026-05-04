// Supabase Edge Function: firebase-phone-signin
// Verifies a Firebase ID token (from phone auth) and returns a Supabase session.
// Deploy: supabase functions deploy firebase-phone-signin
// Secrets needed:
//   supabase secrets set FIREBASE_WEB_API_KEY=<your Firebase Web API Key>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { firebaseToken, fullName, role, phone } = await req.json();

    if (!firebaseToken) {
      return new Response(JSON.stringify({ error: "firebaseToken required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Step 1: Verify Firebase ID token via Firebase REST API ──────────
    const firebaseApiKey = Deno.env.get("FIREBASE_WEB_API_KEY");
    const verifyRes = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${firebaseApiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken: firebaseToken }),
      }
    );
    const verifyData = await verifyRes.json();

    if (!verifyData.users?.[0]) {
      return new Response(JSON.stringify({ error: "Invalid Firebase token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const firebaseUser = verifyData.users[0];
    const phoneNumber: string = firebaseUser.phoneNumber ?? phone ?? "";
    const firebaseUid: string = firebaseUser.localId;

    // ── Step 2: Create Supabase admin client (service role) ──────────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Deterministic Supabase email from Firebase UID
    const email    = `${firebaseUid}@firebase.jerry.app`;
    const password = `fb_${firebaseUid}_jerry`;  // deterministic, never shown to user

    // ── Step 3: Try sign-in first (existing user) ────────────────────────
    const { data: signInData } = await supabase.auth.signInWithPassword({ email, password });

    if (signInData.session) {
      return new Response(JSON.stringify(signInData), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Step 4: New user — create Supabase account (no email confirmation) ─
    const userRole = role ?? "USER";

    const { data: newUserData, error: createErr } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,   // skip email verification (Firebase already verified phone)
      phone: phoneNumber,
      phone_confirm: true,
      user_metadata: {
        role:      userRole,
        full_name: fullName ?? "",
        phone:     phoneNumber,
      },
    });

    if (createErr || !newUserData.user) {
      return new Response(JSON.stringify({ error: createErr?.message ?? "Failed to create user" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = newUserData.user.id;

    // ── Step 5: Create profile in DB ─────────────────────────────────────
    await supabase.from("profiles").upsert({
      id:                 userId,
      role:               userRole,
      full_name:          fullName ?? "",
      phone:              phoneNumber,
      preferred_language: "English",
    });

    if (userRole === "LAWYER") {
      await supabase.from("lawyer_profiles").upsert({ id: userId });
    }

    // ── Step 6: Sign in to get session and return it ──────────────────────
    const { data: finalData, error: finalErr } = await supabase.auth.signInWithPassword({
      email, password,
    });

    if (finalErr || !finalData.session) {
      return new Response(JSON.stringify({ error: "Session creation failed" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify(finalData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
