import { NextRequest, NextResponse } from 'next/server';
import { isValidDeanSession } from '@/lib/dean-session';

export async function GET(request: NextRequest) {
  if (!isValidDeanSession(request.cookies.get('cics-dean-session')?.value)) {
    return NextResponse.json({ error: 'Dean sign-in is required.' }, { status: 401 });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !publishableKey) {
    return NextResponse.json({ error: 'Set the Supabase URL and publishable key in .env.local.' }, { status: 503 });
  }

  const response = await fetch(`${url}/rest/v1/rpc/get_admin_summary`, {
    method: 'POST',
    headers: { apikey: publishableKey, Authorization: `Bearer ${publishableKey}`, 'Content-Type': 'application/json' },
    body: '{}',
    cache: 'no-store',
  });
  const summary = await response.json().catch(() => ({}));
  if (!response.ok) {
    return NextResponse.json({ error: summary.message || summary.hint || 'Could not load Supabase dashboard data. Run the latest schema.sql.' }, { status: 502 });
  }
  return NextResponse.json(summary, { headers: { 'Cache-Control': 'no-store' } });
}
