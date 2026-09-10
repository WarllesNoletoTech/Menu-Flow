# Auditoria de integração (2026-09-10)

## Matriz de contratos

| Domínio | Collection/model e campos | Escrita | Leitura e formato | Consumidor/state | Cache, legado e identidade |
| --- | --- | --- | --- | --- | --- |
| Empresa | `Restaurant`: `open`, identidade, mídia, `mapUrl`, timezone; `RestaurantSettings`: vínculo único | `PATCH /restaurants/me`, `PATCH /restaurants/:id` | `GET /restaurants/me`, público por slug e listagem pública | `EmpresaContext`, home, `Menu` | administrativo e público usam `no-store`; vínculo deve ser `ObjectId` |
| Entrega | `RestaurantSettings.deliveryEnabled`; `DeliveryZone`: `restaurantId`, `name`, `active`, `fee/feeCents` | `PATCH /restaurants/me/settings`; `POST /restaurants/me/delivery-zones` (cria/edita) | `GET /restaurants/me/operations`; `GET /restaurants/:slug` retorna `deliveryEnabled`, `deliveryAvailable`, zonas ativas e motivo | configurações e `CheckoutModal` | causa de incompatibilidade legacy: string não casa com `ObjectId`; migration converte sem tratar “todos” como wildcard |
| Pagamentos | `Payment`: tenant, enum, nome, ativo | `PATCH /restaurants/me/payment-methods` | operações traz todos; público traz ativos | configurações e checkout | índice tenant+método; labels PT-BR centralizados |
| Horários | `RestaurantSettings.openingHours`; `Restaurant.timezone/open` | `PATCH .../business-hours` | GET privado e resposta pública com disponibilidade calculada | editor, home, menu e aceite do pedido | `no-store`; rotina existente recupera vínculo string legado |
| Cardápio | `Category`, `Product`, adicionais e centavos | endpoints de gestão por tenant | menu público filtra categoria/produto ativo e não arquivado | `CatalogManager`, `Menu` | refetch sequenciado; `restaurantId/categoryId` como `ObjectId` |
| Pedidos | `Order`, snapshots, status, totais, `completedAt/completedBy` | `POST /restaurants/:restaurantId/orders`; `PATCH .../status`; cancelamento do cliente | lojista, cliente e tracking leem a mesma collection | painéis, meus pedidos e tracking | leituras sem cache; tenant/customer canônicos; eventos não são autoridade |
| Cliente | `User(CUSTOMER)`, endereços; `Order.customerId` | auth/endereço/checkout/cancelamento | `GET /customer/orders` | contexto de autenticação e páginas de cliente | `customerId` deve ser `ObjectId`; visitante continua permitido |
| Faturamento | `Order` para vendas; `BillingPlan/Invoice` para mensalidade | geração/status administrativo | `GET /billing/me` retorna `salesMetrics`, estimativa e histórico | página Faturamento | `no-store`; ausência de plano não afeta métricas de venda |
| Dashboard | mesma agregação de `Order` | não possui escrita própria | `GET /billing/me/dashboard` | dashboard da empresa | refetch inicial e após WebSocket; período diário no timezone da empresa |
| WebSocket | sem collection própria | `OrdersGateway` publica após persistência | `order.created`, `order.updated` por tenant e usuário | pedidos, dashboard, tracking e faturamento | evento dispara refetch; Mongo/API permanecem fonte de verdade |

## Falhas confirmadas no código anterior

1. `BillingService.estimateRestaurant` retornava `completedOrderCount: 0` antes de consultar pedidos quando não havia plano. A contagem agora precede a decisão de preço.
2. Consultas públicas de entrega eram canônicas (`ObjectId`), mas instalações antigas podem ter `restaurantId` BSON string. Nesse caso a configuração aparecia no fluxo que ainda recuperava legado, enquanto a consulta pública retornava `deliveryEnabled=false` e zero zonas. A escrita de settings agora converte o vínculo seguro e a migration cobre settings, zonas, pagamentos e pedidos.
3. Dashboard calculava “hoje” no timezone do navegador e faturamento tinha somente a contagem tarifável. Ambos agora usam a mesma agregação no backend e limites no timezone da empresa.
4. A tela de faturamento misturava venda e mensalidade. O contrato e a interface agora separam `salesMetrics` de `estimate/invoices`.

## Migração e operação

`npm run check:integration-contracts` é dry-run. Ele relata strings, órfãos, duplicidades e pedidos `COMPLETED` sem `completedAt`. `--apply` converte apenas IDs válidos que apontam para restaurante/usuário existente e preenche `completedAt` apenas de `updatedAt`, registrando `completedAtMigrationSource`. Ambiguidades não são alteradas. A execução é idempotente e não exclui documentos.

Sem `MONGODB_URI`, credenciais de produção, URL Heroku/Vercel ou remote Git disponíveis no ambiente de auditoria, não foi possível enumerar registros reais nem comparar SHA publicado. O código registra uma única conexão Mongoose global; portanto todos os módulos locais usam o mesmo database (`MESMO BANCO: SIM` por configuração). Isso não substitui executar o dry-run no dyno de produção.
