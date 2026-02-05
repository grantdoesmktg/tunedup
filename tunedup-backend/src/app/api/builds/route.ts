import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';
import { checkUsageBlocked } from '@/lib/usage';
import { validateRequest, createBuildSchema, ValidationError } from '@/lib/validation';
import { runBuildPipeline } from '@/services/build-pipeline';
import { BuildListResponse, BuildListItem } from '@/types/api';
import { StepGOutput, StepEOutput } from '@/types/pipeline';

export const dynamic = 'force-dynamic';

const MAX_BUILDS = 3;

// ============================================
// GET /api/builds - List user's builds
// ============================================

export async function GET(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized', code: 'unauthorized' }, { status: 401 });
    }

    const builds = await prisma.build.findMany({
      where: { userId: session.userId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        createdAt: true,
        vehicleJson: true,
        pipelineStatus: true,
        presentationJson: true,
        performanceJson: true,
        intentJson: true,
      },
    });

    const buildList: BuildListItem[] = builds.map((build: typeof builds[number]) => {
      const vehicle = build.vehicleJson as { year: number; make: string; model: string; trim: string };
      const presentation = build.presentationJson as StepGOutput | null;
      const performance = build.performanceJson as StepEOutput | null;
      const intent = build.intentJson as { budget: number };

      // Get best (cumulative) HP gain across stages
      let hpGainRange: [number, number] | null = null;
      if (performance?.afterStage) {
        let best: { low: number; high: number } | null = null;
        let bestMid = -Infinity;
        for (const stage of Object.values(performance.afterStage)) {
          if (!stage?.hpGain) continue;
          const mid = (stage.hpGain.low + stage.hpGain.high) / 2;
          if (mid > bestMid) {
            bestMid = mid;
            best = { low: stage.hpGain.low, high: stage.hpGain.high };
          }
        }
        if (best) {
          hpGainRange = [best.low, best.high];
        }
      }

      return {
        id: build.id,
        createdAt: build.createdAt.toISOString(),
        vehicle: {
          year: vehicle.year,
          make: vehicle.make,
          model: vehicle.model,
          trim: vehicle.trim,
        },
        summary: presentation?.summary || null,
        pipelineStatus: build.pipelineStatus as 'pending' | 'running' | 'completed' | 'failed',
        statsPreview: {
          hpGainRange,
          totalBudget: intent.budget,
        },
      };
    });

    const response: BuildListResponse = {
      builds: buildList,
      canCreateNew: builds.length < MAX_BUILDS,
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Build list error:', error);
    return NextResponse.json({ error: 'Failed to fetch builds' }, { status: 500 });
  }
}

// ============================================
// POST /api/builds - Create new build (SSE)
// ============================================

export async function POST(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Check build limit
    const existingCount = await prisma.build.count({
      where: { userId: session.userId },
    });
    if (existingCount >= MAX_BUILDS) {
      return NextResponse.json(
        {
          error: 'Maximum 3 builds allowed. Delete a build to create a new one.',
          code: 'build_limit_reached',
          canCreateNew: false,
        },
        { status: 400 }
      );
    }

    // Check usage limit
    const blocked = await checkUsageBlocked(session.userId);
    if (blocked) {
      return NextResponse.json(
        {
          error: 'upgrade_required',
          code: 'usage_limit_reached',
          message: "You've used all your tokens this month",
        },
        { status: 403 }
      );
    }

    const body = await request.json();
    const { vehicle, intent } = validateRequest(createBuildSchema, body);

    // Create build record in pending state
    const build = await prisma.build.create({
      data: {
        userId: session.userId,
        vehicleJson: vehicle,
        intentJson: intent,
        pipelineStatus: 'running',
      },
    });

    // Check if client wants SSE
    const acceptHeader = request.headers.get('Accept');
    const wantsSSE = acceptHeader?.includes('text/event-stream');

    if (wantsSSE) {
      // Return SSE stream
      const encoder = new TextEncoder();
      const stream = new ReadableStream({
        async start(controller) {
          const send = (event: string, data: unknown) => {
            controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
          };

          try {
            console.info('[builds] start', { buildId: build.id, userId: session.userId });
            const result = await runBuildPipeline({
              buildId: build.id,
              userId: session.userId,
              vehicle,
              intent,
              onProgress: (event) => {
                send('progress', event);
              },
            });

            send('complete', { buildId: build.id, success: true, totalTokens: result.totalTokens });
            console.info('[builds] complete', { buildId: build.id, userId: session.userId, totalTokens: result.totalTokens });
          } catch (error) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error';
            send('error', {
              error: errorMessage,
              partial: true,
              buildId: build.id,
              code: 'pipeline_failed',
            });
            console.error('[builds] failed', { buildId: build.id, userId: session.userId, error: errorMessage });
          } finally {
            controller.close();
          }
        },
      });

      return new Response(stream, {
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          Connection: 'keep-alive',
        },
      });
    } else {
      // Non-SSE: run pipeline and return result
      try {
        console.info('[builds] start', { buildId: build.id, userId: session.userId });
        const result = await runBuildPipeline({
          buildId: build.id,
          userId: session.userId,
          vehicle,
          intent,
          onProgress: () => {}, // No-op for non-SSE
        });

        console.info('[builds] complete', { buildId: build.id, userId: session.userId, totalTokens: result.totalTokens });
        return NextResponse.json({ buildId: build.id, success: true, totalTokens: result.totalTokens });
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        console.error('[builds] failed', { buildId: build.id, userId: session.userId, error: errorMessage });
        return NextResponse.json(
          { buildId: build.id, success: false, partial: true, code: 'pipeline_failed' },
          { status: 200 }
        );
      }
    }
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message, code: 'validation_error' }, { status: 400 });
    }

    console.error('Build create error:', error);
    return NextResponse.json({ error: 'Failed to create build', code: 'server_error' }, { status: 500 });
  }
}
