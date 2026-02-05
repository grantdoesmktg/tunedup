# TunedUp MVP Architecture

> Generated from MVP.md and Masterprompt.md specifications.
> This document is the source of truth for implementation.

---

## 1. Repository Structure

### tunedup-backend (Next.js + Prisma + Vercel)

```
tunedup-backend/
├── .env.example
├── .env.local              # gitignored
├── .gitignore
├── next.config.js
├── package.json
├── tsconfig.json
├── prisma/
│   ├── schema.prisma
│   └── migrations/
├── src/
│   ├── app/
│   │   └── api/
│   │       ├── auth/
│   │       │   ├── request-link/route.ts
│   │       │   └── verify/route.ts
│   │       ├── pin/
│   │       │   ├── set/route.ts
│   │       │   └── verify/route.ts
│   │       ├── builds/
│   │       │   ├── route.ts              # GET list, POST create
│   │       │   └── [id]/route.ts         # GET detail, DELETE
│   │       ├── chat/route.ts
│   │       └── usage/route.ts
│   ├── lib/
│   │   ├── prisma.ts                     # singleton client
│   │   ├── auth.ts                       # token validation helpers
│   │   ├── gemini.ts                     # Gemini API wrapper
│   │   ├── usage.ts                      # token tracking helpers
│   │   └── validation.ts                 # Zod schemas
│   ├── services/
│   │   ├── build-pipeline/
│   │   │   ├── index.ts                  # orchestrator
│   │   │   ├── step-a-normalize.ts
│   │   │   ├── step-b-strategy.ts
│   │   │   ├── step-c-synergy.ts
│   │   │   ├── step-d-execution.ts
│   │   │   ├── step-e-performance.ts
│   │   │   ├── step-f-sourcing.ts
│   │   │   └── step-g-tone.ts
│   │   └── chat.ts
│   ├── prompts/
│   │   ├── step-a.txt
│   │   ├── step-b.txt
│   │   ├── step-c.txt
│   │   ├── step-d.txt
│   │   ├── step-e.txt
│   │   ├── step-f.txt
│   │   └── step-g.txt
│   └── types/
│       ├── pipeline.ts                   # shared pipeline types
│       └── api.ts                        # request/response types
├── docs/
│   ├── MVP_BOUNDARY.md
│   ├── DECISIONS.md
│   └── LOCAL_DEV.md
└── README.md
```

### tunedup-ios (SwiftUI)

```
tunedup-ios/
├── .gitignore
├── TunedUp.xcodeproj/
├── TunedUp/
│   ├── TunedUpApp.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Models/
│   │   ├── Build.swift
│   │   ├── User.swift
│   │   ├── ChatMessage.swift
│   │   └── PipelineProgress.swift
│   ├── Views/
│   │   ├── Garage/
│   │   │   ├── GarageView.swift
│   │   │   └── BuildCard.swift
│   │   ├── Wizard/
│   │   │   ├── NewBuildWizardView.swift
│   │   │   └── WizardInputs.swift
│   │   ├── BuildDetail/
│   │   │   ├── BuildDetailView.swift
│   │   │   ├── StageAccordion.swift
│   │   │   └── StatsCard.swift
│   │   ├── Chat/
│   │   │   └── MechanicChatView.swift
│   │   └── Auth/
│   │       ├── LoginView.swift
│   │       └── PinEntryView.swift
│   ├── Services/
│   │   ├── APIClient.swift
│   │   ├── AuthService.swift
│   │   ├── KeychainService.swift
│   │   └── SSEClient.swift
│   ├── ViewModels/
│   │   ├── GarageViewModel.swift
│   │   ├── WizardViewModel.swift
│   │   ├── BuildDetailViewModel.swift
│   │   └── ChatViewModel.swift
│   └── Utilities/
│       ├── Theme.swift
│       └── Extensions.swift
├── docs/
│   └── MVP_BOUNDARY.md
└── README.md
```

---

## 2. Prisma Schema

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")          // pooled for Vercel
  directUrl = env("DATABASE_URL_DIRECT")   // direct for migrations
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  pinHash   String?                        // bcrypt hash, nullable until set
  createdAt DateTime @default(now())

  builds    Build[]
  usage     Usage[]
  sessions  Session[]

  @@map("users")
}

model Session {
  id        String   @id @default(cuid())
  userId    String
  token     String   @unique              // random 32-byte hex
  expiresAt DateTime
  createdAt DateTime @default(now())

  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([token])
  @@index([userId])
  @@map("sessions")
}

model Build {
  id               String   @id @default(cuid())
  userId           String
  createdAt        DateTime @default(now())

  // Pipeline outputs (JSON columns)
  vehicleJson      Json                    // VehicleProfile
  intentJson       Json                    // UserIntent
  strategyJson     Json?                   // BuildStrategy (nullable for graceful degradation)
  planJson         Json?                   // BuildPlan with stages/mods/synergy
  executionJson    Json?                   // ExecutionPlan (DIY vs shop)
  performanceJson  Json?                   // PerformanceEstimate
  sourcingJson     Json?                   // Sourcing queries

  // Final presentation
  presentationText String?                 // Mechanic-tone summary
  assumptionsJson  Json?                   // List of assumptions made

  // Pipeline status
  pipelineStatus   String   @default("pending") // pending, running, completed, failed
  failedStep       String?                 // which step failed, if any

  user             User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  chatThreads      ChatThread[]

  @@index([userId])
  @@map("builds")
}

model Usage {
  id          String   @id @default(cuid())
  userId      String
  monthKey    String                       // "2024-01" format
  tokensUsed  Int      @default(0)
  tokensLimit Int      @default(100000)    // default free tier limit
  warned50    Boolean  @default(false)
  warned10    Boolean  @default(false)

  user        User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, monthKey])
  @@map("usage")
}

model ChatThread {
  id        String   @id @default(cuid())
  userId    String
  buildId   String
  createdAt DateTime @default(now())

  build     Build    @relation(fields: [buildId], references: [id], onDelete: Cascade)
  messages  ChatMessage[]

  @@index([buildId])
  @@map("chat_threads")
}

model ChatMessage {
  id        String   @id @default(cuid())
  threadId  String
  role      String                         // "user" | "assistant"
  content   String
  createdAt DateTime @default(now())

  thread    ChatThread @relation(fields: [threadId], references: [id], onDelete: Cascade)

  @@index([threadId])
  @@map("chat_messages")
}
```

---

## 3. API Endpoints

### Authentication

#### POST /api/auth/request-link
Sends 6-digit email code via Resend.

```typescript
// Request
{
  email: string  // user's email
}

// Response 200
{
  success: true,
  message: "Check your email for your 6-digit code"
}

// Response 400
{
  error: "Invalid email format"
}
```

#### POST /api/auth/verify
Verifies email + code and returns a session.

```typescript
// Request
{
  email: string,
  code: string  // 6-digit email code
}

// Response 200
{
  sessionToken: string,  // store in Keychain
  user: {
    id: string,
    email: string,
    hasPin: boolean
  }
}

// Response 401
{
  error: "Invalid or expired code"
}
```

### PIN

#### POST /api/pin/set
Sets or updates user's PIN. Requires session token.

```typescript
// Headers: Authorization: Bearer <sessionToken>

// Request
{
  pin: string  // 4 digits
}

// Response 200
{
  success: true
}

// Response 400
{
  error: "PIN must be exactly 4 digits"
}
```

#### POST /api/pin/verify
Quick login with PIN. Requires session token.

```typescript
// Headers: Authorization: Bearer <sessionToken>

// Request
{
  pin: string
}

// Response 200
{
  verified: true
}

// Response 401
{
  error: "Incorrect PIN"
}
```

### Builds

#### GET /api/builds
List user's builds (max 3).

```typescript
// Headers: Authorization: Bearer <sessionToken>

// Response 200
{
  builds: [
    {
      id: string,
      createdAt: string,
      vehicle: {
        year: number,
        make: string,
        model: string,
        trim: string
      },
      summary: string,           // short presentation text
      pipelineStatus: "pending" | "running" | "completed" | "failed",
      statsPreview: {            // quick stats for card display
        hpGainRange: [number, number] | null,
        totalBudget: number
      }
    }
  ],
  canCreateNew: boolean          // false if 3 builds exist
}
```

#### POST /api/builds
Create new build. Streams progress via SSE.

```typescript
// Headers:
//   Authorization: Bearer <sessionToken>
//   Accept: text/event-stream

// Request
{
  vehicle: {
    year: number,
    make: string,
    model: string,
    trim: string,
    engine?: string,
    drivetrain?: string,
    fuel?: string,
    transmission: "manual" | "auto" | "unknown"
  },
  intent: {
    budget: number,
    goals: {
      power: number,      // 1-5
      handling: number,   // 1-5
      reliability: number // 1-5
    },
    dailyDriver: boolean,
    emissionsSensitive: boolean,
    existingMods: string,
    elevation?: string,
    climate?: string,
    tireType?: string,
    weight?: number,
    city?: string
  }
}

// SSE Response (streamed events)
event: progress
data: {"step": "normalize", "status": "running", "message": "Understanding your car…"}

event: progress
data: {"step": "normalize", "status": "completed", "data": {...vehicleProfile}}

event: progress
data: {"step": "strategy", "status": "running", "message": "Planning stages…"}

// ... continues for each step ...

event: complete
data: {"buildId": "clx123...", "success": true}

event: error
data: {"step": "performance", "error": "Failed to estimate", "partial": true}
```

#### GET /api/builds/:id
Get full build detail.

```typescript
// Headers: Authorization: Bearer <sessionToken>

// Response 200
{
  id: string,
  createdAt: string,
  pipelineStatus: string,
  failedStep: string | null,

  vehicle: VehicleProfile,
  intent: UserIntent,
  strategy: BuildStrategy | null,
  plan: BuildPlan | null,
  execution: ExecutionPlan | null,
  performance: PerformanceEstimate | null,
  sourcing: Sourcing | null,

  presentation: string | null,
  assumptions: string[]
}
```

#### DELETE /api/builds/:id
Delete a build.

```typescript
// Headers: Authorization: Bearer <sessionToken>

// Response 200
{
  success: true
}

// Response 404
{
  error: "Build not found"
}
```

### Chat

#### POST /api/chat
Send message to mechanic. Uses Gemini 2.5 Flash.

```typescript
// Headers: Authorization: Bearer <sessionToken>

// Request
{
  buildId: string,
  message: string  // max 500 chars
}

// Response 200
{
  reply: string,   // max ~300 words, mechanic tone
  threadId: string
}

// Response 400
{
  error: "Message too long (max 500 characters)"
}

// Response 403
{
  error: "upgrade_required",
  message: "You've used all your tokens this month"
}
```

### Usage

#### GET /api/usage
Get current token usage status.

```typescript
// Headers: Authorization: Bearer <sessionToken>

// Response 200
{
  used: number,
  limit: number,
  percentRemaining: number,
  warning: "50_percent" | "10_percent" | null,
  blocked: boolean,
  resetsAt: string  // ISO date of next month
}
```

---

## 4. AI Pipeline Design

### Overview

```
Input → [A] Normalize → [B] Strategy → [C] Synergy → [D] Execution → [E] Performance → [F] Sourcing → [G] Tone → Output
```

Each step:
1. Receives output from previous step(s)
2. Calls Gemini 3 Pro with structured prompt
3. Validates response against JSON schema
4. Streams progress to client
5. Continues even if non-critical steps fail (graceful degradation)

### Step A: Normalize Input

**Purpose:** Parse user input into clean vehicle profile and intent, inferring missing data.

**JSON Schema:**
```typescript
interface StepAOutput {
  vehicleProfile: {
    year: number;
    make: string;
    model: string;
    trim: string;
    engine: string;           // inferred if not provided
    displacement: string;     // inferred
    aspiration: "na" | "turbo" | "supercharged" | "twinturbo";
    drivetrain: "fwd" | "rwd" | "awd";
    transmission: "manual" | "auto" | "dct" | "cvt";
    factoryHp: number;        // estimated
    factoryTorque: number;    // estimated
    curb_weight: number;      // estimated
    platform: string;         // e.g., "S550", "GC8"
  };
  userIntent: {
    budget: number;
    priorityRank: ["power" | "handling" | "reliability", ...]; // ordered
    dailyDriver: boolean;
    emissionsSensitive: boolean;
    existingMods: string[];
    city: string | null;
  };
  confidence: {
    overall: number;          // 0-100
    vehicleData: number;
    userIntent: number;
  };
  assumptions: string[];      // e.g., "Assumed base engine 2.0L EcoBoost"
  followUpQuestions: string[]; // NOT blocking, just noted
}
```

**Prompt Template (step-a.txt):**
```
You are an automotive data normalizer. Given user input about a vehicle and their modification goals, output a structured JSON profile.

RULES:
1. If data is missing, infer the most common/likely value for that year/make/model/trim
2. Always include assumptions when inferring
3. Confidence score reflects how certain you are (100 = user provided everything, 50 = heavy inference)
4. Do NOT ask questions or refuse - always produce output with assumptions noted
5. Parse "existing mods" into an array of individual modifications

USER INPUT:
Year: {{year}}
Make: {{make}}
Model: {{model}}
Trim: {{trim}}
Engine (if provided): {{engine}}
Drivetrain (if provided): {{drivetrain}}
Transmission: {{transmission}}
Budget: ${{budget}}
Goals - Power: {{power}}/5, Handling: {{handling}}/5, Reliability: {{reliability}}/5
Daily Driver: {{dailyDriver}}
Emissions Sensitive: {{emissionsSensitive}}
Existing Mods: {{existingMods}}
City: {{city}}

Output valid JSON matching the StepAOutput schema. No markdown, no explanation, just JSON.
```

---

### Step B: Strategy

**Purpose:** Decide build archetype, stage count, and budget allocation based on profile and intent.

**JSON Schema:**
```typescript
interface StepBOutput {
  archetype: string;           // e.g., "Street Performance", "Track Day", "Balanced DD"
  archetypeRationale: string;  // 1 sentence why
  stageCount: 1 | 2 | 3 | 4;   // how many stages to plan
  budgetAllocation: {
    stage0: number;            // percentage
    stage1: number;
    stage2?: number;
    stage3?: number;
  };
  guardrails: {
    avoidFI: boolean;          // avoid forced induction
    keepWarranty: boolean;     // warranty-safe mods only
    emissionsLegal: boolean;   // CARB/smog legal
    dailyReliability: boolean; // prioritize reliability
  };
  keyFocus: string[];          // e.g., ["intake", "exhaust", "suspension"]
}
```

**Prompt Template (step-b.txt):**
```
You are a build strategy planner. Given a vehicle profile and user intent, decide the overall build approach.

VEHICLE PROFILE:
{{vehicleProfileJson}}

USER INTENT:
{{userIntentJson}}

RULES:
1. Match archetype to their stated goals and budget
2. If daily driver + reliability priority, lean conservative
3. If emissions sensitive, set emissionsLegal guardrail
4. Budget allocation should be realistic for the car and goals
5. Stage count: 1-2 for small budgets, 3-4 for larger builds
6. keyFocus should list 3-5 modification categories to prioritize

Output valid JSON matching the StepBOutput schema. No markdown, no explanation, just JSON.
```

---

### Step C: Synergy Stage Plan

**Purpose:** Generate the actual modification stages with synergy groups and dependencies.

**JSON Schema:**
```typescript
interface StepCOutput {
  stages: Stage[];
}

interface Stage {
  stageNumber: 0 | 1 | 2 | 3;
  name: string;                // e.g., "Foundation", "Bolt-Ons", "Power Adder"
  description: string;         // 1-2 sentences
  estimatedCost: {
    low: number;
    high: number;
  };
  mods: Mod[];
  synergyGroups: SynergyGroup[];
}

interface Mod {
  id: string;                  // unique within build, e.g., "intake-1"
  category: string;            // e.g., "intake", "exhaust", "suspension"
  name: string;                // e.g., "Cold Air Intake"
  description: string;         // what it does, 1-2 sentences
  justification: string;       // why it's in this stage
  estimatedCost: {
    low: number;
    high: number;
  };
  dependsOn: string[];         // mod IDs this requires
  synergyWith: string[];       // mod IDs this synergizes with
}

interface SynergyGroup {
  id: string;
  name: string;                // e.g., "Breathing Package"
  modIds: string[];
  explanation: string;         // why these work together
}
```

**Prompt Template (step-c.txt):**
```
You are a synergy-aware build planner. Create a staged modification plan.

VEHICLE PROFILE:
{{vehicleProfileJson}}

USER INTENT:
{{userIntentJson}}

BUILD STRATEGY:
{{strategyJson}}

RULES:
1. Stage 0 = maintenance/foundation items (fluids, mounts, wear items)
2. Later stages build on earlier ones - respect dependencies
3. Group mods that synergize (e.g., intake + exhaust + tune)
4. Cost estimates should be parts only, realistic ranges
5. Every mod needs a clear justification tied to user goals
6. If emissions sensitive, only include CARB-legal mods
7. If daily driver priority, favor reversible/reliable mods
8. Include synergy explanations (e.g., "intake + exhaust unlocks tune potential")

Output valid JSON matching the StepCOutput schema. No markdown, no explanation, just JSON.
```

---

### Step D: Execution Plan (DIY vs Shop)

**Purpose:** Add installation details, tools, difficulty, and risk notes.

**JSON Schema:**
```typescript
interface StepDOutput {
  modExecutions: ModExecution[];
  consolidatedTools: Tool[];
}

interface ModExecution {
  modId: string;               // references mod from Step C
  diyable: boolean;
  difficulty: 1 | 2 | 3 | 4 | 5;  // 1=easy, 5=expert
  timeEstimate: {
    hours: {
      low: number;
      high: number;
    };
  };
  toolsRequired: string[];     // tool IDs
  shopType: string | null;     // if not DIY: "general mechanic", "performance shop", etc.
  shopLaborEstimate: {
    low: number;
    high: number;
  } | null;
  riskNotes: string[];         // e.g., "Risk of CEL if O2 sensors not extended"
  tips: string[];              // helpful DIY tips
}

interface Tool {
  id: string;
  name: string;
  category: string;            // "hand tool", "specialty", "lift required"
  estimatedCost: number | null;
  reusable: boolean;
}
```

**Prompt Template (step-d.txt):**
```
You are an installation advisor. For each mod in the build plan, determine DIY feasibility and requirements.

VEHICLE PROFILE:
{{vehicleProfileJson}}

BUILD PLAN:
{{planJson}}

RULES:
1. Be realistic about DIY - some mods genuinely need shops
2. Difficulty 1-2 = beginner friendly, 3 = intermediate, 4-5 = advanced/shop
3. Consolidate tools across mods to show what's reusable
4. Include honest risk notes (CELs, warranty, safety)
5. For non-DIY mods, specify the right shop type
6. Labor estimates should reflect real shop rates ($80-150/hr)

Output valid JSON matching the StepDOutput schema. No markdown, no explanation, just JSON.
```

---

### Step E: Performance Estimate

**Purpose:** Estimate before/after performance numbers with honest ranges.

**JSON Schema:**
```typescript
interface StepEOutput {
  baseline: {
    hp: number;
    whp: number;
    torque: number;
    weight: number;
    zeroToSixty: number;
    quarterMile: {
      time: number;
      trapSpeed: number;
    };
  };
  afterStage: {
    [stageNumber: string]: {
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
    };
  };
  assumptions: string[];
  caveats: string[];           // e.g., "Gains depend on tune quality"
}
```

**Prompt Template (step-e.txt):**
```
You are a performance estimator. Provide realistic before/after estimates.

VEHICLE PROFILE:
{{vehicleProfileJson}}

BUILD PLAN:
{{planJson}}

RULES:
1. Use realistic drivetrain loss (15% manual, 18% auto typical)
2. Provide RANGES, not single numbers - be honest about variance
3. Account for synergy (e.g., intake alone = 5hp, with tune = 15hp)
4. Include all assumptions explicitly
5. Caveats should mention real factors (altitude, fuel, tune quality, driver)
6. 0-60 and 1/4 mile estimates should account for traction, not just power

Output valid JSON matching the StepEOutput schema. No markdown, no explanation, just JSON.
```

---

### Step F: Sourcing

**Purpose:** Generate search queries and brand recommendations.

**JSON Schema:**
```typescript
interface StepFOutput {
  modSourcing: ModSourcing[];
  shopTypes: ShopType[];
}

interface ModSourcing {
  modId: string;
  reputableBrands: string[];   // 2-4 known good brands
  searchQueries: string[];     // ready-to-use search strings
  whereToBuy: string[];        // e.g., "manufacturer direct", "Summit Racing"
}

interface ShopType {
  type: string;                // e.g., "Performance Tuner", "Alignment Shop"
  forMods: string[];           // mod IDs this shop handles
  searchQuery: string;         // e.g., "{{make}} performance shop near {{city}}"
}
```

**Prompt Template (step-f.txt):**
```
You are a parts sourcing advisor. Generate search queries and brand recommendations.

VEHICLE PROFILE:
{{vehicleProfileJson}}

BUILD PLAN:
{{planJson}}

USER CITY: {{city}}

RULES:
1. Only recommend brands with good reputations for this specific car
2. Search queries should be specific enough to find relevant results
3. Include both general retailers and marque-specific sources
4. Shop search queries should use the city if provided
5. Match shop types to the mods that need professional install

Output valid JSON matching the StepFOutput schema. No markdown, no explanation, just JSON.
```

---

### Step G: Tone Pass

**Purpose:** Generate the human-readable presentation with mechanic personality.

**JSON Schema:**
```typescript
interface StepGOutput {
  headline: string;            // punchy 1-liner, e.g., "Budget Ripper Build"
  summary: string;             // 2-3 sentences, mechanic tone
  stageDescriptions: {
    [stageNumber: string]: string;  // 1-2 sentence per stage, personality
  };
  disclaimerText: string;      // friendly but clear disclaimer
}
```

**Prompt Template (step-g.txt):**
```
You are a friendly shop mechanic writing build summaries. Add personality while staying accurate.

BUILD PLAN:
{{planJson}}

PERFORMANCE ESTIMATES:
{{performanceJson}}

TONE GUIDELINES:
- Friendly shop mechanic with wicked humor
- Accurate and safe advice, just delivered with personality
- Example: "Okay big guy, we *can* throw a blower on a Camry… just know your pistons might end up decorating the lawn."
- Keep it punchy - no essays
- Be encouraging but honest about limitations

OUTPUT:
1. headline: A punchy title for this build (under 50 chars)
2. summary: 2-3 sentences summarizing the build approach
3. stageDescriptions: One punchy line per stage
4. disclaimerText: Friendly but clear disclaimer about estimates

Output valid JSON matching the StepGOutput schema. No markdown, no explanation, just JSON.
```

---

## 5. Progressive Streaming Implementation

### Server-Side (SSE)

```typescript
// src/app/api/builds/route.ts

export async function POST(request: Request) {
  const body = await request.json();
  const userId = await validateSession(request);

  // Check build limit
  const existingBuilds = await prisma.build.count({ where: { userId } });
  if (existingBuilds >= 3) {
    return Response.json({ error: "Maximum 3 builds allowed" }, { status: 400 });
  }

  // Check usage
  const usage = await getOrCreateUsage(userId);
  if (usage.tokensUsed >= usage.tokensLimit) {
    return Response.json({ error: "upgrade_required" }, { status: 403 });
  }

  // Create build record in pending state
  const build = await prisma.build.create({
    data: {
      userId,
      vehicleJson: body.vehicle,
      intentJson: body.intent,
      pipelineStatus: "running"
    }
  });

  // Return SSE stream
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      const send = (event: string, data: any) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };

      try {
        // Step A
        send("progress", { step: "normalize", status: "running", message: "Understanding your car…" });
        const stepA = await runStepA(body.vehicle, body.intent);
        await prisma.build.update({ where: { id: build.id }, data: { vehicleJson: stepA.vehicleProfile } });
        await trackTokens(userId, stepA.tokensUsed);
        send("progress", { step: "normalize", status: "completed" });

        // Step B
        send("progress", { step: "strategy", status: "running", message: "Planning stages…" });
        const stepB = await runStepB(stepA);
        await prisma.build.update({ where: { id: build.id }, data: { strategyJson: stepB } });
        await trackTokens(userId, stepB.tokensUsed);
        send("progress", { step: "strategy", status: "completed" });

        // Step C
        send("progress", { step: "synergy", status: "running", message: "Optimizing synergy…" });
        const stepC = await runStepC(stepA, stepB);
        await prisma.build.update({ where: { id: build.id }, data: { planJson: stepC } });
        await trackTokens(userId, stepC.tokensUsed);
        send("progress", { step: "synergy", status: "completed" });

        // Step D
        send("progress", { step: "execution", status: "running", message: "Planning installation…" });
        const stepD = await runStepD(stepA, stepC);
        await prisma.build.update({ where: { id: build.id }, data: { executionJson: stepD } });
        await trackTokens(userId, stepD.tokensUsed);
        send("progress", { step: "execution", status: "completed" });

        // Step E
        send("progress", { step: "performance", status: "running", message: "Estimating performance…" });
        const stepE = await runStepE(stepA, stepC);
        await prisma.build.update({ where: { id: build.id }, data: { performanceJson: stepE } });
        await trackTokens(userId, stepE.tokensUsed);
        send("progress", { step: "performance", status: "completed" });

        // Step F
        send("progress", { step: "sourcing", status: "running", message: "Building parts list…" });
        const stepF = await runStepF(stepA, stepC, body.intent.city);
        await prisma.build.update({ where: { id: build.id }, data: { sourcingJson: stepF } });
        await trackTokens(userId, stepF.tokensUsed);
        send("progress", { step: "sourcing", status: "completed" });

        // Step G
        send("progress", { step: "tone", status: "running", message: "Final polish…" });
        const stepG = await runStepG(stepC, stepE);
        await prisma.build.update({
          where: { id: build.id },
          data: {
            presentationText: stepG.summary,
            assumptionsJson: stepA.assumptions,
            pipelineStatus: "completed"
          }
        });
        await trackTokens(userId, stepG.tokensUsed);
        send("progress", { step: "tone", status: "completed" });

        send("complete", { buildId: build.id, success: true });

      } catch (error) {
        // Graceful degradation - save what we have
        await prisma.build.update({
          where: { id: build.id },
          data: {
            pipelineStatus: "failed",
            failedStep: error.step || "unknown"
          }
        });
        send("error", {
          step: error.step,
          error: error.message,
          partial: true,
          buildId: build.id  // still return ID so partial build is viewable
        });
      } finally {
        controller.close();
      }
    }
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive"
    }
  });
}
```

### iOS Client (SSE)

```swift
// Services/SSEClient.swift

import Foundation

class SSEClient: NSObject, URLSessionDataDelegate {
    private var session: URLSession!
    private var task: URLSessionDataTask?
    private var buffer = ""

    var onProgress: ((PipelineProgress) -> Void)?
    var onComplete: ((String) -> Void)?  // buildId
    var onError: ((PipelineError) -> Void)?

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120  // pipeline can take time
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    func startBuild(vehicle: VehicleInput, intent: IntentInput, token: String) {
        guard let url = URL(string: "\(APIClient.baseURL)/api/builds") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body = BuildRequest(vehicle: vehicle, intent: intent)
        request.httpBody = try? JSONEncoder().encode(body)

        task = session.dataTask(with: request)
        task?.resume()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        // Parse SSE events
        let events = buffer.components(separatedBy: "\n\n")
        buffer = events.last ?? ""

        for event in events.dropLast() {
            parseEvent(event)
        }
    }

    private func parseEvent(_ raw: String) {
        var eventType = ""
        var eventData = ""

        for line in raw.components(separatedBy: "\n") {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7))
            } else if line.hasPrefix("data: ") {
                eventData = String(line.dropFirst(6))
            }
        }

        guard let data = eventData.data(using: .utf8) else { return }

        switch eventType {
        case "progress":
            if let progress = try? JSONDecoder().decode(PipelineProgress.self, from: data) {
                onProgress?(progress)
            }
        case "complete":
            if let result = try? JSONDecoder().decode(BuildComplete.self, from: data) {
                onComplete?(result.buildId)
            }
        case "error":
            if let error = try? JSONDecoder().decode(PipelineError.self, from: data) {
                onError?(error)
            }
        default:
            break
        }
    }

    func cancel() {
        task?.cancel()
    }
}
```

---

## 6. Environment Variables

### Backend (.env.example)

```bash
# Database - Neon (dev + prod)
DATABASE_URL="postgresql://user:pass@ep-xxx.us-east-2.aws.neon.tech/tunedup?sslmode=require&pgbouncer=true"
DATABASE_URL_DIRECT="postgresql://user:pass@ep-xxx.us-east-2.aws.neon.tech/tunedup?sslmode=require"

# Resend (email)
RESEND_API_KEY="re_xxx"
RESEND_FROM_EMAIL="auth@tunedup.dev"

# Gemini
GEMINI_API_KEY="xxx"
GEMINI_PRO_MODEL="gemini-2.5-pro"       # for pipeline
GEMINI_FLASH_MODEL="gemini-2.5-flash"   # for chat

# Auth
SESSION_SECRET="random-32-byte-hex"
MAGIC_LINK_SECRET="random-32-byte-hex"
MAGIC_LINK_EXPIRY_MINUTES="15"

# App
APP_URL="https://tunedup.dev"           # optional; used in emails/links if needed
NODE_ENV="development"

# Usage limits (tokens)
DEFAULT_TOKEN_LIMIT="100000"            # free tier monthly limit
```

### iOS (no secrets - all API calls go through backend)

```swift
// APIClient.swift
private let baseURL = "https://www.tunedup.dev"
```

### Deployment

- Backend deploys from GitHub to Vercel.
- Set `DATABASE_URL`, `DATABASE_URL_DIRECT`, and all secrets in Vercel project environment variables.

---

## 7. MVP Boundary Checklist

### ✅ IN SCOPE (building this)

- [x] 6-digit email code auth via Resend
- [x] 4-digit PIN for quick login
- [x] Session token stored in iOS Keychain
- [x] Garage with up to 3 builds
- [x] New Build Wizard with all specified inputs
- [x] 7-step AI pipeline with progressive streaming
- [x] Build detail view with stages, mods, synergy, DIY info
- [x] Parts search query generation (links only)
- [x] Shop type search query generation (links only)
- [x] Mechanic chat with build context
- [x] Token usage tracking (server-side, hidden from user)
- [x] 50% and 10% usage warnings
- [x] "Upgrade required" state when tokens exhausted
- [x] Dark theme UI
- [x] Graceful degradation if pipeline steps fail

### ❌ OUT OF SCOPE (intentionally NOT building)

- [ ] Social features (followers, feeds, sharing)
- [ ] User-to-user messaging
- [ ] Parts price scraping or live pricing
- [ ] Shop booking or scheduling
- [ ] Affiliate links
- [ ] Curated per-car mod databases
- [ ] Image uploads or photo analysis
- [ ] Push notifications
- [ ] Stripe billing / subscriptions (placeholder state only)
- [ ] Admin dashboard
- [ ] Analytics beyond basic usage tracking
- [ ] Multiple auth providers (Google, Apple, etc.)
- [ ] Build versioning or history
- [ ] Build sharing/export
- [ ] Offline mode
- [ ] Localization / i18n
- [ ] Android app

---

## 8. Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Database | Neon Postgres | Serverless, no cold starts, Vercel-friendly, free tier |
| Prisma connection | Pooled + direct | Pooled for queries, direct for migrations |
| Auth | 6-digit email code | Simplest for MVP, no OAuth complexity |
| PIN storage | bcryptjs server-side | Secure, standard practice |
| Session storage | iOS Keychain | Secure local storage on device |
| Build limit | 3 per user | Per spec, prevents abuse |
| Token tracking | Server-side only | Users don't see "tokens" as concept |
| Billing | Skipped | Placeholder "upgrade required" state for now |
| AI provider | Gemini (single provider) | Per spec, simplifies API management |
| Streaming | SSE | Native browser/iOS support, simpler than WebSockets |
| Monorepo | No (2 repos) | Cleaner CI/CD, avoids Xcode/Node conflicts |

---

## Next Steps

1. Initialize `tunedup-backend` repo with Next.js + Prisma
2. Connect Neon database (dev + prod) and set env vars
3. Create Prisma schema and run initial migration
4. Implement auth routes (email code + PIN)
5. Implement build pipeline with SSE streaming
6. Initialize `tunedup-ios` repo with SwiftUI skeleton
7. Implement iOS networking layer + SSE client
8. Build out screens in order: Auth → Garage → Wizard → Detail → Chat
