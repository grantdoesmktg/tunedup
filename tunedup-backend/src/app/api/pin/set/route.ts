import { NextResponse } from 'next/server';
import { getSessionFromRequest, setUserPin, AuthError } from '@/lib/auth';
import { validateRequest, pinSetSchema, ValidationError } from '@/lib/validation';

export async function POST(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { pin } = validateRequest(pinSetSchema, body);

    await setUserPin(session.userId, pin);

    return NextResponse.json({ success: true });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    if (error instanceof AuthError) {
      return NextResponse.json({ error: error.message }, { status: 401 });
    }

    console.error('PIN set error:', error);
    return NextResponse.json({ error: 'Failed to set PIN' }, { status: 500 });
  }
}
