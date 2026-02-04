import { NextResponse } from 'next/server';
import { verifyMagicLink, createSession } from '@/lib/auth';
import { validateRequest, verifySchema, ValidationError } from '@/lib/validation';
import prisma from '@/lib/prisma';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { email, code } = validateRequest(verifySchema, body);

    // Verify magic link and get/create user
    const result = await verifyMagicLink(email, code);
    if (!result) {
      return NextResponse.json({ error: 'Invalid or expired code' }, { status: 401 });
    }

    // Create session
    const sessionToken = await createSession(result.userId);

    // Get user details
    const user = await prisma.user.findUnique({
      where: { id: result.userId },
      select: { id: true, email: true, pinHash: true },
    });

    return NextResponse.json({
      sessionToken,
      user: {
        id: user!.id,
        email: user!.email,
        hasPin: !!user!.pinHash,
      },
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    console.error('Verify error:', error);
    return NextResponse.json({ error: 'Verification failed' }, { status: 500 });
  }
}
