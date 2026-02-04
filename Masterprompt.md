You are a senior product engineer. Build a clean, production-ready MVP for an iOS-first app named “TunedUp” (domain tunedup.dev). The app generates synergy-aware car build plans and provides an in-app mechanic-style chat assistant. This is a restart-from-scratch project. PRIORITY: keep scope tight, avoid social features, avoid monorepo bloat, and produce a shippable MVP.

NON-NEGOTIABLE MVP REQUIREMENTS
1) iOS app in SwiftUI, dark theme, snappy optimistic UI. Progressive loading with skeletons and step-by-step progress updates during build generation.
2) Support ALL cars using AI reasoning. No curated per-car database required for v1. Allow missing data: the AI should infer and proceed with clear assumptions.
3) A “Garage” that stores up to 3 saved builds per user. Each saved build shows: key stats, mod stages, justification, and a chat icon to talk to the mechanic about that build.
4) Auth: magic link via Resend. After login, user can set a 4-digit PIN for quick login. Store a session token locally for faster login.
5) Token usage tracking behind the scenes (do NOT expose “tokens” as a product concept). Warn user at 50% remaining and 10% remaining. Cut off at 0 until monthly reset. (Implement a simple monthly bucket per user.)
6) Two-model setup (single provider): 
   - Workflow/build pipeline: Gemini 3 Pro (higher reasoning/context)
   - Chat: Gemini 2.5 Flash (cheaper, concise)
7) Responses must be concise and in-character (friendly shop mechanic with wicked humor, but still accurate and safe). Example tone: “Okay big guy, we *can* throw a blower on a Camry… just know your pistons might end up decorating the lawn.”
8) No social feeds, no follower system, no moderation, no parts price scraping, no booking, no affiliate links in v1.

ARCHITECTURE REQUIREMENTS
- Backend: Next.js on Vercel with API routes. Use Prisma + Postgres (choose a managed Postgres that does not sleep). 
- Implement streaming/progressive updates for build generation (SSE preferred).
- Store build plans as structured JSON plus a concise presentation summary string.
- Keep code modular, avoid overengineering.

CORE USER FLOWS
A) New Build Wizard -> Generate Build -> Save Build (if under 3) -> View Build Details -> Mechanic Chat
B) Garage -> Select Build -> View details and chat
C) Auth -> Magic link -> Set PIN -> session token

AI PIPELINE (MUST BE CHAINED PROMPTS)
Implement build generation as a multi-step pipeline, each producing strict JSON validated by a schema. Steps:
1) Normalize input -> VehicleProfile + UserIntent + assumptions + confidence
2) Strategy -> BuildStrategy (archetype, stage count, budget allocation, guardrails)
3) Synergy stage plan -> BuildPlan (stages, mods, synergy groups, dependencies, justification)
4) DIY vs Shop -> ExecutionPlan (diyable, difficulty 1–5, time estimate, tools, risk notes)
5) Performance estimate -> PerformanceEstimate (hp/whp range, 0–60 range, trap speed range, assumptions)
6) Sourcing -> reputable brands per mod type, search queries, shop types + local search query templates
7) Tone pass -> concise mechanic-style summary and labels (keep short)

The iOS app should show progress as each step completes. Build results should be viewable even if some later steps fail; degrade gracefully.

DATA MODEL (Prisma)
User: id, email, pinHash (nullable), createdAt
Build: id, userId, createdAt, vehicleJson, intentJson, planJson, presentationText, statsJson, assumptionsJson
Usage: id, userId, monthKey (YYYY-MM), tokensUsed, tokensLimit, warned50, warned10
ChatThread (optional minimal): id, userId, buildId, createdAt
ChatMessage (optional minimal): id, threadId, role, content, createdAt

ENDPOINTS
- POST /api/auth/request-link (Resend)
- POST /api/auth/verify
- POST /api/pin/set
- POST /api/pin/verify
- GET /api/builds
- POST /api/builds (starts pipeline, streams progress, saves final)
- GET /api/builds/:id
- DELETE /api/builds/:id
- POST /api/chat (uses build context + short history)
- GET /api/usage
- POST /api/stripe/webhook

IOS SCREENS
1) Garage list of up to 3 builds
2) New Build Wizard (inputs: year/make/model/trim, budget, goals, daily driver, emissions sensitivity, transmission manual/auto/unknown, existing mods; optional engine/drivetrain/fuel/city)
3) Build detail view (stats summary, stages accordion, mods, DIY vs shop, tools list, parts suggestion queries, shop type queries, assumptions/disclaimer, chat button)
4) Chat view (message length cap + response length cap; concise)

IMPLEMENTATION TASKS
- Scaffold Next.js backend with Prisma and Postgres, and Resend auth.
- Implement SSE progress streaming for /api/builds.
- Implement Gemini integration with two models and strict JSON schema validation for each pipeline step.
- Implement usage tracking.
- Scaffold SwiftUI app with clean dark theme and progressive loading UI.
- Ensure all secrets are server-side; iOS app never calls Gemini directly.

DELIVERABLES
1) A repo structure plan (NOT monorepo) with clear folders for backend and iOS, plus a short “how to run locally” doc.
2) Prisma schema and migrations.
3) API route implementations (including SSE).
4) SwiftUI screen skeletons with networking layer.
5) Prompt templates + JSON schemas for each step.
6) A short “MVP definition” doc embedded in the repo to prevent scope creep.

Start by proposing the simplest repo structure, then generate the Prisma schema, then the backend API routes, then the prompt schemas, then the SwiftUI screens. Keep it lean and shippable.
