# Menu Flow Printer 1.1

Agente de impressão do Menu Flow para **Windows**, sem precisar instalar Node.js ou outro runtime externo.

## Instalação no restaurante

1. No Menu Flow, abra **Operação > Printer**.
2. Ative o Menu Flow Printer, mantenha **Imprimir pedidos automaticamente** ligado e gere uma chave.
3. No computador Windows do restaurante, execute **`Instalar Menu Flow Printer.bat`**.
4. Abra o **Menu Flow Printer** pelo atalho criado.
5. Cole a URL pública do backend e a chave. A URL funciona com ou sem `/` no final.
6. Escolha a impressora da cozinha/produção e a impressora do caixa.
7. Se o restaurante tiver **uma única impressora para cozinha e bar**, deixe marcada a opção **Usar a mesma impressora para cozinha e bar**.
8. Se houver uma impressora exclusiva no bar, desmarque essa opção e selecione a impressora do bar.
9. Use **Testar cozinha**, **Testar bar** e **Testar caixa** antes de iniciar a operação.

O programa fica minimizado na bandeja do Windows, inicia junto com o computador e continua consultando a fila automaticamente.

## Como a impressão funciona

- O garçom envia o pedido e ele entra direto em **Em preparo**; não existe etapa de aceitar pedido de mesa.
- O setor é definido no **cadastro da categoria do cardápio**: Cozinha, Bar ou Sem impressão.
- Um mesmo pedido com comida e bebida gera comandas independentes de **COZINHA** e **BAR**.
- Com uma única impressora, as duas comandas saem na mesma impressora, separadas e cortadas individualmente.
- Com duas impressoras, cada setor recebe somente os seus itens.
- Quando o garçom pede a conta, ela aparece na fila do caixa. A pré-conta pode ser impressa manualmente ou automaticamente, conforme a configuração do estabelecimento.

## Compatibilidade

O agente imprime em modo **RAW/ESC-POS** pelo spooler do Windows. É adequado para a maioria das impressoras térmicas compatíveis com ESC/POS, conforme driver e modelo. Impressoras sem guilhotina normalmente ignoram o comando de corte.

## Segurança

O computador do restaurante não precisa abrir porta na internet. O agente consulta o backend com uma chave exclusiva, reserva cada trabalho, imprime e confirma o resultado. No backend a chave é armazenada em hash.

Se o agente estiver offline, o Menu Flow mantém a fila e oferece impressão pelo navegador como alternativa manual. Trabalhos automáticos pendentes são descartados quando a etapa já avançou, evitando comandas atrasadas.
