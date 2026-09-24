import { createHmac, timingSafeEqual } from 'node:crypto';

function sessionSecret() {
  return process.env.DEAN_SESSION_SECRET || (process.env.NODE_ENV === 'production' ? '' : 'development-only-change-this-session-secret');
}

export function issueDeanSession(now = Date.now()) {
  const expires = String(now + 1000 * 60 * 60 * 12);
  const signature = createHmac('sha256', sessionSecret()).update(expires).digest('hex');
  return `${expires}.${signature}`;
}

export function isValidDeanSession(token?: string) {
  if (!token || !sessionSecret()) return false;
  const [expires, signature, extra] = token.split('.');
  if (!expires || !signature || extra || !/^\d+$/.test(expires) || Number(expires) < Date.now()) return false;
  const expected = createHmac('sha256', sessionSecret()).update(expires).digest('hex');
  const actualBuffer = Buffer.from(signature, 'hex');
  const expectedBuffer = Buffer.from(expected, 'hex');
  return actualBuffer.length === expectedBuffer.length && timingSafeEqual(actualBuffer, expectedBuffer);
}
