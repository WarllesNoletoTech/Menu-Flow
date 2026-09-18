# Menu Flow Printer 1.3

Agente de impressão do Menu Flow para **Windows**, sem precisar instalar Node.js ou outro runtime externo.

## Instalação no restaurante

1. No Menu Flow, abra **Operação > Printer**.
2. Ative o Menu Flow Printer, mantenha **Imprimir pedidos automaticamente** ligado, escolha **58 mm** ou **80 mm** e gere uma chave.
3. No computador Windows do restaurante, execute **`Instalar Menu Flow Printer.bat`**.
4. Abra o **Menu Flow Printer** pelo atalho criado.
5. Cole a URL pública do backend e a chave. A URL funciona com ou sem `/` no final.
6. Escolha a impressora da cozinha/produção e a impressora do caixa.
7. Se o restaurante tiver **uma única impressora para cozinha e bar**, deixe marcada a opção **Usar a mesma impressora para cozinha e bar**.
8. Se houver uma impressora exclusiva no bar, desmarque essa opção e selecione a impressora do bar.

O programa fica minimizado na bandeja do Windows, inicia junto com o computador e continua consultando a fila automaticamente.

## Modo de teste sem impressora

Ative **Modo de teste - não usa impressora; salva prévias em arquivo**.

Nesse modo o agente:

- continua conectado à fila real do Menu Flow;
- recebe pedidos de cozinha, bar, pré-conta e operações de caixa;
- não envia nada para uma impressora física;
- salva cada trabalho em `Documentos\Menu Flow Printer\Testes`;
- gera `.txt` e `.html` com a largura correta de bobina;
- quando o Microsoft Edge está disponível, também gera `.pdf` automaticamente;
- confirma o trabalho no backend como processado, permitindo testar todo o fluxo operacional.

Use **Abrir pasta de testes** para acessar as prévias.

Os botões **Testar cozinha**, **Testar bar** e **Testar caixa** também respeitam o papel escolhido no modo local de teste.

## Layout do papel

O Menu Flow usa a largura configurada no estabelecimento:

- **58 mm:** 30 caracteres úteis por linha, com margem de segurança nas laterais.
- **80 mm:** 46 caracteres úteis por linha, com margem de segurança nas laterais.

Além da largura útil reduzida, o agente aplica uma pequena **margem física ESC/POS à esquerda**. Isso reduz o risco de nomes, observações e valores encostarem ou serem cortados nas bordas em impressoras com área imprimível menor que a bobina.

Pedidos, adicionais, observações, totais, taxa de serviço, caixa, suprimentos, sangrias e fechamento são quebrados e alinhados conforme a bobina escolhida.

O fallback de impressão pelo navegador também usa `@page` com a largura térmica selecionada.

## Como a impressão funciona

- O garçom envia o pedido e ele entra direto em **Em preparo**.
- O setor é definido no **cadastro da categoria do cardápio**: Cozinha, Bar ou Sem impressão.
- Um mesmo pedido com comida e bebida gera comandas independentes de **COZINHA** e **BAR**.
- Com uma única impressora, as duas comandas saem na mesma impressora, separadas e cortadas individualmente.
- Com duas impressoras, cada setor recebe somente os seus itens.
- Quando o garçom pede a conta, ela aparece na fila do caixa. A pré-conta pode ser impressa manualmente ou automaticamente.
- Abertura, suprimento, sangria, movimento e fechamento de caixa também podem ser impressos.

## Compatibilidade

O agente imprime em modo **RAW/ESC-POS** pelo spooler do Windows. É adequado para a maioria das impressoras térmicas compatíveis com ESC/POS, conforme driver e modelo. Impressoras sem guilhotina normalmente ignoram o comando de corte.

## Segurança

O computador do restaurante não precisa abrir porta na internet. O agente consulta o backend com uma chave exclusiva, reserva cada trabalho, imprime ou gera a prévia de teste e confirma o resultado. No backend a chave é armazenada em hash.
