import { NextResponse } from 'next/server';
import { getSessionFromRequest, verifyUserPin, AuthError } from '@/lib/auth';
import { validateRequest, pinVerifySchema, ValidationError } from '@/lib/validation';

export async function POST(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { pin } = validateRequest(pinVerifySchema, body);

    const verified = await verifyUserPin(session.userId, pin);
    if (!verified) {
      return NextResponse.json({ error: 'Incorrect PIN' }, { status: 401 });
    }

    return NextResponse.json({ verified: true });
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
