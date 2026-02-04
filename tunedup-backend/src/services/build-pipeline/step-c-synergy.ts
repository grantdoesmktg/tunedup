import { callPipelineStep, GeminiError } from '@/lib/gemini';
import { StepAOutput, StepBOutput, StepCOutput } from '@/types/pipeline';

const SYSTEM_INSTRUCTION = `You are a synergy-aware build planner for automotive modifications. Create a detailed staged modification plan with proper dependencies and synergy groupings.

CRITICAL RULES:
1. Stage 0 = maintenance/foundation items ONLY (fluids, mounts, wear items, bushings)
2. Later stages must build on earlier ones - respect dependencies
3. Group mods that synergize together (e.g., intake + exhaust + tune)
4. Cost estimates are PARTS ONLY with realistic ranges
5. Every mod needs a clear justification tied to user goals
6. If emissionsLegal guardrail is true, ONLY include CARB-legal mods
7. If dailyReliability guardrail is true, favor reversible/reliable mods
8. Synergy explanations should explain WHY mods work together
9. Each mod needs a unique ID (e.g., "intake-1", "exhaust-1", "tune-1")`;

export async function runStepC(
  stepA: StepAOutput,
  stepB: StepBOutput
): Promise<{ data: StepCOutput; tokensUsed: number }> {
  const prompt = `Create a detailed staged modification plan.

VEHICLE PROFILE:
${JSON.stringify(stepA.vehicleProfile, null, 2)}

USER INTENT:
${JSON.stringify(stepA.userIntent, null, 2)}

BUILD STRATEGY:
${JSON.stringify(stepB, null, 2)}

OUTPUT FORMAT (strict JSON):
{
  "stages": [
    {
      "stageNumber": 0 | 1 | 2 | 3,
      "name": "string (e.g., 'Foundation', 'Bolt-Ons', 'Power Adder')",
      "description": "string (1-2 sentences about this stage's purpose)",
      "estimatedCost": {
        "low": number,
        "high": number
      },
      "mods": [
        {
          "id": "string (unique, e.g., 'intake-1')",
          "category": "string (e.g., 'intake', 'exhaust', 'suspension', 'tune')",
          "name": "string (e.g., 'Cold Air Intake')",
          "description": "string (what it does, 1-2 sentences)",
          "justification": "string (why it's in this stage, tied to user goals)",
          "estimatedCost": {
            "low": number,
            "high": number
          },
          "dependsOn": ["mod-id", ...] (mods this requires),
          "synergyWith": ["mod-id", ...] (mods this synergizes with)
        }
      ],
      "synergyGroups": [
        {
          "id": "string",
          "name": "string (e.g., 'Breathing Package')",
          "modIds": ["mod-id", ...],
          "explanation": "string (why these work together)"
        }
      ]
    }
  ]
}`;

  try {
    const result = await callPipelineStep<StepCOutput>(prompt, SYSTEM_INSTRUCTION);
    return result;
  } catch (error) {
    throw new GeminiError(
      `Failed to create synergy plan: ${error instanceof Error ? error.message : 'Unknown error'}`,
      'synergy'
    );
  }
}
