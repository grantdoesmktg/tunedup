# Architecture Decisions Log

> Documents key decisions made during development with rationale.

---

## Database

### Decision: Neon Postgres (Production) + Docker Postgres (Dev)
**Date:** MVP v1
**Choice:** Neon for production, local Docker for development
**Rationale:**
- Neon: Serverless, no cold starts, native Vercel integration, generous free tier
- Local Docker: Avoids burning Neon compute units during development
- Alternative considered: Supabase, Railway, PlanetScale

### Decision: Pooled + Direct Connection Strings
**Choice:** Use pgbouncer pooled URL for queries, direct URL for migrations
**Rationale:**
- Serverless functions create many short-lived connections
- Connection pooling prevents exhaustion
- Direct connection needed for schema migrations

### Decision: Prisma Singleton Pattern
**Choice:** Global singleton for PrismaClient
**Rationale:**
- Next.js hot reload creates new module instances
- Without singleton, each reload creates new connection pool
- Standard pattern for Next.js + Prisma

---

## Authentication

### Decision: Magic Link Only (No OAuth)
**Choice:** Email magic links via Resend, no social login
**Rationale:**
- Simplest implementation for MVP
- No OAuth complexity/maintenance
- Users have email; not all have Google/Apple accounts
- Can add OAuth providers later without breaking changes

### Decision: bcrypt for PIN Hashing
**Choice:** Server-side bcrypt with 12 salt rounds
**Rationale:**
- Industry standard for password hashing
- 12 rounds balances security vs performance
- Alternative considered: Argon2 (better but more complex)

### Decision: 30-Day Session Expiry
**Choice:** Sessions expire after 30 days
**Rationale:**
- Balances security with convenience
- iOS Keychain keeps token secure on device
- User can re-auth with magic link if expired

---

## AI/LLM

### Decision: Single Provider (Gemini)
**Choice:** Gemini for both pipeline and chat
**Rationale:**
- Simplifies API key management
- Consistent behavior
- Gemini 3 Pro for reasoning, 2.5 Flash for chat
- Alternative considered: Claude for pipeline, but adds complexity

### Decision: Structured JSON Output
**Choice:** Strict JSON schemas for each pipeline step
**Rationale:**
- Predictable parsing
- Type safety
- Easier error handling
- Gemini supports `responseMimeType: 'application/json'`

### Decision: Graceful Degradation
**Choice:** Pipeline continues if Steps D/E/F fail
**Rationale:**
- Core value is stages C (synergy plan)
- Execution/performance/sourcing are enhancements
- Users can see partial results
- Better UX than total failure

---

## Streaming

### Decision: Server-Sent Events (SSE)
**Choice:** SSE over WebSockets for progress updates
**Rationale:**
- Native browser/iOS support
- Simpler than WebSocket lifecycle
- One-way communication is sufficient
- Works through Vercel's edge network

---

## iOS

### Decision: Keychain for Session Token
**Choice:** Store session token in iOS Keychain
**Rationale:**
- Most secure local storage on iOS
- Survives app reinstalls (if configured)
- Standard practice for auth tokens

### Decision: MVVM Architecture
**Choice:** Model-View-ViewModel pattern
**Rationale:**
- SwiftUI-native pattern
- Clean separation of concerns
- Testable ViewModels
- Familiar to iOS developers

---

## Repository Structure

### Decision: Two Separate Repos
**Choice:** `tunedup-backend` and `tunedup-ios` as separate repos
**Rationale:**
- Cleaner CI/CD pipelines
- No Xcode/Node tooling conflicts
- Independent versioning
- Team can work in parallel
- Alternative considered: Monorepo with turborepo

---

## Usage Tracking

### Decision: Server-Side Token Counting
**Choice:** Track tokens on backend, never expose to user
**Rationale:**
- "Tokens" is an implementation detail
- Users understand "usage limits"
- Prevents gaming/manipulation
- Simpler mental model for users

### Decision: Monthly Buckets
**Choice:** Usage resets on calendar month
**Rationale:**
- Simple to implement
- Easy to explain
- Matches billing cycles (future)
- Alternative considered: Rolling 30-day window (more complex)

---

## Build Limits

### Decision: Maximum 3 Builds Per User
**Choice:** Hard limit of 3 saved builds
**Rationale:**
- Per spec requirement
- Encourages thoughtful builds
- Limits storage costs
- Can increase limit for paid tiers (future)

---

*Add new decisions above this line with date and rationale.*
