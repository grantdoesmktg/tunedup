import { NextResponse } from 'next/server';
import { getSessionFromRequest, verifyUserPin, createSession, AuthError } from '@/lib/auth';
import { validateRequest, pinVerifySchema, ValidationError } from '@/lib/validation';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    const body = await request.json();
    const { pin, userId } = validateRequest(pinVerifySchema, body);

    const resolvedUserId = session?.userId || userId;
    if (!resolvedUserId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const verified = await verifyUserPin(resolvedUserId, pin);
    if (!verified) {
      return NextResponse.json({ error: 'Incorrect PIN' }, { status: 401 });
    }

    let sessionToken: string | null = null;
    if (!session) {
      sessionToken = await createSession(resolvedUserId);
    }

    return NextResponse.json({ verified: true, sessionToken });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    if (error instanceof AuthError) {
      return NextResponse.json({ error: error.message }, { status: 401 });
    }

    console.error('PIN verify error:', error);
    return NextResponse.json({ error: 'Verification failed' }, { status: 500 });
  }
}
