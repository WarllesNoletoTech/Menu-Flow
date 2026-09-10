# Revisão técnica e migrações planejadas

## Estado atual e correções desta fase

O catálogo administrativo agora possui uma única fonte de verdade no `CatalogManager`. Cada carregamento recebe uma sequência monotônica; uma mutação invalida todas as leituras anteriores e, depois da resposta confirmada da API, atualiza o estado e executa nova leitura. Assim, um GET iniciado antes de um POST não pode apagar a entidade recém-criada.

Categorias e produtos usam arquivamento lógico (`archivedAt`). Uma categoria com produtos não arquivados é rejeitada com conflito; não há remoção destrutiva. Consultas públicas e administrativas ignoram registros arquivados.

A disponibilidade usa a regra única `canAcceptOrdersNow`: empresa não bloqueada, recebimento manual habilitado e horário configurado/aberto no timezone da empresa. Horário não configurado é fechado por segurança. O campo legado `Restaurant.open` é mantido no banco para compatibilidade, mas sua semântica na interface é “Receber pedidos”; uma migração futura pode renomeá-lo fisicamente.

Entrega e pagamentos são configurações por tenant. O checkout só oferece entrega com região ativa e só aceita um método de pagamento ativo no backend.

## Migração monetária segura (próxima fase)

Os campos monetários legados ainda são decimais e não devem ser renomeados de uma vez. A migração recomendada é aditiva:

1. adicionar campos inteiros em centavos (`priceCents`, `promotionalPriceCents`, `feeCents`, `minimumOrderCents`, `valueCents`, `unitPriceCents`, `subtotalCents`, `deliveryFeeCents`, `discountCents`, `totalCents` e `totalSpentCents`);
2. executar backfill idempotente com `Math.round(valorLegado * 100)`, registrando divergências;
3. durante uma versão, fazer dual-read (centavos primeiro, legado como fallback) e dual-write;
4. validar contagens e totais, trocar todos os cálculos para inteiros e somente depois interromper a escrita legada;
5. remover campos antigos apenas em uma migration futura, com backup e rollback documentados.

Nenhuma migration destrutiva ou reset de dados faz parte desta alteração.

## Produção

O endpoint de bootstrap é bloqueado em produção; use `npm run create-super-admin`. O rate limiter global e limites específicos de autenticação estão ativos. WebSockets revalidam o usuário persistido a cada conexão. Uma futura migração do JWT deve preferir cookie `HttpOnly`, `Secure` e `SameSite`, acompanhada de proteção CSRF. Hosts de imagens devem ser informados em `IMAGE_HOSTS` e apontar apenas para o serviço oficial de upload/CDN.
