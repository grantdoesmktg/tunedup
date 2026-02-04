import prisma from './prisma';

const DEFAULT_TOKEN_LIMIT = parseInt(process.env.DEFAULT_TOKEN_LIMIT || '100000', 10);

// ============================================
// Usage Tracking
// ============================================

function getCurrentMonthKey(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

function getNextMonthReset(): Date {
  const now = new Date();
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  return nextMonth;
}

export async function getOrCreateUsage(userId: string) {
  const monthKey = getCurrentMonthKey();

  let usage = await prisma.usage.findUnique({
    where: {
      userId_monthKey: { userId, monthKey },
    },
  });

  if (!usage) {
    usage = await prisma.usage.create({
      data: {
        userId,
        monthKey,
        tokensUsed: 0,
        tokensLimit: DEFAULT_TOKEN_LIMIT,
      },
    });
  }

  return usage;
}

export async function trackTokens(userId: string, tokens: number): Promise<{
  warning: '50_percent' | '10_percent' | null;
  blocked: boolean;
}> {
  const monthKey = getCurrentMonthKey();

  const usage = await prisma.usage.upsert({
    where: {
      userId_monthKey: { userId, monthKey },
    },
    update: {
      tokensUsed: { increment: tokens },
    },
    create: {
      userId,
      monthKey,
      tokensUsed: tokens,
      tokensLimit: DEFAULT_TOKEN_LIMIT,
    },
  });

  const percentUsed = (usage.tokensUsed / usage.tokensLimit) * 100;
  const percentRemaining = 100 - percentUsed;

  let warning: '50_percent' | '10_percent' | null = null;

  // Check for 50% warning
  if (percentRemaining <= 50 && percentRemaining > 10 && !usage.warned50) {
    await prisma.usage.update({
      where: { id: usage.id },
      data: { warned50: true },
    });
    warning = '50_percent';
  }

  // Check for 10% warning
  if (percentRemaining <= 10 && !usage.warned10) {
    await prisma.usage.update({
      where: { id: usage.id },
      data: { warned10: true },
    });
    warning = '10_percent';
  }

  const blocked = usage.tokensUsed >= usage.tokensLimit;

  return { warning, blocked };
}

export async function checkUsageBlocked(userId: string): Promise<boolean> {
  const usage = await getOrCreateUsage(userId);
  return usage.tokensUsed >= usage.tokensLimit;
}

export async function getUsageStatus(userId: string) {
  const usage = await getOrCreateUsage(userId);
  const percentRemaining = Math.max(0, Math.round(((usage.tokensLimit - usage.tokensUsed) / usage.tokensLimit) * 100));

  let warning: '50_percent' | '10_percent' | null = null;
  if (percentRemaining <= 10) {
    warning = '10_percent';
  } else if (percentRemaining <= 50) {
    warning = '50_percent';
  }

  return {
    used: usage.tokensUsed,
    limit: usage.tokensLimit,
    percentRemaining,
    warning,
    blocked: usage.tokensUsed >= usage.tokensLimit,
    resetsAt: getNextMonthReset().toISOString(),
  };
}
