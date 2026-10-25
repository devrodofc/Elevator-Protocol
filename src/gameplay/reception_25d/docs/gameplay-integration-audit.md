# Etapa 11 — auditoria e plano de integração 2D → 2.5D

## 1. Resumo executivo

Auditoria de 24/10/2026, branch `feat/2.5d-experiment`, Godot **4.7.2-stable
no-dotnet**, conforme `.godotrc`. Este documento é a única alteração desta etapa.
**A integração não foi iniciada; o plano depende de revisão e aprovação.**

O gameplay original está implementado em `ReceptionManager`, na recepção 2D,
com agendas de três dias, visitantes sorteados/fixos, diálogos de exposição,
crachá consultável, decisões de andar/recusa, validação por tags e regras da
Marta, falha com reinício e progressão até a tela final. O controlador mistura
essas responsabilidades com posições, atores, tweens, efeitos e HUD 2D.

A recepção 2.5D implementa circulação de **um ator de teste já presente na cena**,
entrada por duas portas, atendimento espacial, escolha de uma das três cabines
e embarque. Não executa agendas, validação ou progressão. Seu arquivo chamado
`reception_manager.gd` é um esqueleto sem lógica e não está ligado à cena.

Recomendação: compartilhar os recursos e o `RuleValidator` existentes; extrair
gradualmente a sessão de atendimento do controlador original, mantendo-o como
fachada da apresentação 2D; conectar a apresentação 2.5D por um adaptador pequeno.
Não duplicar a lógica do controlador inteiro nem converter `Visitor` em Node3D.

Distinções essenciais:

- **Andar não é cabine.** O painel original decide 1–6, subsolo −1 ou recusa 999;
  os três botões experimentais escolhem índices de cabine 0–2. Não há relação
  implementada entre número da cabine e andar permitido.
- **Crachá não é um validador.** Idade, sexo, ocupação, foto e nome são exibidos;
  não existe verificação de documento adulterado ou regra de acesso por esses campos.
- **Diálogo não tem árvore de escolhas.** `NPCDialogue` contém texto e andar;
  o jogador decide no painel, não em opções de resposta do balão.
- **Marta tem orquestração própria.** Sua cena usa o script visual `Visitor`, mas
  suas entradas/saídas, falas, regras e efeitos não passam pela fila de visitantes.
- O 2D permite sobrepor saída e próximo atendimento. O experimento reutiliza
  um ator e reseta todas as cabines; precisa de uma decisão explícita sobre cadência.

## 2. Escopo e metodologia

### 2.1 Inspeção e limites da evidência

Leitura estática de scripts, recursos, cenas, referências e conexões reais;
buscas por classes, sinais, métodos, tags, entradas de teclado, persistência e
consumidores. Comparação com `CLAUDE.md`, sobretudo seções 9, 11 e 12. A referência
técnica contém caminhos antigos `src/levels/` e `src/ui/hud/`; a implementação
atual foi localizada em `src/gameplay/` e `src/shared/scripts/`.

“Implementado” abaixo significa **há código e ligação identificáveis**, não
aprovação visual nem garantia de ausência de bugs. “Proposto” significa trabalho
futuro, não uma API existente. Nenhum arquivo necessário ficou inacessível.
Não se executou editor, importação, testes headless ou F6 nesta auditoria:
a etapa autoriza somente este Markdown e não exige executar o jogo. Os testes
do plano são critérios futuros; testes anteriores do README não foram repetidos.

O Git já continha mudanças no README, na cena 2.5D e na câmera normal, além de
assets, pipeline, câmera livre e testes não rastreados. Todos foram tratados como
estado inicial válido e preservados. Foi registrado um inventário de hashes dos
arquivos existentes para conferir a preservação ao final, incluindo os não rastreados.

### 2.2 Entradas e configuração efetivas

| Item | Evidência e comportamento atual |
| --- | --- |
| Cena principal | `project.godot`: `run/main_scene="uid://b6hgpbqqj2j76"`; o cabeçalho de `src/ui/menus/scenes/menu.tscn` confirma esse UID. |
| Início normal | `src/ui/menus/scripts/menu.gd::_on_play_pressed()` abre `src/gameplay/tutorial/scenes/tutorial.tscn`. |
| Entrada após tutorial | `src/gameplay/tutorial/scripts/tutorial.gd::_ready()` limpa `ReceptionManager.dia_em_andamento`; `_go_to_reception()` abre a recepção 2D via transição. |
| Recepção original | `src/gameplay/reception/scenes/reception.tscn`, raiz Node2D com `src/gameplay/reception/scripts/reception_manager.gd`. |
| Experimento | `src/gameplay/reception_25d/scenes/reception.tscn`, raiz Node2D sem controlador de gameplay; execução independente com F6. |
| Apresentação | Base 640×360, janela configurada 1920×1080/modo 3, stretch `canvas_items`, Nearest global, snap de transformações 2D. |
| InputMap | `hack_level1` / `hack_level2` declarados; não foi encontrado uso dessas ações no gameplay. Os atalhos de desenvolvimento usam teclas diretamente. |
| Estado entre cenas | `ReceptionManager.dia_em_andamento` é estático, não um Autoload; F9 avança dia nessa recepção. |

### 2.3 Autoloads

| Nome | Arquivo real | Responsabilidade / dependência relevante |
| --- | --- | --- |
| `Dialogue` | `autoload/dialogue/dialogue.tscn`, `autoload/dialogue/dialogue.gd` | CanvasLayer de fala, paginação, digitação, `finished`, `wait_for_advance()`, limpeza de esperas. Layer 10; não armazena visitante ou decisão. |
| `SceneTransition` | `autoload/scene_transition/scene_transition.tscn`, `autoload/scene_transition/scene_transition.gd` | Fade/título, bloqueio de cliques, troca de cena, `_busy` e `finished`. Layer 50. |
| `MusicMenu` | `sounds/music/menu/music_menu.tscn`, `sounds/music/menu/music_menu.gd` | Música do menu; `play_if_stopped()` / `stop_music()`. Inicia também ao executar uma cena com F6. |
| `Audio` | `autoload/audio/audio.gd` | Música, SFX, loops, fade, volumes e bus de música criado em execução; `PROCESS_MODE_ALWAYS`. Reutilizável sem posições 3D. |
| `CheatMenu` | `autoload/cheat_menu/cheat_menu.gd` | P abre menu pausado, layer 100. `go_to_day()` grava a variável estática do controlador 2D e abre caminho 2D fixo; não seleciona a apresentação 2.5D. |

## 3. Inventário do gameplay original

### 3.1 Gerenciamento da recepção e ciclo de atendimento

**Arquivos:** `src/gameplay/reception/scripts/reception_manager.gd` (classe
`ReceptionManager`, 655 linhas nesta inspeção) e a cena original da seção 2.2.

`_ready()` conecta `BadgeDetails.toggled` e `ElevatorPanel.floor_selected`, limpa
o crachá, trava o painel, aplica o dia estático se houver, limpa `Dialogue`, chama
`_build_schedule_data()`, escolhe a música e inicia `_start_day_intro()`.

`_build_schedule_data()` consome `DayScheduleConfig.montar_dia()` uma vez e guarda
`queue_data` e `_rules_today`. Depois da introdução da Marta, `_call_next_visitor()`
retira a primeira entrada com `pop_front()`, instancia `visitor_base_scene` como
`Visitor`, aplica escala/velocidade e `setup()`, conecta `arrived` ao crachá e
chama `move_to_slot(..., _on_visitor_arrived_at_desk, true)`.

Ao chegar, `_update_badge_visitor()` apresenta os dados da visita e
`_on_visitor_arrived_at_desk()` exibe nome/texto e destrava o painel. A decisão
passa por `_on_floor_selected()`: bloqueia reentrância e crachá aberto, trava
o painel, limpa a fala e chama `RuleValidator.validar_decisao()`.

Em sucesso, `_process_success()` limpa o HUD e desconecta `arrived` do crachá.
Para um andar/subsolo, chama `elevator.receive()` **sem await**; para recusa,
`leave_to(spawn_point.global_position)`. Sem elevador disponível, também sai pela
entrada. Limpa o atendimento, incrementa `_served_count`, espera o intervalo,
anuncia regra se devida e chama o próximo. A cena usa velocidade 220 px/s e
escala de visitante 3,4594595; isso não é a velocidade 3 da apresentação 2.5D.

**Entradas:** agenda, dados sorteados, chegada do ator, código do painel e
interações da Marta. **Saídas:** comandos visuais, validação, contagem, próximo
visitante, falha ou troca de dia. Não há sinal próprio de atendimento concluído;
a comunicação combina chamadas diretas, sinais externos, callbacks e `await`.

**Estado:** fila, `current_entry`, `current_visitor_node`, `is_processing_decision`,
`active_rules`, `_served_count`, `_next_rule_index`, `_rules_today`, `_saindo`.
Não existe enum formal de fase do atendimento. O código usa `is_moving` do ator
para destravar o painel após fechar o crachá.

**Reutilização:** requer separação. O mesmo script resolve negócio e acessa
`%VisitorSpawnPoint`, `%VisitorDeskPoint1`, `%Actors`, `%MartaPoint`, `$Elevator`,
`$UI_CanvasLayer`, HUD e `AudioStreamPlayer2D`. Não pode ser anexado diretamente
à raiz 2.5D sem reconstruir dependências 2D.

### 3.2 Agendas, seleção e dados dos NPCs

**Arquivos de dados/lógica:**

- `src/gameplay/scripts/day_schedule.gd` (`DayScheduleConfig`).
- `src/gameplay/scripts/day_interaction.gd` (`DayInteraction`).
- `src/gameplay/schedules/day1.tres`, `src/gameplay/schedules/day2.tres`, `src/gameplay/schedules/day3.tres`.
- `src/npcs/resources/scripts/visitor_data.gd` (`VisitorData`),
  `src/npcs/resources/scripts/name_list.gd` (`NameList`),
  `src/npcs/resources/visitors/male_names.tres`.
- Recursos ativos em `src/npcs/resources/Day1/`, `src/npcs/resources/Day2/`,
  `src/npcs/resources/Day3/` e `src/npcs/resources/birdTest.tres`.

`DayInteraction.build_entries()` escolhe modo ALEATORIO/FIXO, respeita
`repeticoes`, pool próprio ou padrão, fala forçada e sprite fixo. Marca `fixo`.
`VisitorData.pick_visit()` devolve um snapshot por visita:
`visitor`, `dialogue`, `nome`, `sprite`, `cracha`. O recurso contém id, nome,
lista de nomes, cena opcional, sprites possíveis, tags, diálogos, dados de crachá
e retrato. Não contém coordenadas de recepção.

`montar_dia()` preserva a ordem das interações, identifica posições aleatórias,
sorteia regras e um plano de andares em rodadas embaralhadas, garante um caso
de regra quando há posição válida, evita esse caso no visitante imediatamente
seguinte à regra e aplica falas por andar. `_sortear_fala()` prioriza `falas_caso`,
depois falas do visitante/comuns, evita repetição se possível e pode repetir quando
esgota opções. `build_queue()` chama `montar_dia()` de novo: não usar os dois
para obter fila e regras separadamente, pois seriam sorteios distintos.

`_sortear_regras()` efetivamente prioriza uma regra de andar na primeira aparição
e regras de lore nas seguintes; exclui do banco normal efeitos sobre andares
de visitantes fixos. Regras obrigatórias entram em seus grupos. A execução,
mais específica que alguns comentários antigos, é a referência do plano.

As três agendas atuais têm **sete visitas**: quatro aleatórias, duas aleatórias
com pool e uma fixa. Não existe fila visual simultânea no atendimento original.
Nome e crachá são sorteados por visita, não devem ser sorteados novamente no
ServicePoint ou ao abrir o HUD. `VisitorData.id` identifica o tipo/recurso, não
uma visita única; várias entradas podem referenciar o mesmo recurso.

**Apresentação separada:** `src/npcs/scenes/visitor.tscn` e
`src/npcs/scripts/visitor.gd` (`Visitor`, Node2D). `setup()` / `_apply_data()`
instanciam `VisitorData.cena`, se definida, ou usam a textura da visita no Sprite2D
padrão. `move_to_slot()` emite `arrived`; `leave_to()` emite `departed` e libera
o ator. Escala de profundidade, bob de passos e tweens são específicos 2D.

`get_badge_photo()` prioriza retrato explícito, depois procura textura visível
em Sprite2D/AnimatedSprite2D, inclusive atlas/frame. `get_visitor_name()` devolve
o nome do recurso, não o nome sorteado: o controlador usa corretamente o nome
da entrada para diálogo e crachá.

**Reutilização:** recursos/geração de fila são diretos; a apresentação é adaptada
por outro ator. PackedScene 2D arbitrária não vira Sprite3D automaticamente.
O pool ativo usa texturas, mas há suporte a cenas visuais e recursos antigos
que o utilizam; prever essa distinção em vez de quebrar o contrato.

### 3.3 Diálogos

**Dados:** `src/npcs/dialogue/npc_dialogue.gd` (`NPCDialogue`: somente `texto`
e `andar_desejado`), recursos em `src/npcs/dialogue/dialoguesCommon/`,
`src/npcs/dialogue/dialoguesDia2/` e `src/npcs/dialogue/dialoguesDia3/`.
**Apresentação:** Autoload `Dialogue` da seção 2.3.

Visitante começa a falar ao chegar ao balcão; sua fala permanece até a decisão
limpar o balão. Marta usa fala acelerável e `wait_for_advance()`, com espera
ilimitada ou timeout conforme a sequência. `finished` significa que o texto da
última página terminou de aparecer; **não significa visitante liberado**.
Espaço/Enter via `ui_accept` acelera ou avança páginas/espera conforme o modo.
`clear_dialogue()` muda a versão da fala e encerra esperas anteriores.

Não há escolhas de resposta, grafo de conversação ou consequências codificadas
em `NPCDialogue`; a consequência vem da decisão do painel e do validador.
Não há vínculo com posição do NPC no balão. Pode funcionar com NPC parado em
ServicePoint, chamando `display_dialogue()` apenas depois da chegada confirmada
e mantendo a UI no viewport principal. Falas/páginas devem ser limpas no reset
para uma espera antiga não interferir no próximo atendimento.

### 3.4 Crachá e identificação

**Arquivos:** `src/gameplay/hud/scripts/reception_hud.gd`,
`src/gameplay/hud/scripts/badge_details.gd`, cenas correspondentes em
`src/gameplay/hud/scenes/reception_hud.tscn` e
`src/gameplay/hud/scenes/badge_details.tscn`; dados em `VisitorData`.

`_sortear_cracha()` gera idade, sexo e ocupação fixos ou aleatórios. Nome vem
da visita e foto de `Visitor.get_badge_photo()`. O detalhe usa “Não informado”
quando falta valor. Não existe campo de autenticidade, validade, adulteração,
documento falso ou divergência comparada automaticamente pelo validador.

`ReceptionHUD.set_current_visitor()` anima o crachá do ator para a mesa;
`_visitor_badge_position()` usa `Visitor.get_global_transform_with_canvas()`.
Ao limpar o visitante, `_collect_badge()` anima a devolução com WeakRef ao ator.
O ícone só fica interativo após a transferência de 0,5 s; clique abre o detalhe,
clique fora fecha. `BadgeDetails.toggled` faz o controlador travar/destravar o
painel, incluindo a janela de confirmação de 0,15 s.

**Negócio reutilizável:** snapshot de nome/dados, retrato e ausência de valores.
**Apresentação a adaptar:** APIs tipadas `Visitor`, extração de foto e projeção
2D. Não é possível passar diretamente `VisitorGround` (Node3D) às duas UIs.
Recomenda-se receber os dados da visita e uma textura de retrato, com origem
de animação em coordenadas de tela fornecida pela apresentação.

### 3.5 Regras, decisões e consequências

**Arquivos:** `src/shared/scripts/rule_validator.gd` (`RuleValidator`, RefCounted,
métodos estáticos), `src/gameplay/scripts/marta_rule.gd` (`MartaRule`), agendas,
`src/gameplay/hud/scripts/elevator_panel.gd` e
`src/gameplay/hud/scripts/elevator_button.gd`.

`andar_esperado(visitor, dialogo, dia, regras)` aplica esta ordem real:

1. Tags `intruder` ou `deny_access`: retorna **999** imediatamente.
2. Base: `dialogo.andar_desejado`, ou 1 se o diálogo for nulo.
3. Dia ≥2 e tag `delivery`/`generic_delivery`: muda para 1.
4. Tag `send_to_basement`: muda para −1.
5. Regras ativas, na ordem: `MartaRule.aplicar(andar_pedido, andar_atual)`.
   Uma regra com `andar_pedido != 0` substitui o destino se o pedido original
   coincidir. Regras posteriores compatíveis podem sobrescrever o resultado.

`validar_decisao()` compara igualdade com esse destino. Não consulta crachá,
distância, cabine, companhia no livro ou disponibilidade física de elevador.
Não há tratamento para VisitorData nulo: o chamador precisa garantir uma visita válida.

O painel permite **1,2,3,4,5,6,−1,999**. O jogador seleciona, pode desmarcar e
confirma; o script trava imediatamente, espera 0,15 s e emite `floor_selected`.
O livro não gera a regra; é consulta de `CompanyDirectory`. A prancheta recebe
o texto de regras já anunciadas e não é a autoridade de validação.

Resultado correto: som, contador de atendidos e saída conforme decisão. Recusa
correta sai pela entrada; andar/subsolo corretos entram no elevador. Decisão
incorreta chama `fail()`: HUD/painel bloqueados, visitante sai pela entrada,
Marta reage, overlay vermelho/fala e reload do mesmo dia. Portanto, “autorizado
ou recusado” e “acertou ou errou” são dimensões diferentes.

**Casos concretos e limites:**

| Caso atual | Evidência | Destino correto / limitação |
| --- | --- | --- |
| Fixo do dia 1 | `day1.tres` usa `src/npcs/resources/birdTest.tres` (nome Entregador Lucas, sem tags), força sprite de Lucas e fala de andar 3. | 3 na configuração atual; não inferir regra por nome do arquivo nem corrigir para 1 automaticamente. |
| Entregador do dia 2 | `src/npcs/resources/Day2/entregador.tres` tem tag `entregador`; `day2.tres` força fala −1. A regra obrigatória correspondente é narrativa, sem `andar_pedido`. | −1 pelo diálogo forçado. A regra genérica `delivery`/`generic_delivery` **não reconhece** a tag desse recurso. |
| Seu Tião do dia 3 | `src/npcs/resources/Day3/tiao.tres`: `send_to_basement`; `day3.tres` força pedido 6. | −1 pela tag. A regra obrigatória anunciada é narrativa; não é ela que implementa esse desvio. |
| Intruso/negação por tag | Há ramo explícito no validador; busca nos recursos de NPC/agendas não encontrou instância com essas tags. | Suporte implementado, mas não afirmar que esse evento aparece nas agendas atuais. Recusas também podem surgir de regras da Marta. |

O texto final do dia 1 insinua erro ao mandar Lucas ao terceiro, embora essa seja
a decisão aceita. Já é inconsistência conhecida em `CLAUDE.md`; a migração não
deve “consertar” esse conteúdo ou as tags silenciosamente.

### 3.6 Progressão, resultados e estado global

Agendas encadeiam dia 1 → dia 2 → dia 3; o último define
`src/ui/menus/scenes/end_screen.tscn`, com
`src/ui/menus/scripts/end_screen.gd` (epílogo, créditos e retorno ao menu).
`_conclude_day()` é acionado ao esgotar a fila, apresenta a sequência final e
`_ir_para_proximo_dia()` atualiza a variável estática e usa `scene_file_path` para
reabrir a recepção ou `cena_final`. F9 antecipa essa transição, com guarda de busy.

`_served_count` cresce por decisão correta, inclusive recusa, e dispara cadência
de regras. `_rule_due()` usa `intervalo_regras`, disponibilidade de próxima regra
e fila restante: não anuncia regra depois do último visitante.
Falha recarrega a cena, reconstrói a fila/regras e zera estados de instância,
mantendo o dia estático. Não conserva a sequência sorteada anterior.

Não foi encontrado save/load de progresso em disco no fluxo auditado. A variável
estática persiste entre cenas na execução, não entre sessões do aplicativo.
Não existe placar consolidado ou histórico por decisão integrado. O script
`src/gameplay/hud/scripts/shift_summary.gd` tem `setup_summary()`, mas o nó
`ShiftSummary` da recepção é um Control vazio sem esse script; não é tela de
resultado funcional do fluxo. `DialogueUI` e `ManualPanel` também são placeholders.

**Reutilização:** lógica de dias/contagem pode ser compartilhada após extração;
efeitos e roteamento de cena precisam de adaptador. Tutorial e CheatMenu fixam
caminhos 2D e acessam a classe estática original, ponto de compatibilidade obrigatório.

### 3.7 Marta e personagens especiais

**Arquivos:** `src/npcs/scenes/marta.tscn`, `src/npcs/scripts/visitor.gd`,
`src/gameplay/scripts/marta_rule.gd`, agendas e métodos de `ReceptionManager`:
`_start_day_intro`, `_marta_arrive`, `_spawn_marta`, `_marta_announce_rule`,
`_marta_leave`, `fail`, `_conclude_day`, `_apagar_luzes`, `_tremer`.

Marta não tem VisitorData na fila. Sua cena Node2D usa `Visitor` como mecanismo
visual/de movimento; o controlador a instancia e troca Sprite2D diretamente.
Na abertura chega pela esquerda e sai de elevador. Para regras, falha e fim,
chega do elevador; `release()` é esperado até a chegada ao ponto da Marta.
Quando anuncia regra, espera avanço do jogador, só então acrescenta a
`active_rules`, anota na prancheta, mostra-a brevemente e sai.

No dia 1, a falha usa sprite de raiva ao chegar; o dia 2 tem sprite final
ensanguentado, suspense, som e pulsação vermelha. `_apagar_luzes()` espera
`elevator.is_busy()` antes da sequência; `_tremer()` desloca a raiz Node2D sem
mover a HUD. Essas implementações não são comandos equivalentes a apagar
OmniLight3D ou sacudir Camera3D, embora um overlay 2D possa ser reaproveitado.

O elevador original `src/gameplay/scripts/elevator.gd`, ligado por
`src/gameplay/scenes/elevator.tscn`, tem `receive()`, `release()`, `door_position()`
e `is_busy()`. Encaixa atores pelo retângulo visível do sprite, modifica escala/
modulate, anima porta 2D, reproduz som e libera atores ao embarcar. Contabiliza
uso concorrente; `release()` espera entradas e fechamento anteriores.
O elevador 2.5D não oferece esse contrato de saída/ocupação.

Seu Tião e os entregadores, ao contrário de Marta, são visitas fixas da agenda.
Não criar um fluxo de “NPC especial” único que apague essa distinção.

### 3.8 Interfaces e recursos compartilhados

| Elemento | Cena / script real | Estado, comunicação e adaptação |
| --- | --- | --- |
| HUD | `src/gameplay/hud/scenes/reception_hud.tscn`; `src/gameplay/hud/scripts/reception_hud.gd` | Monta mesa, ícone de crachá, livro, prancheta e overlay. Mesa é arte 2D que cobriria o balcão 3D; não instanciar o conjunto sem decisão de composição. Crachá acoplado a Visitor. |
| Detalhe do crachá | `src/gameplay/hud/scenes/badge_details.tscn`; `src/gameplay/hud/scripts/badge_details.gd` | Foto/labels, clique fora, `toggled`; layout reaproveitável, API de dados deve perder dependência de Node2D. |
| Painel de andares | `src/gameplay/hud/scenes/elevator_panel.tscn`; `src/gameplay/hud/scripts/elevator_panel.gd`; `src/gameplay/hud/scripts/elevator_button.gd` | Controls com texturas, `_gui_input`, `pressed(code)` e `floor_selected`; escala 0,25, botões não são Button padrão. Contrato de decisão reutilizável, posicionamento precisa revisão. |
| Livro | `src/gameplay/hud/scenes/company_book.tscn`; `src/gameplay/hud/scripts/company_book.gd` | Dois andares por página, setas cíclicas; consulta a `src/gameplay/resources/company_directory.tres`, `src/gameplay/scripts/company_directory.gd`, `src/gameplay/scripts/company_data.gd`. Sem validação de decisão. |
| Prancheta | `src/gameplay/hud/scenes/rules_board.tscn`; `src/gameplay/hud/scripts/rules_board.gd` | `add_rule`, `clear_rules`, `open/close`, `toggled`; usa altura do viewport. Esc em `_shortcut_input` fecha antes do pause. |
| Fala global | `autoload/dialogue/dialogue.tscn`; `autoload/dialogue/dialogue.gd` | Pode continuar como overlay sem projeção do NPC; nenhum menu de respostas implementado. |
| Pause | `src/ui/menus/scenes/pause.tscn`; `src/ui/menus/scripts/pause.gd`; `src/ui/menus/scenes/options_pause.tscn`; `src/ui/menus/scripts/options_pause.gd` | Esc, pausa SceneTree, opções, menu; processa sempre. A cena experimental não instancia Pause atualmente. |
| Tutorial | `src/gameplay/tutorial/scenes/tutorial.tscn`; `src/gameplay/tutorial/scripts/tutorial.gd`; `src/gameplay/tutorial/scripts/tutorial_step.gd`; `src/gameplay/tutorial/scripts/tutorial_script.gd`; `src/gameplay/tutorial/resources/tutorial_intro.tres` | Narração/diálogo e destaques de HUD, usa cenário/atores 2D. Não migra automaticamente com o atendimento. |

Layers atuais: fala 10, crachá 10, pause 10, transição 50, cheat 100; UI de
elevadores experimentais 5. Igualdade de layer não expressa prioridade modal:
a ordem de desenho/instância também importa. A prancheta pode encobrir o crachá,
risco já registrado em `CLAUDE.md`. `CanvasLayer` não implica bloqueio automático
de `_input` de outros scripts.

`DayConfig` em `src/npcs/level_day_config/day_config.gd` e `PhraseSet` em
`src/npcs/resources/scripts/phrase_set.gd`, com
`src/npcs/resources/visitors/standard_phrases.tres`, não são consumidos pelo fluxo
de agenda ativo encontrado. Há ainda `src/npcs/resources/visitors/common_npc_male1.tres`
com cena visual antiga; não é o recurso masculino referenciado pelos dias atuais.
Preservar esses arquivos, mas não adotá-los como autoridades paralelas.

## 4. Inventário da recepção 2.5D

### 4.1 Cena, ator e apresentação

`src/gameplay/reception_25d/scenes/reception.tscn` contém `RoomViewport` próprio
(640×360, `own_world_3d=true`, `handle_input_locally=false`) e `RoomView`, Sprite2D
que apresenta a ViewportTexture com Nearest, `centered=false`. O mundo fica em
`RoomViewport/Room`, que tem deslocamento global não nulo. Movimentos trabalham
com posições globais e referências do piso, não com a hipótese de piso global Y=0.

`RoomViewport/Room/VisitorGround` é o único ator espacial atual; contém
`TestVisitor` (Sprite3D) e sombra. `src/gameplay/reception_25d/scripts/test_sprite.gd`
carrega `source_texture` uma vez no `_ready()`, cria ImageTexture em memória para
evitar reimportação 3D do PNG original e alinha a base visível do sprite ao piso.
Não lê `VisitorData`, não instancia uma fila e não oferece `setup()` dinâmico.
Trocar a textura de visitas futuras exige reaplicar alinhamento/altura e retrato;
não basta mudar o campo exportado depois do `_ready()`.

`src/gameplay/reception_25d/scripts/reception_manager.gd` contém somente `_ready()`
e `_process()` com `pass`; não há ext_resource desse script na cena. O nome do
arquivo não corresponde a um controlador de atendimento 2.5D já integrado.

### 4.2 Componentes e estados efetivos

Todos os scripts desta tabela estão em `src/gameplay/reception_25d/scripts/`.
São blocos de apresentação funcionais no experimento, **não sistemas definitivos
de atendimento ou garantia de API pronta para múltiplos visitantes**.

| Arquivo / nó | Responsabilidade, entradas/saídas e limites |
| --- | --- |
| `visitor_movement.gd` / `VisitorMovement` | Referência única `visitor: Node3D`; `reset_at`, `start_from`, `follow_route`; converte marcadores em posições com offset do piso. Velocidade 3 unidades/s, consumo de distância por delta inclusive entre segmentos. Emite `movement_reset`, `route_started`, `arrived`; este último não identifica visita nem motivo do trajeto. |
| `visitor_movement_test.gd` / `VisitorMovementTest` | Escolhe entrada pelo Inspector; `_ready()` estaciona/oculta o ator, não começa atendimento. 1/2 chama `_start_from()`, R chama `_reset_test()`. Abre a entrada, espera estado OPEN, inicia trajeto e fecha ao liberar passagem. Substitui execução anterior em vez de enfileirar outra visita. |
| `visitor_orientation.gd` / `VisitorOrientation` | `Mode { BILLBOARD, PAPER }`, PAPER padrão. Observa deslocamento e gira só o visual em Y; no serviço encara a câmera e na cabine o fundo, via `face_when_idle()`. Preserva escala e altura. P alterna modo e consome evento localmente para evitar o CheatMenu; esse atalho é experimental. |
| `automatic_door.gd` / duas instâncias de `entrance_shell.tscn` | `State { CLOSED, OPENING, OPEN, CLOSING }`; `open`, `close`, `reset_closed`, `has_cleared_passage`. Tween reversível/cancelável. Não detecta pessoas sozinho: o harness manda abrir/fechar. Clearance mede chegada ao interior local +Z; não é detector de saída para o exterior. |
| `elevator_selection.gd` / `ElevatorSelection` | Liga movimento, orientação, marcadores e três portas. `Stage { IDLE, ARRIVING, AT_SERVICE, TO_ELEVATOR, WAITING_FOR_DOOR, ENTERING_CABIN, IN_CABIN }`. `availability_changed(bool)` habilita botões; `select_elevator(index)` aceita 0–2 quando `can_select`. Não valida andar nem resultado de atendimento. |
| `elevator_door.gd` / três elevadores | Mesmo enum de porta, métodos open/close/reset/clearance, `entry_point`, `cabin_stop_point`, `cabin_facing_target`. Clearance de embarque mede local −Z. Não possui `receive`, `release`, `is_busy`, sinal de embarque ou gestão de ocupação/fila. Porta fecha por tween; cabine não viaja entre andares. |
| `elevator_selection_ui.gd` / `ElevatorUI/Selection` | Três Buttons ligados diretamente a `select_elevator(index)`, sem código de andar. Hover pausa `_process` da câmera e guarda o estado anterior. A disponibilidade vem apenas da fase espacial. |
| `reception_camera.gd` / `ReceptionCamera` | Yaw limitado/suavizado por bordas da janela principal; FOV 70 preservado. `debug_exploration_active` suspende o giro; `reset_debug_exploration()` limpa alvo antigo. Não conhece modais de atendimento. |
| `debug_free_camera.gd` / `DebugFreeCamera` | Debug habilitado na cena; F alterna, WASD/QE/Shift move e RMB captura mouse com `screen_relative`; retorno restaura transformação inicial e controle normal. Sem colisões. Também limpa captura/teclas ao perder foco; não é movimento de gameplay. |

### 4.3 Fluxo atual completo

```text
VisitorMovementTest._ready → _reset_test
  → ator oculto no SpawnPoint da entrada escolhida; portas fechadas
1 ou 2 → _start_from
  → reset do movimento → ElevatorSelection._on_movement_reset
	→ fecha TODOS os elevadores, limpa seleção e orientação
  → abre entrada escolhida e espera OPEN
  → start_from(SpawnPoint, [EntranceLeft/Right, QueueJoinPoint, ServicePoint])
  → mostra ator; fecha entrada depois de has_cleared_passage
movement.arrived no ServicePoint
  → ElevatorSelection: ARRIVING → AT_SERVICE; can_select=true
clique em Elevador 1/2/3 → select_elevator(índice 0/1/2)
  → TO_ELEVATOR; can_select=false
  → [RetreatPoint, CorridorEntry, TurnPoint da cabine, ApproachPoint da cabine]
arrived → WAITING_FOR_DOOR; encara cabine; open()
porta OPEN → ENTERING_CABIN
  → [EntryPoint, CabinStopPoint]
clearance atingido → close(); para monitoramento em _process
arrived → IN_CABIN; encara fundo
  → ator permanece na cabine; não há próximo visitante automático
```

Fechamento e chegada ao destino são eventos distintos: o monitor pode parar
depois do clearance antes do `arrived` final; a movimentação continua. Não usar
`can_select=false`, início de fechamento ou `is_processing=false` da seleção
como prova de desembarque/visita concluída. R reseta o ator existente; não é
reinício de dia nem limpeza de um gameplay que ainda não existe nessa cena.

Existem marcadores de fila no cenário, mas o caminho atual só usa os pontos da
entrada, junção e serviço; não implementa múltiplos visitantes na fila. O reset
global de portas e as referências únicas de movimento/orientação/seleção impedem
tratar o conjunto atual como gerenciador de vários atores simultâneos.

### 4.4 O que preservar e o que conectar

Preservar geometria/marcadores, velocidade 3, contato com piso, PAPER, cálculo
local de portas, portas tweenadas, cabines, materiais, câmera e 640×360.
`scenes/elevator_01_visual.tscn` herda `scenes/elevator_shell.tscn`; os outros
elevadores continuam na base. O pipeline em
`src/gameplay/reception_25d/art_pipeline/elevator_01/README.md` documenta arte,
não contém regra de atendimento. Não misturar integração de gameplay e revisão de arte.

Substituir o papel do harness como fonte de visitantes/teclas pela agenda e
comandos de uma apresentação conectada; adicionar vínculo da visita ao ator,
trava de decisão no serviço, resultado de negócio, saída de recusa, conclusão
espacial e Marta. Os componentes existentes podem permanecer como mecanismos
de apresentação, com adaptações limitadas e testes de contrato.

## 5. Mapa de dependências

### 5.1 Arquitetura atual observada

```text
project.godot → menu.tscn/menu.gd → tutorial.tscn/tutorial.gd
  → ReceptionManager.dia_em_andamento = null
  → SceneTransition → reception/scenes/reception.tscn
	→ ReceptionManager
	  → DayScheduleConfig.montar_dia
		→ DayInteraction.build_entries → VisitorData.pick_visit → NameList
		→ MartaRule + NPCDialogue + recursos das agendas
	  → visitor.tscn/Visitor.setup + move_to_slot
		→ arrived → HUD.set_current_visitor + fala em Dialogue
	  → ElevatorPanel.floor_selected → RuleValidator.validar_decisao
		→ VisitorData.tags + NPCDialogue.andar_desejado + dia + active_rules
		→ sucesso: contador + Elevator.receive OU Visitor.leave_to
		→ erro: fail → Marta + overlay + reload_current_scene
	  → intervalo: MartaRule → _marta_announce_rule
		→ Marta + Dialogue.wait_for_advance → active_rules + RulesBoard.add_rule
	  → fim: _conclude_day → Marta/efeitos → próximo dia OU end_screen
	  → Audio / MusicMenu / SceneTransition

HUD → BadgeDetails → Visitor.current_data + get_badge_photo
HUD → CompanyBook → CompanyDirectory → CompanyData
BadgeDetails.toggled → ReceptionManager → ElevatorPanel.set_panel_locked
Pause → SceneTree.paused + menu + Dialogue.clear_dialogue
CheatMenu → script ReceptionManager (estado estático) + agendas + cena 2D fixa

reception_25d/scenes/reception.tscn [sem ligação ao grafo de atendimento acima]
  → RoomViewport/Room → VisitorGround/TestVisitor/test_sprite.gd
  → VisitorMovementTest → AutomaticDoor + VisitorMovement
  → VisitorMovement.route_started/arrived/movement_reset → ElevatorSelection
  → ElevatorUI/Selection → select_elevator → movimento + orientação + ElevatorDoor
  → VisitorOrientation → movimento/câmera/cabine
  → DebugFreeCamera → ReceptionCamera; UI → pausa de processamento da câmera
  → Autoloads globais continuam presentes, mesmo sem gameplay integrado
```

### 5.2 Acoplamentos e duplicações

Não foi identificada dependência circular de scripts entre geração de fila,
dados e validador: são bases favoráveis à reutilização. O retorno por sinal do
painel para o controlador e a trava no sentido inverso formam um **ciclo de
interação**, não um ciclo de preload; ainda exigem disciplina para evitar
confirmações duplicadas. `toggled(false)` durante limpeza de crachá também pode
acionar destrava, protegida hoje pelas condições do controlador.

Os principais acoplamentos são: controlador original aos nós da cena; HUD e
crachá ao tipo `Visitor`; posição do crachá ao canvas 2D; progressão/cheats à
variável estática do controlador original; cadência da Marta ao elevador 2D;
disponibilidade do botão experimental somente à chegada espacial.

Há duas implementações de movimento/porta **de apresentação**, necessárias a
mundos diferentes. Não unificá-las por herança só para eliminar nomes parecidos.
O risco de duplicação de negócio surgirá se o harness e o controlador original
forem mantidos como duas autoridades de seleção/avanço no mesmo jogo.
`DENY_ACTION`, `DENY_CODE` e `MartaRule.NEGAR` repetem 999 em scripts diferentes;
preservar compatibilidade e verificar igualdade, sem refatoração incidental agora.

## 6. Classificação de reutilização

“DIRETA” considera compartilhamento do contrato existente; não significa que já
esteja conectado ao experimento. Caminhos agrupados mantêm o prefixo explícito.

| Sistema | Arquivos | Estado atual | Reutilização | Adaptação necessária | Risco |
| --- | --- | --- | --- | --- | --- |
| Validação | `src/shared/scripts/rule_validator.gd` | Funcional, sem nós visuais | DIRETA | Chamar com a mesma visita, dia e regras; código de andar separado da cabine. | Alto se tags/conteúdo forem “corrigidos” na migração. |
| Dados/nomes | `src/npcs/resources/scripts/visitor_data.gd`, `src/npcs/resources/scripts/name_list.gd`, recursos ativos da seção 3.2 | Gera snapshot por visita | DIRETA | Preservar o snapshot; definir representação visual separada para PackedScene 2D. | Médio: ressortear nome/foto/crachá gera divergência. |
| Agenda e interações | `src/gameplay/scripts/day_schedule.gd`, `src/gameplay/scripts/day_interaction.gd`, três agendas da seção 3.2 | Sorteio e casos de regras implementados | DIRETA | Uma chamada a `montar_dia()` por sessão; entrada física é responsabilidade da apresentação. | Alto: recurso compartilhado, listas exportadas, sorteios independentes. |
| Regras da Marta | `src/gameplay/scripts/marta_rule.gd` | Recurso de efeito/lore | DIRETA | Ativar só após o anúncio, como hoje. | Alto: antecipar ativação altera respostas corretas. |
| Dados de diálogo | `src/npcs/dialogue/npc_dialogue.gd`, bancos da seção 3.3 | Texto + pedido, sem escolhas | DIRETA | Disparar somente ao chegar ao serviço. | Baixo. |
| Fala global | `autoload/dialogue/dialogue.gd`, `autoload/dialogue/dialogue.tscn` | Overlay independente do ator | DIRETA | Integrar início/limpeza/espera; validar modais e pausa na nova composição. | Médio: finished não é decisão; espera antiga. |
| Controle de atendimento/dia | `src/gameplay/reception/scripts/reception_manager.gd` | Implementado e fortemente ligado ao 2D | REFATORAÇÃO | Extrair sessão por partes e conservar fachada 2D. | Alto: reentrância, async, compatibilidade estática. |
| Visitante visual original | `src/npcs/scripts/visitor.gd`, `src/npcs/scenes/visitor.tscn` | Node2D/tweens/bob/escala | ESPECÍFICO 2D | Manter no 2D; outro ator apresenta o mesmo snapshot em 3D. | Médio: foto e tipo usados pelo HUD precisam desacoplar. |
| HUD/crachá | `src/gameplay/hud/scripts/reception_hud.gd`, `src/gameplay/hud/scripts/badge_details.gd`, cenas da seção 3.4 | Funcionais, tipados Visitor | REFATORAÇÃO | API de dados/retrato + origem em tela; separar mesa 2D da UI compartilhada. | Alto: captura do mouse, callbacks/tweens com ator destruído. |
| Painel/Buttons | `src/gameplay/hud/scripts/elevator_panel.gd`, `src/gameplay/hud/scripts/elevator_button.gd`, cena da seção 3.8 | Decide andar/recusa com confirmação | ADAPTAÇÃO | Reusar contrato; compor no overlay principal e garantir trava de sessão. | Médio: confirmar enquanto troca visita ou abre crachá. |
| Livro/diretório | `src/gameplay/hud/scripts/company_book.gd`, `src/gameplay/hud/scenes/company_book.tscn`, recursos/scripts da seção 3.8 | Consulta sem ator | DIRETA | Reposicionar por composição, sem alterar regra. | Baixo; legibilidade/área de clique. |
| Prancheta | `src/gameplay/hud/scripts/rules_board.gd`, `src/gameplay/hud/scenes/rules_board.tscn` | Texto e animação/atalho | DIRETA | Alimentar pela mesma sessão; revisar layer/área e trava da câmera. | Médio: Esc/foco e sobreposição ao crachá. |
| Elevador visual original | `src/gameplay/scripts/elevator.gd`, `src/gameplay/scenes/elevator.tscn` | Entrada/saída concorrentes, escala e clipping 2D | ESPECÍFICO 2D | Preservar; mapear contratos de chegada/saída no adaptador 2.5D. | Alto se substituir por simples porta 3D sem ocupação. |
| Marta (orquestração) | `src/gameplay/reception/scripts/reception_manager.gd`, `src/npcs/scenes/marta.tscn` | Sequências próprias misturadas a Node2D | REFATORAÇÃO | Separar evento narrativo de apresentação de ator/efeito; criar apresentação 2.5D. | Alto: release, exclusão mútua e instante de ativação de regra. |
| Áudio/transição | `autoload/audio/audio.gd`, `autoload/scene_transition/scene_transition.gd`, cenas da seção 2.3; `sounds/music/menu/music_menu.gd` | Globais funcionais | DIRETA | Comandar nos mesmos momentos; encerrar música do menu no F6 integrado. | Médio: áudio persistente e cena anterior ainda executando. |
| Pause/cheat/entrada | Arquivos das seções 2.3 e 3.8; `src/ui/menus/scripts/menu.gd` | Roteamento atual 2D | ADAPTAÇÃO | Pause reutilizável; tutorial/cheat/menu mantêm 2D até aprovação da troca de destino. | Alto: testes podem voltar ao 2D sem perceber. |
| Tutorial visual | `src/gameplay/tutorial/scripts/tutorial.gd`, cena/recursos da seção 3.8 | Destaques e atores 2D | ESPECÍFICO 2D | Migrar sua apresentação depois do gameplay; texto/roteiro são reaproveitáveis. | Médio; fora da primeira fatia. |
| Movimento/PAPER | `src/gameplay/reception_25d/scripts/visitor_movement.gd`, `src/gameplay/reception_25d/scripts/visitor_orientation.gd` | Funcionais para referência única | ESPECÍFICO 2.5D | Associar visita, configurar aparência; conclusão identificada e eventual multiator. | Médio/alto: offset, reset global, P por instância. |
| Portas/cabines | `src/gameplay/reception_25d/scripts/automatic_door.gd`, `src/gameplay/reception_25d/scripts/elevator_door.gd`, cenas da seção 4.2 | Mecânica espacial implementada | ESPECÍFICO 2.5D | Adicionar orquestração de retorno/saída/ocupação sem mudar geometria. | Alto: direction do clearance, interrupções e uso compartilhado. |
| Seleção espacial | `src/gameplay/reception_25d/scripts/elevator_selection.gd`, `src/gameplay/reception_25d/scripts/elevator_selection_ui.gd` | Escolhe cabine, nunca valida decisão | ADAPTAÇÃO | Separar autorização do comando físico; só despachar após resultado válido. | Alto se índice for tratado como andar. |
| Harness e sprite de teste | `src/gameplay/reception_25d/scripts/visitor_movement_test.gd`, `src/gameplay/reception_25d/scripts/test_sprite.gd` | Debug de um ator, sem dados | ESPECÍFICO 2.5D | Harness restrito ao teste; aproveitar alinhamento do sprite numa apresentação com setup. | Alto se R/1/2 continuar controlando sessão real. |
| Câmeras | `src/gameplay/reception_25d/scripts/reception_camera.gd`, `src/gameplay/reception_25d/scripts/debug_free_camera.gd` | Normal e exploração implementadas | ESPECÍFICO 2.5D | Compor bloqueio por modal; debug optativo. | Médio: RMB/foco/bordas durante crachá, pause ou fala. |

## 7. Proposta de arquitetura

### 7.1 Separação mínima recomendada — ainda não implementada

Um controlador de sessão compartilhado, pertencente à cena e liberado com ela,
mais uma apresentação por versão. **Não adicionar outro Autoload de gameplay**
nem um barramento global de eventos. O `RuleValidator` permanece a única regra
de decisão; agendas e recursos existentes continuam sendo as fontes de conteúdo.

Nomes de arquivos abaixo são **propostas, ainda inexistentes**:

- `src/gameplay/scripts/reception_session.gd`: Node sem coordenadas/ator visual;
  possui fila, visita atual, dia, regras ativas, contagem e fase de atendimento.
- `src/gameplay/reception_25d/scripts/reception_presentation.gd`: adaptador da
  cena experimental, ligando dados da visita a ator, trajetos, portas e UI.
- `src/gameplay/reception_25d/scenes/reception_gameplay_test.tscn`: cena de teste
  herdando a recepção experimental, para executar as fatias com F6 sem trocar F5.
- A fachada 2D pode permanecer em `ReceptionManager`, delegando gradualmente
  a sessão e mantendo os métodos chamados pela cena/tutorial até migrá-los.

Não usar o esqueleto 2.5D como uma cópia do manager original de 655 linhas.
Não pôr regras nas portas, no Sprite3D nem no script da câmera. O adaptador sabe
onde e como apresentar; a sessão sabe quem atende, quando aceita decisão e qual
é o resultado. UI emite intenção, não libera movimento por conta própria.

### 7.2 Contrato proposto entre sessão, UI e apresentação

Nomes conceituais de sinais/comandos, **não APIs atuais**:

| Direção | Mensagem proposta | Responsabilidade |
| --- | --- | --- |
| Sessão → apresentação | `visit_requested(visit_id, entry)` | Criar/configurar um ator com o snapshot já sorteado. |
| Apresentação → sessão | `service_reached(visit_id)` | Abrir atendimento somente se id e fase forem válidos. |
| UI → sessão | `submit_decision(visit_id, floor_code)` | Validar uma única vez por visita, após chegada, sem crachá/modal bloqueante. |
| Sessão → apresentação | `decision_resolved(visit_id, floor_code, correct)` | Aplicar saída/embarque ou sequência de falha; cabine escolhida separadamente. |
| Apresentação → sessão | `departure_finished(visit_id)` | Confirmar liberação física; cabine chegou ao destino interno e porta terminou conforme política aprovada. |
| Sessão ↔ apresentação | Solicitação e conclusão de evento da Marta | A sessão mantém a regra pendente; apresentação controla ator/fala; a ativação ocorre no marco equivalente ao original. |

Um contador simples de visita e uma geração de reset/cancelamento bastam para
descartar eventos antigos; `VisitorData.id` não serve para isso. Não é necessário
introduzir framework de eventos, ECS ou vários gerenciadores globais.

Estados de sessão sugeridos: introdução, chegada, atendimento, resolução/saída,
evento de Marta, encerramento, falha e transição. São diferentes de
`ElevatorSelection.Stage` e `Door.State`, que continuam estados locais de
apresentação. `can_select` espacial não destrava sozinho o painel de gameplay.
Cada início/finalização precisa ser idempotente e ter cancelamento no reset/saída
de cena; comandos inesperados devem ser ignorados, não avançar a fila.

### 7.3 UI no viewport principal

Manter livro, prancheta, painel, crachá, fala e pause em Controls/CanvasLayer do
viewport principal. `RoomView` é um Sprite2D, **não SubViewportContainer**: não
reencaminha automaticamente cliques para controles ou objetos do mundo 3D.
`handle_input_locally=false` não cria esse encaminhamento. Não há necessidade
de clicar no mundo para integrar a primeira fatia de atendimento.

Para animar o crachá a partir do ator 3D, propor uma âncora de apresentação:
`Camera3D.unproject_position(ponto_global)` fornece pixels do SubViewport;
na configuração atual, converter esses pixels com o transform de canvas de
`RoomView`, e então pelo inverso do transform de canvas da UI. Considerar
visibilidade/atrás da câmera e clipping antes de usar a âncora. Se a apresentação
do RoomView mudar (escala, região, centralização), a conversão deve acompanhá-la.
Não multiplicar por 1920/640 manualmente e não usar diretamente posição global
3D como coordenada do HUD. Validar no stretch real e janela redimensionada.

A API dos detalhes deve receber dados/retrato em vez de `Visitor`. A mesa 2D
não precisa ser duplicada sobre a geometria: compartilhar componentes da HUD,
não necessariamente a cena completa com `Desk`. Preservar a cena 2D durante a
extração e testar a animação de devolução com ator em movimento/destruído.

Definir prioridade modal explícita para crachá, prancheta, pause, cheat e
transição. O bloqueio da câmera hoje olha apenas hover dos três botões.
Suspender bordas/exploração durante modais de atendimento, sem disputa entre
scripts que guardam/restauram `set_process`. Revisar P: hoje PAPER consome a
mesma tecla do cheat; múltiplas instâncias desse script não podem cada uma
tratar/consumir P de forma independente.

### 7.4 Andar, cabine e saída

Guardar `floor_code` da decisão independentemente de `cabin_index`. Não atribuir
destinos 1/2/3 às três cabines por conveniência. Nenhum código auditado impõe
cabine especial para subsolo, Tião ou Marta. Introduzir tal restrição seria uma
nova decisão de design, não uma integração fiel.

Recomendação para a primeira fatia: cabine 1 como escolha técnica fixa apenas
no cenário de validação aprovado; depois definir escolha automática ou explícita
entre cabines, sempre separada do painel de andares. Não adicionar ainda viagem
de cabine ou novas cenas de destino: o original apenas representa a entrada.

Recusa correta exige trajeto de retorno ao acesso; erro exige saída e evento
de falha, não embarque “mesmo assim”. Marta exige saída de cabine para a sala.
Nenhum desses dois trajetos inversos está implementado no experimento.

## 8. Fluxo futuro de atendimento

Este é um fluxo **proposto**, mantendo as decisões encontradas. A introdução ou
regra pendente de Marta ocorre antes de liberar a próxima visita correspondente.

| Passo | Comportamento proposto | O que existe / o que falta |
| --- | --- | --- |
| 1. Selecionar | Sessão obtém a próxima entrada da fila única, com nome/sprite/crachá já fixados para aquela visita. | Geração de fila e pop existem no original; mover a propriedade para sessão compartilhada, sem outro sorteio. |
| 2. Criar ator | Adaptador configura aparência e âncora de chão do ator 2.5D, associando visit_id. | Só há TestVisitor estático; falta setup de apresentação e vínculo dos dados. |
| 3. Entrar | Apresentação escolhe acesso por política aprovada, abre a porta, espera OPEN e percorre os marcadores existentes. | Mecânica de entrada pronta no harness; política de entrada não existe no gameplay original. |
| 4. Chegar ao balcão | `arrived` do trajeto certo se traduz em chegada ao ServicePoint para o visit_id atual. | Movimento/orientação prontos; falta evento de contrato e identificação da visita. |
| 5. Iniciar atendimento | Sessão passa à fase de atendimento e apresenta a fala; HUD recebe snapshot/retrato. | Original possui esse marco no DeskPoint; falta conexão 3D e adaptação do crachá. |
| 6. Inspecionar/decidir | Livro/prancheta/crachá permanecem consultáveis; painel emite andar ou recusa. Modais impedem despacho/câmera indevidos. | UI e códigos existem; falta composição e bloqueio integrado. Não há opções de resposta de diálogo a implementar por migração. |
| 7. Resolver | Sessão chama o mesmo `RuleValidator` com dia/regras ativos, uma vez por visita. | Validação existe; falta endpoint compartilhado consumido pelo adaptador. |
| 8. Reagir | Resultado correto preserva feedback de sucesso; incorreto inicia falha e reação da Marta. | Feedback/sequência existem em 2D; não existe reação animada específica de visitante a reproduzir em Sprite3D. |
| 9. Sair/embarcar | Andar/subsolo corretos → cabine escolhida separadamente; recusa correta → acesso de saída; erro → saída de falha e interrupção do dia. Marta usa rota própria de saída/entrada da cabine. | Embarque experimental existe; retorno ao exterior, saída da cabine e controle de ocupação faltam. Não unificar todos os resultados num destino único. |
| 10. Encerrar/avançar | Registrar resolução uma vez e receber liberação física; respeitar a política de cadência antes de próxima visita, Marta ou fim de dia. | Original conta logo após decisão e permite saída concorrente; experimento não conclui sessão, não libera o ator e não avança a fila. Política de sincronização precisa aprovação. |

Ativar a regra da Marta somente no marco correspondente ao fim do anúncio,
não no momento de sorteá-la. Não incrementar `_served_count` por `arrived`,
clique de cabine, início de tween ou simples mudança para IN_CABIN. A sessão
deve distinguir “decisão contabilizada” de “ator liberou a passagem”. No fim
do dia, aguardar a liberação necessária para a próxima sequência, como o
original já faz via `is_busy()` em partes da orquestração.

## 9. Plano incremental de integração

**Todas as etapas abaixo são futuras.** Executar uma por vez após aprovação,
com diff próprio e F6 antes de seguir. Usar os caminhos reais das seções anteriores;
arquivos novos da seção 7 são propostas. Não alterar agendas, arte, velocidade,
PAPER, geometria ou 2D incidentalmente para fazer uma etapa passar.

### I0 — Fixar contratos e casos de regressão

- **Objetivo:** estabelecer referências de negócio antes da extração.
- **Sistemas/arquivos prováveis:** testes de agenda/validação e roteiro da cena
  original; recursos/scripts das seções 3.1–3.7, somente como fontes de teste.
- **Dependências:** aprovar casos e critérios; nenhuma mudança em gameplay.
- **Alterações propostas:** testes com seed ou entradas congeladas, comparando
  fila, regras e decisões; registrar contrato de sinais e momentos de ativação.
- **Riscos:** comparar duas chamadas independentes de `montar_dia()` como se
  fossem a mesma fila; testes que apenas espelham a implementação.
- **Testes:** casos antes/depois de anúncio, recusa por regra/tag, subsolo,
  Lucas dia 1, entregador dia 2 e Tião dia 3; confirmação duplicada; F6 do 2D
  com introdução, crachá, erro/reload e fim de dia. Testar recursos sem regravá-los.
- **Aceite:** expectativas sustentadas pelo validador/conteúdo, baseline 2D
  registrado, nenhuma alteração de dados. Inconsistências permanecem explícitas.

### I1 — Extrair a autoridade de atendimento, mantendo o 2D

- **Objetivo:** compartilhar fila, snapshot, regras ativas, contagem e decisão
  sem separar de uma vez toda a coreografia de Marta/efeitos.
- **Sistemas/arquivos prováveis:** proposta `reception_session.gd`, controlador
  e cena originais; testes de I0. Recursos e `RuleValidator` permanecem intactos.
- **Dependências:** I0 e aprovação do limite da extração/compatibilidade estática.
- **Alterações propostas:** o manager 2D delega à sessão e mantém apresentação;
  chamadas de anúncio/fim continuam na fachada, informando marcos à sessão.
  Manter uma única propriedade de fila/visita/contagem, não duas cópias sincronizadas.
  Conservar a entrada `dia_em_andamento` até migrar tutorial/cheat conjuntamente.
- **Riscos:** contar duas vezes, destravar painel cedo, alterar sorteio ou instante
  de regra; wrappers ocultando duas autoridades.
- **Testes:** contratos de I0, F6 original nos três dias, recusa correta, erro,
  crachá durante confirmação, F9, menu/cheat e chamadas de Marta.
- **Aceite:** 2D conserva decisões e fluxo; sessão não conhece Vector2/Vector3,
  Sprite2D/Sprite3D ou nós concretos da HUD. Mesma visita não resolve duas vezes.

### I2 — Alimentar um ator 2.5D e parar no ServicePoint

- **Objetivo:** primeira fatia visual conectada aos dados reais, sem despacho.
- **Sistemas/arquivos prováveis:** propostas `reception_gameplay_test.tscn` e
  `reception_presentation.gd`; `test_sprite.gd`, `visitor_movement.gd`,
  `visitor_orientation.gd`, `visitor_movement_test.gd` somente se precisarem
  de limites explícitos de modo de teste/configuração. Cena base preservada.
- **Dependências:** I1; política inicial de entrada aprovada.
- **Alterações propostas:** instanciar a sessão, configurar um ator com a entrada
  sorteada, reaplicar textura/alinhamento; usar rota existente até serviço;
  desativar harness 1/2/R e despacho automático dos botões nessa cena integrada.
  A cena experimental antiga conserva seus controles.
- **Riscos:** dois emissores controlarem o mesmo ator, altura errada para sprites
  diferentes, perda de snapshot, conclusão de uma rota antiga aplicada à nova.
- **Testes:** F6 da cena integrada com duas entradas e aparências diferentes,
  reset durante porta/rota e chegada única; teste programático de mesma
  sequência/snapshot; F6 original e experimento sem regressão.
- **Aceite:** uma visita real chega ao serviço, PAPER e velocidade 3 preservados,
  próxima fase só abre para a chegada esperada. Sem embarque por clique experimental.

### I3 — Compor atendimento, fala e inspeção

- **Objetivo:** inspecionar a visita parada sem depender de um Visitor Node2D.
- **Sistemas/arquivos prováveis:** `reception_hud.gd`, `badge_details.gd`, cenas
  correspondentes, painel, livro/prancheta, adaptador proposto e cena de teste.
- **Dependências:** I2; aprovação da composição de HUD e prioridade modal.
- **Alterações propostas:** APIs de crachá por dados/retrato; origem em tela
  fornecida por cada apresentação; reutilizar componentes sem duplicar mesa 2D;
  apresentar fala e painel ao chegar. Enviar decisão à sessão, mantendo
  despacho físico bloqueado até I4.
- **Riscos:** quebrar API 2D, projeção/stretched coordinates, sobreposição de
  CanvasLayers e mouse/câmera, Enter/Space de foco roubando avanço de fala.
- **Testes:** F6 2D e 2.5D com crachá abrir/fechar/devolver, textos longos,
  livro, Esc na prancheta/pause, janela redimensionada, confirmação duplo clique,
  exploração durante modal e foco perdido.
- **Aceite:** nome/foto/crachá iguais ao snapshot; painel indisponível antes
  do serviço e enquanto modal bloqueia; decisão validada uma vez; UI legível
  na base 640×360 sem mover a câmera de forma involuntária.

### I4 — Aplicar resultados e concluir uma visita

- **Objetivo:** despacho correto, retorno de recusado e fim espacial confiável.
- **Sistemas/arquivos prováveis:** adaptador proposto, `elevator_selection.gd`,
  `elevator_selection_ui.gd`, `visitor_movement.gd`, `automatic_door.gd`,
  `elevator_door.gd`, cena de teste e testes de rotas.
- **Dependências:** I3; aprovar política de cabine e cadência piloto serial.
- **Alterações propostas:** separar andar de cabine; usar cabine 1 apenas no
  primeiro teste aprovado; conectar resultado válido à rota existente;
  implementar retorno pela entrada com clearance de saída apropriado e limpeza
  de ator. Confirmar chegada interna e fechamento antes da liberação definida.
  Erro mantém controle bloqueado para a etapa de falha, não despacha como sucesso.
- **Riscos:** tratar fechamento iniciado como concluído, fechar sobre sprite,
  usar clearance de entrada ao contrário, resetar portas de outro fluxo.
- **Testes:** F6 andar normal, subsolo e recusa correta; testes de invariantes em
  duas entradas/três cabines quando habilitadas, interrupções de tween e reset;
  receber chegada/fechamento em ordens diferentes sem avançar duas visitas.
- **Aceite:** regra única resolve e apresentação executa o destino correto;
  decisão e cabine não se confundem; ator libera passagem e próxima visita
  não herda seleção/fala/crachá. Serialização piloto não muda a versão 2D.

### I5 — Apresentar Marta e ativar regras no momento certo

- **Objetivo:** introdução e anúncio periódico com ator dedicado 2.5D.
- **Sistemas/arquivos prováveis:** fachada original/sessão/adaptador propostos,
  ator de apresentação, `visitor_orientation.gd`, `elevator_door.gd` e cena de teste.
- **Dependências:** I4; aprovar entrada/saída de Marta e exclusão mútua de cabine.
- **Alterações propostas:** implementar saída da cabine para o ponto da Marta
  e retorno, sem usá-la como visitante comum da fila; configurar sprites de
  evento; compartilhar sequência de anúncio e ativação após avanço do jogador.
  Antes de múltiplos atores ativos, retirar atalhos globais de componentes por ator.
- **Riscos:** Marta disputar passagem/ator, evento ativar regra cedo ou ficar
  esperando sinal do visitante, frame/crachá de Marta substituir o de outra visita.
- **Testes:** F6 introdução, regra após dois atendimentos, caso garantido e
  ausência de anúncio após o último; bloquear/adiar enquanto cabine ocupa,
  interromper durante fala/saída; regressão de Marta em 2D.
- **Aceite:** uma regra é anunciada/ativada/anotada uma vez; fala e ativações
  equivalentes ao 2D; nenhuma visita comum criada para representar Marta.

### I6 — Integrar falha, fim do dia e progressão

- **Objetivo:** completar a fatia narrativa e a limpeza de sessão.
- **Sistemas/arquivos prováveis:** sessão/fachadas, efeitos de apresentação,
  cena de teste, `Dialogue` e `SceneTransition` como serviços; recursos de dia intactos.
- **Dependências:** I5 e decisões sobre efeitos/estado entre cenas.
- **Alterações propostas:** resultado errado causa saída e sequência de falha;
  reload mantém o dia, invalida ids antigos e libera mouse. Encerramento espera
  circulação necessária, apresenta sprite/som/overlay e avança usando a
  apresentação escolhida, até `cena_final`. Reaproveitar overlays antes de propor
  nova coreografia de luzes 3D, que precisaria de aprovação própria.
- **Riscos:** esperas pendentes mostrarem fala da cena anterior, sessão não
  resetar, estático apontar para outro dia, áudio/menu continuar indevido.
- **Testes:** F6 nos dias 1–3, erro em cada fase, reload e novo sorteio no mesmo
  dia, dia 1→2→3→final, pause/menu durante Marta/tween/fade; repetir 2D.
- **Aceite:** nenhuma regra/contagem/visita antiga sobrevive ao reload indevido;
  progressão e derrota têm os mesmos critérios de negócio do original.

### I7 — Resolver cadência e uso das três cabines

- **Objetivo:** sair do piloto de um ator com política explícita de circulação.
- **Sistemas/arquivos prováveis:** adaptador, controles espaciais/ocupação,
  seleção de cabine e testes; sessão compartilhada só no contrato de prontidão.
- **Dependências:** I6; aprovar serialização definitiva ou sobreposição equivalente
  ao 2D e seleção automática/por jogador das cabines.
- **Alterações propostas:** se serial aprovado, conservar um ator de visitante
  e liberar a próxima visita após saída; se sobreposição aprovada, instanciar
  movimento/orientação por ator e controlar uso/espera por cabine. Eliminar
  resets globais durante trânsito. Não introduzir restrições de andar por cabine.
- **Riscos:** concorrência entre Marta e visitantes, P consumido por uma única
  instância, chamada de próximo visitante pelo evento de outro ator.
- **Testes:** F6 com sequência longa, cabines simultaneamente indisponíveis,
  Marta aguardando e reset no embarque; nenhum fechamento sobre passagem;
  início/fim de atendimento e contagem independentes do número de atores.
- **Aceite:** política aprovada observada sem teletransportar ator nem fechar
  todas as portas para iniciar uma visita; decisões continuam iguais no 2D.

### I8 — Integrar entradas de aplicação e revisar regressões

- **Objetivo:** habilitar 2.5D como apresentação escolhida somente após as fatias.
- **Sistemas/arquivos prováveis:** `src/ui/menus/scripts/menu.gd`,
  `src/gameplay/tutorial/scripts/tutorial.gd`, `autoload/cheat_menu/cheat_menu.gd`,
  caminho/compatibilidade estática do manager, cenas de UI/teste e README futuro.
- **Dependências:** I7 e aprovação explícita da seleção padrão/menu/tutorial.
- **Alterações propostas:** centralizar a escolha de apresentação sem duplicar
  dia global; adequar destino do tutorial/cheat, pausa e atalhos de debug;
  manter um acesso testável ao 2D. Não mudar F5/main_scene silenciosamente.
- **Riscos:** iniciar sempre 2D, tutorial destacar UI errada, cheat descartar
  apresentação, build conter teclas destrutivas de teste.
- **Testes:** F6 nas duas recepções e depois F5 menu→tutorial→jogo, skip tutorial,
  cheat para cada dia, retorno ao menu, final e reinício; regressão visual/manual
  e headless em cópia com autoloads conforme seção 12 de `CLAUDE.md`.
- **Aceite:** apresentação selecionada consistente nas transições, 2D ainda
  funcional e gameplay único; decisão de tornar 2.5D padrão documentada/aprovada.

## 10. Riscos e decisões pendentes

### 10.1 Riscos técnicos

| Risco | Evidência atual | Mitigação proposta / verificação futura |
| --- | --- | --- |
| Dupla autoridade | Manager 2D seleciona/avança; harness 2.5D também inicia/reseta ator. | Desligar harness na cena integrada, uma sessão dona da fila; teste de chamada duplicada. |
| Estados confundidos | `is_processing_decision`, fase espacial e enum de porta têm significados distintos. | Contratos identificados por visita; não contar chegada/fechamento como nova decisão. |
| Índice vira andar | Botões 2.5D enviam índice, original envia código com −1/999. | Campos separados e teste de decisão igual para cabines diferentes. |
| Acoplamento de UI | HUD/crachá recebem Visitor e canvas transform de Node2D. | API por snapshot/retrato e âncora projetada; testar versão 2D após cada adaptação. |
| Reset destrutivo espacial | `movement_reset` faz seleção fechar as três portas; ator é único. | Reset por sessão/ator com cancelamento; não promover esse fluxo a multiator sem adaptação. |
| Falta de evento de conclusão | `arrived` genérico; seleção termina monitoramento antes do fim da animação. | Agregar chegada/clearance/estado CLOSED no adaptador; conclusão exatamente uma vez. |
| Sinais antigos | Callback de crachá/ator pode disparar depois de trocar visita. O original já desconecta `arrived` na saída. | Manter desconexão, identidade e geração; limpar conexões/tweens no teardown. |
| Async durante troca | `await`, timers e fade permitem cena antiga ainda executar; `_saindo` protege parte do original. | Cancelar sessão, limpar Dialogue e invalidar resultados; testar F9/menu/pause em todos os marcos. |
| Sobreposição/ocupação | Original recebe sem await; elevador 2D mantém `_em_uso`; 3D não tem equivalente. | Aprovar cadência, piloto serial e depois controle explícito; não assumir paridade de tempo. |
| Marta | Fluxo de release separado, efeitos e entrada de regra depois do anúncio. | Ator/evento dedicados e reserva de cabine; testes antes/depois de ativação. |
| Conteúdo divergente | Tag `entregador`, diálogo −1, `birdTest` fixo e mensagem final do dia 1. | Preservar expectativas do código, abrir eventual correção como tarefa de conteúdo separada. |
| Recursos compartilhados | Resource de VisitorData aparece em várias entradas; agendas possuem listas exportadas. | Snapshot por visita; não gravar dados temporários no Resource nem regravar agendas pelo editor. |
| Atlas/aparências | Cenas visuais 2D podem ter AnimatedSprite2D, escala/offset próprios; teste 3D só usa imagem. | Definir política de sprite/retrato e suporte futuro; manter contato com piso e PNG/import original. |
| Input/foco | P conflita intencionalmente, F/R/1/2 são debug, câmera usa mouse da janela, Layers repetem 10. | Política modal e controles de debug por contexto; teste de RMB, Esc, ui_accept, hover e perda de foco. |
| Estado estático | Tutorial/cheat dependem diretamente de ReceptionManager; F6 pode herdar dia na mesma execução. | Compatibilidade temporária, inicialização explícita da cena de teste e só depois migrar roteamento. |
| Validação por cache | `CLAUDE.md` documenta UIDs/caminhos, classes novas e perda de listas ao salvar. | Mudanças textuais mínimas; import/testes em cópia com 4.7.2, hash das agendas e inspeção de referências reais. |

Os procedimentos da seção 9 de `CLAUDE.md` são parte do plano: preservar UIDs,
IDs, arrays e finais de linha, não regravar recursos para trocar um caminho,
registrar original de agendas e parar se houver diferença não autorizada. Na
seção 12 há a restrição de testes `-s` com autoloads: carregar o script do
manager dinamicamente evita compilar acesso a `Audio` antes da inicialização
esperada. Usar os caminhos atuais desta auditoria, não os exemplos antigos.

### 10.2 Decisões a aprovar antes das respectivas etapas

| Decisão | Recomendação fundamentada | Marco |
| --- | --- | --- |
| Limite do núcleo compartilhado | Um Node de sessão local à cena; recursos e validador existentes; manager 2D permanece fachada durante a extração. Reduz ruptura de tutorial/cheat e evita estado global extra. | Antes de I1. |
| Preservar inconsistências de conteúdo | Manter semântica auditada e registrar Lucas/entregador/Tião como casos de regressão. Qualquer ajuste de tags ou mensagens deve ser aprovado separadamente. | Antes de fixar expectativas de I0/I1. |
| Cena de experimentação integrada | Criar cena herdada para F6, mantendo cena experimental e F5 originais até revisão final. Não ligar regras reais ao harness existente. | Antes de I2. |
| Distribuição entre entradas | Inicialmente escolher explicitamente uma entrada de teste e testar as duas; depois política simples configurável. Não há entrada canônica por NPC nas agendas. | Antes de I2. |
| Composição da HUD | Reusar livro/prancheta/painel/crachá como overlays, sem a mesa 2D por cima do balcão; adaptar API de crachá sem remover suporte 2D. | Antes de I3. |
| Escolha da cabine | Primeiro teste fixa cabine 1; depois automático ou escolha do jogador, sempre independente de andar. Recomendação de design técnico: automático reduz uma decisão sem equivalente no original, mas depende de aprovação. | Antes de I4 e política completa antes de I7. |
| Cadência e concorrência | Piloto serial para validar contratos; não declarar equivalência temporal ao 2D. Se a sobreposição original for requisito, implementar ocupação por cabine/múltiplos atores antes de considerar migração concluída. | Antes de I4; decisão definitiva antes de I7. |
| Rota de recusa/falha | Voltar ao acesso de origem no piloto, preservando o sentido da saída original; erro interrompe o dia e chama Marta. Testar clearance exterior, ainda inexistente. | Antes de I4. |
| Marta e efeitos | Ator dedicado, saída de cabine implementada e espera de ocupação; ativação de regra após fala. Reutilizar overlay/SFX primeiro, sem redesign de iluminação. | Antes de I5/I6. |
| Persistência/entrada de dias | Conservar compatibilidade estática até haver ponto único de escolha de apresentação; não adicionar save de progresso nesta migração. | Antes de I6/I8. |
| Debug e troca da apresentação padrão | Debug separado da sessão integrada e bloqueado em modais. Remapear P/cheat de forma aprovada; decidir tutorial/menu e manutenção do acesso 2D somente ao final. | Antes de I3 para modais, antes de I8 para destino padrão. |

## 11. Recomendações finais

Começar por contratos/regressões e separação mínima do atendimento; depois
uma visita real chega ao serviço, recebe UI, decisão e saída, antes de adicionar
Marta, falha/progressão e concorrência. Não transformar a escolha das três
cabines em nova regra de negócio nem inventar validação de crachá/árvore de diálogo.

Reutilizar diretamente o conteúdo e o validador é o maior ganho imediato.
O maior trabalho está na fronteira entre orquestração, UI tipada em Visitor,
circulação inversa e cadência: esses limites precisam de contrato e testes,
não de cópia do controlador original para a cena 3D.

A recepção 2D permanece referência funcional durante todas as etapas. Concluir
cada fatia com F6 das apresentações afetadas e testes necessários em cópia
temporária; não repetir validações sem motivo nem misturar revisão de assets.

**Validação documental desta etapa:** documento no caminho solicitado;
conferência dos arquivos reais referenciados, métodos/sinais usados como
evidência e distinção explícita de APIs futuras; comparação de hashes para
preservar o estado inicial; `git diff --check` e estado final do Git. O documento
novo, ainda não rastreado, também foi conferido quanto a whitespace. As referências
de arquivos existentes foram resolvidas; os três arquivos propostos e os dois
diretórios legados foram explicitamente identificados, sem tratá-los como existentes.
Não houve alteração de projeto para executar a auditoria, execução de gameplay,
limitação de acesso, commit ou push. Aguardar revisão deste plano para iniciar I0/I1.
