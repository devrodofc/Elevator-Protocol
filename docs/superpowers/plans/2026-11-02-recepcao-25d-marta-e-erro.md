# Recepção 2.5D — Marta, erro e fim do dia: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Na cena `reception_gameplay_test.tscn`, a Marta faz a introdução, dita as regras depois do 2º e do 4º
atendimento, reage ao erro (recarregando o mesmo dia) e encerra o dia, avançando dia 1 → 2 → 3 → tela final,
igual ao 2D.

**Architecture:** A `ReceptionSession` continua sendo a única autoridade. Dois scripts novos de apresentação:
`marta_actor.gd` (o segundo ator 3D, com rotas pela cabine 2 e balão de papel próprio) e `reception_effects.gd`
(as camadas vermelha e escura e o tremor, portados do 2D). A orquestração entra em `reception_presentation.gd`,
atrás de uma opção nova, `enable_marta`.

**Tech Stack:** Godot 4.7.2, GDScript. Testes em SceneTree (`extends SceneTree`), rodados com
`--headless --fixed-fps 60`.

**Spec:** `docs/superpowers/specs/2026-11-02-recepcao-25d-marta-e-erro-design.md`

## Global Constraints

- Godot `C:/Users/user/AppData/Roaming/Ryko.GodotHub/godot-versions/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe` (`$G`).
- Testes 2.5D sempre com `"$G" --headless --fixed-fps 60 --path . -s res://<teste>.gd`.
- **Sem commit e sem push** (o Gustavo revisa o diff na branch `gustavo`). Onde o skill diria "Commit", confira `git diff --ignore-cr-at-eol --stat`.
- Não alterar: `dayN.tres`, recursos de NPC, `scenes/reception.tscn` (sala pura), a recepção 2D, `automatic_door.gd`, `visitor_movement.gd`, `visitor_orientation.gd`, `paper_dialogue.gd`.
- Cabine dos visitantes: `Elevator01`. **Cabine da Marta: `Elevator02`**, em todas as aparições.
- Sprite padrão da Marta: `res://src/npcs/assets/marta/marta_1_frame.png`. No erro, ao chegar: `res://src/npcs/assets/marta/marta_anger.png`, **em todos os dias**.
- Tempos do 2D: 1,0 s de choque no erro; camada vermelha `Color(0.7,0,0,0)` → alfa 0,15 em 3,5 s (SINE, IN_OUT); fala de falha até 6 s ou Espaço; prancheta aberta 1,8 s; encarada do fim do dia 2 de 1,8 s.
- Sons: `Audio.SUCESSO` no acerto, `Audio.ERRO` no erro, `Audio.play_sfx(Audio.CHEGOU_ELEVADOR, 0.0, 0.7)` quando a cabine da Marta abre; música `Audio.MUSICA_ERRADA if dia >= 3 else Audio.MUSICA_GAMEPLAY` no `_ready`.
- A regra só é ativada (`session.activate_pending_rule`) **depois do último Espaço** da fala da Marta.
- Toda continuação com `await` confere a geração da sessão (ou a versão do ator) e desiste se mudou.

## Review Focus

1. **Espaço repetido ou rápido durante a fala da Marta:** a fala passa página por página, a regra é ativada uma vez só, e o Espaço não "vaza" para a fala do próximo visitante. Teste na Task 3.
2. **Modal aberto (livro ou prancheta) enquanto a Marta fala ou quando a prancheta deveria abrir sozinha:** o Espaço fica com o modal (a fala espera), e a abertura automática não abre por cima de outro modal (pula, como no 2D quando a prancheta já está aberta). Teste na Task 3.
3. **Erro no visitante do caso da regra (logo depois de uma regra):** depois de recarregar, nenhuma regra antiga continua ativa e a contagem volta a 0. Teste na Task 4.
4. **Recarregar ou trocar de dia no meio da fala ou do trajeto da Marta:** nenhuma fala, cabine aberta ou ativação de regra da cena antiga aparece na nova. Teste na Task 4.
5. **Depois do dia 3:** a tela final abre, e a próxima F6 começa no `Test Day` do Inspector, não no dia 4 nem no 3 guardado. Teste na Task 5.

---

### Task 1: Ator da Marta (`marta_actor.gd`) com rotas pela cabine 2

**Files:**
- Create: `src/gameplay/reception_25d/scripts/marta_actor.gd`
- Modify: `src/gameplay/reception_25d/scripts/elevator_door.gd` (só acrescentar um método)
- Test: `src/gameplay/reception_25d/tests/reception_marta_test.gd` (criar; as próximas tasks acrescentam seções)

**Interfaces:**
- Produces (em `elevator_door.gd`): `func has_exited_passage(world_position: Vector3) -> bool`: verdadeiro quando `to_local(world_position).z >= _closed_positions[0].z + passage_clearance` (o lado da sala; o oposto de `has_cleared_passage`).
- Produces (`marta_actor.gd`, `extends Node`):
  - `const CABIN: String = "Elevator02"`, `const DEFAULT_SPRITE`, `const ANGER_SPRITE` (os caminhos das Global Constraints).
  - `var ground: Node3D` (duplicado de `RoomViewport/Room/VisitorGround`, com o próprio `Sprite3D` `test_sprite.gd` e `ContactShadow`, adicionado como irmão do original e escondido no início).
  - `var cabin` (a `Elevator02`), `var paper` (`paper_dialogue.gd` filho de `ground`), `var busy: bool`.
  - `func setup(presentation: Node2D) -> void`: cria o ator, um `visitor_movement.gd` próprio (velocidade 3, `floor_reference` = `ServicePoint`) e um `visitor_orientation.gd` próprio (PAPER, `set_process_input(false)`; copia `orientation_mode` da orientação do visitante em `_process`, para a tecla P valer para os dois sem ser consumida duas vezes).
  - `func arrive_from_entrance(door, entrance: Marker3D) -> bool` (await): vestíbulo → porta abre → `[entrance, QueueJoinPoint, ServicePoint]` → fecha a porta ao `has_cleared_passage`; volta quando chegou **e** a porta está CLOSED.
  - `func arrive_from_cabin(arrival_sprite: Texture2D = null, start_sprite: Texture2D = null) -> bool` (await): começa escondida no `CabinStopPoint` com `start_sprite` (ou o padrão); cabine abre com `CHEGOU_ELEVADOR` em pitch 0,7; aparece quando OPEN; rota `CabinStopPoint → EntryPoint → ApproachPoint → Elevator02TurnPoint → CorridorEntry → RetreatPoint → ServicePoint`; fecha a cabine ao `has_exited_passage`; ao chegar, troca para `arrival_sprite` se houver e encara a câmera; volta quando chegou **e** a cabine está CLOSED.
  - `func speak(speaker: String, text: String, max_seconds: float = 0.0) -> bool` (await): mostra o balão de papel com `display_dialogue(speaker, text, true)` e espera `wait_for_advance(max_seconds)`; limpa a fala ao terminar.
  - `func leave_into_cabin() -> bool` (await): `[RetreatPoint, CorridorEntry, Elevator02TurnPoint, ApproachPoint]` → abre → `[EntryPoint, CabinStopPoint]` → fecha ao `has_cleared_passage` → volta quando chegou **e** CLOSED; esconde o ator.
  - `func cancel() -> void`: incrementa a versão interna, para o movimento, fecha a cabine (`reset_closed`), limpa a fala e esconde o ator. Toda função com await devolve `false` se a versão mudou no meio.
  - Encaminha `ui_accept` para o próprio balão em `_unhandled_input` quando ele está visível e `presentation.desk.modal.kind` está vazio (mesma lógica do `desk_service._unhandled_input`).
  - **Não** emite `movement_reset`/`route_started` para o adaptador do visitante: são outros nós de movimento.

- [ ] **Step 1: Escrever o teste** em `reception_marta_test.gd`, seção `_actor_routes()`. Cena com `enable_marta = false` (o ator é criado à mão: `MartaActor.new()`, `add_child`, `setup(scene)`), depois que o primeiro visitante chegou ao balcão:
  - `arrive_from_cabin(ANGER)` retorna `true`; durante o trajeto, `Elevator01.state == CLOSED`; ao voltar, `ground.global_position` em XZ == `ServicePoint`, `Elevator02.state == CLOSED`, `sprite.source_texture == ANGER_SPRITE`.
  - `leave_into_cabin()` retorna `true`, `ground.visible == false`, `Elevator02.state == CLOSED`.
  - `cancel()` no meio de `arrive_from_cabin`: a função retorna `false`, `Elevator02.state == CLOSED` e o ator fica escondido.
  - Apertar P uma vez troca o modo dos dois atores (`marta.orientation.orientation_mode == scene.orientation.orientation_mode`).
- [ ] **Step 2: Rodar e ver falhar.** `"$G" --headless --fixed-fps 60 --path . -s res://src/gameplay/reception_25d/tests/reception_marta_test.gd`. Esperado: erro de carregamento de `marta_actor.gd`.
- [ ] **Step 3: Implementar** `has_exited_passage` e `marta_actor.gd` conforme as Interfaces. A espera "chegou e porta CLOSED" é um laço `await get_tree().process_frame` conferindo a versão, no mesmo estilo do `_await_callback` do 2D.
- [ ] **Step 4: Rodar e ver passar.** Esperado: `I5_MARTA_RESULT checks=N failures=0` (o teste imprime essa linha no fim).
- [ ] **Step 5: Conferir o diff** (`git diff --ignore-cr-at-eol --stat`): só os arquivos desta task.

### Task 2: Efeitos de tela (`reception_effects.gd`)

**Files:**
- Create: `src/gameplay/reception_25d/scripts/reception_effects.gd`
- Test: `reception_marta_test.gd`, seção `_effects()`

**Interfaces:**
- Produces (`extends CanvasLayer`, `layer = 4`: abaixo da `ElevatorUI` (5) e dos modais; o balão de papel fica na imagem da sala, logo sob a camada, por isso os alfas máximos do 2D são mantidos):
  - `func setup(presentation: Node2D) -> void` (guarda a cena para o tremor do `RoomView`).
  - `func fade_red() -> ColorRect`: a camada vermelha da falha (valores das Global Constraints).
  - `func apagar_luzes(segundos: float, som: AudioStream = null) -> ColorRect` (await): porta literal do `_apagar_luzes` do 2D (`reception_manager.gd:431-477`), **sem** o laço `elevator.is_busy()` (a presentation só chama depois da liberação). Usa `Audio.fade_out_music`, `Audio.play_sfx(som)` e `tremer`.
  - `func stare_red(escuro: ColorRect) -> void` e `func dim_partial(escuro: ColorRect) -> void`: os dois ramos de luz do `_conclude_day` 2D (`reception_manager.gd:356-369`).
  - `func tremer(segundos: float, forca: float) -> void`: o `_tremer` do 2D aplicado à `position` do nó `RoomView`.
  - `func cancel() -> void`: mata os tweens e apaga as camadas.

- [ ] **Step 1: Teste.** `fade_red()` → depois de 3,6 s (216 quadros), `color.a` ≈ 0,15 (±0,01). `apagar_luzes(0.1)` sem som → camada com `color.a` ≈ 0,7. `tremer(0.3, 3)` → `RoomView.position` volta ao original depois de 0,4 s. `cancel()` → nenhum filho visível.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Conferir o diff.**

### Task 3: Introdução e regras na apresentação

**Files:**
- Modify: `src/gameplay/reception_25d/scripts/reception_presentation.gd`
- Modify: `src/gameplay/reception_25d/scripts/desk_service.gd`
- Modify: `src/gameplay/reception_25d/scenes/reception_gameplay_test.tscn` (`enable_marta = true`)
- Modify: `src/gameplay/reception_25d/tests/reception_dispatch_test.gd` (cada instância da cena: `enable_marta = false`)
- Test: `reception_marta_test.gd`, seção `_intro_and_rules()`

**Interfaces:**
- Consumes: `marta_actor.gd` (Task 1). Sessão: `start_day`, `finish_intro`, `take_due_rule`, `activate_pending_rule`, `finish_rule`, `finish_interval`.
- Produces (presentation):
  - `@export var enable_marta: bool = false` (só tem efeito com `enable_service` e `enable_departure`). Com ele ligado, `_ready` chama `session.start_day(day)` (não a prévia), toca a música do dia e chama `_run_intro()`.
  - `static var dia_em_andamento: DayScheduleConfig = null`: com `enable_marta`, se não for nulo, substitui o `Test Day`.
  - `var marta` (o `MartaActor`), `var effects` (o `ReceptionEffects`), criados em `_ready` quando `enable_marta`.
  - Novos estágios no fim do enum `Stage`: `MARTA` (Marta na sala; nenhum visitante ativo), `FAILING`, `CONCLUDING`, `LEAVING_SCENE`.
  - `signal rule_announced(rule: MartaRule)`, emitido logo depois de `activate_pending_rule` dar `true`.
  - `_run_intro()`: `marta.arrive_from_entrance(_door, _entrance)` → `marta.speak("Marta", schedule.mensagem_inicio)` → `marta.leave_into_cabin()` → `session.finish_intro(gen)` → `_begin_visit()`. O primeiro visitante **não** é chamado em `_ready` quando `enable_marta`.
  - Em `_release()`: com `enable_marta`, chama `session.take_due_rule(visit_id)`. Se vier regra, `_announce_rule(rule)`: `arrive_from_cabin()` → `speak("Marta", rule.fala)` → `activate_pending_rule` → `desk.flash_rules(1.8)` → `leave_into_cabin()` → `finish_rule` → `_begin_visit()`. Sem regra, segue o caminho da I4 (`finish_interval` + `_begin_visit`).
  - `Audio.play_sfx(Audio.SUCESSO)` em `_on_decision_processed` quando correto e `enable_marta`.
- Produces (desk):
  - `func set_marta_present(present: bool) -> void`: trava o painel e o crachá (botões `set_available(false)`, status `"Marta está falando"`); ao soltar, `_refresh_panel()`.
  - `func flash_rules(seconds: float) -> void` (await): se `modal.kind` estiver vazio, `modal.open("rules", {}, session.active_rules)`, espera `seconds` e fecha **se ainda for a mesma abertura**; se outro modal estiver aberto, não faz nada.

- [ ] **Step 1: Teste** (`Presenter.dia_em_andamento = null` antes; cena com `test_day = 1`, `enable_marta = true`, `current_scene` = cena via `change_scene_to_file(SCENE)`):
  - Antes de qualquer visitante: `marta.ground.visible`, `session.state == INTRO`, o balão da Marta com o texto `day1.mensagem_inicio`, `desk.confirm.available == false`.
  - Espaço (InputEventKey `KEY_SPACE` via `root.push_input`) até a fala terminar → Marta entra na cabine 2 → primeiro visitante `WAITING_FOR_DOOR`.
  - Atender certo dois visitantes → depois do 2º `visit_departed`: `Elevator02` abre, `marta` chega, `session.state == RULE`, `session.active_rules.size() == 0` **enquanto ela fala**.
  - Espaço várias vezes seguidas (10 em 10 quadros) → `rule_announced` emitido **uma vez**, `active_rules.size() == 1`, `desk.modal.kind == "rules"` por ~1,8 s e depois `""`.
  - Review Focus 1: depois da regra, o balão do próximo visitante aparece com a fala inteira por digitar (o Espaço não foi herdado: `paper.dialogue._page == 0`).
  - Review Focus 2: abrir o livro (`desk._open("book")`) antes do anúncio terminar → `flash_rules` não troca o modal (`modal.kind == "book"`), e a regra é anotada mesmo assim (`active_rules.size() == 1`).
  - Atender até o fim → regras anunciadas só depois do 2º e do 4º (`rule_announced` 2 vezes no dia 1), nenhuma depois do último.
  - O visitante `caso_regra` é decidido com a regra ativa: `RuleValidator.andar_esperado(..., active_rules)` difere do andar pedido e é aceito como correto.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** presentation, desk e cena. Na `reception_dispatch_test.gd`, `scene.enable_marta = false` em todas as instâncias.
- [ ] **Step 4: Rodar** `reception_marta_test.gd` e `reception_dispatch_test.gd`. Esperado: as duas com `failures=0`.
- [ ] **Step 5: Conferir o diff.**

### Task 4: Fluxo de erro

**Files:**
- Modify: `reception_presentation.gd`
- Test: `reception_marta_test.gd`, seção `_failure()`

**Interfaces:**
- Consumes: Tasks 1–3. Sessão: estado `FAILED`, `begin_transition`. Rota de saída da I4 (`TO_EXIT`/`EXITING`/`CLOSING_EXIT`).
- Produces: `_run_failure()`, chamado por `_on_decision_processed` quando incorreto e `enable_marta` (a I4 sem Marta continua parando em `FAILED`). Sequência: `Audio.play_sfx(Audio.ERRO)` → `desk.set_marta_present(true)` → 1,0 s → `effects.fade_red()` → o visitante inicia a rota de saída (o código da I4, sem contar atendimento e sem `finish_interval`) → espera o visitante passar do `RetreatPoint` (z do ator < z do `RetreatPoint` − 0,5) → `marta.arrive_from_cabin(ANGER_SPRITE)` → `marta.speak("Marta", schedule.mensagem_falha, 6.0)` → `session.begin_transition()` → `get_tree().reload_current_scene()`. `dia_em_andamento` é gravado com o dia atual antes de recarregar.
- A liberação do visitante (`CLOSING_EXIT` → `_release`) **não** chama `finish_interval` nem `_begin_visit` durante a falha.

- [ ] **Step 1: Teste:**
  - Dia 2 (`dia_em_andamento = day2`), errar o 1º visitante: `marta.sprite.source_texture == ANGER_SPRITE` ao chegar, `Elevator01.state == CLOSED` o tempo todo, o visitante sai pela porta (`stage` passa por `TO_EXIT`), camada vermelha com alfa ≈ 0,15, e a nova `current_scene` tem `session.day_number == 2`, `served_count == 0`, `active_rules.is_empty()`.
  - Sem Espaço, a recarga acontece entre 6 e 7 s depois do início da fala; com Espaço, logo depois.
  - Review Focus 3: dia 1, errar o visitante logo depois da 1ª regra → depois da recarga, `active_rules.is_empty()`, `served_count == 0`, `session.state == INTRO`.
  - Review Focus 4: recarregar (`reload_current_scene()`) no meio de `marta.speak` de uma regra → a cena nova não mostra balão nos primeiros 30 quadros além do da introdução, `Elevator02` fechada e `active_rules.is_empty()`.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar e ver passar** (`reception_marta_test.gd` e `reception_dispatch_test.gd`).
- [ ] **Step 5: Conferir o diff.**

### Task 5: Fim do dia e troca de dia

**Files:**
- Modify: `reception_presentation.gd`
- Test: `reception_marta_test.gd`, seção `_conclusion()`

**Interfaces:**
- Consumes: Tasks 1–4; `session.has_next_day()`; `SceneTransition.transition_to(path, title)`; campos do dia: `suspense_antes_do_fim`, `som_no_escuro`, `sprite_marta_fim`, `mensagem_fim`, `proximo_dia`, `cena_final`.
- Produces: `_run_conclusion()`, chamado quando `_begin_visit` encontra a fila vazia com `enable_marta` (no lugar do `DAY_DONE` da I4). Sequência como no 2D (`reception_manager.gd:334-385`): `set_marta_present(true)` → se suspense > 0, `effects.apagar_luzes(...)` → `marta.arrive_from_cabin(null, schedule.sprite_marta_fim)` → com escuro e som, `effects.stare_red(escuro)` + 1,8 s; com escuro sem som, `effects.dim_partial(escuro)` → `marta.speak("Marta", schedule.mensagem_fim)` → se `has_next_day()`: `session.begin_transition()`, `dia_em_andamento = proximo_dia` (ou `null` com `cena_final`) e `SceneTransition.transition_to(scene_file_path ou cena_final, "Dia %d" % proximo.dia_numero ou "")`.
- O `sprite_marta_fim` é o sprite **desde a saída da cabine** (`start_sprite`), como no 2D.

- [ ] **Step 1: Teste** (atendendo certo; usar `RuleValidator.andar_esperado(entry.visitor, entry.dialogue, dia, session.active_rules)`):
  - Dia 1 completo → fala `day1.mensagem_fim` → Espaço → depois da transição, `current_scene` com `session.day_number == 2`.
  - Dia 2 completo → camada escura com alfa ≥ 0,9 antes da Marta → `marta.sprite.source_texture` == `marta_bloody.png` ao sair da cabine → luz vermelha (camada com `color.r > 0`) → Espaço → dia 3.
  - Dia 3 completo → Espaço → `current_scene.scene_file_path == "res://src/ui/menus/scenes/end_screen.tscn"` e `Presenter.dia_em_andamento == null` (Review Focus 5).
  - O `Elevator01` nunca está aberto enquanto a Marta usa o `Elevator02` (amostrado a cada quadro do dia).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Conferir o diff.**

### Task 6: Regressão e documentação

**Files:**
- Modify: `CLAUDE.md` (seção 13: tabela de etapas, I5/I6 feitas, `Enable Marta`, cabine 2, `dia_em_andamento` estático da apresentação, nova suíte na tabela da seção 12)
- Create: `src/gameplay/reception_25d/docs/gameplay-integration-i5-i6.md` (mesmo formato do `gameplay-integration-i4.md`: decisões, alterações, fluxo, validação, roteiro F6)

- [ ] **Step 1: Rodar todas as suítes** com `--fixed-fps 60`: `reception_marta_test`, `reception_dispatch_test`, `reception_desk_test`, `reception_arrival_test` e as 4 de `tests/gameplay_regression/`. Esperado: `failures=0` em todas, menos `validator_schedule_test` (continua com as mesmas 136 falhas de hash já conhecidas, nenhuma nova).
- [ ] **Step 2: Conferir que as cenas do jogo 2D abrem** (menu, tutorial, recepção, tela final: instanciar por 30 quadros, sem `SCRIPT ERROR`).
- [ ] **Step 3: Escrever a documentação.**
- [ ] **Step 4: `git diff --ignore-cr-at-eol --stat` e `git diff --check`**: só os arquivos do plano; nenhum `.tres` de agenda alterado.
