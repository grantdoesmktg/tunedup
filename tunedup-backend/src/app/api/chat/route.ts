import { NextResponse } from 'next/server';
import { getSessionFromRequest } from '@/lib/auth';
import { checkUsageBlocked } from '@/lib/usage';
import { validateRequest, chatSchema, ValidationError } from '@/lib/validation';
import { buildSystemPromptFromBuild, computeContextUsage, getGlobalSystemPrompt, processChat } from '@/services/chat';
import prisma from '@/lib/prisma';

export const dynamic = 'force-dynamic';

// ============================================
// GET /api/chat?buildId=... - Load chat history
// ============================================

export async function GET(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const buildId = searchParams.get('buildId');

    let systemPrompt = '';
    if (buildId) {
      const build = await prisma.build.findUnique({
        where: { id: buildId },
        select: {
          userId: true,
          vehicleJson: true,
          presentationJson: true,
          planJson: true,
          assumptionsJson: true,
        },
      });

      if (!build) {
        return NextResponse.json({ error: 'Build not found' }, { status: 404 });
      }

      if (build.userId !== session.userId) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
      }

      systemPrompt = buildSystemPromptFromBuild(build);
    } else {
      systemPrompt = getGlobalSystemPrompt();
    }

    const thread = await prisma.chatThread.findFirst({
      where: { userId: session.userId, buildId: buildId || null },
      include: {
        messages: {
          orderBy: { createdAt: 'asc' },
          take: 50,
        },
      },
    });

    const history = (thread?.messages || []).map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      content: m.content,
    }));

    const context = computeContextUsage(systemPrompt, history);

    return NextResponse.json({
      threadId: thread?.id || null,
      messages: (thread?.messages || []).map((m) => ({
        id: m.id,
        role: m.role,
        content: m.content,
        createdAt: m.createdAt.toISOString(),
      })),
      context,
    });
  } catch (error) {
    console.error('Chat history error:', error);
    return NextResponse.json({ error: 'Failed to load chat history' }, { status: 500 });
  }
}

// ============================================
// DELETE /api/chat?buildId=... - New chat (clear history)
// ============================================

export async function DELETE(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const buildId = searchParams.get('buildId');

    if (buildId) {
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
    }

    const thread = await prisma.chatThread.findFirst({
      where: { userId: session.userId, buildId: buildId || null },
      select: { id: true },
    });

    if (thread) {
      await prisma.chatMessage.deleteMany({ where: { threadId: thread.id } });
      await prisma.chatThread.delete({ where: { id: thread.id } });
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Chat reset error:', error);
    return NextResponse.json({ error: 'Failed to reset chat' }, { status: 500 });
  }
}

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

    if (buildId) {
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
    }

    // Process chat
    const result = await processChat(session.userId, buildId || null, message);

    return NextResponse.json({
      reply: result.reply,
      threadId: result.threadId,
      context: result.context,
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    console.error('Chat error:', error);
    return NextResponse.json({ error: 'Chat failed' }, { status: 500 });
  }
}
