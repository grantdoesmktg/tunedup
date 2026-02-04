import { callPipelineStep, GeminiError } from '@/lib/gemini';
import { StepAOutput, StepBOutput } from '@/types/pipeline';

const SYSTEM_INSTRUCTION = `You are a build strategy planner for automotive modifications. Given a vehicle profile and user intent, decide the overall build approach including archetype, stage count, and guardrails.

CRITICAL RULES:
1. Match archetype to their stated goals and budget realistically
2. If daily driver + reliability priority, lean conservative with guardrails
3. If emissions sensitive, MUST set emissionsLegal guardrail to true
4. Budget allocation percentages should sum to 100% and be realistic
5. Stage count: 1-2 for small budgets (<$5k), 3-4 for larger builds
6. keyFocus should list 3-5 modification categories to prioritize based on goals`;

export async function runStepB(
  stepA: StepAOutput
): Promise<{ data: StepBOutput; tokensUsed: number }> {
  const prompt = `Create a build strategy for this vehicle and intent.

VEHICLE PROFILE:
${JSON.stringify(stepA.vehicleProfile, null, 2)}

USER INTENT:
${JSON.stringify(stepA.userIntent, null, 2)}

ASSUMPTIONS MADE:
${stepA.assumptions.join('\n')}

OUTPUT FORMAT (strict JSON):
{
  "archetype": "string (e.g., 'Street Performance', 'Track Day', 'Balanced Daily', 'Budget Bolt-Ons')",
  "archetypeRationale": "string (1 sentence explaining why this archetype fits)",
  "stageCount": 1 | 2 | 3 | 4,
  "budgetAllocation": {
    "stage0": number (percentage for maintenance/foundation),
    "stage1": number (percentage),
    "stage2": number (percentage, optional),
    "stage3": number (percentage, optional)
  },
  "guardrails": {
    "avoidFI": boolean (avoid forced induction mods),
    "keepWarranty": boolean (only warranty-safe mods),
    "emissionsLegal": boolean (CARB/smog legal only),
    "dailyReliability": boolean (prioritize reliability)
  },
  "keyFocus": ["string", ...] (3-5 mod categories to prioritize)
}`;

  try {
    const result = await callPipelineStep<StepBOutput>(prompt, SYSTEM_INSTRUCTION);
    return result;
  } catch (error) {
    throw new GeminiError(
      `Failed to create strategy: ${error instanceof Error ? error.message : 'Unknown error'}`,
      'strategy'
    );
  }
}
