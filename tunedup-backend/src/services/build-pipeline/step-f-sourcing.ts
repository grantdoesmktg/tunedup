import { callPipelineStep, GeminiError } from '@/lib/gemini';
import { StepAOutput, StepCOutput, StepFOutput } from '@/types/pipeline';

const SYSTEM_INSTRUCTION = `You are a parts sourcing advisor for automotive modifications. Generate search queries and brand recommendations for each mod in a build plan.

CRITICAL RULES:
1. Only recommend brands with GOOD reputations for this specific vehicle
2. Search queries should be specific enough to find relevant results
3. Include both general retailers (Summit Racing, ECS Tuning) and marque-specific sources
4. Shop search queries should use the user's city if provided
5. Match shop types to mods that need professional installation
6. For each mod, provide 2-4 reputable brand options`;

export async function runStepF(
  stepA: StepAOutput,
  stepC: StepCOutput,
  city: string | null
): Promise<{ data: StepFOutput; tokensUsed: number }> {
  // Flatten all mods
  const allMods = stepC.stages.flatMap((stage) =>
    stage.mods.map((mod) => ({ stageNumber: stage.stageNumber, id: mod.id, name: mod.name, category: mod.category }))
  );

  const prompt = `Generate sourcing information for each mod in this build.

VEHICLE:
${stepA.vehicleProfile.year} ${stepA.vehicleProfile.make} ${stepA.vehicleProfile.model} ${stepA.vehicleProfile.trim}

USER CITY: ${city || 'not specified'}

MODS TO SOURCE:
${JSON.stringify(allMods, null, 2)}

OUTPUT FORMAT (strict JSON):
{
  "modSourcing": [
    {
      "modId": "string (matches mod id)",
      "reputableBrands": ["string", ...] (2-4 known good brands for this vehicle),
      "searchQueries": ["string", ...] (ready-to-use search strings),
      "whereToBuy": ["string", ...] (e.g., "Summit Racing", "manufacturer direct", "FCP Euro")
    }
  ],
  "shopTypes": [
    {
      "type": "string (e.g., 'Performance Tuner', 'Alignment Shop', 'Exhaust Shop')",
      "forMods": ["mod-id", ...] (which mods need this shop type),
      "searchQuery": "string (search query using city if provided, e.g., 'BMW performance tuner near Denver')"
    }
  ]
}`;

  try {
    const result = await callPipelineStep<StepFOutput>(prompt, SYSTEM_INSTRUCTION, true);
    return result;
  } catch (error) {
    throw new GeminiError(
      `Failed to generate sourcing: ${error instanceof Error ? error.message : 'Unknown error'}`,
      'sourcing'
    );
  }
}
