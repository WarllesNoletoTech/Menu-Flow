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

A cobrança é gerada automaticamente no dia 1º para o mês de referência anterior. O vencimento padrão é o dia 5 do mês da cobrança, podendo ser configurado.

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

## Ciclo automático mensal

- O mês atual fica pré-selecionado no painel administrativo de cobranças.
- No dia 1 de cada mês, o backend gera automaticamente as mensalidades de todos os estabelecimentos ativos usando o faturamento elegível do mês anterior.
- Se o backend estiver reiniciando no dia 1, a geração é idempotente: a chave única por estabelecimento + período evita duplicação.
- Ao iniciar depois do dia 1, o serviço faz uma checagem de recuperação e garante a cobrança do mês anterior caso ainda não exista.
- O vencimento padrão é dia 5 do mês da cobrança, podendo ser alterado por plano/estabelecimento.
- O lojista visualiza a cobrança em Assinatura e pode baixar o PDF oficial com identidade visual do Menu Flow, faturamento considerado, faixa, mensalidade, vencimento, status e PIX.
