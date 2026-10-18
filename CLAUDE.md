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
| Engine | **Godot 4.7.2**, GDScript, sem plugins |
| Equipe | Rodrigo (game design), Mari (HUD), Clara (sprites), Gustavo e Daniel (programação) |

**Premissa.** O protagonista está desempregado há seis meses e aceita uma vaga de recepcionista
"boa demais para ser verdade" num prédio comercial de seis andares. Na recepção, cada visitante
diz para onde quer ir; o jogador confere o livro de andares, as regras do dia e o crachá, e escolhe
o andar no painel do elevador (ou nega o acesso).

**Marta** é a supervisora: simpática na superfície, mas é a **vilã**. Ela aparece no começo do dia,
a cada 2 atendimentos para ditar **regras suspeitas** (ex.: "quem pedir o 5º andar, mande para o
subsolo... eles vão entender quando chegarem lá"), quando o jogador erra e no fim do dia.
O subsolo é um "pavimento não atribuído" que oficialmente não existe.

**Andares do prédio** (fonte: tabela do game designer, em `src/levels/resources/company_directory.tres`):

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
menu.tscn ──Jogar──▶ tutorial.tscn ──fim ou "Pular tutorial [Esc]"──▶ (SceneTransition: "Dia 1") ──▶ reception.tscn
    │                                                         (dia 1 → dia 2 → dia 3, mesma cena)
    └─Opções──▶ options.tscn ──Créditos──▶ credits.tscn
```
Na recepção, **Esc** abre o pause (`pause.tscn`: Continuar, Opções, Menu principal, Sair do jogo).

- Cena principal (`run/main_scene`): `src/ui/menus/scenes/menu.tscn` (uid `b6hgpbqqj2j76`).
- O botão Jogar abre o **tutorial** (`menu.gd: GAME_SCENE`), não a recepção.
- Ao falhar na recepção, a cena é recarregada (`reload_current_scene`) **no mesmo dia**.
- Dias encadeados: no fim do dia, depois do Espaço na fala da Marta, a recepção é recarregada com
  `proximo_dia` (transição "Dia N"). O dia atual fica em `ReceptionManager.dia_em_andamento`
  (static); o tutorial zera para o dia 1. Dia 1 → `day1.tres`, Dia 2 → `day2.tres`, Dia 3 → `day3.tres` (último por enquanto).
- **Fim de jogo**: depois da fala de fim do dia 3 (Espaço), transição para `src/ui/menus/scenes/end_screen.tscn`
  (campo `cena_final` do `day3.tres`): epílogo narrado, "Fim.", créditos subindo e "Voltar ao menu".

---

## 3. Configuração do projeto (`project.godot`)

| Item | Valor | Observação |
|---|---|---|
| Resolução base | 640 × 360 | Todas as coordenadas de cena/HUD estão nessa base |
| Janela | 1920 × 1080, modo 3 (tela cheia) | |
| Stretch | `canvas_items` | Texto é desenhado na resolução da janela (fica liso) |
| Filtro de textura | Nearest (`default_texture_filter=0`) | Pixel art nítido |
| Snap 2D | `snap_2d_transforms_to_pixel=true` | |
| Autoloads | `Dialogue`, `SceneTransition`, `MusicMenu`, `Audio` | Ver seção 6. `MusicMenu` é registrado pelo **caminho** (`res://sounds/music/menu/music_menu.tscn`): pelo uid dava "Unrecognized UID" |
| Áudio | `default_bus_layout.tres` | Buses `Master`, `Music`, `SFX` (os sliders das opções usam esses nomes) |
| Input | `hack_level1`, `hack_level2` | Declarados, **não usados** em nenhum script. O hack de pular dia usa **F9** direto no código (`TECLA_PULAR_DIA`) |

Fontes em uso (`src/levels/assets/fonts/`, desde o PR #36): **PixeloidSans** e **PixeloidSans-Bold**
(texto e títulos), além de PixeloidMono e Jersey10. Os recursos `fonts/resources/dynapuff_*.tres` mantêm o nome
antigo, mas hoje apontam para a PixeloidSans. Chewy e DynaPuff foram apagadas.
Algumas cenas (`company_book`, `badge_details`, `rules_board`) referenciam `fonts/Pixeloid_Font_1_0/...`,
caminho que não existe: elas carregam pelo `uid`. Se o uid se perder, corrija o caminho para `fonts/`.

---

## 4. Estrutura de pastas

```
autoload/
  dialogue/            Caixa de fala global (balão de fala, com páginas)
  scene_transition/    Fade + título entre cenas
  audio/               audio.gd (autoload Audio: música do gameplay + efeitos sonoros, ver 6.9)
sounds/music/
  menu/                music_menu.tscn/.gd (autoload MusicMenu: toca musica_menu.wav no bus Music)
  wav/                 musica_menu.wav + mp3 do jogo (musica_gameplay, musica_errada, BotãoPressionado,
                       chegou_elevador, digitando, erro, sucess, passando_pagina)
default_bus_layout.tres  buses Music e SFX
src/
  levels/
    assets/            Arte da HUD (4x): main_hud, badge, buttons, company_book, rules, Elevador, fonts
    resources/         company_directory.tres (livro de andares)
    scenes/            reception.tscn, tutorial.tscn
    schedules/         day1.tres, day2.tres, day3.tres (agendas dos dias)
    scripts/           reception_manager, day_schedule, day_interaction, marta_rule,
                       company_data/directory, tutorial, tutorial_step/script
    tutorial/          tutorial_intro.tres (roteiro do tutorial)
  npcs/
    assets/            Sprites 256x256 dos NPCs (jose, marta, lucas, tiao, manfredo, ...)
    dialogue/          npc_dialogue.gd + dialoguesCommon/ (dia 1), dialoguesDia2/, dialoguesDia3/ (<N> andar/*.tres)
    resources/         visitor_data.gd, Day1/, Day2/, Day3/ (tiao.tres), name_list.gd, male_names.tres, ...
    scenes/            visitor.tscn, characters/ (cenas visuais dos NPCs)
    Marta/             Marta.tscn
    scripts/           visitor.gd
  shared/              rule_validator.gd
  ui/
    hud/               reception_hud, elevator_panel/button, company_book, rules_board,
                       badge_details, shift_summary
    menus/             menu, options, credits, pause, options_pause; assets/ (tela inicial *.jpg, buttons/)
docs/                  decisions/, game-design/, references/, team/ (vazias no repo)
tools/createscene.gd   EditorScript antigo (desatualizado, ver seção 9)
```

---

## 5. Cenas existentes

### 5.1 `src/levels/scenes/reception.tscn` — a recepção (gameplay)
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

### 5.2 `src/ui/hud/reception_hud.tscn` — HUD da recepção (posições na base 640x360)
| Nó | Posição / tamanho | Função |
|---|---|---|
| Desk | (0, 201) 678x181 | Mesa |
| Badge | (115, 195) 43x92 | Crachá fechado (script `reception_hud.gd`, feito pela equipe) |
| CompanyBook | (246, 216) 193x142 | Livro de andares, 2 por página, setas `<` e `>` |
| RulesBoard | (78, 314) 116x151 | Prancheta de regras: só 46 px visíveis; clique sobe/desce; Esc fecha |
| BadgeOverlay/BadgeDetails | CanvasLayer 10 | Crachá aberto (nome, idade, sexo, ocupação, foto) |

### 5.2b `src/levels/scenes/elevator.tscn` — elevador na parede
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


### 5.3 `src/ui/hud/elevator_panel.tscn` — painel do elevador
- Arte em 4x (`src/levels/assets/Elevador/`), painel 384x624 com `scale = 0.25`.
- Botões: 5,6 / 3,4 / 1,2 / S (subsolo, código -1), X (negar, código 999), Confirmar.
- Mecânica: clicar seleciona (botão afunda), clicar de novo desmarca; **Confirmar** só libera com
  seleção e emite `floor_selected(código)`. `set_panel_locked(bool)` trava/escurece tudo.
- Botões são `elevator_button.gd` (Control com `Normal`/`Selected`/`Label`), o sprite afundado é
  alinhado pela base. X normal e Confirmar normal são recortes (`AtlasTexture`) de
  `painel elevador botões.png`. Os sprites "sem contorno" foram gerados a partir dos originais
  trocando os pixels amarelos pela cor da face.

### 5.4 `src/levels/scenes/tutorial.tscn` — tutorial
- Mesmo cenário da recepção (`PisoParede`, cadeiras, elevador, HUD; painel travado). O `WindowClip` tem de ser
  igual ao da recepção (`clip_children = 1`, largura 465): com `clip_children = 2` ele desenha um retângulo
  branco por cima do fundo e das cadeiras.
- `NarrationLayer` (layer 5): tela escura com texto (narração da história do protagonista).
- `SkipLayer` (layer 20): botão "Pular tutorial [Esc]".
- Roteiro: `src/levels/tutorial/tutorial_intro.tres` (12 passos: 4 narrações + 8 falas da Marta).
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
- `src/ui/hud/company_book.tscn`, `rules_board.tscn`, `badge_details.tscn`: componentes da HUD.
- `src/npcs/scenes/visitor.tscn`: nó base do visitante (script `visitor.gd`).
- `src/npcs/Marta/Marta.tscn`: Marta = `visitor.gd` + Sprite2D 256 px.
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
- `pause.tscn` + `pause.gd`: Esc pausa (`get_tree().paused`); Esc com a prancheta de regras aberta só
  fecha a prancheta (`rules_board.gd` usa `_shortcut_input`). "Menu principal" chama `Dialogue.clear_dialogue()`.
  `options_pause.tscn`: opções dentro do pause.

---

## 6. Sistemas e scripts

### 6.1 Fluxo da recepção (`reception_manager.gd`)
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

### 6.2 Validação (`src/shared/rule_validator.gd`)
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
- `sprite_marta_fim` = `Marta sangrenta.png`: só na fala de fim ela aparece ensanguentada ("é katchup!").
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
`MusicMenu` (autoload) toca `musica_menu.wav` no menu; para ao apertar **Jogar** (`menu.gd`) e volta quando o
menu abre de novo (o menu também para a música do gameplay). `Audio` (`autoload/audio/audio.gd`, registrado pelo
caminho) tem um player de música (bus Music), um de loop e 6 vozes de efeito (bus SFX):

| Som | Quando | Onde |
|---|---|---|
| `musica_gameplay` | Recepção, dias 1 e 2 (em loop) | `reception_manager._ready` |
| `musica_errada` | Recepção, a partir do dia 3 (em loop) | `reception_manager._ready` |
| `BotãoPressionado` | Qualquer botão do painel do elevador (inclui X e Confirmar) | `elevator_button._gui_input` |
| `chegou_elevador` | Porta do elevador abre estando fechada: -6 dB (50%); quando a Marta sai, volume normal e pitch 0,7 | `elevator._tocar_chegada` (`release(..., som_da_marta)`) |
| `digitando` | Narração da intro (tutorial), enquanto o texto aparece | `tutorial._show_narration` |
| `passando_pagina` | Setas do livro de andares | `company_book.next_page/previous_page` |
| `sucess` / `erro` | Acerto / erro do andar | `_process_success` / `fail` |
| `MartaSubsoloKetchup` | Fim do dia 2, no escuro (`som_no_escuro` do `day2.tres`) | `_apagar_luzes` |

Os MP3 foram importados sem loop: `audio.gd` liga `loop` em código nas músicas e no `digitando`.
`play_music` não reinicia a mesma música (ao falhar e recarregar a cena ela continua).

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
| Visitantes do dia, ordem, quantidade | `src/levels/schedules/dayN.tres` → `interacoes` |
| Novo dia | copiar `day3.tres`, mudar `dia_numero`, apontar o `proximo_dia` do dia anterior para ele e mover o `cena_final` para o novo último dia |
| Epílogo e créditos finais | `src/ui/menus/scripts/end_screen.gd` → consts `EPILOGO` e `CREDITOS` |
| Suspense / sprite da Marta no fim | `dayN.tres` → `suspense_antes_do_fim`, `sprite_marta_fim` |
| Regras da Marta e intervalo | `dayN.tres` → grupo "Regras da Marta" |
| Falas/andar de um NPC | `.tres` em `src/npcs/resources/Day*/` ou `src/npcs/dialogue/` |
| Livro de andares | `src/levels/resources/company_directory.tres` |
| Roteiro do tutorial | `src/levels/tutorial/tutorial_intro.tres` |
| Lista de nomes | `src/npcs/resources/male_names.tres` |
| Ritmo da recepção | nó `Reception`: `delay_between_visitors`, `visitor_move_speed` |
| Título da transição | `tutorial.tscn` → `titulo_dia` |

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

- **Tag do entregador:** `Day2/entregador.tres` usa a tag `entregador`, mas o validador procura
  `delivery`/`generic_delivery` — a regra "entregador vai ao 1º andar no dia 2" não se aplica a ele.
- `mensagem_fim` do dia 1 diz "você deixou aquele entregador ir para o terceiro andar... você não sabia!",
  embora mandá-lo ao 3º seja o certo pelo validador. Parece pista narrativa intencional; confirmar com o Rodrigo.
- `DialogueUI`, `ManualPanel` e `ShiftSummary` em `reception.tscn` são `Control` vazios; `shift_summary.gd`
  existe mas não está ligado.
- `tools/createscene.gd` ainda aponta para caminhos antigos (`src/levels/reception.tscn`).
- Código/recursos sem uso: `phrase_set.gd` + `standard_phrases.tres` (frases padrão antigas),
  `src/npcs/level_day_config/day_config.gd` (`DayConfig`, substituído por `DayScheduleConfig`),
  `src/npcs/resources/common_npc_male1.tres` (o usado é o de `Day1/`), ações `hack_level1/2`.
- Ao criar um dia novo, preencher `falas_comuns` (senão andares sem fala ficam sem visitante).
- O tutorial destaca o "painel" e diz "escolher o andar no painel do elevador, ou negar o acesso";
  se a mecânica mudar, atualizar `tutorial_intro.tres`.
- A prancheta de regras aberta cobre o crachá.
- Volumes do `Audio` (`MUSIC_VOLUME_DB` -20, `SFX_VOLUME_DB` -6, `LOOP_VOLUME_DB` -10) foram chutados
  sem ouvir; ajustar no jogo.
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
  `var RM = load("res://src/levels/scripts/reception_manager.gd")` e `RM.dia_em_andamento = ...`.
- Scripts de teste (`extends SceneTree`) podem: `change_scene_to_file`, simular teclas com
  `Input.parse_input_event(InputEventAction)`, emitir `pressed` nos botões do elevador e consultar
  `RuleValidator.andar_esperado(...)` para responder certo.
- Em modo `-s`, `await` dentro de `_initialize` funciona para a maioria dos casos; para roteiros
  temporizados no Movie Maker, use um contador de quadros em `_process`.
- O Movie Maker com stretch `canvas_items` grava em 1920x1080.
- Para inspecionar o que **o editor** carrega (diferente do jogo), use uma cópia do projeto com um
  `EditorPlugin` temporário e `--headless -e` (foi assim que o problema 1 foi diagnosticado).
