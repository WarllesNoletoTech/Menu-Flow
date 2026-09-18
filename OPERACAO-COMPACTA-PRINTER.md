# Operação de salão + Menu Flow Printer 1.1

## Fluxo de produção

- Pedido de mesa enviado pelo garçom entra direto em `PREPARING`, sem etapa de aceite.
- A impressão automática acontece assim que o garçom envia o pedido, quando o Menu Flow Printer estiver habilitado.
- Cada **categoria que já existe no cardápio da loja** pode receber apenas um destino de impressão: `KITCHEN`, `BAR` ou `NONE`.
- O sistema **não cria categorias de Cozinha ou Bar** no cardápio.
- Pedidos mistos podem gerar uma comanda de COZINHA e outra de BAR.
- O Menu Flow Printer pode usar a mesma impressora física para COZINHA + BAR ou impressoras diferentes.
- O pedido só fica `READY` quando todos os setores usados no pedido forem finalizados.

## Cardápio

Na administração das categorias reais do cardápio existe o campo **Destino da impressão**:

- Cozinha
- Bar
- Não imprimir

Categorias novas não são classificadas automaticamente por nome. O padrão é Cozinha até o lojista alterar o destino.

Na tela do garçom aparecem somente categorias reais que possuem produtos disponíveis. O garçom não vê categorias artificiais de Cozinha/Bar.

## Caixa

O caixa mantém as funcionalidades completas:

- resumo da conta;
- subtotal, taxa de serviço, desconto, total, valor pago e saldo;
- imprimir pré-conta;
- pagamento parcial;
- dividir por quantidade de pessoas;
- cobrar um pedido específico;
- Pix, dinheiro, débito e crédito;
- observação de pagamento;
- aplicar desconto;
- histórico de pagamentos;
- fechar a mesa quando o saldo chegar a zero.

A fila do caixa continua paginada para evitar uma página longa, mas ao abrir uma conta todas as funções ficam reunidas na mesma janela.

## Janelas e navegação

O editor de produto/adicionais não abre mais um modal por cima da comanda. Ele usa a mesma janela da mesa:

- `Voltar para a comanda` retorna para o pedido;
- o botão `X` fecha a operação inteira de uma vez.

Isso evita fechar uma janela e descobrir outra janela aberta por baixo.

## Deploy recomendado

1. Publicar o backend.
2. Publicar o frontend.
3. Atualizar o Menu Flow Printer nos computadores que usarão BAR.
4. Revisar o **Destino da impressão** das categorias reais no cardápio.
5. Em Operação > Printer, confirmar que a impressão automática de pedidos está habilitada.
