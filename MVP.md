TunedUp MVP v1 Spec (tight + shippable)
Product promise

Generate a synergy-aware staged build plan for any car, save up to 3 builds, and chat with a “wicked-funny mechanic” AI that uses the saved build as context.

iOS screens (minimal)

Home / Garage

Shows 0–3 saved builds (cards)

“Create New Build” CTA (disabled if already 3)

New Build Wizard (single screen w/ sections OR 2-step)
Inputs (required):

Year / Make / Model / Trim (free text + optional suggestions later)

Budget

Goal sliders or pick list (Power, Handling, Reliability)

Daily driver toggle

Emissions/legal sensitivity toggle

Transmission (Manual/Auto/Unknown)

Existing mods (text)

Inputs (optional):

Engine, drivetrain, fuel, elevation/climate notes, tire type, weight if known

City (for shop search queries)

Build Detail

Stats summary (before/after estimates + assumptions)

Stage accordion (Stage 0–3)

Mods list w/ synergy groups + dependencies

DIY vs Shop tags, difficulty, time, tools list

Parts suggestions + “Search” buttons (query links)

Shop search section: shop types + “Search near me” links

“Mechanic Chat” button

Mechanic Chat

Chat UI

Hard caps: user message length, response length

Context = selected build plan JSON + summarized build + last N messages

Key constraints

All cars supported (AI-driven, no curated database requirement)

Ballpark, consistent estimates with explicit disclaimers + assumptions

No social, no feeds, no pricing scraping, no booking

3 saved builds max

Token tracking behind the scenes

Warning at 50% and 10%, then cutoff until reset next month

Models

Workflow/build generation: Gemini 3 Pro

Chat: Gemini 2.5 Flash

Progressive loading (must-have)

Build generation runs as a multi-step pipeline and updates the UI as each step finishes:

“Understanding your car…”

“Planning stages…”

“Optimizing synergy…”

“Estimating performance…”

“Building tools/parts list…”

“Final polish…”

AI workflow pipeline (chained prompts, structured JSON)

Step A: Normalize input
Output: VehicleProfile + UserIntent JSON, with confidence + assumptions and follow-up questions list (but don’t block; proceed if missing).

Step B: Strategy
Output: BuildStrategy JSON: archetype, guardrails, stage count, budget allocation.

Step C: Synergy stage plan
Output: BuildPlan JSON with:

stages

mods per stage

synergy groups

dependencies

“why this exists” justification per stage/mod

Step D: DIY vs Shop
Output: ExecutionPlan JSON:

diyable flag, difficulty, time estimate

tools required (consolidatable)

risk notes

Step E: Performance estimate
Output: PerformanceEstimate JSON:

hp/whp deltas (ranges)

0–60, trap speed (ranges)

assumptions list

Step F: Parts & shop search queries
Output: Sourcing JSON:

reputable brands per mod category

search queries per mod

shop types + search query templates using city if provided

Step G: Tone pass
Output: BuildPlanPresentation:

concise summary

witty mechanic tone

keep it punchy (avoid essays)

Final output stored as:

canonical JSON bundle

a short, human-readable summary text

Backend (Vercel + Prisma) minimal endpoints

POST /api/auth/request-link (Resend email code)

POST /api/auth/verify (verify email + code)

POST /api/pin/set

POST /api/pin/verify

GET /api/builds (list up to 3)

POST /api/builds (create build via pipeline + stream progress)

GET /api/builds/:id

DELETE /api/builds/:id

POST /api/chat (chat with build context)

GET /api/usage (tokens remaining)

POST /api/webhook/stripe (subscription)

Streaming progress: SSE or chunked responses to support progressive loading.
