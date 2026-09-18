# Caixa operacional — Menu Flow

A aba **Operação > Caixa** agora inclui controle de turno de caixa.

## Fluxo
1. Abrir caixa com fundo inicial.
2. Recebimentos de mesas entram automaticamente como vendas do turno.
3. Registrar suprimento quando entrar dinheiro adicional para troco.
4. Registrar sangria quando retirar dinheiro da gaveta.
5. Conferir o dinheiro físico esperado e informar o valor contado.
6. Fechar caixa e consultar/imprimir o fechamento.

## Resumo
- Fundo inicial
- Suprimentos
- Sangrias
- Vendas em dinheiro
- PIX
- Crédito
- Débito
- Total de vendas
- Dinheiro esperado na gaveta
- Dinheiro declarado no fechamento
- Diferença/sobra/falta

## Impressão
O resumo do caixa e cada operação manual podem ser enviados ao **Menu Flow Printer** (impressora do caixa). Se o Printer estiver offline, o frontend usa a impressão do navegador como fallback.

## Regra de recebimento
Para registrar novos pagamentos de mesa, o caixa precisa estar aberto. Isso evita vendas fora de turno e mantém a conferência consistente.
