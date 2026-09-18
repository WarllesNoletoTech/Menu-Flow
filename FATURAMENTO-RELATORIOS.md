# Faturamento e Relatórios — Menu Flow

## Taxa por pedido do Menu Flow
- Desativada para novos pedidos (`MENU_FLOW_ORDER_SERVICE_FEE_CENTS = 0`).
- O campo histórico continua no banco para preservar pedidos antigos.
- Novos relatórios de cobrança da plataforma consideram somente mensalidade, quando utilizada.

## Aba Faturamento
A página `/empresa/faturamento` agora concentra:
- Visão geral
- Produtos e categorias
- Formas de pagamento
- Garçons e taxa de serviço
- Caixa
- Cancelamentos/recusas

## Relatório de garçom
A taxa de serviço usa a comanda/mesa fechada e o garçom responsável no fechamento.
É possível visualizar todos os garçons ou um funcionário individual.

## Pagamentos
Pagamentos mistos das mesas são separados por forma (PIX, dinheiro, crédito e débito).
Entrega/retirada usam a forma de pagamento do pedido.

## Caixa
O relatório usa os movimentos reais do caixa operacional:
- abertura
- vendas
- suprimentos
- sangrias
- diferenças dos fechamentos

## Exportações
- Impressão pelo navegador
- PDF completo no backend
- CSV em UTF-8 com BOM e separador `;`, adequado ao Excel em pt-BR
