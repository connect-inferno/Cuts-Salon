# Cuts-Salon — Salon SaaS

Multi-tenant salon management SaaS. One shared backend/database serves multiple independent salons (currently piloting with 5-6). Read this before making backend changes — it applies to any AI agent working in this repo, not just this session.

## Project shape

- `backend/` — Node.js + Express + TypeScript API, Prisma ORM, PostgreSQL (hosted on Supabase), deployed to Render.
- `mobile/` — Flutter app (salon staff/owner client), deployed to Vercel as a web build.
- `render.yaml` — Render Blueprint (build/start commands, env var declarations).

## Hard rule: the backend must stay swappable

Treat the ORM (Prisma), the database (Postgres/Supabase), and the hosting provider (Render) as replaceable implementation details — never let business logic depend on them directly. Every backend change follows this layering:

```
routes/*.routes.ts          -> wires HTTP verb+path to a controller, plus auth middleware. No logic.
controllers/*.controller.ts -> parses/validates the request (zod), calls a service, shapes the HTTP response.
services/*.service.ts       -> ALL business logic and ALL data access lives here.
utils/prisma.ts, utils/scopedPrisma.ts -> the ONLY files allowed to construct/import PrismaClient directly.
```

Rules that must hold for every new endpoint:

- **Controllers and routes never import `@prisma/client` or `utils/prisma`/`utils/scopedPrisma` directly.** If a controller needs data, it calls a service method. This means swapping Prisma for a different ORM/driver, or swapping Postgres for a different database, should only ever touch `utils/prisma.ts`, `utils/scopedPrisma.ts`, and the `services/` layer — routes and controllers should need zero changes.
- **All Prisma access goes through `services/`.** No raw queries in controllers, ever.
- **Tenant scoping is itself part of this abstraction.** Any query against a salon-owned table goes through `getScopedPrisma(salonId)` (`backend/src/utils/scopedPrisma.ts`) — never the raw `prisma` singleton, and never a hand-written `where: { salonId }`. This is a security boundary (prevents cross-tenant data leaks) and it's also the seam to modify first if the tenancy strategy ever changes (e.g. row-level -> schema-per-tenant).
- **Money/commission/tax calculation logic lives in the relevant service**, not in controllers.
- Prisma's `Decimal` fields are safe to do plain-number math on for now (rounded to 2dp via a `round2` helper) — fine at current scale, revisit if precision issues ever show up.

## Multi-tenancy model

- `Salon` is the tenant root (`backend/prisma/schema.prisma`). Every salon-owned model carries a `salonId` column with per-salon-scoped unique constraints (e.g. customer phone is unique per salon, not globally).
- `User.email` is the one deliberately global-unique field — this lets login resolve `salonId` from the email alone, so staff don't need to pick a salon before logging in.
- Login (`POST /api/v1/auth/login`) returns a JWT containing `salonId`; the `authenticate` middleware (`backend/src/middleware/auth.middleware.ts`) attaches it to `req.user.salonId` on every authenticated request.
- New salons are created via the onboarding endpoint (`POST /api/v1/onboarding/salons`, gated by the `ONBOARDING_SECRET` header) or the internal admin page at `/admin.html`, served statically from the backend (`backend/public/admin.html`). Not for salon staff — internal tool only.

## Adding a new backend endpoint — checklist

1. Extend `backend/prisma/schema.prisma` if needed, generate + apply a migration (`npx prisma migrate dev --name <name>`), commit the generated `prisma/migrations/` folder.
2. Write the service method(s) in `services/` — salonId scoping and business logic happens here, via `getScopedPrisma(salonId)`.
3. Write the controller in `controllers/` — zod validation, calls the service, maps thrown errors to HTTP status codes.
4. Write the route in `routes/` — path + HTTP verb + `authenticate` (+ `requireRole(['OWNER'])` if owner-only) + controller method. Wire it into `app.ts`.
5. Run `npx tsc --noEmit` before considering the change done — Prisma's client extension (`getScopedPrisma`) injects `salonId` at runtime but TypeScript doesn't know that, so `salonId` must still be passed explicitly in every `create()` call's `data`.

## Deployment

- Backend: Render free tier, service `cuts-salon-backend`, auto-deploys from `main` via the Blueprint in `render.yaml`. Build command runs `prisma migrate deploy`, so pushed migrations apply automatically on deploy.
- Database: Supabase Postgres, **session pooler** connection (not the direct connection — Render's network doesn't support Supabase's IPv6-only direct connection without a paid add-on).
- Keep-alive: cron-job.org pings `/health` every 14 minutes so the Render free instance doesn't spin down (repo is private, so this intentionally isn't a GitHub Actions workflow — would burn paid Actions minutes).
- Required env vars on Render: `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `ONBOARDING_SECRET`, `NODE_VERSION`.
