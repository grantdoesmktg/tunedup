import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';
import { checkUsageBlocked } from '@/lib/usage';
import { validateRequest, createBuildSchema, ValidationError } from '@/lib/validation';
import { runBuildPipeline } from '@/services/build-pipeline';
import { BuildListResponse, BuildListItem } from '@/types/api';
import { StepGOutput, StepEOutput } from '@/types/pipeline';

const MAX_BUILDS = 3;

// ============================================
// GET /api/builds - List user's builds
// ============================================

export async function GET(request: Request) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
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

    const buildList: BuildListItem[] = builds.map((build) => {
      const vehicle = build.vehicleJson as { year: number; make: string; model: string; trim: string };
      const presentation = build.presentationJson as StepGOutput | null;
      const performance = build.performanceJson as StepEOutput | null;
      const intent = build.intentJson as { budget: number };

      // Get HP gain from final stage
      let hpGainRange: [number, number] | null = null;
      if (performance?.afterStage) {
        const stageKeys = Object.keys(performance.afterStage).map(Number);
        const maxStage = Math.max(...stageKeys).toString();
        const finalStage = performance.afterStage[maxStage];
        if (finalStage?.hpGain) {
          hpGainRange = [finalStage.hpGain.low, finalStage.hpGain.high];
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
        { error: 'Maximum 3 builds allowed. Delete a build to create a new one.' },
        { status: 400 }
      );
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
          } catch (error) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error';
            send('error', {
              error: errorMessage,
              partial: true,
              buildId: build.id,
            });
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
        const result = await runBuildPipeline({
          buildId: build.id,
          userId: session.userId,
          vehicle,
          intent,
          onProgress: () => {}, // No-op for non-SSE
        });

        return NextResponse.json({ buildId: build.id, success: true, totalTokens: result.totalTokens });
      } catch (error) {
        return NextResponse.json(
          { buildId: build.id, success: false, partial: true },
          { status: 200 }
        );
      }
    }
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    console.error('Build create error:', error);
    return NextResponse.json({ error: 'Failed to create build' }, { status: 500 });
  }
}
