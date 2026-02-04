import { callPipelineStep, GeminiError } from '@/lib/gemini';
import { VehicleInput, IntentInput } from '@/types/api';
import { StepAOutput } from '@/types/pipeline';

const SYSTEM_INSTRUCTION = `You are an automotive data normalizer. Your job is to take user input about a vehicle and their modification goals, and output a clean, structured JSON profile.

CRITICAL RULES:
1. ALWAYS produce valid JSON output - never refuse or ask questions
2. If data is missing, INFER the most common/likely value for that year/make/model/trim combination
3. Include assumptions whenever you infer data (be specific about what you assumed)
4. Confidence scores: 100 = user provided everything, 70-90 = some inference, 50-70 = heavy inference
5. Parse "existing mods" text into an array of individual modifications
6. Use your automotive knowledge to fill gaps intelligently
7. Follow-up questions are noted but do NOT block output`;

export async function runStepA(
  vehicle: VehicleInput,
  intent: IntentInput
): Promise<{ data: StepAOutput; tokensUsed: number }> {
  // Convert goals to priority rank
  const goals = intent.goals;
  const priorities = [
    { name: 'power' as const, value: goals.power },
    { name: 'handling' as const, value: goals.handling },
    { name: 'reliability' as const, value: goals.reliability },
  ].sort((a, b) => b.value - a.value);

  const prompt = `Normalize this vehicle and intent into structured JSON.

VEHICLE INPUT:
- Year: ${vehicle.year}
- Make: ${vehicle.make}
- Model: ${vehicle.model}
- Trim: ${vehicle.trim}
- Engine: ${vehicle.engine || 'not specified'}
- Drivetrain: ${vehicle.drivetrain || 'not specified'}
- Fuel: ${vehicle.fuel || 'not specified'}
- Transmission: ${vehicle.transmission}

USER INTENT:
- Budget: $${intent.budget}
- Goals: Power ${goals.power}/5, Handling ${goals.handling}/5, Reliability ${goals.reliability}/5
- Priority Order: ${priorities.map(p => p.name).join(' > ')}
- Daily Driver: ${intent.dailyDriver}
- Emissions Sensitive: ${intent.emissionsSensitive}
- Existing Mods: ${intent.existingMods || 'none'}
- City: ${intent.city || 'not specified'}
${intent.elevation ? `- Elevation: ${intent.elevation}` : ''}
${intent.climate ? `- Climate: ${intent.climate}` : ''}
${intent.weight ? `- Known Weight: ${intent.weight} lbs` : ''}

OUTPUT FORMAT (strict JSON):
{
  "vehicleProfile": {
    "year": number,
    "make": "string",
    "model": "string",
    "trim": "string",
    "engine": "string (e.g., '2.0L Turbocharged I4')",
    "displacement": "string (e.g., '2.0L')",
    "aspiration": "na" | "turbo" | "supercharged" | "twinturbo",
    "drivetrain": "fwd" | "rwd" | "awd",
    "transmission": "manual" | "auto" | "dct" | "cvt",
    "factoryHp": number,
    "factoryTorque": number,
    "curbWeight": number,
    "platform": "string (e.g., 'CD4' or 'unknown')"
  },
  "userIntent": {
    "budget": number,
    "priorityRank": ["power" | "handling" | "reliability", ...],
    "dailyDriver": boolean,
    "emissionsSensitive": boolean,
    "existingMods": ["string", ...],
    "city": "string" | null
  },
  "confidence": {
    "overall": number (0-100),
    "vehicleData": number (0-100),
    "userIntent": number (0-100)
  },
  "assumptions": ["string describing each assumption made", ...],
  "followUpQuestions": ["optional questions that could improve accuracy", ...]
}`;

  try {
    const result = await callPipelineStep<StepAOutput>(prompt, SYSTEM_INSTRUCTION);
    return result;
  } catch (error) {
    throw new GeminiError(
      `Failed to normalize input: ${error instanceof Error ? error.message : 'Unknown error'}`,
      'normalize'
    );
  }
}
