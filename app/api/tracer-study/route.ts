import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !publishableKey) {
    return NextResponse.json({ error: 'Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in .env.local, then restart the app.' }, { status: 503 });
  }

  const body = await request.json().catch(() => null);
  const email = typeof body?.profile?.email === 'string' ? body.profile.email.trim().toLowerCase() : '';
  if (!email || !email.includes('@') || !body?.response) {
    return NextResponse.json({ error: 'A valid alumni email and completed questionnaire are required.' }, { status: 400 });
  }

  const result = await fetch(`${url}/rest/v1/rpc/submit_tracer_study`, {
    method: 'POST',
    headers: { apikey: publishableKey, Authorization: `Bearer ${publishableKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_profile: { ...body.profile, email }, p_response: body.response }),
  });
  if (!result.ok) {
    const detail = await result.json().catch(() => ({}));
    return NextResponse.json({ error: detail.message || detail.hint || 'Could not save tracer study response. Check that you ran the latest schema.sql.' }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
