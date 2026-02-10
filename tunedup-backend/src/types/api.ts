// ============================================
// API Request/Response Types
// ============================================

// Auth
export interface RequestLinkRequest {
  email: string;
}

export interface RequestLinkResponse {
  success: boolean;
  message: string;
}

export interface VerifyRequest {
  email: string;
  code: string;
}

export interface VerifyResponse {
  sessionToken: string;
  user: {
    id: string;
    email: string;
    hasPin: boolean;
  };
}

export interface PinSetRequest {
  pin: string;
}

export interface PinVerifyRequest {
  pin: string;
}

export interface PinVerifyResponse {
  verified: boolean;
  sessionToken?: string | null;
}

// Builds
export interface VehicleInput {
  year: number;
  make: string;
  model: string;
  trim: string;
  engine?: string;
  drivetrain?: string;
  fuel?: string;
  transmission: 'manual' | 'auto' | 'unknown';
}

export interface IntentInput {
  budget: number;
  goals: {
    power: number;
    handling: number;
    reliability: number;
  };
  dailyDriver: boolean;
  emissionsSensitive: boolean;
  existingMods: string;
  elevation?: string;
  climate?: string;
  tireType?: string;
  weight?: number;
  city?: string;
}

export interface CreateBuildRequest {
  vehicle: VehicleInput;
  intent: IntentInput;
}

export interface BuildListItem {
  id: string;
  createdAt: string;
  vehicle: {
    year: number;
    make: string;
    model: string;
    trim: string;
  };
  summary: string | null;
  pipelineStatus: 'pending' | 'running' | 'completed' | 'failed';
  statsPreview: {
    hpGainRange: [number, number] | null;
    totalBudget: number;
  } | null;
}

export interface BuildListResponse {
  builds: BuildListItem[];
  canCreateNew: boolean;
}

export interface BuildDetailResponse {
  id: string;
  createdAt: string;
  pipelineStatus: string;
  failedStep: string | null;
  vehicle: unknown;
  intent: unknown;
  strategy: unknown | null;
  plan: unknown | null;
  execution: unknown | null;
  performance: unknown | null;
  sourcing: unknown | null;
  presentation: unknown | null;
  assumptions: string[];
}

// Chat
export interface ChatRequest {
  buildId?: string;
  message: string;
}

export interface ChatResponse {
  reply: string;
  threadId: string;
  context: {
    used: number;
    limit: number;
    percent: number;
    warning: boolean;
  };
}

export interface ChatMessageItem {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: string;
}

export interface ChatHistoryResponse {
  threadId: string | null;
  messages: ChatMessageItem[];
  context: {
    used: number;
    limit: number;
    percent: number;
    warning: boolean;
  };
}

// Usage
export interface UsageResponse {
  used: number;
  limit: number;
  percentRemaining: number;
  warning: '50_percent' | '10_percent' | null;
  blocked: boolean;
  resetsAt: string;
}

// Build Progress
export interface ModProgressItem {
  modId: string;
  status: 'pending' | 'purchased' | 'installed';
  purchasedAt: string | null;
  installedAt: string | null;
  notes: string | null;
}

export interface ProgressStats {
  total: number;
  purchased: number;
  installed: number;
}

export interface BuildProgressResponse {
  progress: ModProgressItem[];
  stats: ProgressStats;
}

export interface ProgressUpdateRequest {
  status: 'pending' | 'purchased' | 'installed';
  notes?: string;
}

// Install Guide
export interface InstallGuideRequest {
  modId: string;
}

export interface InstallStep {
  number: number;
  title: string;
  description: string;
  warning?: string;
}

export interface InstallGuide {
  title: string;
  recommendation: 'diy' | 'shop';
  shopReason?: string;
  difficulty: number;
  timeEstimate: string;
  tools: string[];
  steps: InstallStep[];
  tips: string[];
  warnings: string[];
}

export interface InstallGuideResponse {
  guide: InstallGuide;
  tokensUsed: number;
}

// Error responses
export interface ErrorResponse {
  error: string;
  message?: string;
}
