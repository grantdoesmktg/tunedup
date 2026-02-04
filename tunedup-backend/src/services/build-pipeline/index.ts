import prisma from '@/lib/prisma';
import { trackTokens } from '@/lib/usage';
import { VehicleInput, IntentInput } from '@/types/api';
import {
  StepAOutput,
  StepBOutput,
  StepCOutput,
  StepDOutput,
  StepEOutput,
  StepFOutput,
  StepGOutput,
  PipelineStep,
} from '@/types/pipeline';
import { runStepA } from './step-a-normalize';
import { runStepB } from './step-b-strategy';
import { runStepC } from './step-c-synergy';
import { runStepD } from './step-d-execution';
import { runStepE } from './step-e-performance';
import { runStepF } from './step-f-sourcing';
import { runStepG } from './step-g-tone';

// ============================================
// Pipeline Orchestrator
// ============================================

export type ProgressCallback = (event: {
  step: PipelineStep;
  status: 'running' | 'completed' | 'failed';
  message?: string;
  error?: string;
  tokensUsed?: number;
  totalTokens?: number;
}) => void;

export interface PipelineOptions {
  buildId: string;
  userId: string;
  vehicle: VehicleInput;
  intent: IntentInput;
  onProgress: ProgressCallback;
}

export async function runBuildPipeline(
  options: PipelineOptions
): Promise<{ success: boolean; totalTokens: number }> {
  const { buildId, userId, vehicle, intent, onProgress } = options;

  let stepA: StepAOutput | null = null;
  let stepB: StepBOutput | null = null;
  let stepC: StepCOutput | null = null;
  let stepD: StepDOutput | null = null;
  let stepE: StepEOutput | null = null;
  let stepF: StepFOutput | null = null;
  let stepG: StepGOutput | null = null;
  let totalTokens = 0;

  try {
    // Step A: Normalize Input
    onProgress({ step: 'normalize', status: 'running', message: 'Understanding your car…' });
    const resultA = await runStepA(vehicle, intent);
    stepA = resultA.data;
    totalTokens += resultA.tokensUsed;
    await trackTokens(userId, resultA.tokensUsed);
    await prisma.build.update({
      where: { id: buildId },
      data: {
        vehicleJson: stepA.vehicleProfile,
        intentJson: stepA.userIntent,
        assumptionsJson: stepA.assumptions,
      },
    });
    onProgress({
      step: 'normalize',
      status: 'completed',
      tokensUsed: resultA.tokensUsed,
      totalTokens,
    });

    // Step B: Strategy
    onProgress({ step: 'strategy', status: 'running', message: 'Planning stages…' });
    const resultB = await runStepB(stepA);
    stepB = resultB.data;
    totalTokens += resultB.tokensUsed;
    await trackTokens(userId, resultB.tokensUsed);
    await prisma.build.update({
      where: { id: buildId },
      data: { strategyJson: stepB },
    });
    onProgress({
      step: 'strategy',
      status: 'completed',
      tokensUsed: resultB.tokensUsed,
      totalTokens,
    });

    // Step C: Synergy Stage Plan
    onProgress({ step: 'synergy', status: 'running', message: 'Optimizing synergy…' });
    const resultC = await runStepC(stepA, stepB);
    stepC = resultC.data;
    totalTokens += resultC.tokensUsed;
    await trackTokens(userId, resultC.tokensUsed);
    await prisma.build.update({
      where: { id: buildId },
      data: { planJson: stepC },
    });
    onProgress({
      step: 'synergy',
      status: 'completed',
      tokensUsed: resultC.tokensUsed,
      totalTokens,
    });

    // Step D: Execution Plan (can fail gracefully)
    try {
      onProgress({ step: 'execution', status: 'running', message: 'Planning installation…' });
      const resultD = await runStepD(stepA, stepC);
      stepD = resultD.data;
      totalTokens += resultD.tokensUsed;
      await trackTokens(userId, resultD.tokensUsed);
      await prisma.build.update({
        where: { id: buildId },
        data: { executionJson: stepD },
      });
      onProgress({
        step: 'execution',
        status: 'completed',
        tokensUsed: resultD.tokensUsed,
        totalTokens,
      });
    } catch (error) {
      console.error('Step D failed (continuing):', error);
      onProgress({
        step: 'execution',
        status: 'failed',
        error: 'Could not generate execution details',
        totalTokens,
      });
    }

    // Step E: Performance Estimate (can fail gracefully)
    try {
      onProgress({ step: 'performance', status: 'running', message: 'Estimating performance…' });
      const resultE = await runStepE(stepA, stepC);
      stepE = resultE.data;
      totalTokens += resultE.tokensUsed;
      await trackTokens(userId, resultE.tokensUsed);
      await prisma.build.update({
        where: { id: buildId },
        data: { performanceJson: stepE },
      });
      onProgress({
        step: 'performance',
        status: 'completed',
        tokensUsed: resultE.tokensUsed,
        totalTokens,
      });
    } catch (error) {
      console.error('Step E failed (continuing):', error);
      onProgress({
        step: 'performance',
        status: 'failed',
        error: 'Could not estimate performance',
        totalTokens,
      });
    }

    // Step F: Sourcing (can fail gracefully)
    try {
      onProgress({ step: 'sourcing', status: 'running', message: 'Building parts list…' });
      const resultF = await runStepF(stepA, stepC, intent.city || null);
      stepF = resultF.data;
      totalTokens += resultF.tokensUsed;
      await trackTokens(userId, resultF.tokensUsed);
      await prisma.build.update({
        where: { id: buildId },
        data: { sourcingJson: stepF },
      });
      onProgress({
        step: 'sourcing',
        status: 'completed',
        tokensUsed: resultF.tokensUsed,
        totalTokens,
      });
    } catch (error) {
      console.error('Step F failed (continuing):', error);
      onProgress({
        step: 'sourcing',
        status: 'failed',
        error: 'Could not generate sourcing info',
        totalTokens,
      });
    }

    // Step G: Tone Pass
    onProgress({ step: 'tone', status: 'running', message: 'Final polish…' });
    const resultG = await runStepG(stepC, stepE);
    stepG = resultG.data;
    totalTokens += resultG.tokensUsed;
    await trackTokens(userId, resultG.tokensUsed);
    await prisma.build.update({
      where: { id: buildId },
      data: {
        presentationJson: stepG,
        pipelineStatus: 'completed',
      },
    });
    onProgress({
      step: 'tone',
      status: 'completed',
      tokensUsed: resultG.tokensUsed,
      totalTokens,
    });

    return { success: true, totalTokens };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const failedStep = getFailedStep(stepA, stepB, stepC);

    await prisma.build.update({
      where: { id: buildId },
      data: {
        pipelineStatus: 'failed',
        failedStep,
        errorMessage,
      },
    });

    throw error;
  }
}

function getFailedStep(
  stepA: StepAOutput | null,
  stepB: StepBOutput | null,
  stepC: StepCOutput | null
): PipelineStep {
  if (!stepA) return 'normalize';
  if (!stepB) return 'strategy';
  if (!stepC) return 'synergy';
  return 'tone';
}
