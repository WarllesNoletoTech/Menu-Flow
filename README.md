# Menu Flow

Plataforma SaaS de cardápio digital multi-tenant para restaurantes. O monorepo separa uma vitrine **Next.js/PWA** (`Menu-Flow-frontend`) de uma API **NestJS + MongoDB/Mongoose** (`Menu-Flow-backend`). Os nomes dessas pastas são mantidos intencionalmente.

## Decisões de arquitetura e riscos tratados

- **Mongoose, não TypeORM:** o catálogo possui estruturas variáveis (grupos de adicionais e snapshots do pedido), que se encaixam naturalmente em documentos MongoDB.
- **Isolamento por tenant:** todo documento pertencente a uma loja possui `restaurantId`; queries administrativas recebem o tenant do JWT e o `TenantGuard` rejeita uma URL de outra loja. O navegador nunca é a autoridade para trocar de restaurante.
- **Pedidos imutáveis:** preço, nome e adicionais são gravados como snapshot no pedido. No checkout a API ignora qualquer preço vindo do cliente, busca os produtos do restaurante e recalcula subtotal e entrega.
- **Domínio público separado:** cardápio usa o `slug` apenas para resolver a loja. Escritas de gestão exigem JWT e papel apropriado.
- **Tempo real extensível:** `OrdersGateway` publica eventos por sala `restaurant:<id>`. A autenticação/entrada de sockets do painel deve sempre validar o JWT antes de permitir a associação à sala.
- **Rappidex:** `backend/src/integrations/delivery-provider.ts` é somente o contrato para uma integração futura; não há simulação de entrega.

> Antes de produção, configure backup/retention no Atlas, restrinja `FRONTEND_URL`, faça upload de mídia com armazenamento externo e acrescente auditoria, testes de integração e paginação nas listagens administrativas.

## Estrutura

```text
Menu-Flow-frontend/     Next.js, TypeScript, Tailwind e manifest PWA
Menu-Flow-backend/      NestJS, REST, JWT, guards, Mongoose e WebSocket
```

Os modelos Mongoose contemplam `User`, `Restaurant`, `Category`, `Product`, `AddonGroup`, `Addon`, `Order`, `OrderItem`, `Customer`, endereço embutido, `Coupon`, `DeliveryZone`, `Payment` e `RestaurantSettings`.

## Configuração local

1. Tenha Node.js 20+ e uma instância MongoDB (local ou Atlas).
2. Copie o exemplo: `cp .env.example Menu-Flow-backend/.env` e configure `MONGODB_URI` e um `JWT_SECRET` longo e aleatório.
3. Crie `Menu-Flow-frontend/.env.local` com `NEXT_PUBLIC_API_URL=http://localhost:3001`.
4. Instale dependências na raiz: `npm install`.
5. Execute a API: `npm run dev:api`.
6. Em outro terminal, execute a vitrine: `npm run dev`.
7. Abra `http://localhost:3000`. Na página inicial, informe o código da loja; o cardápio também pode ser acessado diretamente em `http://localhost:3000/<slug-do-restaurante>`.

A API atende em `http://localhost:3001`; o Swagger fica em `/api`.

## Primeiro acesso e desenvolvimento

1. Faça uma única chamada `POST /auth/bootstrap` com `{ "name", "email", "password" }` para criar o `SUPER_ADMIN` inicial.
2. Autentique por `POST /auth/login` e envie `Authorization: Bearer <token>`.
3. Crie uma loja por `POST /restaurants` com `{ "name", "slug", "description" }`.
4. Crie usuários de loja com `restaurantId` e o papel `RESTAURANT_ADMIN` ou `EMPLOYEE` através do módulo de usuários (o papel `SUPER_ADMIN` não deve ser usado no dia a dia).
5. Cadastre categorias, produtos, zonas de entrega e formas de pagamento usando os endpoints protegidos daquele `restaurantId`.

## Verificação

```bash
npm run build
npm run lint
npm run typecheck
```

## Deploy

- Faça deploy de `frontend` na Vercel e informe `NEXT_PUBLIC_API_URL`.
- Faça deploy de `backend` no Railway/Heroku com `MONGODB_URI`, `JWT_SECRET`, `FRONTEND_URL` e `PORT`. No Heroku, conecte o repositório pela raiz deste monorepo: o `package.json` raiz, o `Procfile` e o `app.json` selecionam o buildpack Node.js, compilam somente a API e iniciam `@menu-flow/backend`. Se configurar `Menu-Flow-backend` como diretório raiz do deploy, use o `package.json` e o `Procfile` existentes nessa pasta.
- Use MongoDB Atlas com usuário de menor privilégio e whitelist de rede apropriada.

## Fluxos já implementados

- Checkout público recalcula preços no servidor, recusa produtos de outro tenant, loja bloqueada/fechada, pedido abaixo do mínimo e bairros sem zona de entrega.
- Cupons válidos aplicam desconto no servidor; o pedido persiste somente o valor calculado.
- Administradores podem criar e atualizar categorias e produtos no restaurante do token. Produtos suportam grupos de adicionais e regras mínimas/máximas, validadas no checkout pelo backend. Funcionários podem consultar pedidos e avançar o status conforme o fluxo permitido.
- A criação de usuários exige uma associação válida entre o papel e uma loja existente; administradores da loja não podem alterar o bloqueio da plataforma.
- Eventos `order.created` e `order.updated` usam salas Socket.IO por restaurante. O painel deve conectar com `auth: { token }` e `query: { restaurantId }`; o gateway valida ambos antes de ingressar na sala.
