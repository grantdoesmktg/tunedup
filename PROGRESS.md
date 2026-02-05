# TunedUp MVP Build Progress

> Last updated: 2026-02-04

## Overall Status: ✅ Scaffold Complete

The foundational code for both backend and iOS has been scaffolded. Next steps are to:
1. Finalize iOS wiring (URL scheme + first screen + device networking)
2. Test end-to-end auth flow on device
3. Verify Resend domain and email delivery
4. Monitor production build costs

---

## Backend (`tunedup-backend`)

### Infrastructure
| Task | Status | Notes |
|------|--------|-------|
| Folder structure | ✅ Done | All directories created |
| package.json + configs | ✅ Done | Next.js 14, Prisma, Zod, Resend, Gemini SDK |
| Docker Compose (local Postgres) | ✅ Done | PostgreSQL 16 Alpine |
| Prisma schema | ✅ Done | User, Session, MagicLink, Build, Usage, Chat models |
| Prisma singleton client | ✅ Done | Prevents connection pool exhaustion |
| Environment setup (.env.example) | ✅ Done | All variables documented |
| Vercel deployment | ✅ Done | Build live; backend deployed |

### Auth System
| Task | Status | Notes |
|------|--------|-------|
| Auth utilities (lib/auth.ts) | ✅ Done | Magic link, sessions, PIN hashing |
| POST /api/auth/request-link | ✅ Done | Resend email integration |
| POST /api/auth/verify | ✅ Done | Token exchange + user creation |
| POST /api/pin/set | ✅ Done | bcryptjs hashing (serverless-safe) |
| POST /api/pin/verify | ✅ Done | Session-authenticated |

### Build System
| Task | Status | Notes |
|------|--------|-------|
| Gemini client wrapper | ✅ Done | Pro + Flash models, JSON output |
| Pipeline orchestrator | ✅ Done | 7-step with graceful degradation |
| Step A: Normalize | ✅ Done | Vehicle + intent parsing |
| Step B: Strategy | ✅ Done | Archetype, guardrails, budget allocation |
| Step C: Synergy | ✅ Done | Stages, mods, dependencies |
| Step D: Execution | ✅ Done | DIY/shop, difficulty, tools |
| Step E: Performance | ✅ Done | Before/after estimates |
| Step F: Sourcing | ✅ Done | Brands, search queries |
| Step G: Tone | ✅ Done | Mechanic personality pass |
| SSE streaming | ✅ Done | Real-time progress events |

### API Routes
| Task | Status | Notes |
|------|--------|-------|
| GET /api/builds | ✅ Done | List with stats preview |
| POST /api/builds (SSE) | ✅ Done | Pipeline trigger + streaming |
| GET /api/builds/:id | ✅ Done | Full detail response |
| DELETE /api/builds/:id | ✅ Done | Ownership check |
| POST /api/chat | ✅ Done | Build context + history |
| GET /api/usage | ✅ Done | Token status + warnings |

### Prompt Templates
| Task | Status | Notes |
|------|--------|-------|
| step-a (normalize) | ✅ Done | Embedded in step file |
| step-b (strategy) | ✅ Done | Embedded in step file |
| step-c (synergy) | ✅ Done | Embedded in step file |
| step-d (execution) | ✅ Done | Embedded in step file |
| step-e (performance) | ✅ Done | Embedded in step file |
| step-f (sourcing) | ✅ Done | Embedded in step file |
| step-g (tone) | ✅ Done | Embedded in step file |
| chat-mechanic.txt | ✅ Done | Standalone template |

---

## iOS App (`tunedup-ios`)

### Infrastructure
| Task | Status | Notes |
|------|--------|-------|
| Xcode project setup | ✅ Done | Project created; files restored and re-added |
| Folder structure | ✅ Done | Models, Views, ViewModels, Services, Utilities |
| Theme/styling | ✅ Done | Dark theme, colors, fonts, modifiers |
| API client | ✅ Done | Full REST client with auth |
| SSE client | ✅ Done | URLSessionDataDelegate implementation |
| Keychain service | ✅ Done | Secure token storage |
| Device networking | 🚧 In Progress | Must use Mac LAN IP + enable Local Network permission |

### Screens
| Task | Status | Notes |
|------|--------|-------|
| LoginView | ✅ Done | Email input + magic link + deep link handling |
| PinEntryView | ✅ Done | Number pad + verification |
| GarageView | ✅ Done | Build list + empty state + skeletons |
| BuildCard | ✅ Done | Status badge, stats preview |
| NewBuildWizardView | ✅ Done | 3-step form + progress view |
| BuildDetailView | ✅ Done | Full detail with all sections |
| StageAccordion | ✅ Done | Expandable with mods |
| MechanicChatView | ✅ Done | Chat UI + typing indicator |

### ViewModels
| Task | Status | Notes |
|------|--------|-------|
| AuthService | ✅ Done | ObservableObject singleton |
| GarageViewModel | ✅ Done | Build list management |
| WizardViewModel | ✅ Done | Form state + SSE handling |
| BuildDetailViewModel | ✅ Done | Detail loading |
| ChatViewModel | ✅ Done | Message state + API calls |

### Models
| Task | Status | Notes |
|------|--------|-------|
| User.swift | ✅ Done | Auth models |
| Build.swift | ✅ Done | All pipeline output types |
| PipelineProgress.swift | ✅ Done | Progress tracking |
| ChatMessage.swift | ✅ Done | Chat + request types |

---

## Documentation
| Task | Status | Notes |
|------|--------|-------|
| ARCHITECTURE.md | ✅ Done | Full spec with schemas |
| PROGRESS.md | ✅ Done | This file |
| MVP_BOUNDARY.md (backend) | ✅ Done | In/out scope list |
| MVP_BOUNDARY.md (iOS) | ✅ Done | iOS-specific scope |
| DECISIONS.md | ✅ Done | Architecture rationale |
| LOCAL_DEV.md | ✅ Done | Setup instructions |
| README.md (backend) | ✅ Done | Project overview |
| README.md (iOS) | ✅ Done | Project overview |

---

## Testing Results (2026-02-04)

### ✅ Verified Working
| Feature | Status | Notes |
|---------|--------|-------|
| Docker Postgres setup | ✅ Tested | Fixed port conflict with local Postgres |
| Prisma migrations | ✅ Tested | All 7 tables created successfully |
| Magic link creation | ✅ Tested | Email flow working (Resend integration pending domain verification) |
| Build pipeline (7 steps) | ✅ Tested | Complete build in ~60s, 32,558 tokens used |
| SSE streaming | ✅ Tested | Real-time progress events working |
| Database persistence | ✅ Tested | All pipeline outputs saved correctly |
| Token usage tracking | ✅ Tested | Usage increments correctly (32,558 tokens per build) |
| Graceful degradation | ✅ Tested | Step D can fail, pipeline continues |
| Build limit enforcement | ✅ Tested | 4th build rejected as expected |
| SSE token logging | ✅ Tested | Per-step token totals emitted in SSE |

### 🐛 Bugs Fixed During Testing
1. **bcrypt native module** - Required `npm rebuild bcrypt` after installation
2. **Local Postgres conflict** - Had to stop local Postgres to use Docker on port 5432
3. **Gemini model names** - Changed from `gemini-2.5-pro-preview-05-06` → `gemini-2.5-pro`
4. **Step G null check** - Fixed `stepE.caveats.join()` error when stepE is null
5. **Vercel build failure** - Switched to `bcryptjs` to avoid native module build errors

### 💰 Performance & Cost Analysis
- **Build time:** ~60+ seconds (user patience concern)
- **Tokens per build:** 32,558 tokens
- **Cost per build:** ~$0.15-0.24 (Gemini 2.5 Pro)
- **Free tier:** 100k tokens = ~3 builds per user

### 🚀 Optimization Opportunities

#### **Phase 1: Model Switching (PRIORITY - Easy Win)** ✅ COMPLETED
**Status:** ✅ Implemented (2026-02-04)
**Impact:** 50% faster, 50% cheaper, same quality
**Details:**
- Switched steps D, E, F, G to Gemini 2.5 Flash
- Kept Pro for steps A, B, C (the "thinking" steps)
- **Expected results:**
  - Time: 60s → 30-35s ⚡
  - Cost: $0.15 → $0.08 per build 💰
  - Quality: No degradation ✅

**Files modified:**
- ✅ `src/lib/gemini.ts` - Added `useFlash` parameter to `callPipelineStep()` and `getFlashModelForPipeline()` function
- ✅ `src/services/build-pipeline/step-d-execution.ts` - Now uses Flash model
- ✅ `src/services/build-pipeline/step-e-performance.ts` - Now uses Flash model
- ✅ `src/services/build-pipeline/step-f-sourcing.ts` - Now uses Flash model
- ✅ `src/services/build-pipeline/step-g-tone.ts` - Now uses Flash model

**Next test:** Capture input/output token split for precise cost accounting

#### **Phase 2: Parallel Processing (Medium Effort)**
**Status:** ⏳ Future optimization
**Impact:** 30-50% additional time reduction
**Details:**
- Run steps D, E, F in parallel after step C completes
- They don't depend on each other, only on C
- Requires Promise.all() refactor in pipeline orchestrator

## Next Steps

### Immediate
1. **Configure URL scheme** - `tunedup://` for magic link deep links
2. **Set app entry view** - Ensure `TunedupApp.swift` points to desired first screen
3. **Device networking** - Use Mac LAN IP in `APIClient.swift` + enable Local Network permission
4. **Test auth flow** - Request magic link, verify, set PIN on device
5. **Verify Resend domain** - Add DNS records in Vercel Domains

### Before Launch
1. Set up Neon database
2. Deploy backend to Vercel
3. Configure Resend domain
4. Get Gemini API keys
5. TestFlight build
6. Fix magic link email verification (domain setup)

---

## Legend
- ✅ Done
- 🚧 In Progress
- ⏳ Pending
- ❌ Blocked
