import { NextResponse } from 'next/server';
import { timingSafeEqual } from 'node:crypto';
import { issueDeanSession } from '@/lib/dean-session';

function safeEqual(a: string, b: string) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

export async function POST(request: Request) {
  if (process.env.NODE_ENV === 'production' && !process.env.DEAN_SESSION_SECRET) {
    return NextResponse.json({ error: 'DEAN_SESSION_SECRET must be set in production.' }, { status: 503 });
  }
  const body = await request.json().catch(() => null);
  const username = process.env.DEAN_USERNAME || 'dean';
  const password = process.env.DEAN_PASSWORD || 'CICS2025!';
  if (typeof body?.username === 'string' && typeof body?.password === 'string' && safeEqual(body.username, username) && safeEqual(body.password, password)) {
    const response = NextResponse.json({ ok: true });
    response.cookies.set('cics-dean-session', issueDeanSession(), {
      httpOnly: true, sameSite: 'strict', secure: process.env.NODE_ENV === 'production',
      path: '/', maxAge: 60 * 60 * 12,
    });
    return response;
  }
  return NextResponse.json({ ok: false }, { status: 401 });
}
