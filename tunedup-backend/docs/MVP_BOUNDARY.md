# MVP Boundary Definition

> This document defines what IS and IS NOT in scope for TunedUp MVP v1.
> Reference this before adding any features.

## IN SCOPE (Building This)

### Authentication
- [x] 6-digit email code auth via Resend
- [x] 4-digit PIN for quick re-login
- [x] Session tokens (30-day expiry)
- [x] iOS Keychain storage for tokens

### Garage
- [x] List up to 3 saved builds
- [x] Build cards with summary stats
- [x] Create new build (if under limit)
- [x] Delete builds

### Build Generation
- [x] 7-step AI pipeline (Gemini 3 Pro)
- [x] Progressive SSE streaming
- [x] Graceful degradation on step failures
- [x] Structured JSON output per step
- [x] All cars supported via AI inference

### Build Details
- [x] Stats summary (before/after)
- [x] Stage accordion (Stage 0-3)
- [x] Mods with synergy groups and dependencies
- [x] DIY vs Shop indicators
- [x] Difficulty ratings (1-5)
- [x] Time estimates
- [x] Tools list (consolidated)
- [x] Risk notes
- [x] Parts search queries (links only)
- [x] Shop search queries (links only)
- [x] Assumptions list

### Chat
- [x] Mechanic persona (Gemini 2.5 Flash)
- [x] Build context awareness
- [x] Message length cap (500 chars)
- [x] Response length cap (~300 words)
- [x] Chat history (last 10 messages)

### Usage Tracking
- [x] Server-side token counting
- [x] Monthly usage buckets
- [x] 50% warning
- [x] 10% warning
- [x] Cutoff at limit
- [x] "Upgrade required" state

### UI/UX
- [x] Dark theme
- [x] Progressive loading with skeletons
- [x] Step-by-step progress during generation
- [x] Optimistic UI updates

---

## OUT OF SCOPE (Intentionally NOT Building)

### Social Features
- [ ] User profiles
- [ ] Followers/following
- [ ] Public builds
- [ ] Build sharing
- [ ] Comments
- [ ] Likes/votes
- [ ] Leaderboards
- [ ] Activity feeds

### Commerce
- [ ] Parts price scraping
- [ ] Live pricing
- [ ] Affiliate links
- [ ] Shop booking
- [ ] Payment processing
- [ ] Stripe subscriptions (placeholder only)

### Advanced Features
- [ ] Build versioning/history
- [ ] Build export (PDF, etc.)
- [ ] Build comparison
- [ ] Image uploads
- [ ] Photo analysis
- [ ] VIN decoder
- [ ] OBD integration
- [ ] Dyno data import

### Data Management
- [ ] Curated per-car mod databases
- [ ] Admin dashboard
- [ ] Content moderation
- [ ] Analytics dashboard

### Platform
- [ ] Android app
- [ ] Web app (beyond API)
- [ ] Push notifications
- [ ] Offline mode
- [ ] Localization (i18n)

### Auth Extensions
- [ ] Google OAuth
- [ ] Apple Sign In
- [ ] Phone number auth
- [ ] 2FA

---

## Decision Framework

When considering a new feature, ask:

1. **Does it directly serve the core promise?**
   > "Generate a synergy-aware staged build plan, save builds, chat with mechanic"

2. **Can MVP ship without it?**
   > If yes, it's not MVP

3. **Does it add complexity without proportional value?**
   > If yes, defer it

4. **Is the user explicitly asking for it or are we assuming?**
   > Build for known needs first

---

## Post-MVP Candidates

Features to consider after successful MVP launch:

1. Build sharing (public links)
2. More auth providers
3. Build export to PDF
4. Push notifications for usage warnings
5. Stripe billing integration
6. Web dashboard
7. Build comparison tool

---

*Last updated: MVP v1 spec*
