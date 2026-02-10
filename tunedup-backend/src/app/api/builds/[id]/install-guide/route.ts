import { NextResponse } from 'next/server';
import { z } from 'zod';
import prisma from '@/lib/prisma';
import { getSessionFromRequest } from '@/lib/auth';
import { validateRequest, ValidationError } from '@/lib/validation';
import { callPipelineStep } from '@/lib/gemini';
import { trackTokens, checkUsageBlocked } from '@/lib/usage';

export const dynamic = 'force-dynamic';

// Validation schema
const installGuideRequestSchema = z.object({
  modId: z.string().min(1),
});

// Install guide output schema
interface InstallGuideStep {
  number: number;
  title: string;
  description: string;
  warning?: string;
}

interface InstallGuide {
  title: string;
  recommendation: 'diy' | 'shop';
  shopReason?: string;
  difficulty: number;
  timeEstimate: string;
  tools: string[];
  steps: InstallGuideStep[];
  tips: string[];
  warnings: string[];
}

// ============================================
// POST /api/builds/:id/install-guide - Generate install guide for a mod
// ============================================

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await getSessionFromRequest(request);
    if (!session) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Check usage limit
    const isBlocked = await checkUsageBlocked(session.userId);
    if (isBlocked) {
      return NextResponse.json({ error: 'upgrade_required' }, { status: 403 });
    }

    const { id } = await params;

    // Get build with all relevant data
    const build = await prisma.build.findUnique({
      where: { id },
    });

    if (!build) {
      return NextResponse.json({ error: 'Build not found' }, { status: 404 });
    }

    if (build.userId !== session.userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    // Validate request body
    const body = await request.json();
    const { modId } = validateRequest(installGuideRequestSchema, body);

    // Extract mod and execution data from build
    const plan = build.planJson as { stages?: Array<{ mods?: Array<{ id: string; name: string; category: string; description: string }> }> } | null;
    const execution = build.executionJson as { modExecutions?: Array<{ modId: string; diyable: boolean; difficulty: number; timeEstimate: { hours: { low: number; high: number } }; toolsRequired: string[]; riskNotes: string[] }> } | null;
    const vehicle = build.vehicleJson as { year: number; make: string; model: string; trim: string; engine?: string } | null;

    // Find the mod
    let foundMod: { id: string; name: string; category: string; description: string } | null = null;
    if (plan?.stages) {
      for (const stage of plan.stages) {
        const mod = stage.mods?.find((m) => m.id === modId);
        if (mod) {
          foundMod = mod;
          break;
        }
      }
    }

    if (!foundMod) {
      return NextResponse.json({ error: 'Mod not found in build' }, { status: 404 });
    }

    // Find execution details for this mod
    const modExecution = execution?.modExecutions?.find((e) => e.modId === modId);

    // Build the prompt
    const systemPrompt = buildInstallGuideSystemPrompt();
    const userPrompt = buildInstallGuideUserPrompt(
      vehicle,
      foundMod,
      modExecution
    );

    // Generate install guide using Gemini (use Flash for cost efficiency)
    const result = await callPipelineStep<InstallGuide>(
      userPrompt,
      systemPrompt,
      true // useFlash
    );

    // Track usage
    await trackTokens(session.userId, result.tokensUsed);

    return NextResponse.json({
      guide: result.data,
      tokensUsed: result.tokensUsed,
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    console.error('Install guide generation error:', error);
    return NextResponse.json({ error: 'Failed to generate install guide' }, { status: 500 });
  }
}

function buildInstallGuideSystemPrompt(): string {
  return `You are a friendly shop mechanic creating an install guide. Be helpful, accurate, and include safety warnings.

PERSONALITY:
- Friendly mechanic with wicked humor
- Clear and concise explanations
- Don't assume the user has expertise
- Include "gotchas" that catch beginners
- Always prioritize safety

OUTPUT FORMAT:
Return valid JSON matching this exact structure:
{
  "title": "Installing [mod name] on your [year make model]",
  "recommendation": "diy" | "shop",
  "shopReason": "Optional reason if shop is recommended",
  "difficulty": 1-5,
  "timeEstimate": "1-2 hours",
  "tools": ["tool1", "tool2"],
  "steps": [
    {
      "number": 1,
      "title": "Step title",
      "description": "Detailed description",
      "warning": "Optional warning"
    }
  ],
  "tips": ["Pro tip 1", "Pro tip 2"],
  "warnings": ["Safety warning 1", "Safety warning 2"]
}

IMPORTANT RULES:
- If diyable is false, set recommendation to "shop" and explain why in shopReason
- If diyable is true, provide detailed step-by-step DIY instructions
- Always include safety warnings where relevant
- Be specific to the vehicle when possible
- Include time estimates for each major step
- Mention any specialty tools that might be needed`;
}

function buildInstallGuideUserPrompt(
  vehicle: { year: number; make: string; model: string; trim: string; engine?: string } | null,
  mod: { id: string; name: string; category: string; description: string },
  execution: { modId: string; diyable: boolean; difficulty: number; timeEstimate: { hours: { low: number; high: number } }; toolsRequired: string[]; riskNotes: string[] } | undefined
): string {
  const vehicleStr = vehicle
    ? `${vehicle.year} ${vehicle.make} ${vehicle.model} ${vehicle.trim}${vehicle.engine ? ` (${vehicle.engine})` : ''}`
    : 'Unknown vehicle';

  const diyable = execution?.diyable ?? true;
  const difficulty = execution?.difficulty ?? 3;
  const timeEstimate = execution?.timeEstimate
    ? `${execution.timeEstimate.hours.low}-${execution.timeEstimate.hours.high} hours`
    : 'Unknown';
  const tools = execution?.toolsRequired ?? [];
  const risks = execution?.riskNotes ?? [];

  return `Generate an install guide for the following:

VEHICLE: ${vehicleStr}
MODIFICATION: ${mod.name}
CATEGORY: ${mod.category}
DESCRIPTION: ${mod.description}

EXECUTION CONTEXT:
- DIY Recommended: ${diyable ? 'Yes' : 'No (Shop recommended)'}
- Difficulty: ${difficulty}/5
- Estimated Time: ${timeEstimate}
- Tools Required: ${tools.length > 0 ? tools.join(', ') : 'Unknown'}
- Risk Notes: ${risks.length > 0 ? risks.join('; ') : 'None noted'}

${!diyable ? `
SHOP RECOMMENDED:
Since this modification is marked as "Shop Recommended", start by being honest about why a shop is recommended. Explain what makes this install challenging, then provide general information about what's involved so the user understands what they're paying for at the shop.
` : `
DIY GUIDE:
Provide a clear, step-by-step guide that a moderately skilled DIYer could follow. Include all safety precautions and tips from experience.
`}

Return the install guide as JSON.`;
}
