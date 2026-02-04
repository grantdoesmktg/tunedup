// ============================================
// AI Pipeline Types - Strict JSON Schemas
// ============================================

// Step A: Normalize Input
export interface VehicleProfile {
  year: number;
  make: string;
  model: string;
  trim: string;
  engine: string;
  displacement: string;
  aspiration: 'na' | 'turbo' | 'supercharged' | 'twinturbo';
  drivetrain: 'fwd' | 'rwd' | 'awd';
  transmission: 'manual' | 'auto' | 'dct' | 'cvt';
  factoryHp: number;
  factoryTorque: number;
  curbWeight: number;
  platform: string;
}

export interface UserIntent {
  budget: number;
  priorityRank: Array<'power' | 'handling' | 'reliability'>;
  dailyDriver: boolean;
  emissionsSensitive: boolean;
  existingMods: string[];
  city: string | null;
}

export interface StepAOutput {
  vehicleProfile: VehicleProfile;
  userIntent: UserIntent;
  confidence: {
    overall: number;
    vehicleData: number;
    userIntent: number;
  };
  assumptions: string[];
  followUpQuestions: string[];
}

// Step B: Strategy
export interface BuildStrategy {
  archetype: string;
  archetypeRationale: string;
  stageCount: 1 | 2 | 3 | 4;
  budgetAllocation: {
    stage0: number;
    stage1: number;
    stage2?: number;
    stage3?: number;
  };
  guardrails: {
    avoidFI: boolean;
    keepWarranty: boolean;
    emissionsLegal: boolean;
    dailyReliability: boolean;
  };
  keyFocus: string[];
}

export type StepBOutput = BuildStrategy;

// Step C: Synergy Stage Plan
export interface Mod {
  id: string;
  category: string;
  name: string;
  description: string;
  justification: string;
  estimatedCost: {
    low: number;
    high: number;
  };
  dependsOn: string[];
  synergyWith: string[];
}

export interface SynergyGroup {
  id: string;
  name: string;
  modIds: string[];
  explanation: string;
}

export interface Stage {
  stageNumber: 0 | 1 | 2 | 3;
  name: string;
  description: string;
  estimatedCost: {
    low: number;
    high: number;
  };
  mods: Mod[];
  synergyGroups: SynergyGroup[];
}

export interface StepCOutput {
  stages: Stage[];
}

// Step D: Execution Plan
export interface Tool {
  id: string;
  name: string;
  category: 'hand tool' | 'specialty' | 'lift required' | 'diagnostic';
  estimatedCost: number | null;
  reusable: boolean;
}

export interface ModExecution {
  modId: string;
  diyable: boolean;
  difficulty: 1 | 2 | 3 | 4 | 5;
  timeEstimate: {
    hours: {
      low: number;
      high: number;
    };
  };
  toolsRequired: string[];
  shopType: string | null;
  shopLaborEstimate: {
    low: number;
    high: number;
  } | null;
  riskNotes: string[];
  tips: string[];
}

export interface StepDOutput {
  modExecutions: ModExecution[];
  consolidatedTools: Tool[];
}

// Step E: Performance Estimate
export interface PerformanceBaseline {
  hp: number;
  whp: number;
  torque: number;
  weight: number;
  zeroToSixty: number;
  quarterMile: {
    time: number;
    trapSpeed: number;
  };
}

export interface StagePerformance {
  hpGain: { low: number; high: number };
  whpGain: { low: number; high: number };
  torqueGain: { low: number; high: number };
  estimatedHp: { low: number; high: number };
  estimatedWhp: { low: number; high: number };
  zeroToSixty: { low: number; high: number };
  quarterMile: {
    time: { low: number; high: number };
    trapSpeed: { low: number; high: number };
  };
}

export interface StepEOutput {
  baseline: PerformanceBaseline;
  afterStage: Record<string, StagePerformance>;
  assumptions: string[];
  caveats: string[];
}

// Step F: Sourcing
export interface ModSourcing {
  modId: string;
  reputableBrands: string[];
  searchQueries: string[];
  whereToBuy: string[];
}

export interface ShopType {
  type: string;
  forMods: string[];
  searchQuery: string;
}

export interface StepFOutput {
  modSourcing: ModSourcing[];
  shopTypes: ShopType[];
}

// Step G: Tone Pass
export interface StepGOutput {
  headline: string;
  summary: string;
  stageDescriptions: Record<string, string>;
  disclaimerText: string;
}

// Pipeline Progress Events
export type PipelineStep =
  | 'normalize'
  | 'strategy'
  | 'synergy'
  | 'execution'
  | 'performance'
  | 'sourcing'
  | 'tone';

export interface PipelineProgressEvent {
  step: PipelineStep;
  status: 'running' | 'completed' | 'failed';
  message?: string;
  tokensUsed?: number;
  totalTokens?: number;
  data?: unknown;
}

export interface PipelineCompleteEvent {
  buildId: string;
  success: boolean;
  totalTokens?: number;
}

export interface PipelineErrorEvent {
  step: PipelineStep;
  error: string;
  partial: boolean;
  buildId?: string;
}

// Combined pipeline result
export interface PipelineResult {
  stepA: StepAOutput;
  stepB: StepBOutput | null;
  stepC: StepCOutput | null;
  stepD: StepDOutput | null;
  stepE: StepEOutput | null;
  stepF: StepFOutput | null;
  stepG: StepGOutput | null;
  tokensUsed: number;
}
