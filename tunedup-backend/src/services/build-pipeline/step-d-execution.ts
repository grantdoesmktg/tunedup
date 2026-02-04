import { callPipelineStep, GeminiError } from '@/lib/gemini';
import { StepAOutput, StepCOutput, StepDOutput } from '@/types/pipeline';

const SYSTEM_INSTRUCTION = `You are an installation advisor for automotive modifications. For each mod in a build plan, determine DIY feasibility, difficulty, tools required, and shop recommendations.

CRITICAL RULES:
1. Be REALISTIC about DIY - some mods genuinely require professional shops
2. Difficulty scale: 1-2 = beginner friendly (basic tools), 3 = intermediate, 4-5 = advanced/shop required
3. Consolidate tools across all mods to show what's reusable
4. Include HONEST risk notes (CELs, warranty voiding, safety concerns)
5. For non-DIY mods, specify the appropriate shop type
6. Labor estimates should reflect real shop rates ($80-150/hr typical)
7. Tool categories: "hand tool", "specialty", "lift required", "diagnostic"`;

export async function runStepD(
  stepA: StepAOutput,
  stepC: StepCOutput
): Promise<{ data: StepDOutput; tokensUsed: number }> {
  // Flatten all mods from all stages
  const allMods = stepC.stages.flatMap((stage) =>
    stage.mods.map((mod) => ({ stageNumber: stage.stageNumber, ...mod }))
  );

  const prompt = `Create execution details for each mod in this build plan.

VEHICLE:
${stepA.vehicleProfile.year} ${stepA.vehicleProfile.make} ${stepA.vehicleProfile.model} ${stepA.vehicleProfile.trim}

ALL MODS TO ASSESS:
${JSON.stringify(allMods, null, 2)}

OUTPUT FORMAT (strict JSON):
{
  "modExecutions": [
    {
      "modId": "string (matches mod id from build plan)",
      "diyable": boolean,
      "difficulty": 1 | 2 | 3 | 4 | 5,
      "timeEstimate": {
        "hours": {
          "low": number,
          "high": number
        }
      },
      "toolsRequired": ["tool-id", ...],
      "shopType": "string (e.g., 'Performance Tuner', 'General Mechanic') | null if DIY",
      "shopLaborEstimate": {
        "low": number,
        "high": number
      } | null,
      "riskNotes": ["string", ...],
      "tips": ["string (helpful DIY tips)", ...]
    }
  ],
  "consolidatedTools": [
    {
      "id": "string",
      "name": "string",
      "category": "hand tool" | "specialty" | "lift required" | "diagnostic",
      "estimatedCost": number | null,
      "reusable": boolean
    }
  ]
}`;

  try {
    const result = await callPipelineStep<StepDOutput>(prompt, SYSTEM_INSTRUCTION, true);
    return result;
  } catch (error) {
    throw new GeminiError(
      `Failed to create execution plan: ${error instanceof Error ? error.message : 'Unknown error'}`,
      'execution'
    );
  }
}
