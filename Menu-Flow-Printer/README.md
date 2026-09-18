# Menu Flow Printer

Agente de impressão do Menu Flow para **Windows**, sem precisar instalar Node.js ou outro runtime externo.

## Instalação no restaurante

1. No Menu Flow, entre em **Operação > Menu Flow Printer**.
2. Ative o recurso e clique em **Gerar nova chave**.
3. No computador Windows do restaurante, abra a pasta `Menu-Flow-Printer`.
4. Dê dois cliques em **`Instalar Menu Flow Printer.bat`**. Ele instala o agente e cria os atalhos automaticamente. Se o Windows pedir confirmação, aceite a execução do PowerShell.
5. Abra o **Menu Flow Printer** pelo atalho da Área de Trabalho.
6. Informe:
   - URL pública do backend do Menu Flow;
   - chave gerada no painel;
   - impressora da cozinha;
   - impressora do caixa.
7. Clique em **Salvar e conectar**.
8. Use **Testar cozinha** e **Testar caixa** antes de começar a operação.

O programa fica minimizado na bandeja do Windows e inicia automaticamente junto com o computador.

## Fluxo implementado

- Pedido criado pelo garçom entra diretamente em **Em preparo**.
- Com `Imprimir cozinha automaticamente` ligado, o pedido entra na fila do Menu Flow Printer e imprime sozinho.
- A cozinha trabalha em **Operação > Cozinha** e só precisa tocar em **Pronto**.
- Ao tocar em **Pedir conta**, a mesa aparece imediatamente em **Operação > Caixa** e o caixa recebe uma notificação quando o navegador/PWA permitir notificações.
- O caixa pode imprimir a pré-conta com um clique, registrar pagamentos e fechar a mesa.
- `Imprimir conta automaticamente` é opcional. Por padrão, a conta fica aguardando o clique do caixa.
- Se o Menu Flow Printer estiver offline, o painel abre a impressão do navegador como fallback.

## Compatibilidade

O agente envia impressão em modo **RAW/ESC-POS** pelo spooler do Windows. É adequado para a maioria das impressoras térmicas compatíveis com ESC/POS (Elgin, Epson, Bematech e similares, conforme driver/modelo).

Impressoras sem guilhotina normalmente ignoram o comando de corte.


## Segurança e funcionamento

O computador do restaurante **não precisa abrir nenhuma porta na internet**. O Menu Flow Printer consulta a fila do backend usando uma chave exclusiva do estabelecimento, reserva um trabalho, imprime e confirma o resultado. A chave é armazenada no computador do restaurante e no backend somente em formato de hash.

Se o agente ficar offline, os trabalhos permanecem na fila e a interface do Menu Flow oferece impressão pelo navegador como alternativa manual. Trabalhos automáticos antigos são descartados quando o pedido já avançou de etapa, evitando impressão atrasada de comandas que já ficaram prontas.

> Nesta versão há dois destinos operacionais: **Cozinha** e **Caixa**. Roteamento por categoria para bar/copa pode ser acrescentado depois sem mudar o fluxo do garçom.
