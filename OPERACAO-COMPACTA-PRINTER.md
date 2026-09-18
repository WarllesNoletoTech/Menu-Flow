# Operação compacta + Menu Flow Printer 1.1

## O que mudou

- Pedido de mesa enviado pelo garçom entra direto em `PREPARING` e é enfileirado automaticamente para impressão.
- Categoria do cardápio possui `productionSector`: `KITCHEN`, `BAR` ou `NONE`.
- Pedidos mistos geram uma comanda de COZINHA e outra de BAR.
- O Menu Flow Printer pode usar a mesma impressora física para COZINHA + BAR ou impressoras diferentes.
- A produção finaliza os setores separadamente. O pedido só fica `READY` quando todos os setores usados estiverem prontos.
- A tela Operação usa paginação para Mesas, Produção, Caixa e produtos do cardápio, reduzindo a necessidade de rolagem.
- O caixa possui fechamento integral rápido com Pix, Dinheiro, Débito ou Crédito.
- Em dinheiro, o caixa pode informar o valor recebido e visualizar o troco.
- Pagamentos parciais, desconto, transferência, junção de mesas e histórico continuam em opções secundárias.
- A URL do backend no agente Windows é normalizada; barra `/` no final não interfere na conexão.

## Compatibilidade com cardápios existentes

Categorias antigas sem `productionSector` continuam funcionando. Nomes típicos de bebidas (Bebidas, Refrigerantes, Sucos, Cervejas, Drinks etc.) são inferidos como BAR na criação de pedidos. O lojista pode confirmar ou alterar o setor na tela de categorias.

## Deploy recomendado

1. Publicar o backend.
2. Publicar o frontend.
3. Atualizar o Menu Flow Printer nos computadores dos restaurantes que usarão BAR.
4. No cardápio, revisar o setor de cada categoria.
5. Em Operação > Printer, confirmar que `Imprimir pedidos automaticamente` está ligado.

## Smoke test

1. Abra uma mesa com um garçom.
2. Faça um pedido com pelo menos um item de Cozinha e um item de Bar.
3. Confirme que o pedido entra direto em Produção sem etapa de aceite.
4. Confirme duas comandas: COZINHA e BAR. Com impressora compartilhada, ambas devem sair na mesma impressora.
5. Marque somente BAR como pronto: o pedido deve continuar em preparo para Cozinha.
6. Marque Cozinha como pronta: o pedido passa para Pronto e o garçom pode marcar Entregue na mesa.
7. Garçom solicita conta; ela deve aparecer automaticamente no Caixa.
8. Teste `Receber e fechar` com Pix e depois, em outra mesa, Dinheiro com troco.
9. Confirme que a mesa volta para Livre após o fechamento.
