# Integração Menu Flow ↔ Rappidex

## Fluxo

- Pedido **PICKUP / retirada**: permanece somente no Menu Flow.
- Pedido **DELIVERY / entrega**: o backend do Menu Flow tenta enviar para a Rappidex usando o ID do estabelecimento Menu Flow.
- A Rappidex só cria a entrega quando uma empresa Rappidex estiver com **Usar integração Menu Flow** ativado e com o mesmo **ID da empresa Menu Flow** configurado.
- A entrega criada pela integração nasce em **AGUARDANDO_LIBERACAO**.
- Liberar a entrega sem motoboy mantém o pedido Menu Flow no fluxo interno atual; quando o motoboy assumir a entrega e a Rappidex passar para **ACAMINHO**, o Menu Flow muda automaticamente para **OUT_FOR_DELIVERY / Saiu para entrega**.
- Todas as mudanças de status da Rappidex são guardadas em `rappidexStatus` e exibidas no card do pedido Menu Flow.
- Ao chegar em **FINALIZADO**, o Menu Flow conclui automaticamente o pedido.

## Configuração no Menu Flow

Configure no backend:

```env
RAPPIDEX_API_URL=https://SEU-BACKEND-RAPPIDEX
RAPPIDEX_INTEGRATION_SECRET=UM_SEGREDO_FORTE_E_IGUAL_NOS_DOIS_BACKENDS
```

No painel **Administração → Integrações**, copie o ID da empresa Menu Flow e use esse ID na empresa correspondente da Rappidex.

A ativação/desativação da integração não é feita no Menu Flow; ela é controlada na Rappidex, em **Empresas Cadastradas → Integração Menu Flow**.

## Segurança

A comunicação é backend-to-backend por `Authorization: Bearer <segredo>`. O segredo não deve ser colocado em variáveis públicas do frontend.

## iFood

A integração Menu Flow usa endpoints, campos e identificadores próprios. Ela não usa `ifoodOrderId`, `ifoodMerchantId`, Merchant ID, créditos ou webhooks do iFood.
