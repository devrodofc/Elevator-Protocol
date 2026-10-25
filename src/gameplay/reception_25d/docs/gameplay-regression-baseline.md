# I0 — baseline e regressão do gameplay original

## 1. Objetivo da regressão

Registro de **24/10/2026**, branch `feat/2.5d-experiment`, engine executada
**Godot 4.7.2.stable.official.ed1daf0bf**, sem .NET, conforme `.godotrc`.
A referência é a recepção **2D**:
`src/gameplay/reception/scenes/reception.tscn`.

Esta entrega executa exclusivamente I0, após leitura integral de
[gameplay-integration-audit.md](gameplay-integration-audit.md), preservado sem
alterações. Não implementa sessão compartilhada, adaptador ou integração.
Os testes protegem o comportamento existente, inclusive inconsistências de
conteúdo, para que I1 não o modifique acidentalmente.

Foram criados somente testes, fixtures de teste e este documento. A importação
e as execuções ocorreram numa cópia temporária, preservando os arquivos originais
e todas as alterações locais anteriores, inclusive arquivos não rastreados.

## 2. Sistemas cobertos

| Sistema | Fontes existentes exercitadas |
| --- | --- |
| Validação e prioridades | `src/shared/scripts/rule_validator.gd`, `src/gameplay/scripts/marta_rule.gd` |
| Agendas/interações | `src/gameplay/scripts/day_schedule.gd`, `src/gameplay/scripts/day_interaction.gd` |
| Snapshot da visita | `src/npcs/resources/scripts/visitor_data.gd`, `src/npcs/resources/scripts/name_list.gd`, `src/npcs/dialogue/npc_dialogue.gd` |
| Conteúdo real | `src/gameplay/schedules/day1.tres`, `src/gameplay/schedules/day2.tres`, `src/gameplay/schedules/day3.tres` e dependências autorais `.tres`, incluindo a lista padrão de nomes carregada dinamicamente |
| Atendimento | `src/gameplay/reception/scripts/reception_manager.gd` e cena original 2D |
| Atores/Marta/elevador | `src/npcs/scripts/visitor.gd`, `src/npcs/scenes/visitor.tscn`, `src/npcs/scenes/marta.tscn`, `src/gameplay/scripts/elevator.gd`, `src/gameplay/scenes/elevator.tscn` |
| UI | Scripts `elevator_panel.gd`, `elevator_button.gd`, `reception_hud.gd`, `badge_details.gd`, `company_book.gd`, `rules_board.gd` em `src/gameplay/hud/scripts/`, com cenas correspondentes |
| Fala/transição | `autoload/dialogue/dialogue.gd`, `autoload/scene_transition/scene_transition.gd`, com os Autoloads reais |
| Destino final | `src/ui/menus/scenes/end_screen.tscn`, efetivamente carregada ao concluir o dia 3 |

### Arquivos novos

Testes do gameplay ficam em `tests/gameplay_regression/`, separados dos testes
da câmera experimental. São dois scripts `SceneTree`, sem framework ou dependência
externa nova:

- `tests/gameplay_regression/validator_schedule_test.gd`, com seu `.gd.uid`.
- `tests/gameplay_regression/reception_flow_test.gd`, com seu `.gd.uid`.
- `tests/gameplay_regression/fixtures/schedule_snapshots.json`: três agendas
  completas, com dados das 21 entradas e das seis regras selecionadas.
- `tests/gameplay_regression/fixtures/resource_integrity.json`: SHA-256 de
  **68 arquivos `.tres` autorais** referenciados transitivamente pelas agendas,
  incluindo a lista padrão de nomes. Não congela hashes do código a refatorar.
- Este documento.

Os scripts não são ligados a cenas e não executam automaticamente com F5/F6.
Nenhum teste anterior, script, cena, recurso, import ou documento foi modificado.

## 3. Comportamentos atuais e contratos do atendimento

“Automatizado” significa estado/execução conferidos, não aprovação visual ou
auditiva. Não foram usados mocks, subclasses para sobrescrever o manager,
teletransporte de atores, sinais de chegada falsos ou timings encurtados.

| Marco | Contrato atual | Cobertura automática / limite |
| --- | --- | --- |
| Início do dia | `_ready()` aplica dia estático ou agenda da cena, gera fila/regras juntas, limpa HUD/fala, trava painel e inicia Marta. | Sete visitas, duas regras selecionadas, zero servidos e zero regras ativas. Dia 1 usa o fallback real da cena; falhas dos dias 2/3 inicializam o dia estático. |
| Introdução de Marta | Chega pela esquerda, fala, espera avanço do jogador, entra no elevador; só depois começa o primeiro visitante. | Posição real no `MartaPoint`, painel travado, sem contagem/regra; atriz efetivamente liberada antes do atendimento. |
| Próximo visitante | `_call_next_visitor()` faz `pop_front`, instancia Visitor e aplica dados sorteados. | FIFO comparado à fila do próprio `_ready`, sem gerar outra agenda. Identidade de recurso/sprite do ator conferida. |
| Chegada ao balcão | Tween termina, emite `arrived` e executa callback. | Ator inicialmente em movimento/painel travado; depois no `VisitorDeskPoint1`, painel liberado, fala e crachá associados. |
| Diálogo | Nome da visita e texto do NPCDialogue; fala permanece até decidir. | Nome/texto integral paginado conferidos; avanço de Marta passa por eventos `ui_accept` no viewport principal. |
| Crachá disponível | `arrived` chama `_update_badge_visitor`; transferência de 0,5 s antecede interação. | Aguarda tween real e `_badge_interactive`; confere foto, nome, idade, sexo, ocupação e “Não informado”. |
| Inspeção do crachá | `toggled` trava painel; clique fora fecha e libera se visitante está no balcão. | Handlers e sinais reais exercitados; controle desabilitado não decide; dados não são sorteados novamente. Picking é manual. |
| Livro/prancheta | Livro avança/volta página; prancheta abre/fecha e recebe regras anunciadas. | Lógica real de paginação/abertura conferida; texto da regra após anúncio. Layout, Esc e área de clique são manuais. |
| Confirmação de andar | Seleciona/desmarca, trava e espera 0,15 s antes de `floor_selected`. | Handlers `_gui_input` dos controles reais; confirmações repetidas durante a espera emitem o sinal uma vez. Crachá não reabre nesse intervalo. |
| Validação | `_on_floor_selected()` usa visitante, diálogo, dia e regras ativas. | Expectativas independentes no teste unitário; no fluxo real o validador orienta o jogador automatizado e as consequências são verificadas. |
| Atendimento correto | Limpa HUD/fala, desconecta `arrived` do crachá, incrementa uma vez e chama `elevator.receive()` sem await para andar/subsolo. | Estado, conexão, ocupação e movimento real conferidos; todos os sete atores liberados até o fim do dia. SFX não foi ouvido. |
| Recusa correta | 999, quando esperado, retorna pela entrada com `leave_to(spawn_point)`. | Cenário dedicado verifica `departed` na posição real da entrada, liberação do ator e avanço da contagem. |
| Decisão incorreta | Trava processamento/painel sem contar sucesso; visitante sai pela entrada, Marta reage e ocorre reload do mesmo dia. | Escolha errada em cada dia; saída, fala de falha, nova instância e limpeza do estado conferidas. |
| Próximo atendimento | Espera dois segundos após sucesso; pode começar antes do fim da saída, pois não aguarda `receive()`. | Sete entradas consumidas naturalmente; o teste não serializa o controlador. Sobreposição visual exata é manual. |
| Anúncio de regra | Após atendimentos 2/4: Marta sai do elevador, fala e espera avanço; só então acrescenta a regra ativa e anota. | Oito anúncios entre progressão e recusa dedicada. Texto completo, incluindo última página, fica dez frames sem confirmação e a regra continua inativa. Depois do avanço entra exatamente o recurso anunciado e seu efeito passa a valer. |
| Encerramento | Após sete visitas, sem terceira regra, Marta apresenta fim de dia; avanço troca dia/cena. | Mensagens, contagens, sprite final de Marta do dia 2 e transições naturais 1→2→3→tela final. Epílogo/créditos completos são manuais. |

### Progressão e Marta

- São três dias de sete atendimentos. Regras selecionadas pela agenda não são
  consideradas ativas antes do anúncio. Cada dia atual tem uma regra de andar
  e depois lore; aparecem após 2 e 4 atendimentos, sem anúncio extra ao final.
- `Dialogue.finished` significa fim da digitação da última página, não término
  do anúncio. O teste mantém essa página completa sem último avanço e verifica
  a lista real `active_rules`; depois confirma o efeito com essa mesma lista.
- Marta não consome entrada da fila, cuja quantidade restante também é conferida.
  Ela tem ator/fluxo separado dos visitantes comuns.
- Introdução/anúncio dependem de avanço do jogador; falha aceita avanço ou
  timeout de seis segundos. `failure-timeout-2` não envia o último avanço e
  observa o reload automático, sem medir duração audiovisual por relógio de parede.
- Erro reconstrói sete visitas no mesmo dia, zera contagem/regras e reinicia a
  introdução. Não se exige que o novo sorteio seja diferente ou igual ao anterior:
  coincidências são válidas. Cada `_ready` gera somente a própria agenda.
- Progressão usa a mesma cena nos próximos dias e `cena_final` no terceiro;
  o teste também confere a limpeza do dia estático. Não usa F9/cheat para avançar.

## 4. Casos de teste e reprodutibilidade

### Validador

Inputs sintéticos são Resources novos somente do teste: exercitam ramos reais
do validador, sem representar uma recepção artificial. Não se afirma que todos
esses tipos de visitante apareçam nas agendas atuais.

| Grupo | Expectativa verificada |
| --- | --- |
| Pedido | 1–6 e −1 preservados sem efeito aplicável; diálogo nulo usa 1. |
| Tags de bloqueio | `intruder`/`deny_access` retornam 999 antes de regras, entrega e subsolo. |
| Entrega genérica | `delivery`/`generic_delivery` mantêm pedido no dia 1 e vão para 1 nos dias seguintes. |
| Subsolo | `send_to_basement` leva a −1 e sobrepõe entrega. |
| Marta | Regra ativa pode redirecionar, mandar ao subsolo ou recusar. Lore, regra não correspondente e null não alteram. |
| Prioridade | Regras vêm depois de entrega/subsolo; comparam pedido original, sem encadear o destino intermediário; última correspondente vence. Bloqueio por tag continua prioritário. |
| Ativação | A mesma regra fora da lista ativa não interfere; dentro dela interfere. O teste da cena protege o instante da inclusão real. |
| Decisões/códigos | Para cada destino, confere aceitação/rejeição de 1–6, −1, 999 e 0; constante de recusa permanece 999. |
| Tags exatas | `entregador` não equivale a `delivery`; tags continuam sensíveis a maiúsculas. |

Casos concretos usam a visita fixa da agenda realmente gerada, nas oito sessões
de teste de cada dia:

| Caso | Recurso/pedido efetivos | Destino esperado |
| --- | --- | --- |
| Lucas, dia 1 | `src/npcs/resources/birdTest.tres`, sprite forçado de Lucas, fala pedindo 3, sem tags de entrega/recusa. | **3** |
| Entregador, dia 2 | `src/npcs/resources/Day2/entregador.tres`, tag `entregador`, fala forçada −1. | **−1**, pela fala, não pelo ramo genérico de entregadores. |
| Tião, dia 3 | `src/npcs/resources/Day3/tiao.tres`, pedido 6, tag `send_to_basement`. | **−1**, pela tag. |

### Agendas, interações e VisitorData

Para cada dia: seeds **0, 1, 2, 3, 42, 73, 20261024** verificam invariantes;
uma sessão adicional com seed **4201, 4202, 4203**, respectivamente, compara o
snapshot congelado. Total: **24 sessões**, cada qual com **uma única chamada a
`montar_dia()`** para fila e regras juntas. Não se chama `build_queue()` depois
para conferir a mesma sessão. A referência armazenada vem de captura anterior
com a mesma seed e engine; não de dois sorteios independentes na mesma execução.

Verifica-se:

- Sete entradas na ordem: quatro aleatórias, duas do pool específico, uma fixa;
  pertencimento ao pool e identidade dos overrides de visitante/diálogo/sprite.
- Nome da lista correta, sprite do visitante, crachá no intervalo/valores fixos;
  uma fala válida por entrada, sem repetição de texto nestas agendas.
- Andares aleatórios permitidos representados, sem terceiro andar entre os
  aleatórios do dia 1; uma regra de efeito seguida de lore; obrigatória narrativa
  na segunda aparição dos dias 2/3; efeito não altera o pedido do fixo.
- Um caso garantido depois do visitante imediatamente seguinte ao anúncio;
  pedido correspondente e diálogo de fonte elegível, inclusive fallback.
- Retirar/devolver entrada à fila não modifica os dados já gerados.
- DayInteraction FIXO com repetições/overrides, ALEATORIO com pool próprio ou
  padrão; VisitorData evita falas usadas quando há alternativas e permite
  repetição após esgotamento; fala forçada e campos fixos são preservados.
- Idade com limites invertidos é normalizada; opções aleatórias vazias de
  sexo/ocupação voltam ao valor fixo. Só Resources novos do teste são configurados
  para esses casos-limite.
- Cadeia dos dias, referência da tela final e hashes dos 68 `.tres` antes/depois.

Snapshots completos incluem nome, caminhos/identidade, sprite, crachá,
texto/andar/diálogo, flags e conteúdo/ordem das regras. Resumo para revisão:

| Dia / seed | Pedidos das sete visitas | Primeira regra |
| --- | --- | --- |
| 1 / 4201 | 1, 5, 6, 4, 2, 1, 3 | Pediu 2 → mandar para 5 |
| 2 / 4202 | 4, 1, 3, 2, 5, 6, −1 | Pediu 5 → mandar para 6 |
| 3 / 4203 | 6, 4, 5, 2, 1, 3, 6 | Pediu 1 → recusar (999) |

### Cena 2D real

O script do manager é carregado dinamicamente depois dos Autoloads, conforme
`CLAUDE.md` seção 12, com o caminho atual. Trocas/reloads são reais. Não há
alteração de trajetos, velocidades, delays, portas, textos ou `time_scale`.
`--fixed-fps 60` fixa o delta e acelera tempo de parede, preservando segundos
simulados dos tweens/timers originais.

`ui_accept` é enviado ao viewport para Marta. Painel/crachá usam os handlers de
input dos Controls existentes, suas conexões e sinais reais. Isso não valida
picking, foco de janela, cursor físico, renderização ou áudio. Não se fabricam
`arrived`/`departed`, nem se chama `_process_success()`, `fail()` ou
`_marta_announce_rule()` para forçar resultado. Livro/prancheta testam lógica,
não ergonomia. O script de produção permanece responsável pelo fluxo inteiro.

O validador, já coberto por expectativas independentes, orienta o jogador
automatizado no sucesso. As consequências são verificadas separadamente: a
passagem completa sozinha não provaria que o destino calculado está correto.
Os três visitantes fixos também possuem destinos literais independentes.

Há timeout por espera e watchdog global para evitar processo preso. No teardown,
após as verificações, espera-se o fade final, limpa-se a fala, interrompem-se
players de áudio em memória e libera-se a cena. Isso não altera o fluxo testado.

## 5. Resultados automatizados executados

Cópia usada: `/tmp/ep-i0/project`, com dados/configuração da Godot em `/tmp/ep-i0/`.
Importação inicial e com os scripts novos sem erros/avisos de GDScript ou
referências. O projeto original não foi regravado.

| Execução | Verificações | Falhas | Resultado observado |
| --- | --- | --- | --- |
| `validator_schedule_test.gd` | **3055** | **0** | 24 agendas, validador, 68 recursos íntegros, três snapshots completos idênticos. |
| Fluxo `progression` | **792** | **0** | 21 decisões corretas, seis anúncios, três dias naturais e tela final. |
| Fluxo `denial` | **268** | **0** | Dia 3/seed 4203: sete decisões corretas, uma recusa com retorno à entrada, dois anúncios e final. |
| Fluxo `failure-1` | **47** | **0** | Erro no dia 1, Marta com raiva, saída do visitante e reload do dia 1. |
| Fluxo `failure-2` | **46** | **0** | Erro e reload do dia 2, sem contabilizar sucesso. |
| Fluxo `failure-3` | **46** | **0** | Erro e reload do dia 3, sem passar à tela final. |
| Fluxo `failure-timeout-2` | **46** | **0** | Falha do dia 2 sem último avanço: timeout original provoca reload. |
| **Total** | **4300** | **0** | Sete execuções com código de saída 0. |

28 decisões corretas em cenas reais incluem a repetição do dia 3 no cenário
dedicado de recusa. Há ainda quatro decisões incorretas nos cenários de falha.
Quantidade de verificações não equivale a comportamentos independentes.

### Logs e avisos de encerramento

Resultados: `I0_DATA_RESULT` / `I0_FLOW_RESULT`, com `failures=0`. Marcos:
`I0_RULE`, `I0_DAY_COMPLETED`, `I0_FAILURE_RELOAD`. Logs temporários em
`/tmp/ep-i0/`: `data-test.log`, `flow-progression.log`, `flow-denial.log`,
`flow-failure-*.log`; não são dependências para repetir a suíte.

**A execução não é livre de avisos de cleanup.** Controle da cena original sem
roteiro, por 120 frames: quatro instâncias ObjectDB e dois recursos ainda em uso
ao encerrar. Teste de dados com Autoloads: duas instâncias/um recurso. Nos fluxos,
a última execução registrou 11/quatro em `progression` e 13/cinco em
`failure-timeout-2`; outros cenários terminaram sem esses avisos nessa rodada.
Contagens variaram entre execuções.

Diagnóstico com `--verbose` identificou remanescentes como AudioStreamMP3/WAV e
AudioStreamPlaybackMP3/WAV, incluindo música e SFX. Não se afirma que todo aviso
dos fluxos tenha quantidade idêntica ao controle. Cleanup de áudio permanece
limitação, não correção autorizada; a suíte não valida liberação/qualidade sonora.
Não houve erro de GDScript/referência nos resultados finais. Os avisos são
registrados separadamente e não substituem o resultado das verificações.

### Integridade e Git

Comparação SHA-256 anterior/posterior, incluindo arquivos locais não rastreados:
nenhum arquivo anterior alterado/removido. Agendas, recursos, UIDs, listas e
finais de linha preservados. Manifesto verifica 68 recursos a cada execução do
teste de dados. `git diff --check` passou; arquivos novos foram conferidos
separadamente, pois o diff normal não inclui não rastreados. Sem commit ou push.

## 6. Roteiro de validação manual com F6

**Testes interativos realizados nesta etapa: nenhum. Todos os itens abaixo
estão PENDENTES de validação pelo desenvolvedor.** Headless não aprova cliques
reais, foco, renderização, leitura ou áudio.

Abrir **`src/gameplay/reception/scenes/reception.tscn`**, a recepção 2D, em
Godot 4.7.2 e usar F6. Não usar a cena 2.5D para aprovar esta baseline. Uma nova
execução começa no dia 1; para revisar dias 2/3 isolados, P abre o cheat original,
mas isso não substitui a progressão natural.

Registrar por execução: data, engine, branch, dia, regra anunciada, pedido,
decisão, resultado observado, imagem/log se necessário e aprovado/reprovado.
Não editar recursos para fabricar recusa ou alterar sorteio.

| ID | Procedimento | Resultado esperado | Situação |
| --- | --- | --- | --- |
| M01 | Iniciar F6, observar Marta; aguardar texto completo sem confirmar, depois usar Espaço conforme as páginas. | Painel travado; sem atendimento até Marta sair e passar o intervalo; texto legível. | Pendente |
| M02 | Aguardar primeiro visitante e observar chegada/fala/transferência do crachá. | Painel só libera no balcão; nome e aparência correspondem ao crachá; sem saltos de animação. | Pendente |
| M03 | Abrir crachá por clique, tentar decidir, fechar por clique fora; repetir durante confirmação rápida. | Dados legíveis, painel bloqueado ao inspecionar, sem decisão dupla nem reabertura indevida do crachá. | Pendente |
| M04 | Consultar livro e páginas; abrir/fechar prancheta por clique e Esc. | Texto legível, área de clique correta; Esc fecha prancheta antes de pause; nada dispara atrás da UI. | Pendente |
| M05 | Escolher andar correto conforme pedido/regras, desmarcar, selecionar e confirmar; clicar novamente rápido. | Uma contagem; crachá devolvido, fala limpa, visitante entra e some no elevador; porta e som coerentes. | Pendente |
| M06 | Após regra de recusa, aguardar visitante correspondente e confirmar X/999. | Sucesso: visitante volta pela entrada, próximo atendimento ocorre. Se não houver regra de recusa sorteada, repetir outra execução ou registrar não exercitado. | Pendente |
| M07 | Após dois e quatro atendimentos, observar Marta saindo do elevador; completar texto sem último avanço, depois confirmar. | Regra não ativa antes do fim do anúncio; anotação aparece depois. Não chega visitante comum durante a apresentação. | Pendente |
| M08 | Escolher destino propositalmente incorreto. | Saída pela entrada, painel travado, efeito vermelho/Marta; reload do mesmo dia sem contagem/regras antigas; raiva no dia 1. | Pendente |
| M09 | Repetir erro nos dias 2/3 via cheat; numa falha não enviar último avanço. | Mesmo dia reinicia; timeout encerra falha; UI/áudio não ficam presos. Cheat não certifica progressão natural. | Pendente |
| M10 | Atender sete visitas do dia 1, avançar fala final e continuar dias 2/3 sem F9/cheat. | 1→2→3→final, sem terceira regra após última visita. Lucas→3; entrega para Marta→subsolo; Tião→subsolo. | Pendente |
| M11 | Observar suspense/som e sprite final de Marta no dia 2; assistir epílogo/créditos ao concluir dia 3. | Efeitos, texto, som, créditos e retorno ao menu sem sobreposições inadequadas. | Pendente |
| M12 | Abrir pause/voltar ao menu durante atendimento, fala e animação; conferir foco/retorno. | Sem fala antiga sobre menu/nova cena, perda de controle ou áudio indevido. Interrupções não estão automatizadas nesta I0. | Pendente |

Respeitar a regra **já anunciada**, não uma apenas sorteada para aparecer depois.
Nem todo pedido divergente deve ser negado: regras também redirecionam para
outro andar/subsolo. Recusa errada é falha, embora 999 seja ação válida do painel.

## 7. Inconsistências conhecidas e comportamento preservado

1. **Lucas/dia 1:** texto final insinua erro ao enviá-lo ao terceiro, mas o
   validador aceita 3. `birdTest.tres` não tem tags; nome/caminho não criam regras.
2. **Entregador/dia 2:** tag `entregador` não corresponde a `delivery`/
   `generic_delivery`; destino −1 vem do diálogo fixo. Não corrigir tag nem
   aplicar regra genérica por interpretação durante a extração.
3. **Tião/dia 3:** pedido 6 é sobreposto por `send_to_basement`; a fala obrigatória
   correspondente de Marta é narrativa, não a implementação do efeito.
4. **Regras sorteadas:** uma regra de andar e depois lore; obrigatória ocupa a
   segunda vaga dos dias 2/3 e limita a variedade de lore sorteada. Preservado,
   conforme auditoria e referência técnica.
5. **Caso garantido:** `caso_regra` não exige que a fala pertença a `falas_caso`:
   `_sortear_fala()` aceita fallback das fontes permitidas. Testa-se pedido,
   posição e origem elegível, não preferência absoluta.
6. **Espaços em nomes:** Lucas e outras entradas podem ter espaços finais. HUD
   usa `strip_edges` para testar vazio, mas apresenta o valor original; não se
   exige trim silencioso na baseline.
7. **Crachá/diálogo:** não há validação de documento falso ou árvore de respostas.
   Também não há placar/histórico integrado; recusa correta conta como sucesso.
8. **Cleanup headless:** avisos de áudio da seção 5 persistem fora da correção
   autorizada; não classificar os testes como aprovação auditiva.

Observações de conteúdo são separadas das expectativas dos testes. Não foram
corrigidos código, recursos, auditoria ou apresentação para fazê-los passar.

## 8. Limitações da cobertura e riscos remanescentes

- Três seeds com snapshots e outras 21 sessões com invariantes não esgotam a
  aleatoriedade. Engine fixada é necessária para comparar estado do gerador
  global/ordem dos sorteios. Não se testa distribuição estatística nem afirma
  que todas as regras do banco saíram nessas seeds.
- Fluxo correto usa o validador como oráculo; erros nele dependem da tabela
  independente e casos concretos, não apenas da passagem completa.
- Handlers reais não substituem picking/foco, hitboxes, composição visual,
  acessibilidade, leitura 640×360 ou sons. Esses pontos exigem revisão manual.
- Há leitura de campos/métodos internos para observar o contrato atual. I1 pode
  adaptar a observação ao novo contrato, preservando expectativas/fixtures;
  não remover verificações só para obter resultado verde.
- Não se mede quantitativamente a sobreposição de atores. O teste não serializa
  o manager, mas não certifica todo cenário concorrente.
- Não cobre automaticamente pause/menu/F9/cheat durante animação/anúncio,
  cancelamento em todos os pontos, save/load inexistente, epílogo completo,
  créditos ou esgotamento de todos os pools. São limites, não autorização
  para correções fora do escopo.
- O manifesto detecta qualquer mudança de conteúdo/UID/listas dos `.tres`, mesmo
  quando semanticamente válida. Alterações autorais aprovadas exigirão revisão
  explícita da baseline; não regenerar fixtures para esconder regressão.
- Os hashes são dos bytes, incluindo finais de linha. Conversão LF/CRLF por
  outro checkout pode produzir falha de integridade sem alterar regras; conferir
  esse caso conforme `CLAUDE.md`, sem regravar recursos ou atualizar o manifesto
  silenciosamente. A cópia de testes deve manter os bytes do estado auditado.
- Logs devem ser inspecionados para distinguir erro novo de GDScript/referência
  dos avisos de áudio documentados; código de saída 0 não certifica ausência
  universal de mensagens do motor.

## 9. Comandos para repetir os testes

Na raiz do projeto, ajustar `G` à instalação indicada por `.godotrc`. A suíte
depende só de Godot/JSON; rsync/mktemp abaixo apenas preparam cópia segura.

```bash
G="/home/rodmherr/Godot/versions/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64"
PROJETO="$(mktemp -d /tmp/ep-i0-replay.XXXXXX)"
rsync -a --exclude=.git --exclude=.godot --exclude=builds ./ "$PROJETO/"

# Opcional: dados/configuração do motor também na cópia.
export XDG_DATA_HOME="$PROJETO/.i0-data"
export XDG_CONFIG_HOME="$PROJETO/.i0-config"

"$G" --headless --path "$PROJETO" --import

"$G" --headless --fixed-fps 60 --path "$PROJETO" \
  --log-file "$PROJETO/i0-data.log" \
  -s res://tests/gameplay_regression/validator_schedule_test.gd

for CENARIO in progression denial failure-1 failure-2 failure-3 failure-timeout-2; do
  "$G" --headless --fixed-fps 60 --path "$PROJETO" \
    --log-file "$PROJETO/i0-$CENARIO.log" \
    -s res://tests/gameplay_regression/reception_flow_test.gd \
    -- --scenario="$CENARIO" || break
done

git diff --check
```

Conferir os sete resultados, códigos de saída e logs de GDScript/referências;
não apenas o último comando. Os scripts retornam 1 em falha ou watchdog.
Nos exemplos antigos de `CLAUDE.md`, o caminho atual do controlador é
`src/gameplay/reception/scripts/reception_manager.gd`.

O parâmetro de desenvolvimento `--record-snapshots` do teste de dados somente
imprime captura JSON em stdout. Execução normal **nunca grava/atualiza** fixtures
nem aceita diferenças automaticamente. Não usar captura como teste de regressão.
Rever/aprovar mudanças esperadas antes de nova captura; a suíte tampouco atualiza
o manifesto de recursos.

## 10. Critérios para iniciar I1

| Critério | Estado ao concluir I0 |
| --- | --- |
| Validador/agendas com expectativas explícitas e casos concretos | Atendido: 3055 verificações de dados, zero falhas. |
| Fluxo real: regra não ativa antes do fim do anúncio, sucesso/recusa, erro/reload e progressão | Atendido nas execuções headless, sem substituir a implementação. |
| Recursos originais e alterações locais preservados | Atendido por hashes; importação restrita à cópia. |
| Fixtures revisáveis, engine/seeds/comandos fixados e limites documentados | Atendido; referências não dependem do cache local da Godot. |
| Revisão F6 e aprovação funcional/visual/auditiva | **Pendente**: nenhum item M01–M12 aprovado interativamente nesta etapa. |
| Concordância em preservar inconsistências durante a extração | Exige revisão da equipe; correção de conteúdo é tarefa separada. |
| Aprovação do limite da extração e compatibilidade tutorial/cheat | Exige aprovação de I1 na auditoria; não implementado aqui. |

**A base automatizada está preparada para apoiar I1.** Iniciar implementação
somente após revisão desta baseline, registro da validação manual pendente e
aprovação explícita da etapa seguinte. Avisos de cleanup devem continuar
distinguíveis de regressões novas; sua ausência não foi certificada.
I1 não foi iniciada e nenhum código de sessão compartilhada foi criado.
