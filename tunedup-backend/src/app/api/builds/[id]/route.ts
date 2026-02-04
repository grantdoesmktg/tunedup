import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';
import { BuildDetailResponse } from '@/types/api';

// ============================================
// GET /api/builds/:id - Get build detail
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

    const build = await prisma.build.findUnique({
      where: { id },
    });

    if (!build) {
      return NextResponse.json({ error: 'Build not found' }, { status: 404 });
    }

    if (build.userId !== session.userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    const response: BuildDetailResponse = {
      id: build.id,
      createdAt: build.createdAt.toISOString(),
      pipelineStatus: build.pipelineStatus,
      failedStep: build.failedStep,
      vehicle: build.vehicleJson,
      intent: build.intentJson,
      strategy: build.strategyJson,
      plan: build.planJson,
      execution: build.executionJson,
      performance: build.performanceJson,
      sourcing: build.sourcingJson,
      presentation: build.presentationJson,
      assumptions: (build.assumptionsJson as string[]) || [],
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Build detail error:', error);
    return NextResponse.json({ error: 'Failed to fetch build' }, { status: 500 });
  }
}

// ============================================
// DELETE /api/builds/:id - Delete build
// ============================================

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { id } = await params;

    const build = await prisma.build.findUnique({
      where: { id },
      select: { userId: true },
    });

    if (!build) {
      return NextResponse.json({ error: 'Build not found' }, { status: 404 });
    }

    if (build.userId !== session.userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    await prisma.build.delete({
      where: { id },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Build delete error:', error);
    return NextResponse.json({ error: 'Failed to delete build' }, { status: 500 });
  }
}
