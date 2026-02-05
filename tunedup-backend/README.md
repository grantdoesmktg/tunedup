# TunedUp Backend

Next.js API backend for TunedUp - AI-powered car modification build planner.

## Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Database:** PostgreSQL via Prisma
- **AI:** Google Gemini (3 Pro for pipeline, 2.5 Flash for chat)
- **Email:** Resend
- **Hosting:** Vercel

## Quick Start

```bash
# Install dependencies
pnpm install

# Start local Postgres
pnpm docker:up

# Setup environment
cp .env.example .env.local
# Edit .env.local with your keys

# Initialize database
pnpm db:generate
pnpm db:push

# Start dev server
pnpm dev
```

See [docs/LOCAL_DEV.md](docs/LOCAL_DEV.md) for detailed setup instructions.

## API Endpoints

### Authentication
- `POST /api/auth/request-link` - Send 6-digit email code
- `POST /api/auth/verify` - Exchange token for session

### PIN
- `POST /api/pin/set` - Set 4-digit PIN
- `POST /api/pin/verify` - Verify PIN

### Builds
- `GET /api/builds` - List user's builds
- `POST /api/builds` - Create new build (SSE streaming)
- `GET /api/builds/:id` - Get build details
- `DELETE /api/builds/:id` - Delete build

### Chat
- `POST /api/chat` - Send message to mechanic AI

### Usage
- `GET /api/usage` - Get token usage status

## Project Structure

```
src/
├── app/api/          # API routes
├── lib/              # Shared utilities
│   ├── prisma.ts     # Database client
│   ├── auth.ts       # Authentication
│   ├── gemini.ts     # AI client
│   ├── usage.ts      # Token tracking
│   └── validation.ts # Request validation
├── services/
│   ├── build-pipeline/  # 7-step AI pipeline
│   └── chat.ts          # Chat service
├── types/            # TypeScript types
└── prompts/          # Prompt templates
```

## AI Pipeline

Build generation runs through 7 chained steps:

1. **Normalize** - Parse input, infer missing data
2. **Strategy** - Determine build archetype, guardrails
3. **Synergy** - Plan stages with mod dependencies
4. **Execution** - DIY vs shop, tools, difficulty
5. **Performance** - Before/after estimates
6. **Sourcing** - Brands, search queries
7. **Tone** - Mechanic personality pass

## Documentation

- [LOCAL_DEV.md](docs/LOCAL_DEV.md) - Development setup
- [MVP_BOUNDARY.md](docs/MVP_BOUNDARY.md) - Scope definition
- [DECISIONS.md](docs/DECISIONS.md) - Architecture decisions

## Scripts

```bash
pnpm dev          # Start dev server
pnpm build        # Production build
pnpm start        # Start production server
pnpm lint         # Run linter
pnpm typecheck    # Type checking

pnpm docker:up    # Start local Postgres
pnpm docker:down  # Stop local Postgres

pnpm db:generate  # Generate Prisma client
pnpm db:push      # Push schema (dev)
pnpm db:migrate   # Run migrations
pnpm db:studio    # Open Prisma Studio
```

## Environment Variables

See [.env.example](.env.example) for required variables.

## License

Proprietary - All rights reserved
