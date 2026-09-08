# Menu Flow

Multi-tenant digital-menu SaaS. The repository separates a **Next.js PWA-ready storefront** from a **NestJS/MongoDB API**. Every restaurant-owned document has a `restaurantId`, and API access is scoped from the authenticated user's tenant rather than from a client-supplied value.

## Architecture decisions

- **MongoDB + Mongoose** fits flexible restaurant/menu documents and embeds immutable product snapshots in orders.
- **Tenant isolation** is enforced by `TenantGuard`, role guards, and service queries that always add `restaurantId`.
- **Public data** is resolved by a restaurant slug; private management endpoints derive the tenant from the JWT.
- The `DeliveryProvider` abstraction is the Rappidex seam. It deliberately has no fake integration.

## Setup

1. Copy `.env.example` to `backend/.env` and `frontend/.env.local` (put `NEXT_PUBLIC_API_URL` in the latter).
2. Create a MongoDB Atlas database and put its connection string in `MONGODB_URI`.
3. Install dependencies: `npm install`.
4. Start the API: `npm run dev:api`.
5. Start the storefront: `npm run dev`.
6. Open `http://localhost:3000/<restaurant-slug>`.

## First administrator and restaurant

Use `POST /auth/bootstrap` once while no users exist. It accepts an email, password, name and creates the first `SUPER_ADMIN`. Then use `POST /restaurants` with that admin's bearer token. Create restaurant administrators through the users module (the foundational schema and role system is included; an operator UI is the next delivery phase).

## Development notes

- API docs are available at `/api` while the API is running.
- Restaurant managers use JWTs containing `restaurantId` and `role`. Never trust a `restaurantId` sent by the browser for protected writes.
- The public menu is mobile-first and its checkout currently sends an order to the real API. Configure delivery zones and products through protected API endpoints.
- Deployment targets: deploy `frontend` to Vercel, `backend` to Railway/Heroku, and use MongoDB Atlas in production. Set each service's environment variables in its host dashboard.
