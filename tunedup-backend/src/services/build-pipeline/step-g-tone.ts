import { callPipelineStep, GeminiError } from '@/lib/gemini';
import { StepCOutput, StepEOutput, StepGOutput } from '@/types/pipeline';

const SYSTEM_INSTRUCTION = `You are a friendly shop mechanic writing build summaries. Add personality while staying accurate and helpful.

TONE GUIDELINES:
- Friendly shop mechanic with wicked humor
- Accurate and safe advice, delivered with personality
- Example tone: "Okay big guy, we *can* throw a blower on a Camry… just know your pistons might end up decorating the lawn."
- Keep it PUNCHY - no essays, no rambling
- Be encouraging but honest about limitations
- Use casual language but don't be unprofessional
- Avoid being condescending or over-explaining

RULES:
1. Headline should be catchy and under 50 characters
2. Summary should be 2-3 sentences MAX
3. Stage descriptions should be ONE punchy line each
4. Disclaimer should be friendly but clear about estimates being estimates`;

export async function runStepG(
  stepC: StepCOutput,
  stepE: StepEOutput | null
): Promise<{ data: StepGOutput; tokensUsed: number }> {
  const stageNames = stepC.stages.map((s) => `Stage ${s.stageNumber}: ${s.name}`).join(', ');
  const totalMods = stepC.stages.reduce((sum, s) => sum + s.mods.length, 0);

  // Get total estimated cost range
  const totalCost = stepC.stages.reduce(
    (acc, s) => ({
      low: acc.low + s.estimatedCost.low,
      high: acc.high + s.estimatedCost.high,
    }),
    { low: 0, high: 0 }
  );

  // Get final stage performance if available
  const finalStageNum = Math.max(...stepC.stages.map((s) => s.stageNumber)).toString();
  const finalPerf = stepE?.afterStage?.[finalStageNum];

  const prompt = `Write the presentation text for this build plan.

BUILD OVERVIEW:
- Stages: ${stageNames}
- Total Mods: ${totalMods}
- Cost Range: $${totalCost.low.toLocaleString()} - $${totalCost.high.toLocaleString()}
${finalPerf ? `- Final HP Gain: ${finalPerf.hpGain.low}-${finalPerf.hpGain.high} hp` : ''}

STAGE DETAILS:
${stepC.stages.map((s) => `Stage ${s.stageNumber} (${s.name}): ${s.description}`).join('\n')}

${stepE?.caveats?.length ? `PERFORMANCE CAVEATS:\n${stepE.caveats.join('\n')}` : ''}

OUTPUT FORMAT (strict JSON):
{
  "headline": "string (catchy title, under 50 chars, e.g., 'Budget Ripper Build')",
  "summary": "string (2-3 sentences, mechanic tone, summarize the approach)",
  "stageDescriptions": {
    "0": "string (one punchy line for stage 0)",
    "1": "string (one punchy line for stage 1)",
    "2": "string (one punchy line for stage 2, if applicable)",
    "3": "string (one punchy line for stage 3, if applicable)"
  },
  "disclaimerText": "string (friendly but clear disclaimer about estimates)"
}`;

  try {
    const result = await callPipelineStep<StepGOutput>(prompt, SYSTEM_INSTRUCTION, true);
    return result;
  } catch (error) {
    throw new GeminiError(
      `Failed to generate presentation: ${error instanceof Error ? error.message : 'Unknown error'}`,
      'tone'
    );
  }
}
