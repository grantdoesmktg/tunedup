import { NextResponse } from 'next/server';
import { z } from 'zod';
import prisma from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';
import { validateRequest, ValidationError } from '@/lib/validation';

export const dynamic = 'force-dynamic';

// Validation schema for progress update
const progressUpdateSchema = z.object({
  status: z.enum(['pending', 'purchased', 'installed']),
  notes: z.string().max(500).optional(),
});

// ============================================
// PATCH /api/builds/:id/progress/:modId - Update progress for a specific mod
// ============================================

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string; modId: string }> }
) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { id, modId } = await params;

    // Verify build exists and belongs to user
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

    // Validate request body
    const body = await request.json();
    const { status, notes } = validateRequest(progressUpdateSchema, body);

    // Determine timestamps based on status
    const now = new Date();
    let purchasedAt: Date | null = null;
    let installedAt: Date | null = null;

    if (status === 'purchased') {
      purchasedAt = now;
    } else if (status === 'installed') {
      // When marking as installed, also set purchased if not already set
      const existing = await prisma.buildProgress.findUnique({
        where: { buildId_modId: { buildId: id, modId } },
      });
      purchasedAt = existing?.purchasedAt || now;
      installedAt = now;
    }

    // Upsert progress entry
    const progress = await prisma.buildProgress.upsert({
      where: {
        buildId_modId: { buildId: id, modId },
      },
      update: {
        status,
        notes: notes ?? undefined,
        purchasedAt: status === 'pending' ? null : purchasedAt,
        installedAt: status === 'installed' ? installedAt : null,
      },
      create: {
        buildId: id,
        modId,
        status,
        notes,
        purchasedAt,
        installedAt,
      },
    });

    return NextResponse.json({
      modId: progress.modId,
      status: progress.status,
      purchasedAt: progress.purchasedAt?.toISOString() || null,
      installedAt: progress.installedAt?.toISOString() || null,
      notes: progress.notes,
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    console.error('Update progress error:', error);
    return NextResponse.json({ error: 'Failed to update progress' }, { status: 500 });
  }
}
