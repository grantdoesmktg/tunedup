# Local Development Setup

## Prerequisites

- Node.js 18+
- Docker Desktop
- pnpm (recommended) or npm

## Quick Start

### 1. Clone and Install

```bash
cd tunedup-backend
pnpm install
```

### 2. Environment Setup

```bash
cp .env.example .env.local
```

Edit `.env.local` and set:
- Keep DATABASE_URL pointing to local Docker (uncomment the local lines, comment Neon lines)
- Add your RESEND_API_KEY (get from resend.com)
- Add your GEMINI_API_KEY (get from Google AI Studio)
- Generate secrets: `openssl rand -hex 32`

### 3. Start Local Database

```bash
pnpm docker:up
```

This starts a PostgreSQL 16 container on port 5432.

### 4. Initialize Database

```bash
pnpm db:generate   # Generate Prisma client
pnpm db:push       # Push schema to database
```

### 5. Start Dev Server

```bash
pnpm dev
```

Server runs at http://localhost:3000

## Database Commands

```bash
pnpm docker:up      # Start Postgres container
pnpm docker:down    # Stop Postgres container
pnpm db:generate    # Regenerate Prisma client after schema changes
pnpm db:push        # Push schema changes (dev only, no migration)
pnpm db:migrate     # Create and apply migration (for production)
pnpm db:studio      # Open Prisma Studio GUI
```

## Testing API Endpoints

### Request Email Code

```bash
curl -X POST http://localhost:3000/api/auth/request-link \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'
```

### Create Build (with SSE)

```bash
curl -X POST http://localhost:3000/api/builds \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SESSION_TOKEN" \
  -H "Accept: text/event-stream" \
  -d '{
    "vehicle": {
      "year": 2020,
      "make": "Honda",
      "model": "Civic",
      "trim": "Si",
      "transmission": "manual"
    },
    "intent": {
      "budget": 5000,
      "goals": { "power": 4, "handling": 3, "reliability": 4 },
      "dailyDriver": true,
      "emissionsSensitive": false,
      "existingMods": "none"
    }
  }'
```

## Switching to Neon (Production Database)

1. Create a Neon project at neon.tech
2. Get the pooled and direct connection strings
3. Update `.env.local`:

```bash
DATABASE_URL="postgresql://...?sslmode=require&pgbouncer=true"
DATABASE_URL_DIRECT="postgresql://...?sslmode=require"
```

4. Run migrations: `pnpm db:migrate:prod`

## Troubleshooting

### Prisma Client Issues
```bash
pnpm db:generate
```

### Port 5432 Already in Use
```bash
pnpm docker:down
# or kill other Postgres processes
lsof -i :5432
```

### Connection Pool Exhaustion
The Prisma singleton in `src/lib/prisma.ts` prevents this in dev. In production, the pooled Neon connection handles it.
