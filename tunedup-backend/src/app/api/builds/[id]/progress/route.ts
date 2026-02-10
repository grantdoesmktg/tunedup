import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// ============================================
// GET /api/builds/:id/progress - Get progress for all mods in a build
// ============================================

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { id } = await params;

    // Verify build exists and belongs to user
    const build = await prisma.build.findUnique({
      where: { id },
      select: { userId: true, planJson: true },
    });

    if (!build) {
      return NextResponse.json({ error: 'Build not found' }, { status: 404 });
    }

    if (build.userId !== session.userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    // Get all progress entries for this build
    const progressEntries = await prisma.buildProgress.findMany({
      where: { buildId: id },
    });

    // Calculate stats
    const plan = build.planJson as { stages?: Array<{ mods?: Array<{ id: string }> }> } | null;
    let totalMods = 0;
    if (plan?.stages) {
      for (const stage of plan.stages) {
        totalMods += stage.mods?.length || 0;
      }
    }

    const purchased = progressEntries.filter((p) => p.status === 'purchased' || p.status === 'installed').length;
    const installed = progressEntries.filter((p) => p.status === 'installed').length;

    return NextResponse.json({
      progress: progressEntries.map((p) => ({
        modId: p.modId,
        status: p.status,
        purchasedAt: p.purchasedAt?.toISOString() || null,
        installedAt: p.installedAt?.toISOString() || null,
        notes: p.notes,
      })),
      stats: {
        total: totalMods,
        purchased,
        installed,
      },
    });
  } catch (error) {
    console.error('Get progress error:', error);
    return NextResponse.json({ error: 'Failed to fetch progress' }, { status: 500 });
  }
}
