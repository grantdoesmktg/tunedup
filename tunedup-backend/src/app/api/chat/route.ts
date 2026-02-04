import { NextResponse } from 'next/server';
import { getSessionFromRequest } from '@/lib/auth';
import { checkUsageBlocked } from '@/lib/usage';
import { validateRequest, chatSchema, ValidationError } from '@/lib/validation';
import { processChat } from '@/services/chat';
import prisma from '@/lib/prisma';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Check usage limit
    const blocked = await checkUsageBlocked(session.userId);
    if (blocked) {
      return NextResponse.json(
        { error: 'upgrade_required', message: "You've used all your tokens this month" },
        { status: 403 }
      );
    }

    const body = await request.json();
    const { buildId, message } = validateRequest(chatSchema, body);

    // Verify build ownership
    const build = await prisma.build.findUnique({
      where: { id: buildId },
      select: { userId: true },
    });

    if (!build) {
      return NextResponse.json({ error: 'Build not found' }, { status: 404 });
    }

    if (build.userId !== session.userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    // Process chat
    const result = await processChat(session.userId, buildId, message);

    return NextResponse.json({
      reply: result.reply,
      threadId: result.threadId,
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    console.error('Chat error:', error);
    return NextResponse.json({ error: 'Chat failed' }, { status: 500 });
  }
}
