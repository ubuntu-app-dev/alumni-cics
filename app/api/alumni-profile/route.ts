import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !publishableKey) {
    return NextResponse.json({ error: 'Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in .env.local, then restart the app.' }, { status: 503 });
  }

  const profile = await request.json().catch(() => null);
  if (typeof profile?.email !== 'string' || !profile.email.includes('@')) {
    return NextResponse.json({ error: 'A valid alumni email is required.' }, { status: 400 });
  }

  // Null out age if missing or outside the DB check constraint (15–120).
  const rawAge = Number(profile.age);
  const safeAge = Number.isFinite(rawAge) && rawAge >= 15 && rawAge <= 120 ? rawAge : null;

  const response = await fetch(`${url}/rest/v1/rpc/save_alumni_profile`, {
    method: 'POST',
    headers: { apikey: publishableKey, Authorization: `Bearer ${publishableKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_profile: { ...profile, email: profile.email.trim().toLowerCase(), age: safeAge } }),
  });
  if (!response.ok) {
    const detail = await response.json().catch(() => ({}));
    return NextResponse.json({ error: detail.message || detail.hint || 'Could not save alumni profile. Run the latest schema.sql.' }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}
