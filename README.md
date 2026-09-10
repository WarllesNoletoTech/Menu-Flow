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
7. Abra `http://localhost:3000` para entrar no sistema; o cardápio continua público em `http://localhost:3000/<slug-do-restaurante>`.

A API atende em `http://localhost:3001`; o Swagger fica em `/api`.

## Diagnóstico e migração de vínculos legados

Versões antigas podem ter persistido `User.restaurantId` como BSON `string`, embora o schema atual use BSON `ObjectId`. O MongoDB considera esses tipos diferentes em consultas, mesmo quando o texto hexadecimal é igual. Os comandos abaixo são manuais: não fazem parte do bootstrap nem do `heroku-postbuild`.

1. Gere o relatório de integridade, que lê a collection nativa (sem casting do Mongoose) e não exibe senhas:

   ```bash
   npm run check:legacy-links
   ```

2. Faça obrigatoriamente o dry run. Esse é o modo padrão e não grava no banco:

   ```bash
   npm run migrate:legacy-links -- --dry-run
   ```

3. Revise os usuários elegíveis, IDs, estabelecimentos inexistentes, valores inválidos e casos com mais de um lojista. Casos ambíguos nunca são alterados automaticamente. Só depois aplique:

   ```bash
   npm run migrate:legacy-links -- --apply
   ```

A migração seleciona apenas `RESTAURANT_ADMIN` e `EMPLOYEE` cujo tipo BSON real é `string`. Ela valida o hexadecimal, confirma `Restaurant._id`, e atualiza exclusivamente o tipo do campo para `ObjectId`, preservando o mesmo ID. Ela não cria nem exclui documentos e não altera nome, e-mail, senha, role, status ou pedidos.

Os horários possuem uma verificação separada para `RestaurantSettings`. O primeiro comando é sempre um dry run: ele lista IDs ausentes/inválidos, vínculos órfãos e duplicidades sem alterar dados. O modo `--apply` somente converte vínculos string seguros, inicializa campos ausentes e cria/confirma o índice único quando não há ambiguidades:

```bash
npm run migrate:business-hours --workspace @menu-flow/backend
# somente depois de revisar o relatório:
npm run migrate:business-hours --workspace @menu-flow/backend -- --apply
```

Se houver duplicidades ou documentos órfãos, a migração encerra sem excluir ou mesclar documentos; esses IDs devem ser revisados manualmente antes de uma nova execução.

Em produção, após publicar e antes de aplicar, abra um dyno one-off (substitua somente o nome da aplicação):

```bash
heroku run bash -a <APP>
```

Dentro do dyno, execute o JavaScript já compilado, nesta ordem:

```bash
node Menu-Flow-backend/dist/scripts/check-legacy-user-links.js
node Menu-Flow-backend/dist/scripts/migrate-legacy-restaurant-links.js --dry-run
node Menu-Flow-backend/dist/scripts/migrate-business-hours.js
# após revisar e aprovar o dry run:
node Menu-Flow-backend/dist/scripts/migrate-legacy-restaurant-links.js --apply
node Menu-Flow-backend/dist/scripts/migrate-business-hours.js --apply
```

Se o diretório raiz do app Heroku for `Menu-Flow-backend`, remova o prefixo `Menu-Flow-backend/` desses três caminhos. A aplicação não precisa receber nenhum segredo na linha de comando: o dyno usa `MONGODB_URI` já configurada no ambiente.

## Primeiro acesso e desenvolvimento

1. Faça uma única chamada `POST /auth/bootstrap` com `{ "name", "email", "password" }` para criar o `SUPER_ADMIN` inicial. Como alternativa somente em desenvolvimento, defina `ADMIN_SEED_ENABLED=true` e `ADMIN_NAME`, `ADMIN_EMAIL` e `ADMIN_PASSWORD`: o bootstrap automático é idempotente, não cria duplicatas e nunca roda com `NODE_ENV=production`.
2. Autentique por `POST /auth/login` e envie `Authorization: Bearer <token>`.
3. Crie uma loja por `POST /restaurants` com `{ "name", "slug", "description" }`.
4. Crie usuários de loja com `restaurantId` e o papel `RESTAURANT_ADMIN` ou `EMPLOYEE` através do módulo de usuários (o papel `SUPER_ADMIN` não deve ser usado no dia a dia).
5. Cadastre categorias, produtos, zonas de entrega e formas de pagamento usando os endpoints protegidos daquele `restaurantId`.

O login em `/` solicita e-mail e senha ao endpoint `POST /auth/login`, guarda apenas o JWT e os dados não sensíveis da sessão no `sessionStorage` (nenhuma senha é persistida) e direciona o papel retornado pela API para `/admin`, `/empresa` ou `/funcionario`. Essas páginas verificam o perfil no cliente para uma navegação adequada; a autorização efetiva e o isolamento entre restaurantes permanecem nos guards JWT, roles e tenant da API.

## Verificação

```bash
npm run build
npm run lint
npm run typecheck
```

## Deploy

- Faça deploy de `frontend` na Vercel e informe `NEXT_PUBLIC_API_URL`.
- Faça deploy de `backend` no Railway/Heroku com `MONGODB_URI` e `JWT_SECRET`; configure também `FRONTEND_URL` quando quiser restringir o CORS ao frontend publicado. No Heroku, **não** defina uma porta fixa: a plataforma fornece `PORT` automaticamente. No Heroku, conecte o repositório pela raiz deste monorepo: o `package.json` raiz, o `Procfile` e o `app.json` selecionam o buildpack Node.js, compilam somente a API e iniciam `@menu-flow/backend`. Se configurar `Menu-Flow-backend` como diretório raiz do deploy, use o `package.json` e o `Procfile` existentes nessa pasta.
- Use MongoDB Atlas com usuário de menor privilégio e whitelist de rede apropriada.

## Fluxos já implementados

- Checkout público recalcula preços no servidor, recusa produtos de outro tenant, loja bloqueada/fechada, pedido abaixo do mínimo e bairros sem zona de entrega.
- Cupons válidos aplicam desconto no servidor; o pedido persiste somente o valor calculado.
- Administradores podem criar e atualizar categorias e produtos no restaurante do token. Produtos suportam grupos de adicionais e regras mínimas/máximas, validadas no checkout pelo backend. Funcionários podem consultar pedidos e avançar o status conforme o fluxo permitido.
- A criação de usuários exige uma associação válida entre o papel e uma loja existente; administradores da loja não podem alterar o bloqueio da plataforma.
- Eventos `order.created` e `order.updated` usam salas Socket.IO por restaurante. O painel deve conectar com `auth: { token }` e `query: { restaurantId }`; o gateway valida ambos antes de ingressar na sala.

## Usuários e seed de desenvolvimento

A autenticação é centralizada em `POST /auth/login`: a API devolve o papel do usuário e a interface o direciona para `/admin`, `/empresa`, `/funcionario` ou `/cliente`. Clientes (`CUSTOMER`) não possuem `restaurantId`; pedidos podem ter `customerId` opcional, preservando o checkout visitante. A rota `/` é o login unificado, enquanto `/<slug>` permanece o cardápio público.

Para preparar dados de desenvolvimento/teste, com o MongoDB configurado:

```bash
npm install
npm run seed:test
```

O comando é idempotente e bloqueado quando `NODE_ENV=production`. Ele cria o restaurante `restaurante-teste`, itens básicos do cardápio, um pedido de exemplo e as contas abaixo:

| Papel | E-mail | Senha |
| --- | --- | --- |
| SUPER_ADMIN | admin.teste@menuflow.local | Admin@123456 |
| RESTAURANT_ADMIN | empresa.teste@menuflow.local | Empresa@123456 |
| EMPLOYEE | funcionario.teste@menuflow.local | Funcionario@123456 |
| CUSTOMER | cliente.teste@menuflow.local | Cliente@123456 |

**Essas credenciais são somente para desenvolvimento/testes. Não utilizar em produção.**
