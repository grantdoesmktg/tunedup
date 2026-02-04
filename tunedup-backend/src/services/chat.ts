import prisma from '@/lib/prisma';
import { callChat } from '@/lib/gemini';
import { trackTokens } from '@/lib/usage';

const MAX_HISTORY_MESSAGES = 10;
const MAX_RESPONSE_WORDS = 300;

interface BuildContext {
  vehicle: {
    year: number;
    make: string;
    model: string;
    trim: string;
  };
  summary: string | null;
  stages: Array<{
    name: string;
    mods: string[];
  }>;
  assumptions: string[];
}

function buildSystemPrompt(context: BuildContext): string {
  const stagesSummary = context.stages
    .map((s) => `${s.name}: ${s.mods.join(', ')}`)
    .join('\n');

  return `You are a friendly shop mechanic with wicked humor helping a customer with their ${context.vehicle.year} ${context.vehicle.make} ${context.vehicle.model} ${context.vehicle.trim} build.

BUILD CONTEXT:
${context.summary || 'Build summary not available'}

MODIFICATION STAGES:
${stagesSummary || 'No stages defined yet'}

ASSUMPTIONS MADE:
${context.assumptions.length > 0 ? context.assumptions.join('\n') : 'None noted'}

YOUR PERSONALITY:
- Friendly shop mechanic with wicked humor
- Accurate and safe advice, delivered with personality
- Keep responses CONCISE - under ${MAX_RESPONSE_WORDS} words
- Be helpful but don't over-explain
- Use casual language but stay professional
- If asked about something outside the build, you can help but bring it back to the car
- If asked about pricing, give rough ranges and emphasize "it depends"

RULES:
- NEVER recommend unsafe modifications without warnings
- NEVER suggest skipping safety equipment
- Always consider the user's stated goals (daily driver, emissions, etc.)
- Keep responses SHORT and punchy - no essays`;
}

export async function processChat(
  userId: string,
  buildId: string,
  userMessage: string
): Promise<{ reply: string; threadId: string; tokensUsed: number }> {
  // Get or create chat thread
  let thread = await prisma.chatThread.findFirst({
    where: { userId, buildId },
    include: {
      messages: {
        orderBy: { createdAt: 'desc' },
        take: MAX_HISTORY_MESSAGES,
      },
    },
  });

  if (!thread) {
    thread = await prisma.chatThread.create({
      data: { userId, buildId },
      include: { messages: true },
    });
  }

  // Get build context
  const build = await prisma.build.findUnique({
    where: { id: buildId },
    select: {
      vehicleJson: true,
      presentationJson: true,
      planJson: true,
      assumptionsJson: true,
    },
  });

  if (!build) {
    throw new Error('Build not found');
  }

  // Extract context
  const vehicle = build.vehicleJson as { year: number; make: string; model: string; trim: string };
  const presentation = build.presentationJson as { summary?: string } | null;
  const plan = build.planJson as { stages?: Array<{ name: string; mods: Array<{ name: string }> }> } | null;
  const assumptions = (build.assumptionsJson as string[]) || [];

  const context: BuildContext = {
    vehicle,
    summary: presentation?.summary || null,
    stages:
      plan?.stages?.map((s) => ({
        name: s.name,
        mods: s.mods.map((m) => m.name),
      })) || [],
    assumptions,
  };

  const systemPrompt = buildSystemPrompt(context);

  // Format history (reverse to chronological order)
  const history = thread.messages.reverse().map((m) => ({
    role: m.role as 'user' | 'model',
    content: m.content,
  }));

  // Call Gemini
  const result = await callChat(systemPrompt, history, userMessage);

  // Save messages
  await prisma.chatMessage.createMany({
    data: [
      {
        threadId: thread.id,
        role: 'user',
        content: userMessage,
      },
      {
        threadId: thread.id,
        role: 'assistant',
        content: result.data,
      },
    ],
  });

  // Track tokens
  await trackTokens(userId, result.tokensUsed);

  return {
    reply: result.data,
    threadId: thread.id,
    tokensUsed: result.tokensUsed,
  };
}
