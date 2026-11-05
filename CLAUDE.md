# CLAUDE.md — Coffee & Games (GameJamPlus 2026/27)

Guia do projeto para quem vai mexer no código (pessoas e agentes de IA).
Leia inteiro antes de alterar cenas, recursos ou scripts: a seção **Problemas técnicos**
lista armadilhas reais que já quebraram o projeto.

---

## 1. O jogo

| | |
|---|---|
| Jam | GameJamPlus 2026/27 — 16 a 18/10/2026, build até 18/10 às 23h59 |
| Tema | *Something's Off* ("alguma coisa está errada") |
| Gênero | Dedução / inspeção / suspense psicológico (refs.: Papers, Please; That's Not My Neighbor) |
| Engine | **Godot 4.7.2**, GDScript; único plugin: GUT (`addons/gut`, só testes) |
| Equipe | Rodrigo (game design), Mari (HUD), Clara (sprites), Gustavo e Daniel (programação) |

**Premissa.** O protagonista está desempregado há seis meses e aceita uma vaga de recepcionista
"boa demais para ser verdade" num prédio comercial de seis andares. Na recepção, cada visitante
diz para onde quer ir; o jogador confere o livro de andares, as regras do dia e o crachá, e escolhe
o andar no painel do elevador (ou nega o acesso).

**Marta** é a supervisora: simpática na superfície, mas é a **vilã**. Ela aparece no começo do dia,
a cada 2 atendimentos para ditar **regras suspeitas** (ex.: "quem pedir o 5º andar, mande para o
subsolo... eles vão entender quando chegarem lá"), quando o jogador erra e no fim do dia.
O subsolo é um "pavimento não atribuído" que oficialmente não existe.

**Andares do prédio** (fonte: tabela do game designer, em `src/gameplay/resources/company_directory.tres`):

| Andar | Setor | O que é |
|---|---|---|
| Subsolo (-1) | Pavimento Não Atribuído | "Acesso desativado para circulação regular. Não apertar sem autorização superior." |
| 1º | Área Comum | Refeitório, descanso, entregas e pedidos |
| 2º | Recursos Humanos & Contabilidade | Admissões, papelada, rescisões, contratos |
| 3º | Tecnologia & Desenvolvimento | Servidores, suporte, programação, infraestrutura |
| 4º | Marketing & Relações Públicas | Comunicação visual, publicidade, imprensa |
| 5º | Arquivo Morto & Pesquisa Avançada | Acesso restrito, dados confidenciais |
| 6º | Presidência / Diretoria Executiva | Gabinete do diretor geral |

---

## 2. Fluxo do jogo (cenas)

```
menu.tscn ──Jogar──▶ tutorial_3d.tscn ──fim ou "Pular tutorial [Esc]"──▶ (SceneTransition: "Dia 1") ──▶ reception_3d.tscn
	│                                                         (dia 1 → dia 2 → dia 3, mesma cena)
	└─Opções──▶ options.tscn ──Créditos──▶ credits.tscn
```
**Desde 04/11/2026 o jogo é 3D** (`src/gameplay/reception_25d/scenes/reception_3d.tscn` e `tutorial_3d.tscn`,
ver seção 14). A recepção e o tutorial 2D continuam no repositório e funcionam sozinhos, mas o menu, o cheat e a
tela final só conhecem a 3D. Na recepção, **Esc** abre o pause (`pause.tscn`: Continuar, Opções, Menu principal,
Sair do jogo).

- Cena principal (`run/main_scene`): `src/ui/menus/scenes/menu.tscn` (uid `b6hgpbqqj2j76`).
- O botão Jogar abre o **tutorial** (`menu.gd: GAME_SCENE`), não a recepção.
- Ao falhar na recepção, a cena é recarregada (`reload_current_scene`) **no mesmo dia**.
- Dias encadeados: no fim do dia, depois do Espaço na fala da Marta, a recepção é recarregada com
  `proximo_dia` (transição "Dia N"). O dia atual fica em `ReceptionManager.dia_em_andamento`
  (static); o tutorial zera para o dia 1. Dia 1 → `day1.tres`, Dia 2 → `day2.tres`, Dia 3 → `day3.tres` (último por enquanto).
- **Fim de jogo**: depois da fala de fim do dia 3 (Espaço), transição para `src/ui/menus/scenes/end_screen.tscn`
  (campo `cena_final` do `day3.tres`): epílogo narrado, "Fim.", créditos subindo e "Voltar ao menu".
- **Dia em andamento da 3D:** `reception_presentation.gd: dia_em_andamento` (static). O tutorial 3D e a tela final
  zeram esse campo (e a lista de vítimas do subsolo, `horror_director.gd: victims`).
- As cenas experimentais 2.5D (`reception.tscn`, `reception_gameplay_test.tscn`) seguem fora do fluxo (F6). Ver seção 13.

---

## 3. Configuração do projeto (`project.godot`)

| Item | Valor | Observação |
|---|---|---|
| Resolução base | 640 × 360 | Todas as coordenadas de cena/HUD estão nessa base |
| Janela | 1920 × 1080, modo 3 (tela cheia) | |
| Stretch | `canvas_items` | Texto é desenhado na resolução da janela (fica liso) |
| Filtro de textura | Nearest (`default_texture_filter=0`) | Pixel art nítido |
| Snap 2D | `snap_2d_transforms_to_pixel=true` | |
| Autoloads | `Dialogue`, `SceneTransition`, `MusicMenu`, `Audio`, `CheatMenu` | Ver seção 6. `MusicMenu` é registrado pelo **caminho** (`res://sounds/music/menu/music_menu.tscn`): pelo uid dava "Unrecognized UID" |
| Áudio | `default_bus_layout.tres` | Buses `Master`, `Music`, `SFX` (os sliders das opções usam esses nomes) |
| Input | `hack_level1`, `hack_level2` | Declarados, **não usados** em nenhum script. O hack de pular dia usa **F9** direto no código (`TECLA_PULAR_DIA`) |

Fontes em uso (`assets/fonts/`, desde a reorganização do PR #52): `pixeloid_sans.ttf`,
`pixeloid_sans_bold.ttf` e `pixeloid_mono.ttf`. As cenas da HUD e o `dialogue.tscn` já apontam para esse caminho.
Jersey10, Chewy, DynaPuff e os recursos `dynapuff_*.tres` não existem mais (`fonts/resources/` está vazia).

Versão da Godot para o GodotHub: `.godothub/.godotrc` (`4.7.2-stable no-dotnet`). `.godothub/project.json` é
gerado pelo GodotHub; não editar.

---

## 4. Estrutura de pastas

```
autoload/
  dialogue/            Caixa de fala global (balão de fala, com páginas)
  scene_transition/    Fade + título entre cenas
  cheat_menu/          cheat_menu.gd (autoload CheatMenu: tecla P, ver 6.10)
  audio/               audio.gd (autoload Audio: música do gameplay + efeitos sonoros, ver 6.9)
assets/fonts/          pixeloid_sans.ttf, pixeloid_sans_bold.ttf, pixeloid_mono.ttf
sounds/
  music/               music_menu.wav, music_gameplay.mp3, music_reverse.mp3 (a "errada", dia 3)
	menu/              music_menu.tscn/.gd (autoload MusicMenu: toca music_menu.wav no bus Music)
  sfx/                 BotãoPressionado.mp3, chegou_elevador.mp3, digitando.mp3, erro.mp3,
					   sucess.mp3, passando_pagina.mp3, MartaSubsoloKetchup.mp3
default_bus_layout.tres  buses Music e SFX
src/
  gameplay/
	reception/         scenes/reception.tscn + scripts/reception_manager.gd (recepção 2D, a do jogo)
	reception_25d/     Recepção 2.5D experimental (fora do fluxo; ver seção 13)
	hud/               scenes/ + scripts/: reception_hud, elevator_panel/button, company_book, rules_board,
					   badge_details, shift_summary; assets/ (arte da HUD 4x: main_hud, badge, buttons,
					   company_book, rules, Elevador)
	resources/         company_directory.tres (livro de andares)
	scenes/            elevator.tscn (elevador 2D da parede)
	schedules/         day1.tres, day2.tres, day3.tres (agendas dos dias)
	scripts/           reception_session (estado do atendimento, 6.1b), day_schedule, day_interaction,
					   marta_rule, elevator, company_data/directory
	tutorial/          scenes/tutorial.tscn, scripts/ (tutorial, tutorial_step, tutorial_script),
					   resources/tutorial_intro.tres (roteiro)
  npcs/
	assets/            Sprites 256x256 dos NPCs (jose, marta, lucas, tiao, manfredo, ...)
	dialogue/          npc_dialogue.gd + dialoguesCommon/ (dia 1), dialoguesDia2/, dialoguesDia3/ (<N> andar/*.tres)
	resources/         Day1/, Day2/, Day3/ (tiao.tres), birdTest.tres (entregador), scripts/ (visitor_data,
					   name_list, phrase_set), visitors/ (male_names.tres, standard_phrases.tres, ...)
	scenes/            visitor.tscn, marta.tscn, characters/ (cenas visuais dos NPCs)
	scripts/           visitor.gd
  shared/scripts/      rule_validator.gd
  ui/menus/            scenes/ (cenas), scripts/ (menu, options, credits, pause, options_pause, end_screen,
					   display_mode); assets/ (tela inicial *.jpg, buttons/)
test/unit/             testes GUT (test_rule_validator.gd)
tests/gameplay_regression/  testes SceneTree da I0/I1 (fluxo 2D, sessão, agendas) + fixtures/
addons/gut/            plugin GUT
docs/                  decisions/ (2026-10-18-audios-e-cutscene-ketchup.md); game-design/, references/, team/ vazias
tools/createscene.gd   EditorScript antigo (desatualizado, ver seção 9)
```
Pastas como `src/levels/`, `src/player/`, `src/run/`, `src/enemies/`, `exemple/` e `data/` estão vazias (sobras da
reorganização, não vão para o git). Há arquivos `.bak` versionados em `src/ui/menus/` e `autoload/cheat_menu/`:
são cópias antigas, nenhuma cena os usa.

---

## 5. Cenas existentes

### 5.1 `src/gameplay/reception/scenes/reception.tscn` — a recepção (gameplay)
```
Reception (Node2D) ─ reception_manager.gd
├── Wall (ColorRect 640x201, branco)           parede atrás da janela
├── PisoParede (TextureRect, "piso e parede.png" repetido na horizontal, escala 1)   fundo da recepção
├── Chairs (Sprite2D cadeiras.png) em (17, 20)   cadeiras de espera atrás do personagem
├── Elevator (elevator.tscn) em (282, -38), escala 1.4   elevador na parede (atrás dos atores; base atrás da mesa)
├── WindowClip (ColorRect 465x201, clip_children=1)   recorta os atores; termina na borda direita
│                                                     da porta do elevador (x 465) para eles "entrarem"
│   └── Actors (%Actors)
│       ├── VisitorSpawnPoint (-150, 255)   VisitorDeskPoint1 (141, 255)   VisitorExitPoint (440, 255)
│       └── MartaSpawnPoint (-150, 140)     MartaPoint (141, 140)          MartaExitPoint (-150, 140)
├── UI_CanvasLayer
│   ├── ReceptionHUD (reception_hud.tscn)
│   ├── DialogueUI / ManualPanel / ShiftSummary   placeholders vazios (não usados)
│   └── ElevatorPanel (elevator_panel.tscn) em (495, 203), escala 0,25
├── FeedbackAudio (bus SFX)
└── Pause (pause.tscn, CanvasLayer 10, process_mode ALWAYS)
```
Exports relevantes no nó `Reception`: `schedule_config = day1.tres`, `delay_between_visitors = 0.3`,
`visitor_scale = 3.4594595` (arte 256 px em tamanho real), `visitor_move_speed = 220`,
`marta_start_scale = marta_focus_scale = (1, 1)`.

### 5.2 `src/gameplay/hud/scenes/reception_hud.tscn` — HUD da recepção (posições na base 640x360)
| Nó | Posição / tamanho | Função |
|---|---|---|
| Desk | (0, 201) 678x181 | Mesa |
| Badge | (115, 195) 43x92 | Crachá fechado (script `reception_hud.gd`, feito pela equipe) |
| CompanyBook | (246, 216) 193x142 | Livro de andares, 2 por página, setas `<` e `>` |
| RulesBoard | (78, 314) 116x151 | Prancheta de regras: só 46 px visíveis; clique sobe/desce; Esc fecha |
| BadgeOverlay/BadgeDetails | CanvasLayer 10 | Crachá aberto (nome, idade, sexo, ocupação, foto) |

### 5.2b `src/gameplay/scenes/elevator.tscn` — elevador na parede (`src/gameplay/scripts/elevator.gd`)
- `AnimatedSprite2D` (`Sprite`) com os quadros `Elevador  (1).png`, `frame 2`, `frame 3` (animações `abrir`/`fechar`).
  O `Sprite` fica na **origem (0, 0)** da cena, alinhado com o `DoorPoint` (102, 182) e com `PORTA_ARTE`:
  mover o sprite tira o elevador da tela e a porta fica invisível (aconteceu no PR #39, ver seção 9).
- **Encaixe automático na porta**: o elevador mede a área visível (sem transparência) do sprite atual
  de cada ator e calcula escala e posição para a figura caber na abertura (`PORTA_ARTE` = x 100–132,
  y 70–199 da arte, abaixo da luz indicadora) com a cabeça logo abaixo do batente
  (`ocupacao_da_porta` 0,86, `scale_maxima_na_porta` 0,92). Serve para qualquer NPC sem ajuste manual.
- `receive(ator)`: abre, o ator anda até a porta encolhendo até o tamanho do encaixe, segue
  `distancia_entrando` px para dentro escurecendo — o que passa de x 465 é cortado pelo `WindowClip`,
  então ele some atrás do batente — e a porta fecha; o ator é liberado.
- `release(ator, destino)`: o ator começa escondido dentro do elevador, sai pela porta e anda até o
  destino; a porta fecha atrás dele. `release` espera o elevador esvaziar (ninguém sai enquanto alguém
  entra); entradas (`receive`) começam na hora.
- Quem é **negado** não entra no elevador: volta para a esquerda (`leave_to(spawn_point)`).
- **Marta**: na abertura do dia chega pela esquerda e vai embora **entrando no elevador**; em todas as
  aparições seguintes (regras, falha, fim do dia) ela **sai do elevador**, vai até a mesa e, nas regras,
  volta para o elevador (`_marta_arrive(from_elevator)`, `_marta_leave()` em `reception_manager.gd`).


### 5.3 `src/gameplay/hud/scenes/elevator_panel.tscn` — painel do elevador
- Arte em 4x (`src/gameplay/hud/assets/Elevador/`), painel 384x624 com `scale = 0.25`.
- Botões: 5,6 / 3,4 / 1,2 / S (subsolo, código -1), X (negar, código 999), Confirmar.
- Mecânica: clicar seleciona (botão afunda), clicar de novo desmarca; **Confirmar** só libera com
  seleção e emite `floor_selected(código)`. `set_panel_locked(bool)` trava/escurece tudo.
- Botões são `elevator_button.gd` (Control com `Normal`/`Selected`/`Label`), o sprite afundado é
  alinhado pela base. X normal e Confirmar normal são recortes (`AtlasTexture`) de
  `painel elevador botões.png`. Os sprites "sem contorno" foram gerados a partir dos originais
  trocando os pixels amarelos pela cor da face.

### 5.4 `src/gameplay/tutorial/scenes/tutorial.tscn` — tutorial
- Mesmo cenário da recepção (`PisoParede`, cadeiras, elevador, HUD; painel travado). O `WindowClip` tem de ser
  igual ao da recepção (`clip_children = 1`, largura 465): com `clip_children = 2` ele desenha um retângulo
  branco por cima do fundo e das cadeiras.
- `NarrationLayer` (layer 5): tela escura com texto (narração da história do protagonista).
- `SkipLayer` (layer 20): botão "Pular tutorial [Esc]".
- Scripts: `src/gameplay/tutorial/scripts/tutorial.gd`, `tutorial_script.gd` e `tutorial_step.gd`.
- Roteiro: `src/gameplay/tutorial/resources/tutorial_intro.tres` (12 passos: 4 narrações + 8 falas da Marta).
  Cada `TutorialStep` tem `falante` (vazio = narração), `texto`, `destaque`
  (NENHUM, FALA, LIVRO, REGRAS, CRACHA, PAINEL). O destaque é um contorno vermelho piscando que
  **lê a posição real** do elemento a cada quadro (`_update_highlight_rect`); em REGRAS a prancheta sobe.
- No fim (ou ao pular): `SceneTransition.transition_to(reception, "Dia 1")`.

### 5.5 Outras cenas
- `autoload/dialogue/dialogue.tscn`: CanvasLayer 10 com o **balão de fala** (`balão de fala vazio.png`,
  0,22 do tamanho, em 220,24; a ponta à esquerda aponta para quem fala), `NameLabel` (PixeloidSans-Bold 14),
  `TextLabel` (PixeloidSans 10), `SkipHint`. A HUD não tem mais prancheta de fala nem janela de vidro.
  **Fala longa vira páginas** (`_paginate`): cada página cabe no balão, quebrando no fim de frase quando dá
  e sem deixar 1-2 palavras soltas na última. Espaço: completa a digitação → próxima página → (última) continua.
  Visitantes (não aceleráveis) também passam página com Espaço. Não diminuir a letra para caber:
  com `line_spacing = -2` as linhas se encostam.
- `autoload/scene_transition/scene_transition.tscn`: CanvasLayer 50, `Fade` + `Title` (PixeloidSans).
- `src/gameplay/hud/scenes/company_book.tscn`, `rules_board.tscn`, `badge_details.tscn`: componentes da HUD
  (também reaproveitados pelas consultas do balcão 2.5D).
- `src/npcs/scenes/visitor.tscn`: nó base do visitante (script `visitor.gd`).
- `src/npcs/scenes/marta.tscn`: Marta = `visitor.gd` + Sprite2D 256 px.
- `src/npcs/scenes/characters/*`: cenas visuais dos NPCs (jose, CommonNPCs, PassaroTeste).
- `src/ui/menus/scenes/menu.tscn`: fundo animado com os 3 quadros `tela inicial do game N frame.jpg`
  (`AnimationPlayer`) e botões `TextureButton` (`Play`, `Options`, `Quit`, arte em `assets/buttons/`).
  `menu.gd` chama `MusicMenu.play_if_stopped()`.
- `options.tscn` (tela cheia, volumes Master/Music/SFX), `credits.tscn` (texto centralizado dentro da tela
  azul do computador do fundo: x 100–553, y 73–250).
- `end_screen.tscn` + `scripts/end_screen.gd`: tela de fim de jogo. Epílogo em tela escura (const `EPILOGO`,
  Espaço acelera/continua, como a narração do tutorial), "Fim.", créditos subindo (const `CREDITOS`,
  `[estilo, texto]` com estilos titulo/sub/secao/nome/espaco) e "Voltar ao menu". Esc pula para o fim dos
  créditos; Esc de novo volta ao menu. Abaixa a música do jogo e toca a do menu nos créditos. Zera
  `ReceptionManager.dia_em_andamento`.
- `src/ui/menus/scenes/pause.tscn` + `src/ui/menus/scripts/pause.gd`: Esc pausa (`get_tree().paused`); Esc com a prancheta de regras aberta só
  fecha a prancheta (`rules_board.gd` usa `_shortcut_input`). "Menu principal" chama `Dialogue.clear_dialogue()`.
  `src/ui/menus/scenes/options_pause.tscn` + `src/ui/menus/scripts/options_pause.gd`: opções dentro do pause.

---

## 6. Sistemas e scripts

### 6.1 Fluxo da recepção (`src/gameplay/reception/scripts/reception_manager.gd`)
1. `_ready`: liga sinais do painel e do crachá, trava o painel, monta o dia
   (`schedule_config.montar_dia()` → `queue_data` + `_rules_today`) e chama a intro.
2. **Intro**: Marta entra pela esquerda, fala `mensagem_inicio` e **espera o Espaço sem tempo limite**.
3. `_call_next_visitor`: instancia `visitor.tscn` dentro de `%Actors`, escala fixa `visitor_scale`
   (desliga o efeito de profundidade do visitante), anda até o balcão.
4. `_on_visitor_arrived_at_desk`: mostra nome (sorteado) + fala na prancheta e destrava o painel.
5. `_on_floor_selected` → `RuleValidator.validar_decisao(visitante, fala, código, dia, active_rules)`.
6. Acerto (`_process_success`): visitante sai, `_served_count += 1`; se for a vez,
   **Marta dita a próxima regra** (`_marta_announce_rule`), a regra vai para `active_rules` e para a
   prancheta (que sobe ~1,8 s); depois chama o próximo.
7. Erro (`fail`): tela avermelha, Marta fala `mensagem_falha`, até 6 s (ou Espaço) e recarrega a cena.
8. Fila vazia → `_conclude_day`: (se `suspense_antes_do_fim` > 0, luzes piscam e a sala escurece:
   `_apagar_luzes`) Marta sai do elevador (com `sprite_marta_fim`, se houver) e fala `mensagem_fim`;
   depois do Espaço, se houver `proximo_dia`, transição "Dia N" e recarrega a recepção; se não houver e
   o dia tiver `cena_final`, abre essa cena (tela de fim de jogo).

**Hack de teste — F9** (`TECLA_PULAR_DIA` em `reception_manager.gd`): na recepção, pula o resto do dia: dia 1 → 2 →
3 → tela final (créditos). Usa o mesmo `_ir_para_proximo_dia()` do fim normal do dia. Não funciona com o jogo
pausado nem durante uma transição (aperte de novo quando a tela clarear). Ao sair, `_saindo = true` trava o painel
e bloqueia falas da cena antiga (durante o escurecimento ela ainda roda); a recepção nova limpa o balão no `_ready`.
Para trocar a tecla, mude a constante; para desligar o hack, use uma tecla inexistente ou remova `_unhandled_key_input`.

As rotinas com `await` param se a cena sair da árvore (`if not is_inside_tree(): return`): pause →
menu principal ou reload no meio de uma fala não geram erro.

Helpers: `_spawn_marta` (escala fixa), `_add_actor` (põe em `%Actors`), `_wait_dialogue(s)`
(s ≤ 0 = espera só o jogador), `_await_callback` (transforma callback em `await`).

### 6.1b Sessão de atendimento (`src/gameplay/scripts/reception_session.gd`, `ReceptionSession`)
Desde a etapa I1 do 2.5D, o **estado lógico** do dia saiu do manager e foi para um Node filho criado por
`_create_session()`. **Não é autoload** e morre com a cena. Não conhece atores, coordenadas, HUD, áudio nem tweens.
- Guarda fila, visita atual (`current_entry`, `current_visit_id`), regras sorteadas/ativas, contagem e estado
  (`State`: INTRO, READY, ARRIVING, SERVING, RESOLVED, INTERVAL, RULE, CONCLUDING, FAILED, TRANSITION, CLOSED).
- Chama `montar_dia()` **uma vez** em `start_day()`; os snapshots da fila são somente leitura.
- Comandos com identidade: `request_next_visit(geração)`, `service_reached(id)`, `submit_decision(id, código)`
  (única chamada ao `RuleValidator`; `{}` = comando rejeitado), `complete_visit(id)` (conta 1 acerto),
  `take_due_rule`/`activate_pending_rule`/`finish_rule`, `finish_interval(id)`. Fora de ordem → ignorado.
- `generation` muda em reinício/transição/fechamento: callbacks antigos comparam a geração e desistem.
- O manager 2D continua sendo a fachada: `queue_data`, `active_rules`, `current_entry` etc. são consultas
  delegadas à sessão. `ReceptionManager.dia_em_andamento` (static) continua no manager.
- Modos de prévia, usados só pelo 2.5D: `start_arrival_preview` (I2), `start_service_preview` (I3) e
  `start_dispatch_preview` (I4). `start_day` desliga todos.

### 6.2 Validação (`src/shared/scripts/rule_validator.gd`)
`andar_esperado(visitante, fala, dia, regras)` devolve o destino correto; `validar_decisao` compara.
Ordem de aplicação:
1. Tag `intruder` ou `deny_access` → **negar (999)**.
2. Base: `fala.andar_desejado`.
3. Dia ≥ 2 e tag `delivery`/`generic_delivery` → **1º andar**.
4. Tag `send_to_basement` → **subsolo (-1)**.
5. Regras da Marta já ditadas (`MartaRule.aplicar`): se o andar **pedido** = `andar_pedido`, vira `andar_destino`.

Códigos: andares 1–6, subsolo **-1**, negar **999** (`RuleValidator.DENY_ACTION`, `ElevatorPanel.DENY_CODE`).

### 6.3 Agenda do dia (`day_schedule.gd` + `day_interaction.gd`)
- `DayScheduleConfig`: `dia_numero`, `proximo_dia`, `cena_final` (só no último dia), `sprite_marta_fim`, `suspense_antes_do_fim`, `som_no_escuro`,
  mensagens da Marta (início, fim, falha), `intervalo_regras` (padrão 2; 0 desliga), `regras_por_dia`,
  `regras_marta` (banco sorteado), `regras_obrigatorias` (ditas todo dia), `pool_padrao`, `interacoes`,
  `andares_do_dia`, `falas_comuns`, `usar_falas_do_visitante` (desligado = só `falas_comuns`).
- `DayInteraction`: modo ALEATÓRIO (sorteia do `pool` ou do `pool_padrao`) ou FIXO
  (`visitante`, `sprite`, `dialogo` forçados), com `repeticoes`. Entradas de FIXO recebem `"fixo": true`.
- `montar_dia()`:
  - os visitantes **aleatórios** cobrem todos os `andares_do_dia` (padrão 1–6), cada um ao menos uma
	vez, em **ordem sorteada**; a fala de cada um é sorteada entre as falas daquele andar (do próprio
	visitante + `falas_comuns`), **sem repetir texto no dia**. Visitantes FIXOS mantêm a fala deles;
  - escolhe `regras_por_dia` regras em **ordem fixa**: a 1ª aparição da Marta (depois do 2º visitante)
	dita uma **regra de andar** (com efeito); as seguintes só **regras de lore** (sem efeito, não limitam
	andar). `regras_obrigatorias` entram no grupo delas (as de lore vêm antes das sorteadas: nos dias 2 e 3
	a 2ª regra é sempre o aviso da entrega/do Tião). Regras de andar que mudariam o destino de um
	visitante FIXO ficam de fora naquele dia;
  - **garante 1 caso de regra**: um visitante aleatório depois da regra de andar pede o andar dela
	(marcado com `"caso_regra": true`); a ordem das regras não muda.
	O caso **nunca é o visitante logo depois da regra** (vem pelo menos um depois), e o visitante
	logo depois de qualquer regra com efeito não pede o andar dela (`_evitar_caso_no_proximo`).
- Entrada da fila: `{visitor, dialogue, nome, sprite, cracha, fixo, caso_regra?}`.

### 6.4 Regras da Marta (`marta_rule.gd`)
Campos: `fala`, `texto_prancheta`, `andar_pedido` (0 = só narrativa), `andar_destino`, `falas_caso`
(opcional: falas preferidas para o visitante que é o caso).
**Dia 1** (`day1.tres`): 7 visitantes = 6 aleatórios + entregador fixo por último. `andares_do_dia = 1, 2, 4, 5, 6`:
nenhum aleatório pede o 3º andar, que é só do entregador (um dos 5 andares se repete).
`intervalo_regras = 2`, `regras_por_dia = 2` → a Marta dita regras depois do 2º e do 4º atendimento.
Banco de 7 regras (nenhuma envolve o 3º andar no dia 1: o entregador pede o 3º e a
mensagem de fim do dia depende disso — não adicionar regra do 3º andar neste dia):

| Regra (prancheta) | Efeito |
|---|---|
| Pediu o 5º andar? Mande para o subsolo. | 5 → -1 |
| 4º andar: negar acesso. Ignore os barulhos. | 4 → 999 |
| 6º andar? Mande para o subsolo. | 6 → -1 |
| Pediu o 2º andar? Mande para o 5º. | 2 → 5 |
| Ninguém chamado Rogério trabalha aqui. | narrativa |
| Batidas no poço do elevador são normais. | narrativa |
| Sorria. As câmeras estão vendo. | narrativa |

**Dia 2** (`day2.tres`): mesmo formato (6 aleatórios + entregador fixo por último, Marta depois do 2º e do 4º),
falas próprias em `src/npcs/dialogue/dialoguesDia2/<N> andar/` (3 por andar, `usar_falas_do_visitante = false`).
- `regras_obrigatorias`: a Marta sempre avisa "Entrega para a Marta? Mande para o subsolo." (narrativa);
  a outra regra é sorteada do banco de 7: 3→negar, 1→subsolo, 4→2º, 5→6º + 3 narrativas.
- O entregador pede "entrega para a dona Marta" (`andar_desejado = -1`): o certo é o subsolo.
- `sprite_marta_fim` = `src/npcs/assets/marta/marta_bloody.png`: só na fala de fim ela aparece ensanguentada ("é katchup!").
  Durante o dia usa o sprite padrão. `suspense_antes_do_fim = 3.0` + `som_no_escuro = MartaSubsoloKetchup.mp3`:
  depois que o entregador entra no elevador a música some, as luzes piscam e a sala fica quase preta (0,9);
  1 s depois toca o `MartaSubsoloKetchup` com o cenário tremendo e um vermelho fraco no escuro; mais 3 s de
  silêncio, o elevador chega grave e a Marta sai, para e encara 1,8 s sob luz vermelha que pulsa enquanto ela
  fala (`_apagar_luzes`, `_tremer`, `_conclude_day`). A música só volta no dia seguinte.

**Dia 3** (`day3.tres`): mesmo formato, falas em `src/npcs/dialogue/dialoguesDia3/<N> andar/`. Visitante fixo
no fim: **Seu Tião**, o faxineiro (`src/npcs/resources/Day3/tiao.tres`, sprite `tiao/tiao_jardineiro.png`,
tag `send_to_basement`, crachá 67 / Masculino / Faxineiro). Ele pede o 6º andar, mas o certo é o **subsolo**:
a regra obrigatória da Marta é "Seu Tião (faxineiro)? Sempre para o subsolo." e o validador também manda o
`send_to_basement` para -1. A outra regra é sorteada: 2→1º, 4→subsolo, 3→5º, 1→negar + 3 narrativas.
Fim: suspense de 2 s e a Marta volta **limpa** (sprite padrão), dizendo que o Tião limpou o "katchup".

Falas do dia 1 por andar ficam em `src/npcs/dialogue/dialoguesCommon/<N> andar/` (24 no total, incluindo
4 do 6º andar); estão todas em `falas_comuns` do `day1.tres`.

**Tom das falas:** visitantes falam de coisas comuns de escritório, com humor (café, TI, RH, papelada).
**O suspense é exclusivo da Marta** (regras, intro, falha, fim do dia). Não escrever falas de NPC sinistras.

### 6.5 Visitantes (`visitor_data.gd`, `visitor.gd`)
- `VisitorData` (`@tool`): `nome`, `nome_aleatorio` + `lista_nomes` (padrão `male_names.tres`),
  `cena` **ou** `sprites` (sorteia um), `tags`, `dialogos`, grupo Crachá (idade/sexo/ocupação fixos ou
  sorteados, `retrato`). `pick_visit()` sorteia fala (sem repetir), nome, sprite e dados do crachá.
- `Visitor` (Node2D): `setup`, `move_to_slot(pos, callback, is_desk_slot)`, `leave_to`, animação de
  passos (bob). Tem efeito de profundidade (`queue_scale` → `desk_scale`) que a recepção **neutraliza**.
- A Marta usa o mesmo `visitor.gd`.

### 6.6 Caixa de fala global (`Dialogue`)
```gdscript
Dialogue.display_dialogue(nome, texto, skippable := false)
Dialogue.clear_dialogue()          # também encerra qualquer wait_for_advance pendente
await Dialogue.wait_for_advance(s) # s <= 0: espera só o jogador
```
Com `skippable`, mostra "[Espaço] acelerar" (completa a digitação) e depois "[Espaço] continuar".
Falas de visitantes **não** são puláveis (ficam na tela enquanto o jogador decide).

### 6.7 Transição (`SceneTransition`)
`SceneTransition.transition_to(caminho, titulo := "")`: escurece, mostra o título, troca a cena e
clareia; emite `finished`. Bloqueia cliques durante a troca.

### 6.8 Livro e prancheta
- `company_book.gd`: `next_page()` / `previous_page()` com volta circular; título do andar em tamanho 12
  (com 15, "1º andar" ocupa 86 px numa coluna de 76 e encosta na outra coluna); dados em
  `company_directory.tres` (7 entradas: 1º–6º e Subsolo por último). Logo só aparece se preenchido.
- `rules_board.gd`: `open()`, `close()`, `toggle()`, `add_rule(texto)`, `clear_rules()`.

### 6.9 Áudio (`Audio` + `MusicMenu`)
As músicas ficam em `sounds/music/`; os efeitos, incluindo `MartaSubsoloKetchup.mp3`, em `sounds/sfx/`.
`MusicMenu` (autoload) toca `sounds/music/music_menu.wav` no menu; para ao apertar **Jogar** (`menu.gd`) e volta quando o
menu abre de novo (o menu também para a música do gameplay). `Audio` (`autoload/audio/audio.gd`, registrado pelo
caminho) tem um player de música (bus Music), um de loop e 6 vozes de efeito (bus SFX):

| Som | Quando | Onde |
|---|---|---|
| `music_gameplay` (`MUSICA_GAMEPLAY`) | Recepção, dias 1 e 2 (em loop) | `reception_manager._ready` |
| `music_reverse` (`MUSICA_ERRADA`) | Recepção, a partir do dia 3 (em loop) | `reception_manager._ready` |
| `BotãoPressionado` | Qualquer botão do painel do elevador (inclui X e Confirmar) | `elevator_button._gui_input` |
| `chegou_elevador` | Porta do elevador abre estando fechada: -6 dB (50%); quando a Marta sai, volume normal e pitch 0,7 | `elevator._tocar_chegada` (`release(..., som_da_marta)`) |
| `digitando` | Narração da intro (tutorial), enquanto o texto aparece | `tutorial._show_narration` |
| `passando_pagina` | Setas do livro de andares | `company_book.next_page/previous_page` |
| `sucess` / `erro` | Acerto / erro do andar | `_process_success` / `fail` |
| `MartaSubsoloKetchup` | Fim do dia 2, no escuro (`som_no_escuro` do `day2.tres`) | `_apagar_luzes` |

Os MP3 foram importados sem loop: `audio.gd` liga `loop` em código nas músicas e no `digitando`.
`play_music` não reinicia a mesma música (ao falhar e recarregar a cena ela continua).

**Volumes (tudo no `audio.gd`):**
- `DEFAULT_BUS_PERCENT`: volume inicial dos buses em %, aplicado só ao abrir o jogo (Master 100, **Music 50**,
  SFX 100). É o que os sliders das opções mostram; depois quem manda são os sliders (o volume não é salvo).
- `MENU_MUSIC_VOLUME_DB` (-6): o `audio.gd` sobrescreve o `volume_db` do `MusicMenu` (o -33 do `music_menu.tscn`
  não vale mais). `MUSIC_VOLUME_DB` (0), `SFX_VOLUME_DB`, `LOOP_VOLUME_DB`: **em dB, não em %**.
- A música do gameplay veio ~17 dB mais baixa que a do menu (média -30,7 dBFS): passa pelo bus `MusicaGameplay`
  (criado em código, manda para `Music`) com `AudioEffectHardLimiter` (+15 dB, teto -1 dB).
- Medido com Música em 50%: menu ~-25,5 dBFS e gameplay ~-25,1 dBFS de média (antes o menu saía a -46,7).

### 6.10 Tela de cheat (`CheatMenu`)
`autoload/cheat_menu/cheat_menu.gd` (registrado pelo caminho; interface montada em código, sem `.tscn`).
A tecla **P** abre/fecha em qualquer cena e pausa o jogo; **Esc** também fecha (e não chega ao pause, então
abrir por cima do pause e fechar volta ao pause). Botões: Primeira/Segunda/Terceira fase (Dia 1/2/3) e Menu inicial.
Ir para um dia = `reception_presentation.gd: dia_em_andamento = dayN.tres` + `SceneTransition.transition_to(reception_3d, "Dia N")`,
o mesmo caminho do fim do dia. Antes de trocar: despausa, limpa a fala, para o loop do `Audio` e a música do menu;
depois que a cena nova entra, limpa a fala de novo (a cena antiga continua rodando durante o fade).
Para tirar da build final: remover a linha `CheatMenu` de `[autoload]` no `project.godot`.

---

## 7. Escala da arte e posições

- Arte da HUD foi desenhada em **4x** (mockup `tela_principal_exemplo.png` = 2560x1440).
  Use tamanho = PNG ÷ 4 (ou `scale = 0.25`, como no painel do elevador).
- `tela_principal_vazia .png` (641x361, com espaço no nome) é o gabarito 1x de posições.
- Sprites de NPC são 256x256; na janela aparecem em tamanho real e cortados pela mesa.
- Mesa começa em y = 201; Marta para em y = 140, visitantes em y = 255 (offset interno diferente).

---

## 8. Como editar conteúdo (sem código)

| Quero mudar | Onde |
|---|---|
| Visitantes do dia, ordem, quantidade | `src/gameplay/schedules/dayN.tres` → `interacoes` |
| Novo dia | copiar `day3.tres`, mudar `dia_numero`, apontar o `proximo_dia` do dia anterior para ele e mover o `cena_final` para o novo último dia |
| Epílogo e créditos finais | `src/ui/menus/scripts/end_screen.gd` → consts `EPILOGO` e `CREDITOS` |
| Suspense / sprite da Marta no fim | `dayN.tres` → `suspense_antes_do_fim`, `sprite_marta_fim` |
| Regras da Marta e intervalo | `dayN.tres` → grupo "Regras da Marta" |
| Falas/andar de um NPC | `.tres` em `src/npcs/resources/Day*/` ou `src/npcs/dialogue/` |
| Livro de andares | `src/gameplay/resources/company_directory.tres` |
| Roteiro do tutorial | `src/gameplay/tutorial/resources/tutorial_intro.tres` |
| **Diálogos da 3D (o jogo)**: tutorial, Marta, Godofredo, telefone, regras da Marta, mensagens do dia | `src/gameplay/reception_25d/scripts/story_lines.gd` (sobrescreve em memória os textos dos `.tres`; nada é salvo) |
| Lista de nomes | `src/npcs/resources/visitors/male_names.tres` |
| Ritmo da recepção | nó `Reception`: `delay_between_visitors`, `visitor_move_speed` |
| Título da transição | `src/gameplay/tutorial/scenes/tutorial.tscn` → `titulo_dia` |

---

## 9. Problemas técnicos encontrados (e como evitar)

1. **`@export var x: PackedStringArray = []` apaga dados no editor.**
   Em scripts não-`@tool`, o padrão `= []` (Array comum em campo PackedStringArray) faz o editor
   descartar os valores do `.tres` ao carregar e **regravar o arquivo vazio** ao salvar. Isso apagou
   duas vezes `standard_phrases.tres` e `male_names.tres`. Use `@export var x: PackedStringArray`
   (sem padrão) ou `PackedStringArray()`. Por precaução, listas de Resource novas também estão sem `= []`.

2. **Criar classes/`.tres` com o editor aberto.** O editor não registra `class_name` novo nem lê os
   campos do recurso novo até recarregar. Sintomas: `Could not find type "X" in the current scope`,
   Inspector vazio, `.tres` sobrescrito vazio. Depois de criar arquivos por fora: **Projeto →
   Recarregar Projeto Atual, sem salvar**. Para código crítico, prefira
   `preload("res://...gd")` a depender do `class_name` (feito em `elevator_panel.gd`).

3. **Fim de linha (CRLF/LF).** O Git para Windows usa `core.autocrlf=true` e a Godot regrava
   `.import`/`project.godot` com LF. Resultado: dezenas de arquivos "modificados" sem mudança real.
   Confira com `git diff --ignore-cr-at-eol --stat`; **não commite** arquivos que só mudaram fim de linha.
   Solução definitiva sugerida (não aplicada): `.gitattributes` com `* text=auto eol=lf`.

4. **`.import` de assets novos precisam ir para o git** (guardam uid e configurações). Já aconteceu de
   só os PNGs estarem no stage.

5. **Repositório dentro do OneDrive.** Já causou `Permission denied` em `git stash -u` (pastas travadas).
   Evite `stash -u`; feche a Godot antes de operações grandes de git.

6. **Rename de arquivos quebra caminhos em merges.** O PR #16 moveu cenas/scripts para `scenes/` e
   `scripts/`; um merge automático gerou código que não compilava (`current_visita` vs `current_entry`).
   Sempre rode o jogo depois de merges, mesmo sem conflito marcado.

7. **`uid` em `.tscn` escrito à mão.** Ao reescrever um `.tscn`, preserve o `uid` do cabeçalho, senão
   cenas que referenciam por uid emitem "invalid UID" e caem no caminho.

8. **`Control.get_global_rect()` ignora `scale`.** Para nós escalados (painel do elevador 0,25), use
   `get_global_transform()` + `size * scale` (ver `tutorial.gd`).

9. **`Array.filter()` devolve Array sem tipo.** Atribuir a `Array[Tipo]` dá erro em runtime; use laço.

10. **Arte de NPC com offsets diferentes.** `joseNPC.tscn` tem sprite com escala 0,289 e offset; a Marta
	tem Sprite2D 256 px sem offset. Por isso Marta e visitantes usam alturas de ponto diferentes.

11. **`visitor.gd` tem efeito de profundidade** (0,2 → 3,0 ao andar). Na janela isso foi desligado
	igualando `queue_scale` e `desk_scale` antes de adicionar o nó.

12. **Painel antigo do elevador** só conectava os botões 1, 2, 3 e Negar; 4, 5, 6 e Subsolo nunca
	travavam. Corrigido no painel com sprites (todos os botões são iterados).

13. **Fontes pixel em tamanho errado ficam ilegíveis** (VCR em 8 px quebrava). Hoje as fontes não são
	pixel e o stretch é `canvas_items`, então texto pequeno (8–10 px) ainda é legível.

14. **Corrotinas e troca de cena.** Esperas pendentes (`wait_for_advance`) continuavam rodando após
	trocar de cena; `clear_dialogue()` agora encerra a espera e o tutorial aguarda frames antes de trocar.

15. **O editor apaga as falas do `day1.tres`** (já aconteceu 2 vezes: PR #36 e PR #39). Abrir/salvar o
	`day1.tres` com o projeto desatualizado regrava o arquivo sem a lista `falas_comuns` (PR #36) ou sem os
	20 `ext_resource` das falas, deixando a lista apontando para ids inexistentes (PR #39:
	`Can't load cached ext-resource id: fc_common1a`). Aí o `day1.tres` não carrega, a **recepção não abre**
    e o jogo para no tutorial. Antes de commitar o `day1.tres`: `grep -c fc_common day1.tres` deve dar 21
    (20 `ext_resource` + a lista) e a recepção tem de abrir. Recarregue o projeto antes de editar dias.

16. **Mover o `Sprite` do elevador** (o PR #39 pôs `position = (378, 11)` e um `Sprite2D` vazio na
    `elevator.tscn`) tira o elevador da tela; os atores continuam indo para o `DoorPoint` (porta invisível).

17. **Aviso `invalid UID: uid://d02lrjb830jbu` no `tutorial.tscn`.** O `tutorial_intro.tres` tem esse uid no
    cabeçalho, mas a Godot não o registra no cache (nem com `--headless -e`). É só aviso: a cena carrega
    pelo caminho e o jogo não é afetado.


18. **Texto de várias linhas dentro de `.tscn`/`.tres` com CRLF.** Com o Git do Windows (`autocrlf`), uma
    string que ocupa várias linhas no arquivo fica com `\r\n` dentro, e a Godot desenha o `\r` como
    uma linha a mais (espaço dobrado). Aconteceu na lista da equipe em `credits.tscn`. Escreva o texto numa
    linha só, com `\n` escapado: `text = "Rodrigo - Game Designer\nDaniel - Programador"`.

---

## 10. Pendências e inconsistências conhecidas

- **Entregador:** os dias 1 e 2 usam `src/npcs/resources/birdTest.tres` ("Entregador Lucas", sem tags, sprite e
  fala definidos na interação FIXA do dia). `Day2/entregador.tres` (tag `entregador`) não é usado por nenhuma
  agenda. O validador procura `delivery`/`generic_delivery`, então a regra "entregador vai ao 1º andar no
  dia 2" não se aplica a ele.
- `mensagem_fim` do dia 1 diz "você deixou aquele entregador ir para o terceiro andar... você não sabia!",
  embora mandá-lo ao 3º seja o certo pelo validador. Parece pista narrativa intencional; confirmar com o Rodrigo.
- `DialogueUI`, `ManualPanel` e `ShiftSummary` em `reception.tscn` são `Control` vazios; `shift_summary.gd`
  existe mas não está ligado.
- `tools/createscene.gd` ainda aponta para caminhos antigos (`src/levels/reception.tscn`).
- Código/recursos sem uso: `phrase_set.gd` + `standard_phrases.tres` (frases padrão antigas),
  `src/npcs/level_day_config/day_config.gd` (`DayConfig`, substituído por `DayScheduleConfig`),
  `src/npcs/resources/visitors/common_npc_male1.tres` (o usado é o de `Day1/`), ações `hack_level1/2`,
  arquivos `.bak` em `src/ui/menus/` e `autoload/cheat_menu/`.
- `day2.tres` e `day3.tres` têm `andares_do_dia = null` (regravados pelo editor no commit 4c42c42). Funciona:
  ao carregar, o campo fica com o padrão 1–6 (conferido com `montar_dia()`).
- Ao criar um dia novo, preencher `falas_comuns` (senão andares sem fala ficam sem visitante).
- O tutorial destaca o "painel" e diz "escolher o andar no painel do elevador, ou negar o acesso";
  se a mecânica mudar, atualizar `tutorial_intro.tres`.
- A prancheta de regras aberta cobre o crachá.
- Os efeitos sonoros vieram baixos nos arquivos (ex.: `sucess` -46 dBFS de média, `passando_pagina` -61):
  se ficarem enterrados sob a música, subir `SFX_VOLUME_DB` (até ~+6) ou reexportar os arquivos.
- Nos dias 2 e 3, as regras de lore do banco não saem: a 2ª vaga (lore) é sempre a obrigatória
  (entrega / Tião). Decisão do Gustavo: manter assim.

---

## 11. Git e forma de trabalhar

- Branch principal de integração: **`develop`** (PRs no GitHub `devrodofc/GameJamPlus-2026`).
- Uma branch por tarefa, criada a partir da `develop` atualizada (`feat/...`, `fix/...`).
  Crie sem upstream apontando para a develop (`git branch --unset-upstream`) para evitar push errado.
- **Não fazer commit nem push sem pedido explícito** do Gustavo; ele revisa as alterações no
  Source Control antes. Quando pedir, commitar só os arquivos com mudança real.
- Antes de commitar: rodar o jogo/headless, conferir `git diff --ignore-cr-at-eol --stat`.
- Arquivos de cena compartilhados (`reception.tscn`, `reception_manager.gd`) são editados por várias
  pessoas: alterações mínimas e avisar a equipe.

---

## 12. Testes e verificação

Godot usada (na máquina do Gustavo):
`C:/Users/user/AppData/Roaming/Ryko.GodotHub/godot-versions/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`

```bash
G=".../Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path . --import                    # reimporta / registra classes novas
"$G" --headless --path . -s teste.gd                  # roda um SceneTree script de teste
"$G" --path . --windowed --resolution 640x360 \
     --write-movie out/f.png --fixed-fps 20 --quit-after 200 -s roteiro.gd   # grava quadros (abre janela)
```
- Em scripts `-s`, **não escreva `ReceptionManager` no código-fonte do teste**: isso compila o
  `reception_manager.gd` antes dos autoloads e dá "Identifier not found: Audio". Use
  `var RM = load("res://src/gameplay/reception/scripts/reception_manager.gd")` e `RM.dia_em_andamento = ...`.
- Scripts de teste (`extends SceneTree`) podem: `change_scene_to_file`, simular teclas com
  `Input.parse_input_event(InputEventAction)`, emitir `pressed` nos botões do elevador e consultar
  `RuleValidator.andar_esperado(...)` para responder certo.
- Em modo `-s`, `await` dentro de `_initialize` funciona para a maioria dos casos; para roteiros
  temporizados no Movie Maker, use um contador de quadros em `_process`.
- O Movie Maker com stretch `canvas_items` grava em 1920x1080.
- Para inspecionar o que **o editor** carrega (diferente do jogo), use uma cópia do projeto com um
  `EditorPlugin` temporário e `--headless -e` (foi assim que o problema 1 foi diagnosticado).

### Suítes existentes
| Suíte | Como rodar | Resultado esperado |
|---|---|---|
| GUT (validador) | `test/unit/test_rule_validator.gd`, pelo painel GUT do editor | sem falhas |
| I0/I1 (2D, sessão, agendas) | `tests/gameplay_regression/*.gd` com `-s` | `failures=0` |
| I2 chegada 2.5D | `src/gameplay/reception_25d/tests/reception_arrival_test.gd` | `I2_ARRIVAL_RESULT ... failures=0` |
| I3 balcão 2.5D | `src/gameplay/reception_25d/tests/reception_desk_test.gd` | `I3_DESK_RESULT ... failures=0` |
| I4 saída 2.5D | `src/gameplay/reception_25d/tests/reception_dispatch_test.gd` | `I4_DISPATCH_RESULT ... failures=0` |
| I5/I6 Marta, erro, fim do dia | `src/gameplay/reception_25d/tests/reception_marta_test.gd` (~5 min) | `I5_MARTA_RESULT ... failures=0` |

**Rode os testes 2.5D sempre com `--fixed-fps 60`**:
`"$G" --headless --fixed-fps 60 --path . -s res://src/gameplay/reception_25d/tests/reception_desk_test.gd`.
Eles esperam um número fixo de quadros por animação; sem `--fixed-fps` os quadros passam rápido demais e
aparecem falhas falsas (prancheta "não volta", "Result available for I4" e um `SCRIPT ERROR` em `.correct`).
O aviso `N resources still in use at exit` no fim é conhecido e não indica falha.

`tests/gameplay_regression/validator_schedule_test.gd` compara o SHA-256 dos recursos com
`fixtures/resource_integrity.json`. No Windows (`core.autocrlf=true`) os arquivos ficam com CRLF e o hash não
bate (falha falsa). Além disso, `day1/2/3.tres` foram regravados pelo editor no commit `4c42c42`, depois do fixture
(24/10). Resultado atual: 3055 verificações, 136 falhas, todas "Authored resource bytes preserved". Se as mudanças nas
agendas forem aceitas, regenere o fixture.

---

## 13. Recepção 2.5D (experimento em andamento)

Iniciado pelo Rodrigo na branch `feat/2.5d-experiment` (PR #54). Objetivo: trocar a recepção 2D por uma sala 3D
renderizada em 640×360 e ampliada com filtro nearest (mantém o visual pixel art), com os NPCs como `Sprite3D`
usando os mesmos PNGs. **Continua fora do fluxo do jogo**: menu, tutorial, cheat e F9 só conhecem a recepção 2D.
Para testar, abra a cena e use **F6** (F5 roda o jogo normal).

Documentação detalhada (leia antes de mexer): `src/gameplay/reception_25d/README.md` (etapas 1–10: sala,
câmera, portas, cabines, arte do Elevador 1, câmera livre) e `src/gameplay/reception_25d/docs/`
(`gameplay-integration-audit.md` = etapa 11, auditoria e plano I0–I8; `gameplay-integration-iN.md` = cada etapa).

### Cenas
| Cena | Para quê |
|---|---|
| `scenes/reception.tscn` | Sala experimental "pura": teclas **1/2** (entrar pela porta esquerda/direita), **R** (reset), botões das 3 cabines, **P** (BILLBOARD/PAPER), **F** (câmera livre). Sem regras de jogo. Não alterar: os testes comparam com ela. |
| `scenes/reception_gameplay_test.tscn` | **Herda** a anterior e liga o gameplay real (sessão + `reception_presentation.gd`). É a cena de trabalho das etapas I2+. |
| `tests/reception_arrival_fixture.tscn` | Herda a de gameplay com `enable_service = false` (só a chegada da I2). |

Exports do nó raiz da `reception_gameplay_test.tscn`: `Test Day` (1–3, escolhe `dayN.tres`), `Initial Entrance`
(Esquerda/Direita), `Enable Service` (I3: balcão), `Enable Departure` (I4: saída) e `Enable Marta` (I5/I6: dia
completo com a Marta). Desligando de trás para frente volta-se às etapas anteriores. Com `Enable Marta`, o
`Test Day` só vale na primeira abertura: depois o dia fica em `reception_presentation.gd: dia_em_andamento`
(static), que o erro mantém e o fim do dia avança.

### Etapas do plano (I0–I8)
| Etapa | Situação | O que entrega |
|---|---|---|
| I0 | feita | Casos de regressão do 2D (`tests/gameplay_regression/`) |
| I1 | feita | `ReceptionSession` (6.1b): o estado do atendimento sai do manager 2D |
| I2 | feita | Visita real da agenda entra por uma porta e chega ao balcão |
| I3 | feita | Balcão com objetos 3D clicáveis: crachá, livro, prancheta, painel de andares (1–6, -1, X, OK); fala em papel 3D |
| **I4** | **feita (02/11/2026)** | Acerto embarca na **cabine 1**; recusa certa sai pela porta de entrada; erro trava; próximo visitante só depois da saída |
| **I5** | **feita (02/11/2026)** | Marta 3D: introdução, regras depois do 2º e 4º atendimento (ativadas depois da fala) |
| **I6** | **feita (02/11/2026)** | Erro (Marta com raiva, reload no mesmo dia), fim do dia, dias 1→2→3→tela final |
| I7 | pendente | Política definitiva de cabines (3) e de vários visitantes ao mesmo tempo |
| I8 | **feita (04/11/2026)** | Jogo ligado ao 3D: `reception_3d.tscn` + `tutorial_3d.tscn` (seção 14); regressões revisadas |

### Arquitetura (resumo)
- `ReceptionSession` é a **única autoridade** (fila, decisão via `RuleValidator`, contagem). A apresentação 2.5D
  só move atores, abre portas e mostra UI; nunca sorteia nem valida.
- `reception_presentation.gd` (adaptador): pega a visita da sessão, aplica o sprite no `TestVisitor`
  (`test_sprite.gd`), anda pelas rotas (`visitor_movement.gd`, `visitor_orientation.gd`), controla portas
  (`automatic_door.gd` nas entradas, `elevator_door.gd` nas cabines) e, na I4, a saída. Sinais:
  `visit_reached_service(id)`, `visit_departed(id)`, `presentation_failed(motivo)`.
- `desk_service.gd` (I3): objetos do balcão (`desk_models.gd` = caixas provisórias), picking por raycast
  (`desk_picker.gd`), consultas modais (`desk_modal.gd` + `inspection_*.gd`, que reaproveitam a HUD 2D), fala
  (`paper_dialogue.gd`, a cena `Dialogue` original numa textura) e crachá (`badge_transfer.gd`). Emite
  `decision_processed(result)`.
- **Andar ≠ cabine.** O painel envia o código do andar (1–6, -1, 999). A cabine é decisão de apresentação: por
  enquanto sempre a cabine 1 (`PILOT_CABIN`), qualquer que seja o andar. Não associar cabine a andar sem decisão
  de design.
- `ElevatorSelection` e `VisitorMovementTest` (harness da sala pura) ficam **desligados** na cena de gameplay.
- `marta_actor.gd` (I5): a Marta é um **segundo ator** (`MartaGround`, cópia do sprite e da sombra do visitante),
  com movimento, orientação e balão de papel próprios. Usa só a **cabine 2** (`Elevator02`). API com `await`:
  `arrive_from_entrance`, `arrive_from_cabin(sprite_chegada, sprite_saida)`, `speak`, `leave_into_cabin`; `cancel()`
  faz todas devolverem `false`. A tecla P é lida só pela orientação do visitante; a da Marta copia o modo.
- `reception_effects.gd` (I6): CanvasLayer 4 com as camadas do 2D (vermelho da falha, luzes apagando, luz
  vermelha do dia 2) e o tremor, aplicado ao `RoomView`. Mesmos valores do `reception_manager.gd`.

### I4 — saída do visitante (decisões tomadas)
- **Cadência em série:** só um visitante na sala; o próximo entra depois que o anterior saiu de fato
  (cabine **fechada** com ele dentro, ou porta de entrada **fechada** depois que ele sumiu no vestíbulo).
  "Começou a fechar" não conta como saída.
- **Acerto (andar ou subsolo):** a sessão conta o atendimento na hora da decisão (como no 2D); o crachá volta, o NPC
  anda até a cabine 1, espera a porta abrir, entra, a porta fecha e só então `visit_departed` + próximo visitante.
- **Recusa certa (X):** volta pela mesma porta de entrada (fila → entrada → vestíbulo), some e a porta fecha.
- **Erro sem Marta (`Enable Marta` desligado):** estado `FAILED`; o NPC fica parado, nada abre, a fila não anda.
- **Fim da fila sem Marta:** estado `DAY_DONE` ("Fila concluída · fim do dia na I6").
- No modo só da I4 (`start_dispatch_preview`) nenhuma regra é anunciada.

### I5/I6 — Marta, erro e fim do dia (decisões tomadas)
Design: `docs/superpowers/specs/2026-11-02-recepcao-25d-marta-e-erro-design.md`. Igual ao 2D, com estas adaptações:
- **Introdução:** a Marta entra pela porta de entrada, fala `mensagem_inicio` (espera Espaço), entra na cabine 2;
  só então o primeiro visitante.
- **Regras:** depois que o visitante do 2º/4º atendimento saiu de fato, a cabine 2 abre (`chegou_elevador` grave),
  ela vem ao balcão e dita a regra. A regra só vale depois do último Espaço (`rule_announced`); a prancheta abre
  sozinha por 1,8 s (não abre por cima de outra consulta) enquanto ela volta para a cabine 2.
- **Erro:** som de erro, painel travado, 1 s, tela avermelha, o visitante sai pela porta de entrada; quando ele passa
  do corredor, a Marta sai da cabine 2 e chega **com raiva em todos os dias** (`marta_anger.png`; no 2D a raiva
  continua só no dia 1). Fala `mensagem_falha` (até 6 s ou Espaço) e recarrega o mesmo dia.
- **Fim do dia:** como o 2D (suspense, `sprite_marta_fim` desde a saída da cabine, encarada sob luz vermelha no dia
  2, `mensagem_fim`), depois transição "Dia N" para a mesma cena ou para a `cena_final` (dia 3 → créditos).
- Enquanto a Marta está na sala, o painel de andares fica travado; livro e prancheta continuam consultáveis.
- Sons: `sucess` no acerto, `erro` no erro, música do dia (`music_reverse` a partir do dia 3).

### Cuidados
- Não mexa na geometria, nos marcadores (`VisitorPositions`, `ElevatorRoutes`, `ApproachPoint`/`EntryPoint`/
  `CabinStopPoint`), na velocidade nem nos materiais para "fazer um teste passar". Velocidade dos NPCs e da Marta:
  **3,6** na `reception_gameplay_test.tscn` (override no nó `VisitorMovement`, pedido do Gustavo em 02/11/2026); a sala
  experimental continua com 3 (padrão do `visitor_movement.gd`). A Marta copia a velocidade do visitante.
- A tecla **P** é consumida pela orientação PAPER antes do `CheatMenu` nessas cenas (conflito conhecido).
- `VisitorData.cena` (NPC feito como cena 2D) não é suportado no 2.5D: a visita é rejeitada (`UNSUPPORTED`). As
  agendas atuais só usam sprites.
- O editor regrava a `reception_gameplay_test.tscn` (ids `unique_id`, `transform` no lugar de `position`): é só
  formato, mas confira o diff antes de commitar.


---

## 14. Recepção 3D — o jogo (desde 04/11/2026)

Cenas em `src/gameplay/reception_25d/scenes/`:
- `reception_3d.tscn`: **herda** `reception_gameplay_test.tscn` (mesma sessão, regras, Marta e saídas já testadas) e
  troca o script raiz por `scripts/reception_3d.gd` (que `extends reception_presentation.gd`). Tem o `Pause`.
- `tutorial_3d.tscn`: herda `reception_3d.tscn` com `tutorial_mode = true`: toca o `tutorial_intro.tres` na mesma
  sala (narração em tela preta, a Marta entra pela porta, cada fala destaca o objeto em vermelho: livro, prancheta,
  crachá, painel). Esc pula. No fim a luz apaga, ela some e abre o "Dia 1".

**Não altere `reception_gameplay_test.tscn` nem `reception.tscn` para mudar o jogo**: os testes I2–I6 usam essas
cenas. Tudo o que é só do jogo fica nos scripts novos abaixo (criados em código, sem `.tscn` próprios):

| Script | O que faz |
|---|---|
| `reception_3d.gd` | Raiz. 3D renderizado na **resolução da janela** (`_apply_resolution`, não 640×360: texto e geometria nítidos), câmera (posição, inclinação −14°, A/D/setas, borda do mouse de 3,5%, sem girar com o mouse sobre algo clicável), HUD, tooltip, F9, susto do erro, fim do dia, final do dia 3 e o tutorial. |
| `desk_dressing.gd` | Veste o balcão com a **arte da HUD**: painel com `painel elevador.png` e os sprites dos botões (afunda, acende, `BotãoPressionado`), livro, prancheta e crachá com as figuras originais, balcão com o miolo de `mesa.png`, abajur, luz de rosto e monitor com relógio do turno. `DESK_TOP` = 0,93 m (balcão mais baixo que o da sala experimental para os chibis aparecerem). |
| `horror_director.gd` | Camada de terror (só apresentação: nunca decide nem valida). Ver abaixo. |
| `screen_hud.gd` | HUD 2D nítida: barra de instrução (traduz o `status` do `desk_service`), dia e atendidos, nome do objeto sob o mouse, dica de controles, narração do tutorial. |
| `ambience.gd` | Áudio **procedural** (AudioStreamGenerator, bus SFX): zumbido de lâmpada, estalos, batimento cardíaco, batidas no poço, impacto grave, drone no dia 3. Nenhum arquivo de áudio novo. |
| `shaders/room_post.gdshader` | Pós-efeito só da imagem 3D (`RoomView`): vinheta, grão, aberração cromática, distorção e pulso vermelho. |

Mudanças em scripts compartilhados (todas desligadas por padrão, os testes antigos não mudam):
`paper_dialogue.gd: screen_space` (fala no `Dialogue` global, ao lado da cabeça de quem fala, na faixa de cima da
tela), `reception_camera.gd: keyboard_look/edge_hold/effect_rotation`, `visitor_orientation.gd: allow_mode_key`
(desligado no jogo: o **P** volta a abrir o cheat).

**Terror (`horror_director.gd`), crescendo por dia (`DAY_LOOK`):**
- Todo dia começa no escuro: as lâmpadas acendem falhando (`lights_on`). Neblina, luz, janelas (anoitecendo) e
  saturação pioram a cada dia; o dia 3 fica avermelhado.
- Visores de andar nas 3 cabines (T, 1–6, S). Quem embarca sobe andar por andar; ao chegar no **S** há impacto,
  tremor, pulso vermelho e "SUBSOLO" no monitor. O visor da cabine 2 (a da Marta) fica sempre no **S** e pisca
  antes de ela aparecer (`marta_incoming`), com batimento cardíaco enquanto ela está na sala.
- **Vítimas do subsolo** (`victims`, static, máx. 4): voltam paradas dentro da cabine quando ela abre para o próximo
  visitante e ficam sentadas nas cadeiras, visíveis só quando a luz falha.
- Eventos aleatórios com visitante no balcão: luz piscando, batidas no poço, porta de entrada abrindo sozinha,
  cabine 3 abrindo vazia com luz vermelha, a **Marta parada no canto** (some quando você olha para ela),
  "ELA ESTÁ VENDO" no monitor e flash subliminar da Marta ensanguentada no rosto do visitante (dia 3).
- Câmera de segurança no teto que segue o jogador (LED piscando). Regra das câmeras → "SORRIA." no monitor.
- **Erro:** a luz cai, o visitante some no escuro e a Marta (com raiva) aparece colada no balcão com impacto,
  tremor, aberração e zoom; depois fala `mensagem_falha` e o dia recarrega.
- **Fim do dia 3:** depois da fala, apagão, a cabine dela desce e o rosto ensanguentado aparece por um instante.
- Personagens: ciclo de passos com os quadros existentes (`npc_male_1` 1–3, `marta` 1–3) e balanço ao andar.
  Visitantes em tamanho humano (`pixel_size` 0,0084), iluminados pela sala (`shaded`), sem sombra projetada.

**Como verificar:** abrir `tutorial_3d.tscn` ou `reception_3d.tscn` com F6 (ou F5 pelo menu). Para o dia, use o cheat
(P) ou `reception_presentation.gd: dia_em_andamento` num script `-s`. Testes automáticos continuam os da seção 12.
Não há teste automático de áudio: o volume do ambiente (`ambience.gd: volume_db` −8 dB) foi escolhido sem ouvir.

### 14.1 Mecânicas e história da 3D (desde 04/11/2026)

**Sem música no gameplay** (`reception_3d.gd` chama `Audio.stop_music()`): o som é o ambiente procedural, o telefone
e o elevador. O menu e os créditos continuam com música.

Referências usadas: FNAF (regras e lore por telefone; a voz confiável que depois liga de onde não deveria),
Doki Doki Literature Club (a personagem simpática que racha aos poucos) e Papers, Please (regras acumuladas,
advertências). Tudo em `story_director.gd` (`DAYS` = o roteiro de cada dia).

| Mecânica | Como funciona | Onde |
|---|---|---|
| **Telefone** | O telefone da mesa toca (som procedural, fone tremendo, LED). Clique atende; a ligação aparece no canto superior esquerdo (Espaço passa a fala). Não atender em 22 s = chamada perdida (advertência se era do Godofredo). | `desk_devices.gd`, `story_director.gd`, `screen_hud.gd: show_call` |
| **Regra do 6º andar** | Do dia 1 em diante: só sobe ao 6º quem foi **anunciado pelo nome** por telefone; os outros que pedem o 6º: negar. A regra e os nomes ficam numa **folha de papel na mesa** (`sixth_floor_note.gd`), não na prancheta da Marta. A história transforma visitas futuras em convidados (nome único no dia) e às vezes num "penetra" não anunciado. | `src/gameplay/scripts/phone_rule.gd` (GUARDA/CONVIDADO, sem texto de prancheta), `ReceptionSession.add_extra_rule/override_upcoming`, `RuleValidator` (`visita` opcional, regras `final`), `desk_modal.gd` (não lista regras sem texto) |
| **Câmera do elevador + ALARME** | Quem embarca é visto ao vivo no monitor da mesa (câmera dentro da cabine 1). Alguns passeios **descem sozinhos** ao subsolo (luz vermelha, figura atrás do passageiro): nos dias 1 e 2 o ALARME salva; se não apertar, ele some. Alarme sem motivo = advertência. **Dia 3:** a Marta proíbe o alarme na abertura; apertar ainda para a cabine, mas ela responde pelo alto-falante e o jogador leva advertência **a cada aperto** (3 sabotagens no dia: não dá para salvar todos sem ser demitido). O Seu Tião (tag `send_to_basement`) desce para limpar e não vira vítima. | `elevator_watch.gd`, `story_director.gd: begin_ride/_on_alarm_clicked` |
| **Advertências** | 3 = demitido: a Marta "consegue seu emprego de volta" e o mesmo dia recomeça. | `story_director.gd: _warn`, `reception_3d.gd: _run_fired` |
| **Recomeço depois de falhar** | Andar errado ou demissão recarregam o mesmo dia **direto no atendimento**: sem luzes falhando, sem Godofredo nem Marta na abertura ("Dia N · de novo"). A regra do 6º andar volta à prancheta; ligações de lore e a visita do Godofredo do dia 2 já ouvidas não se repetem (ligações de convidado sim, porque dão os nomes). | `reception_3d.gd: _retry_day/_skip_intro`, `story_director.gd: heard/on_retry`, `horror_director.gd: lights_now` |
| **Relatório do turno** | Antes de trocar de dia: atendidos, salvos, mandados ao subsolo, desaparecidos, advertências e um comentário da Marta. | `story_director.gd: report_text`, `screen_hud.gd: show_report` |

**Arco da história** (textos em `story_lines.gd`):
- **Dia 1, parece tudo normal:** o Godofredo (sprite `manfredo_diretor.png`, cabine 3) é um chefe mal-humorado comum;
  a Marta é simpática e prestativa. Fora do lugar: "o subsolo... essa parte é comigo", o elevador "parado no subsolo a
  tarde toda". Errar no dia 1 é suave (sem apagão, sem Marta com raiva). O tutorial termina com ela só indo embora.
- **Dia 2, fica claro:** o Godofredo liga avisando que o elevador desceu à noite, pede segredo da Marta e desce para
  cobrar explicações (funcionários e entregador sumidos); a Marta o desmente na frente do jogador e pede que ele conte
  o que o Godofredo disser. O entregador da encomenda dela não volta ("é katchup").
- **Dia 3, sem disfarce:** o Godofredo some (não aparece nem liga); a Marta assume o prédio e o ramal do 6º, proíbe o
  alarme e o Seu Tião limpa a "bagunça" lá embaixo. **Ninguém liga do subsolo:** quem desce, morre lá.

**Testar:** o roteiro de cada dia foi validado jogando os dias 1, 2 e 3 completos por script (atendendo o telefone,
apertando ou ignorando o alarme, com 3 alarmes falsos). As suítes da seção 12 continuam passando.
