# I5 + I6 — Marta, erro e fim do dia

> Registro histórico: a cena intermediária citada neste documento foi removida na Etapa C (07/11/2026).
> Os testes atuais usam `tests/reception_arrival_fixture.tscn` (I2) e `tests/reception_service_fixture.tscn`
> (I3–I6), sob `src/gameplay/reception_25d/`, sem os sistemas narrativos do jogo final.
> A arquitetura atual e os resultados da migração estão no README da recepção 2.5D.


Implementado em 02/11/2026, branch local `gustavo`, Godot 4.7.2-stable. Design aprovado pelo Gustavo:
`docs/superpowers/specs/2026-11-02-recepcao-25d-marta-e-erro-design.md`; plano:
`docs/superpowers/plans/2026-11-02-recepcao-25d-marta-e-erro.md`. A cena continua fora do fluxo do jogo
(menu, tutorial, cheat, F9 e F5 não mudaram).

## Decisões

| Decisão | Escolha | De quem |
| --- | --- | --- |
| Comportamento geral | Igual ao 2D (falas, tempos, ordem, critérios) | Gustavo |
| Sprite no erro | `marta_anger.png` em **todos os dias** (no 2D só no dia 1) | Gustavo |
| Cabine da Marta | Outra cabine: **`Elevator02`**, em todas as aparições | Gustavo (outra cabine) + escolha da cabine 2 |
| Regras | Marta só sai depois que o visitante anterior saiu de fato | escolha (evita cruzamento) |
| Erro | Marta só sai depois que o visitante passou do `RetreatPoint` | escolha (evita cruzamento) |
| Ator | Segundo ator 3D, não uma visita da fila | escolha |
| Troca de dia na F6 | `dia_em_andamento` estático na apresentação | escolha |
| Opção | `Enable Marta` no Inspector | escolha |

## Alterações

| Arquivo | Mudança |
| --- | --- |
| `scripts/marta_actor.gd` (novo) | Ator da Marta: rotas entrada→balcão, cabine 2→balcão, balcão→cabine 2; fala própria (Espaço); `cancel()`. |
| `scripts/reception_effects.gd` (novo) | Camadas do 2D (vermelho da falha, luzes apagando, luz vermelha) e tremor do `RoomView`. |
| `scripts/elevator_door.gd` | Só acrescenta `has_exited_passage()` (clearance no sentido da sala). |
| `scripts/reception_presentation.gd` | `enable_marta`, `dia_em_andamento`, `rule_announced`; `_run_intro`, `_announce_rule`, `_run_failure`, `_run_conclusion`; estágios `MARTA`, `FAILING`, `CONCLUDING`, `LEAVING_SCENE`; sons e música. |
| `scripts/desk_service.gd` | `set_marta_present()` (trava o painel) e `flash_rules()` (abre a prancheta 1,8 s, sem passar por cima de outra consulta). |
| `scenes/reception_gameplay_test.tscn` | `enable_marta = true`. |
| `tests/reception_marta_test.gd` (novo) | Suíte I5/I6. |
| `tests/reception_dispatch_test.gd` | Instâncias com `enable_marta = false` (continua testando a I4 pura). |

Sem mudança: agendas, recursos de NPC, sala experimental, recepção 2D, portas, movimento, orientação, balão de papel.

## Validação (`--headless --fixed-fps 60`)

| Suíte | Resultado |
| --- | --- |
| I5/I6 `reception_marta_test.gd` | 62 verificações, 0 falhas |
| I4 `reception_dispatch_test.gd` | 512 / 0 |
| I3 `reception_desk_test.gd` | 250 / 0 |
| I2 `reception_arrival_test.gd` | 359 / 0 |
| I1 sessão / fluxo | 705 / 0 e 131 / 0 |
| I0 fluxo 2D real | 792 / 0 |
| I0 `validator_schedule_test.gd` | 3055 / 136: as mesmas falhas de hash já conhecidas (CRLF + agendas do commit 4c42c42) |
| Cenas do jogo 2D (menu, tutorial, recepção, tela final) | abrem sem erro de script |

A suíte I5/I6 cobre: rotas da Marta pela cabine 2 sem abrir a cabine 1; P alternando os dois atores; cancelamento
no meio da rota; efeitos com os valores do 2D; introdução antes do 1º visitante; regras só depois do 2º e do 4º
atendimento e ativadas só depois da fala; Espaço repetido ativando uma vez; livro aberto segurando o Espaço;
prancheta aberta ~1,8 s e sem substituir outra consulta; caso da regra decidido com ela ativa; erro no dia 2 com
Marta com raiva, saída pela porta, ~6 s sem Espaço e recarga no mesmo dia; erro logo depois de uma regra sem
herdar regra ou contagem; recarga no meio da fala sem vazar fala; dias 1 → 2 (escuro ≥ 0,9, Marta ensanguentada,
luz vermelha) → 3 → tela final, com `dia_em_andamento` zerado; as duas cabines nunca abertas ao mesmo tempo.

**Não validado:** revisão visual e auditiva com F6 (enquadramento da Marta, legibilidade do balão no escuro,
volume dos sons).

## Roteiro F6

1. Recarregue o projeto sem salvar. Abra `tests/reception_service_fixture.tscn`, com `Enable Service`, `Enable Departure` e `Enable Marta` ligados.
2. A Marta entra pela porta, fala (Espaço) e entra na cabine 2. O primeiro visitante entra.
3. Atenda dois visitantes certos: a cabine 2 abre, a Marta dita a regra e a prancheta abre sozinha.
4. Erre um andar: tela vermelha, o visitante sai pela porta, a Marta chega com raiva e o dia recomeça.
5. Atenda o dia inteiro: fim do dia, "Dia 2"; no fim do dia 2, luzes apagando e Marta ensanguentada.
6. Termine o dia 3: tela final com créditos.
7. Desligue `Enable Marta` para voltar à I4.

## Limites conhecidos

- Pause (Esc) e F9 não existem no 2.5D.
- No erro, a Marta para no balcão enquanto o visitante ainda está saindo pela porta; a cabine 1 nunca é usada.
- O tremor do dia 2 sacode a imagem da sala inteira, incluindo o balcão (escolha do design).
