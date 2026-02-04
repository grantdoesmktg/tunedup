import { callPipelineStep, GeminiError } from '@/lib/gemini';
import { StepAOutput, StepCOutput, StepEOutput } from '@/types/pipeline';

const SYSTEM_INSTRUCTION = `You are a performance estimator for automotive modifications. Provide realistic before/after performance estimates with honest ranges and assumptions.

CRITICAL RULES:
1. Use realistic drivetrain loss percentages (15% manual, 18% auto typical, varies by car)
2. Provide RANGES, not single numbers - be honest about variance
3. Account for synergy effects (e.g., intake alone = 5hp, with tune = 15hp)
4. Include ALL assumptions explicitly
5. Caveats should mention real factors: altitude, fuel quality, tune quality, driver skill, traction
6. 0-60 and 1/4 mile estimates should account for traction limitations, not just power
7. Be conservative rather than optimistic - underpromise, overdeliver`;

export async function runStepE(
  stepA: StepAOutput,
  stepC: StepCOutput
): Promise<{ data: StepEOutput; tokensUsed: number }> {
  const prompt = `Estimate performance before and after each stage of modifications.

VEHICLE PROFILE:
${JSON.stringify(stepA.vehicleProfile, null, 2)}

BUILD PLAN (all stages):
${JSON.stringify(stepC.stages, null, 2)}

OUTPUT FORMAT (strict JSON):
{
  "baseline": {
    "hp": number (factory crank HP),
    "whp": number (wheel HP after drivetrain loss),
    "torque": number (factory torque),
    "weight": number (curb weight lbs),
    "zeroToSixty": number (seconds),
    "quarterMile": {
      "time": number (seconds),
      "trapSpeed": number (mph)
    }
  },
  "afterStage": {
    "0": {
      "hpGain": { "low": number, "high": number },
      "whpGain": { "low": number, "high": number },
      "torqueGain": { "low": number, "high": number },
      "estimatedHp": { "low": number, "high": number },
      "estimatedWhp": { "low": number, "high": number },
      "zeroToSixty": { "low": number, "high": number },
      "quarterMile": {
        "time": { "low": number, "high": number },
        "trapSpeed": { "low": number, "high": number }
      }
    },
    "1": { ... },
    "2": { ... if applicable },
    "3": { ... if applicable }
  },
  "assumptions": ["string describing assumptions made", ...],
  "caveats": ["string describing factors that affect results", ...]
}`;

  try {
    const result = await callPipelineStep<StepEOutput>(prompt, SYSTEM_INSTRUCTION, true);
    return result;
  } catch (error) {
    throw new GeminiError(
      `Failed to estimate performance: ${error instanceof Error ? error.message : 'Unknown error'}`,
      'performance'
    );
  }
}
