# Cobrança do Menu Flow por faturamento

## Faixas padrão

- Até R$ 1.000,00 de faturamento elegível: R$ 49,90
- De R$ 1.000,01 até R$ 3.500,00: R$ 69,90
- Acima de R$ 3.500,00: R$ 129,90

## Base de cálculo

A faixa mensal considera somente:

- pedidos de entrega/retirada concluídos;
- comandas de mesa fechadas;
- valor dos produtos menos descontos.

Não entram na faixa:

- taxa de entrega;
- taxa de serviço do garçom;
- pedidos cancelados ou recusados;
- pedidos ainda em andamento.

## Ciclo

A cobrança é gerada para um mês de referência fechado. O vencimento padrão é a primeira terça-feira do mês seguinte.

Ao gerar a primeira cobrança no modelo novo, estabelecimentos ativos sem plano por faturamento recebem automaticamente o plano padrão. Estabelecimentos criados depois do período de referência não são cobrados naquele mês.

## Histórico

Cada fatura congela:

- faturamento considerado;
- faixa aplicada;
- valor da mensalidade;
- período;
- vencimento;
- modelo de cálculo.

Alterações futuras nas faixas não modificam faturas já emitidas.

## Áreas do sistema

### Administrador

`Cobranças` mostra as mensalidades, geração mensal, valores pendentes/vencidos e ações para marcar como pago, isentar ou cancelar.

`Cobranças > Planos` permite editar as faixas por faturamento.

### Lojista

`Assinatura` mostra a estimativa do mês atual, faixa vigente, quanto falta para a próxima faixa, histórico e dados PIX quando houver cobrança pendente.
