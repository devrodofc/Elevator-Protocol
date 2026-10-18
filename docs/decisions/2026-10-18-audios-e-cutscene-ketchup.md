# Áudios do jogo e cutscene do ketchup (fim do dia 2)

- **Branch:** `feat/audios-e-cutscene-ketchup`
- **Base:** `develop` em `b0cb464` (PR #40), depois atualizada com a `develop` até `88cba41` (PR #43)
- **Data:** 18/10/2026
- **Commits:** `eac683e` (mudanças) → `fdfa57c` (merge da develop, com 2 conflitos resolvidos)

Este arquivo existe para ajudar quem pegar **conflito de merge** com esta branch: ele diz exatamente
o que mudou em cada arquivo e o que precisa sobreviver na resolução. Para a visão geral do sistema de
áudio, ver `CLAUDE.md` seção 6.9.

---

## 1. O que a branch faz

### Áudios
| Som | Quando toca |
|---|---|
| `musica_menu.wav` | No menu (já tocava). **Agora para ao apertar Jogar** e volta quando o menu abre de novo |
| `musica_gameplay.mp3` | Recepção nos dias 1 e 2, em loop. Não reinicia quando a cena recarrega após um erro |
| `musica_errada.mp3` | Recepção a partir do dia 3, em loop |
| `BotãoPressionado.mp3` | Qualquer botão do painel do elevador (inclui X e Confirmar), só com o painel destravado |
| `chegou_elevador.mp3` | Porta do elevador abre estando fechada. Comum: **-6 dB (50%)**. Quando a **Marta sai**: volume original e **pitch 0,7** |
| `digitando.mp3` | Em loop enquanto o texto da narração da intro (tutorial) aparece |
| `passando_pagina.mp3` | Setas `<` e `>` do livro de andares |
| `sucess.mp3` | Acerto (inclusive negar certo) |
| `erro.mp3` | Erro |
| `MartaSubsoloKetchup.mp3` | Fim do dia 2, no escuro (ver abaixo) |

### Cutscene do fim do dia 2
Depois que o entregador entra no elevador:
1. A música some (fade de 1,2 s) e a sala fica em silêncio.
2. As luzes piscam e a sala fica quase preta (alpha 0,9).
3. 1 s depois toca o `MartaSubsoloKetchup`, com o **cenário tremendo** (a HUD não treme) e um vermelho
   fraco no escuro.
4. Mais 3 s de silêncio (`suspense_antes_do_fim`).
5. O elevador chega com o som **grave** e a Marta ensanguentada sai.
6. Ela para e **encara 1,8 s** em silêncio; a luz volta pouco e **vermelha, pulsando** enquanto ela fala.
7. A música só volta no dia seguinte (dia 3: `musica_errada`).

O escuro mais forte, o tremor e a luz vermelha só acontecem em dias com `som_no_escuro`. O dia 3 continua
com o suspense antigo, mas agora também com a música sumindo e o som grave do elevador.

---

## 2. Arquivos novos
| Arquivo | O que é |
|---|---|
| `autoload/audio/audio.gd` (+ `.uid`) | Autoload `Audio`: 1 player de música (bus Music), 1 de loop e 6 vozes de efeito (bus SFX) |
| `sounds/music/wav/BotãoPressionado.mp3` (+ `.import`) | Antes `WhatsApp Audio 2026-10-18 at 17.35.13.mp3` |
| `sounds/music/wav/erro.mp3` (+ `.import`) | Antes `WhatsApp Audio 2026-10-18 at 17.22.32.mp3` |
| `sounds/music/wav/sucess.mp3` (+ `.import`) | Antes `WhatsApp Audio 2026-10-18 at 17.34.49.mp3` |
| `sounds/music/wav/MartaSubsoloKetchup.mp3` (+ `.import`) | Som do subsolo no fim do dia 2 (uid `c0uvc5hjrrjyk`) |

Os 3 `WhatsApp Audio ...` foram **apagados** (renomeados para os nomes acima; ninguém os referenciava).

API do `Audio`:
```gdscript
Audio.play_sfx(stream, volume_db := 0.0, pitch := 1.0)  # volume_db soma ao SFX_VOLUME_DB (-6)
Audio.play_music(stream)        # não reinicia se já toca a mesma
Audio.stop_music()
Audio.fade_out_music(segundos)  # some e para; o próximo play_music volta no volume normal
Audio.start_loop(stream) / Audio.stop_loop()
```
Constantes: `MUSIC_VOLUME_DB -20`, `SFX_VOLUME_DB -6`, `LOOP_VOLUME_DB -10`, `ELEVADOR_VOLUME_DB -6`,
`ELEVADOR_MARTA_PITCH 0.7`. **Os volumes foram escolhidos sem ouvir**: ajustar no jogo.
Os MP3 de música e o `digitando` foram importados sem loop; o `audio.gd` liga `loop = true` em código.

---

## 3. Arquivos alterados (o que precisa sobreviver num conflito)

### `project.godot`
Uma linha nova em `[autoload]`, **pelo caminho** (pelo uid dava "Unrecognized UID", igual ao `MusicMenu`):
```ini
Audio="*res://autoload/audio/audio.gd"
```

### `src/levels/scripts/reception_manager.gd` (arquivo compartilhado: o mais provável de conflitar)
| Função | Mudança |
|---|---|
| `_ready` | Depois de `_build_schedule_data()`: escolhe a música pelo `dia_numero` (`>= 3` → `MUSICA_ERRADA`, senão `MUSICA_GAMEPLAY`) e chama `Audio.play_music` |
| `_process_success` | 1ª linha: `Audio.play_sfx(Audio.SUCESSO)` |
| `fail` | 1ª linha: `Audio.play_sfx(Audio.ERRO)` |
| `_conclude_day` | Lê `som_escuro = schedule_config.som_no_escuro` e passa para `_apagar_luzes(suspense, som_escuro)`. Novo ramo `if escuro and som_escuro:` (luz vermelha que pulsa + espera de 1,8 s) antes do `elif escuro:` antigo |
| `_apagar_luzes` | Novo parâmetro `som: AudioStream = null`. `Audio.fade_out_music(1.2)` depois que o elevador esvazia; espera 1,4 s (com som) ou 0,6 s (sem); escuro final 0,9 (com som) ou 0,7; bloco `if som:` que toca o som, chama `_tremer` e faz o brilho vermelho |
| `_tremer` (nova) | Treme `position` do nó `Reception` com força decrescente |
| `_marta_arrive` | `elevator.release(marta_instance, target_pos, true)`: o `true` é o som grave da Marta |

**Conflito já resolvido no merge com a develop (PR #43, `chore/marta`)** em `_marta_arrive`. A linha certa
junta as duas branches:
```gdscript
marta_instance = _spawn_marta(elevator.door_position(), sprite, arrival_sprite)  # develop
await elevator.release(marta_instance, target_pos, true)                         # esta branch
```

### `src/levels/scripts/elevator.gd`
- `open(som_da_marta := false)` e `release(actor, destino, som_da_marta := false)`: parâmetro novo, repassado de `release` para `open`.
- `receive` chama `_tocar_chegada()` antes de `_sprite.play("abrir")`.
- Função nova `_tocar_chegada(som_da_marta)`: só toca se a animação atual é `fechar` (porta fechada).

### `src/levels/scripts/day_schedule.gd`
Campo novo logo depois de `suspense_antes_do_fim`:
```gdscript
@export var som_no_escuro: AudioStream
```

### `src/levels/schedules/day2.tres`
Só 2 linhas (o resto do arquivo é igual à develop):
```
[ext_resource type="AudioStream" uid="uid://c0uvc5hjrrjyk" path="res://sounds/music/wav/MartaSubsoloKetchup.mp3" id="11_ketchup"]
som_no_escuro = ExtResource("11_ketchup")      ← logo abaixo de suspense_antes_do_fim = 3.0
```

### Outros scripts (1 a 3 linhas cada)
| Arquivo | Mudança |
|---|---|
| `src/ui/menus/scripts/menu.gd` | `_ready`: `Audio.stop_music()` antes de `MusicMenu.play_if_stopped()`. `_on_play_pressed`: `MusicMenu.stop_music()` |
| `src/ui/hud/elevator_button.gd` | `_gui_input`: `Audio.play_sfx(Audio.BOTAO)` entre `accept_event()` e `pressed.emit(code)` |
| `src/ui/hud/company_book.gd` | `next_page` e `previous_page`: `Audio.play_sfx(Audio.PASSANDO_PAGINA)` na 1ª linha |
| `src/levels/scripts/tutorial.gd` | `_show_narration`: `Audio.start_loop(Audio.DIGITANDO)` depois de conectar o tween. `_on_narration_typed` e `_go_to_reception`: `Audio.stop_loop()` |

### `CLAUDE.md`
- Seção 3: `Audio` na linha de autoloads. Seção 4: pasta `autoload/audio/` e lista dos áudios.
- Seção 6.3: campo `som_no_escuro`. Seção 6.4 (dia 2): descrição da cutscene.
- **Seção 6.9 nova** (Áudio). Seção 10: nota dos volumes.
- **Conflito já resolvido no merge:** na seção 10 ficou a nota de volumes desta branch + o texto novo da
  develop sobre as regras de lore ("Decisão do Gustavo: manter assim"). O item antigo "Música do menu
  continua tocando no jogo / sons sem uso" foi **removido**, porque esta branch resolve isso.

---

## 4. Como resolver um conflito novo com esta branch
1. Em `reception_manager.gd`, aceite a versão da outra branch e **reaplique as linhas da tabela da seção 3**
   (cada uma é independente). Não perca o `true` do `elevator.release` em `_marta_arrive`.
2. Num conflito em `day2.tres`, **não aceite uma versão salva pelo editor**: use a versão da develop e
   adicione só as 2 linhas acima.
3. Depois do merge: `grep -c fc_common src/levels/schedules/day1.tres` deve dar **21** (problema 15 do `CLAUDE.md`).
4. Rode o jogo (ou os testes headless) antes de commitar.

## 5. Armadilhas encontradas nesta branch
- **O editor aberto regravou o `day2.tres` sozinho** e escreveu `andares_do_dia = null` (problema 1 do
  `CLAUDE.md`), além de apagar valores iguais ao padrão (`intervalo_regras`, `regras_por_dia`,
  `andar_destino = 999`). O arquivo foi restaurado da develop e só as 2 linhas foram reaplicadas.
  **Feche a Godot antes de operações de git** e, se ela estava aberta, use **Projeto → Recarregar Projeto
  Atual sem salvar** antes de abrir um `.tres`.
- O editor também regravou `reception.tscn`, `day1.tres` e `day3.tres` sem motivo. Essas mudanças
  **não** entraram nos commits (ficaram num stash local de backup).
- Dezenas de `.import` aparecem como modificados só por fim de linha: não foram commitados
  (`git diff --ignore-cr-at-eol --stat`).
- Depois do merge, a develop moveu as fontes para `fonts/`. O 1º `--import` mostra erros
  `Failed loading resource: res://src/levels/assets/fonts/...` (cache antigo); no 2º `--import` eles somem.

## 6. Como foi testado
Testes headless (`godot_console.exe --headless --path . -s <teste>.gd`, scripts fora do repositório):
- **Fluxo de áudio (16 verificações):** música do menu para ao Jogar e volta no menu; `digitando` na narração
  e parado na recepção; música certa nos dias 1, 2 e 3 (em loop); livro, botão do painel, elevador, acerto e
  erro tocam o som certo; ao voltar ao menu a música do gameplay para.
- **Fim do dia 2 (12 verificações), pelo fluxo real** (intro com Espaço → visitante → acerto com a fila vazia):
  ding comum a -12 dB (SFX -6 + elevador -6); música some antes do ketchup; o ketchup toca; o cenário treme e
  volta ao lugar; ding da Marta a -6 dB e pitch 0,7; a Marta fala em silêncio; o dia 3 recomeça a
  `musica_errada` no volume normal.
- Os testes rodaram de novo **depois do merge com a develop**: todos passaram.
- **Não testado:** o volume e o som de verdade (o teste não ouve). Ajustar ouvindo no jogo.
