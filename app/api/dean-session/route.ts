import { NextRequest, NextResponse } from 'next/server';
import { isValidDeanSession } from '@/lib/dean-session';

export async function GET(request: NextRequest) {
  const valid = isValidDeanSession(request.cookies.get('cics-dean-session')?.value);
  return NextResponse.json({ authenticated: valid }, { status: valid ? 200 : 401 });
}

export async function DELETE() {
  const response = NextResponse.json({ ok: true });
  response.cookies.set('cics-dean-session', '', { httpOnly: true, sameSite: 'strict', secure: process.env.NODE_ENV === 'production', path: '/', maxAge: 0 });
  return response;
}
