# Menu Flow — Controle de Mesas e App do Garçom

Implementação adicionada sobre a versão `Menu-Flow-main (37)`.

## O que foi implementado

- Nova modalidade interna de pedido `TABLE`, sem alterar o checkout público de Entrega/Retirada.
- Cadastro rápido e gerenciamento de mesas por estabelecimento.
- Abertura de mesa/comanda com quantidade de pessoas, cliente opcional e garçom responsável.
- Vários pedidos vinculados à mesma comanda, reaproveitando o cardápio, preços, promoções e adicionais existentes.
- Fluxo de salão rápido: pedido do garçom -> **Em preparo automaticamente** -> Pronto -> Entregue na mesa -> conclusão ao fechar a comanda. Não existe etapa de aceitar para pedido de mesa.
- Status visuais: Livre, Aguardando pedido, Pedido em preparo, Pedido pronto, Ocupada e Aguardando pagamento.
- Transferência de mesa, junção de mesas e troca de garçom.
- Taxa de serviço percentual configurável por estabelecimento.
- Desconto controlado por permissão.
- Pagamentos parciais por Pix, dinheiro, crédito e débito.
- Atalhos para saldo total, divisão igual por pessoas e cobrança de um pedido específico.
- Fechamento somente com saldo zerado e sem pedidos ainda pendentes/preparando/prontos.
- Histórico de auditoria da comanda (abertura, pedido, entrega, cancelamento, conta, pagamentos, desconto, transferência, troca de garçom e fechamento).
- Perfis de funcionário: Garçom, Cozinha, Caixa, Gerente e Outro.
- Permissões granulares do salão no cadastro do funcionário.
- PWA separado `Menu Flow Garçom`, com manifest próprio e abertura direta no controle de mesas.
- Funcionário com acesso ao salão entra diretamente na tela de Mesas.
- Notificação OneSignal para o garçom responsável quando um pedido da mesa fica pronto.
- Notificação OneSignal para caixa/gerente/lojista quando o garçom solicita a conta.
- Pedidos de mesa aparecem como `Mesa / salão` no painel de pedidos e no faturamento existente.

## Proteção da integração Rappidex

Pedidos de mesa usam `fulfillment: TABLE` e não entram na integração Rappidex. A integração existente continua limitada a pedidos `DELIVERY`.

Também foram adicionadas validações para impedir que um pedido de mesa receba `OUT_FOR_DELIVERY` e para impedir que Entrega/Retirada recebam o status `DELIVERED_TO_TABLE`.

## Habilitação

1. No painel Super Admin, abra o estabelecimento.
2. Em Configurações, ative `Controle de mesas`.
3. Ative `App do garçom` se os funcionários do salão forem usar o PWA.
4. Defina a taxa de serviço desejada.
5. No painel do lojista, abra `Funcionários` e selecione a função/permissões de cada funcionário.
6. Abra `Mesas` e crie as mesas em lote.

## Permissões do salão

- `TABLES_VIEW`: visualizar mesas/comandas.
- `TABLES_OPEN`: abrir mesa.
- `TABLES_ORDER`: adicionar pedidos.
- `TABLES_KITCHEN`: operar a fila da cozinha e marcar pedido como pronto.
- `TABLES_DELIVER`: marcar pedido pronto como entregue na mesa.
- `TABLES_PRINT`: imprimir pedido ou pré-conta.
- `TABLES_CANCEL`: cancelar pedido de mesa.
- `TABLES_TRANSFER`: transferir/juntar mesas e trocar garçom.
- `TABLES_REQUEST_BILL`: solicitar conta.
- `TABLES_PAYMENT`: registrar pagamentos.
- `TABLES_DISCOUNT`: aplicar desconto.
- `TABLES_CLOSE`: fechar a mesa.

O preset Garçom recebe as permissões operacionais do salão. Caixa recebe as permissões financeiras. Gerente recebe todas.

## Teste recomendado

1. Criar 3 mesas.
2. Criar/editar um funcionário como Garçom.
3. Entrar com o funcionário e abrir uma mesa.
4. Adicionar produtos e adicionais pelo cardápio.
5. Abrir `Operação > Cozinha` e confirmar que o pedido já chegou em `Em preparo`, sem aceite. Marcar `Pronto`.
6. Confirmar a notificação do garçom e marcar `Entregue na mesa`.
7. Adicionar um segundo pedido na mesma mesa.
8. Solicitar a conta.
9. Registrar dois pagamentos parciais com formas diferentes.
10. Confirmar saldo zero e fechar a mesa.
11. Fazer um pedido normal de Entrega e confirmar que a integração Rappidex continua funcionando apenas nele.

## Banco de dados

Não existe migration SQL. O MongoDB cria as novas coleções/documentos conforme o uso:

- `restauranttables`
- `tablesessions`
- `tableevents`
- `printjobs` (fila temporária do Menu Flow Printer, com expiração automática)

Os pedidos existentes continuam compatíveis. Novos campos em `Order`, `User` e `RestaurantSettings` são opcionais/defaultados.

## QR por mesa

A base para QR foi preparada (token por mesa e flags de configuração), mas o autoatendimento público por QR **não foi ativado nesta entrega**. Isso evita abrir um novo endpoint público de pedidos sem definir antes regras de aprovação, segurança e experiência do cliente.

## Antes do deploy

Execute na raiz do projeto:

```bash
npm ci
npm run typecheck
npm run build
```

Depois faça o deploy normal do backend e frontend usando as mesmas variáveis de ambiente já utilizadas pelo Menu Flow.

## Revisão final desta entrega

- Transferência de mesas agrupadas atua na mesa selecionada na interface, sem assumir sempre a primeira mesa da comanda.
- Foi adicionado índice único parcial para impedir duas comandas abertas usando a mesma mesa em condições de concorrência.
- Abertura, transferência e junção retornam conflito amigável quando outra operação ocupa a mesa simultaneamente.
- Validação de transpiração TypeScript/TSX executada em 171 arquivos de código-fonte: 0 erros sintáticos.
- Smoke-check estrutural confirmou módulo de mesas, rotas, manifest do garçom e barreira `fulfillment !== DELIVERY` na integração Rappidex.

### Observação sobre build no ambiente de revisão

O `npm ci`/`npm run typecheck` completo não pôde ser concluído neste ambiente porque o acesso ao registry do npm falhou por DNS (`EAI_AGAIN`). O pacote foi mantido sem `node_modules`. Antes do deploy, execute normalmente `npm ci`, `npm run typecheck` e `npm run build` em um ambiente com acesso ao registry.


## Operação simplificada

A navegação do salão foi concentrada em uma única tela chamada **Operação**. Dentro dela existem três visões rápidas, sem o funcionário precisar procurar recursos em menus diferentes:

- **Mesas** — garçom abre mesa, adiciona itens, entrega pedidos e solicita a conta.
- **Cozinha** — recebe automaticamente os pedidos de mesa já em `Em preparo`, pode imprimir e marca apenas `Pronto`.
- **Caixa** — mostra automaticamente as mesas com conta solicitada, permite imprimir pré-conta, registrar pagamentos e fechar a mesa.

Funcionário com função `WAITER` abre em Mesas; `KITCHEN` abre em Cozinha; `CASHIER` abre em Caixa. A tela atualiza automaticamente em intervalos curtos.

## Menu Flow Printer

Foi incluído o agente local **Menu Flow Printer** na pasta `Menu-Flow-Printer`.

### O que ele faz

- Instala no Windows por `Instalar Menu Flow Printer.bat`.
- Fica na bandeja do Windows e inicia automaticamente com o computador.
- Lista as impressoras já instaladas no Windows.
- Permite escolher uma impressora para **Cozinha** e outra para **Caixa**.
- Imprime em modo RAW/ESC-POS, adequado para impressoras térmicas compatíveis.
- Suporta papel 58 mm e 80 mm no conteúdo gerado pelo backend.
- Pode imprimir pedido da cozinha automaticamente assim que o garçom envia.
- A pré-conta pode ficar apenas na fila do caixa (padrão) ou ser impressa automaticamente, conforme a configuração do lojista.
- Há impressão manual por botão e fallback pelo navegador se o agente estiver offline.

### Configuração

1. Faça deploy do backend com o novo módulo `PrinterModule`.
2. Faça deploy do frontend.
3. No painel do lojista, abra `Operação > Menu Flow Printer`.
4. Ative o recurso, escolha 58/80 mm e gere uma nova chave.
5. No computador do restaurante, execute `Menu-Flow-Printer/Instalar Menu Flow Printer.bat`.
6. Informe a URL pública do backend, cole a chave, escolha as impressoras de cozinha/caixa e clique em `Salvar e conectar`.
7. Execute os testes de cozinha e caixa no aplicativo local.

O agente usa polling autenticado: o Windows não abre porta pública. A chave completa é exibida apenas no momento da geração e o backend armazena apenas o hash.

### Rotas principais do Printer

Painel autenticado:

- `GET /printer/settings`
- `PATCH /printer/settings`
- `POST /printer/token`
- `POST /printer/jobs/order/:orderId`
- `POST /printer/jobs/bill/:sessionId`
- `GET /printer/jobs/recent`

Agente local autenticado pela chave `x-menuflow-printer-token`:

- `POST /printer/agent/claim`
- `PATCH /printer/agent/jobs/:jobId`

## Novo teste operacional recomendado

1. Ativar `Controle de mesas` e o Menu Flow Printer.
2. Abrir uma mesa com usuário Garçom.
3. Adicionar um item e tocar `Enviar para cozinha`.
4. Confirmar que o pedido entra imediatamente em `Operação > Cozinha` como `Em preparo` e, se impressão automática estiver ativa, sai na térmica sem janela do navegador.
5. Cozinha toca `Pronto`; confirmar aviso no garçom.
6. Garçom entrega e toca `Pedir conta`.
7. Confirmar que a mesa entra imediatamente em `Operação > Caixa` e que caixa/gerente recebem notificação.
8. Caixa toca `Imprimir conta`, registra pagamentos e fecha a mesa.
9. Desligar temporariamente o Menu Flow Printer e confirmar que `Imprimir` abre o fallback do navegador.
10. Fazer pedido `DELIVERY` e confirmar que apenas ele continua elegível à integração Rappidex.

## Operação compacta e Menu Flow Printer 1.1

- Pedidos de mesa enviados pelo garçom entram diretamente em `PREPARING`.
- O cardápio classifica cada categoria com `productionSector`: `KITCHEN`, `BAR` ou `NONE`.
- Ao enviar um pedido, os itens são congelados no pedido com seu setor e a fila de impressão gera uma comanda independente por setor.
- Uma única impressora pode receber COZINHA e BAR; o agente também aceita impressoras separadas.
- A tela Operação usa paginação de mesas, produção e caixa para reduzir rolagem durante o atendimento.
- A produção finaliza Cozinha e Bar separadamente. O pedido só vira `READY` quando todos os setores envolvidos estiverem prontos.
- O caixa possui fechamento integral rápido em uma única janela: Pix, Dinheiro, Débito ou Crédito. Pagamentos parciais continuam disponíveis em Mais opções.
- Categorias `NONE` não entram na fila de produção nem de impressão; se um pedido tiver somente itens `NONE`, ele nasce pronto para entrega.
