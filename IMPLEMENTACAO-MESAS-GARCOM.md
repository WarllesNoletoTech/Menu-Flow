# Menu Flow — Controle de Mesas e App do Garçom

Implementação adicionada sobre a versão `Menu-Flow-main (37)`.

## O que foi implementado

- Nova modalidade interna de pedido `TABLE`, sem alterar o checkout público de Entrega/Retirada.
- Cadastro rápido e gerenciamento de mesas por estabelecimento.
- Abertura de mesa/comanda com quantidade de pessoas, cliente opcional e garçom responsável.
- Vários pedidos vinculados à mesma comanda, reaproveitando o cardápio, preços, promoções e adicionais existentes.
- Fluxo de salão: pedido -> preparo -> pronto -> entregue na mesa -> conclusão ao fechar a comanda.
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
- `TABLES_DELIVER`: marcar pedido pronto como entregue na mesa.
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
5. No painel de pedidos do lojista, aceitar -> preparar -> pronto.
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
- Validação de transpiração TypeScript/TSX executada em 168 arquivos de código-fonte: 0 erros sintáticos.
- Smoke-check estrutural confirmou módulo de mesas, rotas, manifest do garçom e barreira `fulfillment !== DELIVERY` na integração Rappidex.

### Observação sobre build no ambiente de revisão

O `npm ci`/`npm run typecheck` completo não pôde ser concluído neste ambiente porque o acesso ao registry do npm falhou por DNS (`EAI_AGAIN`). O pacote foi mantido sem `node_modules`. Antes do deploy, execute normalmente `npm ci`, `npm run typecheck` e `npm run build` em um ambiente com acesso ao registry.
