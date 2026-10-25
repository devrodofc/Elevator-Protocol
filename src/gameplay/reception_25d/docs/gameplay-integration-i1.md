# I1 — sessão de atendimento compartilhada

Implementação em 24/10/2026, branch `feat/2.5d-experiment`, Godot
**4.7.2.stable.official.ed1daf0bf**, sem .NET, conforme `.godotrc`.

O desenvolvedor aprovou a validação manual **geral** da recepção 2D e autorizou
explicitamente iniciar I1 com a cobertura atual. Essa autorização substitui o
bloqueio anterior; não aprova individualmente M01–M12. O registro histórico da
[I0](gameplay-regression-baseline.md) permanece intacto. A aprovação visual da
I1 será feita pelo desenvolvedor após esta entrega.

## Implementação e propriedade do estado

`src/gameplay/scripts/reception_session.gd` define `ReceptionSession`, um Node
criado pelo manager em `_create_session()`, filho da instância da recepção 2D.
Ele é liberado com essa cena. Não é Autoload e não contém atores, coordenadas,
câmeras, elevadores, HUD, tweens, áudio ou chamadas aos Autoloads visuais.
Não foi necessário alterar `reception/scenes/reception.tscn`.

| Estado anterior do manager | Autoridade na I1 |
| --- | --- |
| `queue_data`, `current_entry` | Sessão: fila única e snapshot atual. Manager expõe consultas delegadas. |
| `active_rules`, `_rules_today`, `_next_rule_index` | Sessão: regras sorteadas, reserva pendente e ativação após anúncio. |
| `_served_count`, `is_processing_decision` | Sessão: contagem e fase lógica, sem sincronização de cópias. |
| `schedule_config` | Export preservado como configuração inicial; após inicializar, seu getter consulta o dia da sessão. |
| `dia_em_andamento` | Continua estático no `ReceptionManager`, somente como contrato de entrada/progressão entre cenas. |
| `current_visitor_node`, `marta_instance`, trava visual do crachá | Permanecem na apresentação 2D. |

A sessão chama **uma vez** `DayScheduleConfig.montar_dia()` em `start_day()`.
Assim reutiliza `DayInteraction` e `VisitorData.pick_visit()` sem reproduzir
seus algoritmos. Mantém nomes, sprites, crachás, diálogos, ordem e identidade
dos Resources. Containers do snapshot/crachá são copiados e tornados somente
leitura; as coleções públicas são visões de consulta somente leitura.
Não existem novos sorteios ao selecionar a visita ou chegar ao balcão.

`RuleValidator.validar_decisao()` continua sendo a única implementação da
validação. São aceitos os códigos 1–6, −1 e 999. Um comando inválido ou fora de
fase retorna `{}`; uma resposta errada válida retorna `correct=false` e inicia
falha. Somente uma conclusão correta incrementa o contador, inclusive recusa.
Lucas continua indo para 3, o entregador do dia 2 para −1 e Tião para −1.
As inconsistências narrativas/tags conhecidas foram preservadas.

## Contrato com a apresentação 2D

| Método da sessão | Marco informado pelo manager |
| --- | --- |
| `start_day(config)` / `finish_intro(generation)` | Montagem inicial e fim da introdução/saída de Marta/intervalo original. |
| `request_next_visit(generation)` | Seleção FIFO somente quando a sessão está pronta. Retorna o snapshot, sem criar ator. |
| `service_reached(visit_id)` | Callback do movimento real ao balcão; libera a fase de decisão uma vez. |
| `submit_decision(visit_id, floor_code)` | Painel emite intenção; manager verifica crachá/modal e sessão valida identidade/fase. |
| `complete_visit(visit_id)` | Sucesso aceito: limpa atendimento, conta uma vez e inicia intervalo lógico. |
| `take_due_rule(visit_id)` | Após intervalo, reserva a próxima regra se a cadência e a fila permitirem. |
| `activate_pending_rule(generation, rule)` | Exatamente onde antes ocorria `active_rules.append()`: após o último avanço da fala de Marta. |
| `finish_rule(generation, rule)` / `finish_interval(visit_id)` | Libera próxima visita após a saída/intervalo de Marta, ou intervalo sem regra. |
| `has_next_day()` | Informa existência de próximo dia ou cena final; manager executa a transição original. |
| `begin_transition()` / `close()` | Cancela comandos/continuações ao trocar ou remover a cena. |

Fases: `IDLE → INTRO → READY → ARRIVING → SERVING → RESOLVED → INTERVAL`.
Do intervalo, o fluxo retorna a `READY` ou passa por `RULE`. Fila esgotada
leva a `CONCLUDING`; erro leva a `FAILED`. `TRANSITION` e `CLOSED` bloqueiam
operações. `start_day()` reinicia dados e invalida a geração anterior.

O identificador de ocorrência combina instância do Node, geração e contador
local monotônico. Não usa `VisitorData.id`, RNG ou novo estado global.
Chegada, crachá e decisão têm callbacks vinculados ao ID da visita; o sinal
de chegada do crachá é desconectado antes da saída. Decisão/conclusão repetidas
ou callbacks de outra ocorrência não contam nem avançam a fila.

Não foram criados sinais novos: métodos com resultados explícitos bastam para
esta extração. Permanecem os sinais reais `Visitor.arrived`,
`ElevatorPanel.floor_selected` e `BadgeDetails.toggled`. As continuações com
`await` no manager conferem a geração e a validade da apresentação. Transições
externas pelo CheatMenu são detectadas durante o fade; a transição de entrada
da nova recepção é distinguida da saída. Remover a cena fecha a sessão.

O manager mantém instanciação, movimentação, diálogos, crachá, livro/prancheta,
painel, elevador, coreografia de Marta, sons, overlays, suspense e roteamento.
Ele continua chamando `elevator.receive()` **sem await** no sucesso: a extração
não serializa a saída física com a próxima visita. Nenhum intervalo foi alterado.
Tutorial, CheatMenu, final e F9 continuam usando os caminhos e o campo estático
originais. `main_scene` e o comportamento de F5 não foram alterados.

## Verificações executadas

Execução em `/tmp/ep-i1/project`, com dados/configuração isolados em
`/tmp/ep-i1/data` e `/tmp/ep-i1/config`, `--headless --fixed-fps 60`.
A I0 foi executada integralmente antes e depois, sem alterar seus testes ou
fixtures. Novos testes carregam o manager depois dos Autoloads, como exige
`CLAUDE.md` seção 12; o teste integrado reutiliza os helpers reais da I0.

| Execução | Antes | Depois | Falhas depois |
| --- | ---: | ---: | ---: |
| I0 dados/agendas/validador | 3055 | 3055 | 0 |
| I0 `progression` | 792 | 792 | 0 |
| I0 `denial` | 268 | 268 | 0 |
| I0 `failure-1` | 47 | 47 | 0 |
| I0 `failure-2` | 46 | 46 | 0 |
| I0 `failure-3` | 46 | 46 | 0 |
| I0 `failure-timeout-2` | 46 | 46 | 0 |
| **Subtotal I0** | **4300** | **4300** | **0** |
| I1 `reception_session_test.gd` | — | 705 | 0 |
| I1 `reception_session_flow_test.gd` | — | 131 | 0 |
| **Total após extração** | — | **5136** | **0** |

I1 verifica snapshots congelados dos três dias, consumo de RNG equivalente à
agenda original, propriedade da fila, identidades com o mesmo VisitorData,
fases, códigos do painel, validação, duplicação, intervalos, regras,
cancelamento/reinício e identidades entre instâncias. O fluxo 2D adicional
confere callbacks antigos, F9 durante confirmação pendente, CheatMenu durante
introdução, pause/menu durante regra pendente e menu → tutorial limpando o dia.
A I0 mantém a cobertura de Lucas/entregador/Tião, recusa, falha/reload nos três
dias, timeout e progressão natural até a cena final.

Importação final com 4.7.2 sem erros/avisos de GDScript ou referências; os scripts
também foram efetivamente compilados/carregados nos testes. O sandbox bloqueou
os sockets locais do editor nas importações iniciais; as importações foram
repetidas fora do sandbox, apenas na cópia temporária, sem esses erros.

Permanecem avisos preexistentes de cleanup de áudio: teste de dados e teste
unitário I1 terminaram com dois Objects/um recurso em uso; a progressão final
registrou 11/quatro. A execução anterior à extração também apresentou esses
avisos, com quantidades variáveis. Não houve erro de GDScript/referência nem
regressão de gameplay nas execuções finais. Esses avisos não foram corrigidos
fora do escopo e os testes não aprovam áudio/renderização.

Os 68 recursos do manifesto I0 mantiveram seus hashes. Comparação dos 465
arquivos iniciais, incluindo não rastreados: apenas o manager 2D mudou;
nenhum arquivo inicial foi removido. Os 81 arquivos preexistentes em
`reception_25d/` permaneceram idênticos. Nessa árvore foi criado somente este
documento. Agendas, `.tscn`, `.tres`, `.import`, UIDs existentes, F5 e alterações
locais anteriores foram preservados. `git diff --check` e whitespace dos novos
arquivos passaram. Sem commit ou push.

Para repetir, preparar/importar uma cópia conforme seção 9 do baseline I0,
executar seus sete comandos e acrescentar:

```bash
"$G" --headless --fixed-fps 60 --path "$PROJETO" \
  -s res://tests/gameplay_regression/reception_session_test.gd
"$G" --headless --fixed-fps 60 --path "$PROJETO" \
  -s res://tests/gameplay_regression/reception_session_flow_test.gd
```

## Regressão manual F6 e limites

Recarregar o projeto no editor **sem salvar recursos antigos**, conforme
`CLAUDE.md`, para registrar a nova classe. Abrir
`src/gameplay/reception/scenes/reception.tscn` e executar F6 com Godot 4.7.2.
Validar novamente M01–M12 do baseline; sequência objetiva:

1. Aguardar Marta, avançar todas as páginas e observar a chegada do visitante.
   Conferir que o painel só libera no balcão e o crachá mantém nome/aparência.
2. Abrir/fechar crachá, consultar livro/prancheta, testar clique fora e Esc.
   Confirmar rapidamente duas vezes: somente um atendimento e devolução correta.
3. Após dois e quatro atendimentos, deixar a última página de Marta completa
   sem confirmar: regra ainda inativa. Avançar e conferir anotação/novo efeito.
4. Exercer recusa 999 com regra anunciada, retorno pela entrada e próximo
   visitante. Se o sorteio não permitir, repetir ou registrar não exercitado.
5. Errar nos três dias e observar reação, timeout e reinício do mesmo dia,
   com sete visitas, zero contagem e nenhuma regra antiga. P permite testes
   isolados, sem substituir a progressão natural.
6. Completar 1 → 2 → 3 → final: Lucas → 3, entregador → −1, Tião → −1.
   Conferir suspense/som/sprite final de Marta, epílogo e créditos.
7. Usar F9 durante chegada/confirmação, P durante fala, pause → menu durante
   atendimento/anúncio e iniciar pelo menu/tutorial. Observar ausência de falas,
   crachá ou controles antigos sobre a cena nova, além de áudio/foco corretos.

Os testes headless não aprovam cliques físicos, composição visual, hitboxes,
foco, som ou toda sobreposição possível de atores. A autorização manual geral
da I0 não substitui essa revisão da I1. Resources referenciados pelos snapshots
continuam compartilhados e não devem ser mutados durante atendimento.

## Preparação para I2

A sessão já oferece agenda, snapshot, identidade e marco de chegada sem
dependência visual. A I2 poderá ligá-los a um adaptador 2.5D, depois da revisão
F6 desta entrega e da escolha da política inicial de entrada. Ainda será preciso
configurar aparência/âncora do ator e distinguir seus eventos por ocorrência;
HUD tipada em Visitor, rotas inversas, Marta 3D e política de cabine/cadência
continuam nas etapas correspondentes da auditoria. **I2 não foi iniciada.**
