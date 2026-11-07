# I4 — aplicar o resultado e concluir a visita

> Registro histórico: a cena intermediária citada neste documento foi removida na Etapa C (07/11/2026).
> Os testes atuais usam `tests/reception_arrival_fixture.tscn` (I2) e `tests/reception_service_fixture.tscn`
> (I3–I6), sob `src/gameplay/reception_25d/`, sem os sistemas narrativos do jogo final.
> A arquitetura atual e os resultados da migração estão no README da recepção 2.5D.


Implementado em 02/11/2026, branch local `gustavo` (a partir da `develop` em `7206e6a`), Godot
4.7.2-stable. Segue as recomendações da auditoria (seção 10.2) para as três decisões pendentes
antes da I4. Não implementa Marta, regras anunciadas, falha com reload, fim do dia nem progressão.
A cena continua fora do fluxo do jogo: menu, tutorial, cheat, `main_scene` e F5 não mudaram.

## Decisões aplicadas

| Decisão | Escolha | Origem |
| --- | --- | --- |
| Escolha da cabine | Sempre a **cabine 1** (`PILOT_CABIN = "Elevator01"`), independente do andar. | Recomendação "primeiro teste fixa cabine 1". |
| Cadência | **Serial**: um visitante na sala; o próximo só entra depois da liberação física do anterior. | Recomendação "piloto serial". |
| Rota de recusa | Volta pela **mesma porta de entrada** por onde entrou. | Recomendação "voltar ao acesso de origem". |
| Erro | Não despacha: estado `FAILED`, NPC parado, fila parada. | "Erro mantém controle bloqueado para a etapa de falha". |

## Alterações

| Arquivo | Mudança |
| --- | --- |
| `src/gameplay/scripts/reception_session.gd` | Novo modo `start_dispatch_preview(config)`: várias visitas, `complete_visit` permitido, `take_due_rule` sempre `null` (sem Marta). `start_day` desliga o modo. |
| `scripts/reception_presentation.gd` | Export `enable_departure`; o início de visita virou `_begin_visit()` (reutilizado a cada visita); novos estágios `TO_CABIN`, `WAITING_FOR_CABIN`, `ENTERING_CABIN`, `TO_EXIT`, `EXITING`, `CLOSING_EXIT`, `FAILED`, `DAY_DONE`; sinal `visit_departed(id)`; `cancel_preview` também fecha a cabine. |
| `scripts/desk_service.gd` | `prepare_next_visit()`: limpa seleção, resultado, fala, crachá e o modal do crachá antes da próxima visita. |
| `scenes/reception_gameplay_test.tscn` | `enable_departure = true`. |
| `tests/reception_desk_test.gd` | As três instâncias da cena usam `enable_departure = false`: a suíte continua testando o contrato da I3 (NPC parado depois da decisão). Nenhuma expectativa foi alterada. |
| `tests/reception_dispatch_test.gd` | Nova suíte da I4. |

Não foram alterados: a cena experimental `scenes/reception.tscn`, portas, cabines, movimentação,
orientação, câmera, materiais, agendas, recursos de NPC, HUD 2D nem a recepção 2D.

## Fluxo

```text
decisão confirmada (DeskService.decision_processed)
  incorreta → FAILED (nada se move; I6 fará a falha)
  correta   → session.complete_visit (conta na decisão, como no 2D)
			→ espera o crachá voltar ao visitante
  andar/subsolo → TO_CABIN: RetreatPoint, CorridorEntry, Elevator01TurnPoint, ApproachPoint
				→ WAITING_FOR_CABIN: abre a cabine 1, encara a porta
				→ ENTERING_CABIN (porta OPEN): EntryPoint, CabinStopPoint; fecha ao passar o clearance
				→ chegou ao CabinStopPoint E porta CLOSED → liberação
  recusa (999)  → TO_EXIT: abre a porta de origem; QueueJoinPoint, Entrance
				→ EXITING (porta OPEN): SpawnPoint do vestíbulo
				→ chegou: esconde o ator e fecha a porta (CLOSING_EXIT)
				→ porta CLOSED → liberação
liberação → session.finish_interval → visit_departed(id) → desk.prepare_next_visit → _begin_visit
fila vazia → DAY_DONE ("Fila concluída · fim do dia na I6")
```

A saída é verificada a cada quadro (`_advance_departure`), então chegada e fechamento podem acontecer
em qualquer ordem: a liberação exige as duas coisas. "Começou a fechar" nunca conta como saída.

## Validação

Todas as suítes rodaram na pasta do projeto com `--headless --fixed-fps 60`. **Sem `--fixed-fps` as suítes
2.5D dão falhas falsas**, porque esperam um número fixo de quadros por animação.

| Suíte | Antes | Depois |
| --- | --- | --- |
| I4 `reception_dispatch_test.gd` | — | 512 verificações, 0 falhas (24 embarques, 4 recusas) |
| I3 `reception_desk_test.gd` | 250 / 0 | 250 / 0 |
| I2 `reception_arrival_test.gd` | 359 / 0 | 359 / 0 |
| I1 `reception_session_test.gd` | — | 705 / 0 |
| I1 `reception_session_flow_test.gd` | — | 131 / 0 |
| I0 `reception_flow_test.gd` (2D real) | — | 792 / 0 (21 decisões, 6 anúncios) |
| I0 `validator_schedule_test.gd` | — | 3055 / **136** (ver abaixo) |

As 136 falhas do `validator_schedule_test.gd` não vêm da I4 (nenhum dos arquivos verificados foi alterado
aqui). São todas na checagem "Authored resource bytes preserved", que compara o SHA-256 dos recursos
com `fixtures/resource_integrity.json` (gerado em 24/10):
- 65 de 68 arquivos só diferem pelo fim de linha: com `core.autocrlf=true` o Windows deixa CRLF, e o fixture
  foi gerado com LF. Removendo o `\r`, o hash bate.
- `day1.tres`, `day2.tres` e `day3.tres` mudaram de verdade no commit `4c42c42` (o editor regravou: uids,
  `andares_do_dia = null`, campos iguais ao padrão removidos). O comportamento continua o mesmo (`montar_dia`
  gera 7 visitas e 2 regras em cada dia, e os testes de agenda/fluxo do I0/I1 passam), mas o fixture
  precisa ser regenerado pela equipe se essas mudanças forem aceitas.

A I4 cobre: dias 1, 2 e 3 completos (7 visitas cada), as duas entradas, recusa correta (dia 1 com a regra
real "4º andar: negar acesso" ativada na sessão, no lugar do anúncio da Marta da I5), contagem uma vez
por decisão, uma liberação por visita com a identidade certa, próxima visita sem herdar crachá/fala/
seleção/resultado, identidade antiga rejeitada, todas as cabines fechadas na liberação, erro sem
movimento/cabine/contagem e cancelamento no meio do embarque sem liberação.

**Não validado:** revisão visual/interativa com F6 (enquadramento do NPC entrando na cabine e saindo
pela porta, giro do sprite nas curvas). Fazer o roteiro abaixo.

### Roteiro F6

1. Recarregue o projeto sem salvar. Abra `tests/reception_service_fixture.tscn`, deixe `Enable Service` e
   `Enable Departure` ligados e `Enable Marta` desligado, escolha dia/entrada e use F6.
2. Atenda corretamente: o crachá volta, o NPC anda até a cabine 1, a porta abre, ele entra e a porta fecha.
   Só então o próximo entra pela porta de entrada.
3. Recusa (X): nas agendas atuais nenhum visitante deve ser recusado sem as regras da Marta, então na F6
   o X sempre dá "incorreto". A saída pela porta só é vista no teste automático (que ativa a regra real
   do 4º andar) até a I5 trazer os anúncios da Marta.
4. Erre um andar: o painel mostra "Incorreto · falha na I6" e nada se move.
5. Atenda os 7 visitantes: o painel mostra "Fila concluída · fim do dia na I6".
6. Desligue `Enable Departure`: a cena volta ao comportamento da I3.

## Próximo passo (I5)

Marta 3D: introdução e regras a cada 2 atendimentos, ativadas depois da fala. Antes disso é preciso
aprovar como ela entra/sai (provavelmente saindo da cabine) e a exclusão mútua com o visitante na cabine.
