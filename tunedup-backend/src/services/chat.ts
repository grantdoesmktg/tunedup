import prisma from '@/lib/prisma';
import { callChat, estimateTokensForText } from '@/lib/gemini';
import { trackTokens } from '@/lib/usage';

const MAX_HISTORY_MESSAGES = 10;
const MAX_RESPONSE_WORDS = 300;
const CONTEXT_TOKEN_LIMIT = Number(process.env.CHAT_CONTEXT_TOKEN_LIMIT || 8000);
const CONTEXT_WARNING_RATIO = 0.5;

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

export function getGlobalSystemPrompt(): string {
  return `You are a friendly shop mechanic with wicked humor helping someone with general car questions.

YOUR PERSONALITY:
- Friendly shop mechanic with wicked humor
- Accurate and safe advice, delivered with personality
- Keep responses CONCISE - under ${MAX_RESPONSE_WORDS} words
- Be helpful but don't over-explain
- Use casual language but stay professional

CAPABILITIES:
- Answer general car maintenance questions
- Explain car modification concepts
- Help users understand what mods might suit their goals
- Recommend when someone should create a build plan for detailed advice

RULES:
- NEVER recommend unsafe modifications without warnings
- NEVER suggest skipping safety equipment
- If someone asks about a specific build, suggest they create a build plan in the app for detailed, personalized advice
- Keep responses SHORT and punchy - no essays`;
}

function estimateContextTokens(
  systemPrompt: string,
  history: Array<{ role: 'user' | 'model'; content: string }>,
  userMessage?: string
): number {
  const historyText = history.map((m) => `${m.role}: ${m.content}`).join('\n');
  const combined = [systemPrompt, historyText, userMessage || ''].join('\n');
  return estimateTokensForText(combined);
}

function buildContextFromBuild(build: {
  vehicleJson: unknown;
  presentationJson: unknown;
  planJson: unknown;
  assumptionsJson: unknown;
}): BuildContext {
  const vehicle = build.vehicleJson as { year: number; make: string; model: string; trim: string };
  const presentation = build.presentationJson as { summary?: string } | null;
  const plan = build.planJson as { stages?: Array<{ name: string; mods: Array<{ name: string }> }> } | null;
  const assumptions = (build.assumptionsJson as string[]) || [];

  return {
    vehicle,
    summary: presentation?.summary || null,
    stages:
      plan?.stages?.map((s) => ({
        name: s.name,
        mods: s.mods.map((m) => m.name),
      })) || [],
    assumptions,
  };
}

export function buildSystemPromptFromBuild(build: {
  vehicleJson: unknown;
  presentationJson: unknown;
  planJson: unknown;
  assumptionsJson: unknown;
}): string {
  const context = buildContextFromBuild(build);
  return buildSystemPrompt(context);
}

export function computeContextUsage(
  systemPrompt: string,
  history: Array<{ role: 'user' | 'model'; content: string }>,
  userMessage?: string
): { used: number; limit: number; percent: number; warning: boolean } {
  const used = estimateContextTokens(systemPrompt, history, userMessage);
  const limit = CONTEXT_TOKEN_LIMIT;
  const percent = limit > 0 ? used / limit : 0;
  return {
    used,
    limit,
    percent,
    warning: percent >= CONTEXT_WARNING_RATIO,
  };
}

export async function processChat(
  userId: string,
  buildId: string | null,
  userMessage: string
): Promise<{ reply: string; threadId: string; tokensUsed: number; context: { used: number; limit: number; percent: number; warning: boolean } }> {
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
  let systemPrompt = getGlobalSystemPrompt();
  if (buildId) {
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

    systemPrompt = buildSystemPromptFromBuild(build);
  }

  // Format history (reverse to chronological order)
  const history = thread.messages.reverse().map((m) => ({
    role: m.role === 'assistant' ? 'model' : 'user',
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

  const contextUsage = computeContextUsage(systemPrompt, history, userMessage);

  return {
    reply: result.data,
    threadId: thread.id,
    tokensUsed: result.tokensUsed,
    context: contextUsage,
  };
}
