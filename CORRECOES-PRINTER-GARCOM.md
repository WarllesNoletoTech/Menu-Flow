# Correções Printer + App do Garçom

## Impressão automática
- Corrigido o tratamento de configurações antigas sem `printerAutoKitchen` persistido: campo ausente agora assume **ativado**, igual à interface.
- Pedido lançado pelo garçom agora enfileira a impressão de forma aguardada pelo backend antes de responder, reduzindo perda de trabalhos assíncronos.
- Cozinha e Bar possuem automações independentes.
- O menu Printer permite escolher impressão automática para:
  - pedidos da cozinha;
  - pedidos do bar;
  - pré-conta ao solicitar conta;
  - abertura do caixa;
  - suprimento;
  - sangria;
  - fechamento do caixa.
- A tela do Printer exibe os trabalhos recentes com status: Na fila, Imprimindo, Impresso e Erro.

## App do garçom / mesas
- Mesa sem consumo não exibe a aba Conta nem o botão Solicitar conta.
- Backend também bloqueia solicitação de conta sem pedido válido.
- Após existir consumo, a ação de fechamento aparece próxima ao resumo da mesa com o valor atual.
- Depois de solicitar a conta, a interface informa que novos itens estão bloqueados e que a conta foi enviada ao caixa.
