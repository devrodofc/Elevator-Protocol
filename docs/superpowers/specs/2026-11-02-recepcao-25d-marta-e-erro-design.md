# Recepção 2.5D — Marta, erro e fim do dia (I5 + I6)

Data: 02/11/2026. Base: branch local `gustavo`, com a I4 pronta (visitantes embarcam na cabine 1 ou
saem pela porta). Documentos de referência: `CLAUDE.md` (seções 6.1, 6.1b e 13) e
`src/gameplay/reception_25d/docs/gameplay-integration-audit.md` (seções I5 e I6).

## Intenção

O fluxo dos visitantes no 2.5D já funciona. Falta o que dá ao jogo o suspense: a **Marta** (introdução,
regras e fim do dia) e o **erro** (ela aparece e o dia recomeça). A regra do Gustavo é: **igual ao jogo 2D**,
adaptado à sala 3D. A recepção 2D é a referência de comportamento: mesmas falas, mesmos tempos, mesma
ordem e mesmos critérios de acerto, erro e progressão.

## Objetivos

1. **Erro:** o mesmo fluxo do 2D, com uma diferença: a Marta chega **com raiva em todos os dias**.
2. **Introdução** do dia pela Marta.
3. **Regras** depois do 2º e do 4º atendimento, ativadas só depois da fala.
4. **Fim do dia**, com o suspense do dia 2 (e do dia 3), e avanço **dia 1 → 2 → 3 → tela final**.

## Fora do escopo

- Ligar o 2.5D ao menu, ao tutorial, ao cheat ou ao F9 (é a I8). A cena continua rodando só com F6.
- Política definitiva das três cabines e vários visitantes ao mesmo tempo (é a I7).
- Mudar o jogo 2D. Lá a Marta continua com raiva só no dia 1.
- Arte nova, animação de quadros da Marta, iluminação 3D nova, mudar textos ou agendas (`dayN.tres`).
- Pause (Esc) e F9 no 2.5D.

## O que seria um fracasso, mesmo funcionando

- Regra valendo **antes** da Marta terminar de falar, ou anotada duas vezes.
- Marta e visitante na mesma cabine, ou a Marta atravessando o visitante.
- Fala da cena antiga aparecendo depois de recarregar ou trocar de dia.
- Erro contando atendimento, ou o dia seguinte começando com regras ou contagem do anterior.
- Quebrar o 2D ou os testes I0–I4.

## Decidido pelo Gustavo

- Erro igual ao 2D: som de erro → 1 s → tela avermelha devagar → visitante sai pela porta por onde entrou →
  Marta sai de uma cabine e vem ao balcão → fala `mensagem_falha` (até 6 s ou Espaço) → recarrega **o mesmo
  dia** (novo sorteio).
- Marta **com raiva** (`src/npcs/assets/marta/marta_anger.png`) ao chegar no erro, **em todos os dias**.
- No **erro** e nas **regras**, a Marta sai de **outra cabine** (não a 1, que é dos visitantes).
- Introdução: entra pela porta de entrada, fala no balcão, vai embora por uma cabine.
- Regras: sai da cabine, dita a regra, a regra vai para a prancheta, que abre sozinha por ~1,8 s, e ela volta.
- Fim do dia: igual ao 2D (suspense, sprite do fim, `mensagem_fim`, Espaço, transição "Dia N"; no dia 3,
  tela final). O escuro e o vermelho são camadas sobre a tela, como no 2D.

## Escolhas minhas (podem ser corrigidas)

1. **A cabine da Marta é a 2 (`Elevator02`) em todas as aparições**, inclusive a saída da introdução e a
   chegada no fim do dia. A cabine 1 fica só para os visitantes, e as duas nunca disputam a mesma porta.
2. **Ordem em série:** a Marta das regras só sai da cabine depois que o visitante anterior terminou de sair
   (`visit_departed`). No 2D ela vem logo depois da decisão. Aqui ela espera para os dois não se cruzarem.
3. **No erro**, a Marta só sai da cabine 2 depois que o visitante passou da área do corredor, ou seja, do ponto
   `RetreatPoint` em direção à fila. Assim os dois não se cruzam.
4. A Marta é um **segundo ator 3D** (o próprio `Sprite3D` com sombra, movimento e orientação próprios), não
   uma visita da fila. Sprite padrão: `src/npcs/assets/marta/marta_1_frame.png`.
5. A fala da Marta usa o **mesmo balão de papel** dos visitantes (`paper_dialogue.gd`), com "[Espaço]
   acelerar/continuar", como no 2D.
6. **Sons como no 2D:** `sucess` no acerto, `erro` no erro, `chegou_elevador` quando a cabine da Marta abre
   (pitch 0,7, volume normal), música do dia (`music_gameplay` nos dias 1–2, `music_reverse` no dia 3) e o
   `MartaSubsoloKetchup` no escuro do dia 2.
7. O **tremor** do fim do dia 2 mexe a imagem da sala (`RoomView`); o balcão e a UI tremem junto, porque
   fazem parte da imagem.
8. **Troca de dia dentro da cena de teste:** o dia atual fica numa variável estática da apresentação.
   Recarregar no erro mantém o dia, e o fim do dia faz a transição "Dia N" para a mesma cena com o dia
   seguinte. O `Test Day` do Inspector só vale na primeira abertura. Depois do dia 3, a cena final é a
   `cena_final` do `day3.tres` (tela de créditos).
9. Uma opção nova no Inspector, **`Enable Marta`** (requer `Enable Departure`): ligada, a cena roda o dia
   completo (`session.start_day` + `finish_intro`, como o 2D). Desligada, volta à I4 sem Marta. A suíte da I4
   roda com ela desligada.
10. Enquanto a Marta está na sala, o painel de andares fica travado. Livro e prancheta continuam
    consultáveis, exceto durante a abertura automática da prancheta.

## Como funciona (para quem vai construir)

### Autoridade
`ReceptionSession` continua sendo a única dona do estado. A apresentação só chama os comandos que já
existem: `start_day`, `finish_intro`, `request_next_visit`, `service_reached`, `submit_decision`,
`complete_visit`, `take_due_rule`, `activate_pending_rule` (**só depois do último Espaço da fala**),
`finish_rule`, `finish_interval`, `begin_transition`, `has_next_day`. Nada de sorteio ou validação na
apresentação. Toda continuação assíncrona confere `session.generation` e desiste se mudou.

### Sequências

**Introdução:** Marta aparece no vestíbulo da entrada escolhida → porta abre → anda até o `ServicePoint`
(mesma rota dos visitantes) → porta fecha atrás dela → fala `mensagem_inicio` (espera Espaço, sem limite)
→ anda até a cabine 2, que abre; ela entra e a porta fecha → `finish_intro` → primeiro visitante.

**Acerto e regras:** I4 sem mudança até `visit_departed`. Depois da liberação, se `take_due_rule` devolver
regra: a cabine 2 abre (`chegou_elevador`) → Marta sai e anda até o `ServicePoint` → fala `rule.fala`
(Espaço) → `activate_pending_rule` → a prancheta abre sozinha ~1,8 s mostrando a regra → Marta volta e
entra na cabine 2, que fecha → `finish_rule` → próximo visitante. Sem regra: `finish_interval` e próximo
visitante, como hoje.

**Erro:** `erro` → painel travado → 1 s → camada vermelha sobe até alfa 0,15 em 3,5 s → visitante sai pela
porta de origem (rota de recusa da I4) → quando ele passar do `RetreatPoint`, a cabine 2 abre e a Marta sai
(sprite padrão, troca para **raiva** ao chegar) → fala `mensagem_falha` (Espaço ou 6 s) → limpa a fala →
`begin_transition` → recarrega a cena no mesmo dia.

**Fim do dia:** fila vazia (`CONCLUDING`) → painel travado → se `suspense_antes_do_fim > 0`, repete o
`_apagar_luzes` do 2D: música some, luzes piscam, escuro; com `som_no_escuro`, toca o som com tremor e um
vermelho fraco → Marta sai da cabine 2 com `sprite_marta_fim` (se houver) → no dia 2, para e encara 1,8 s
sob luz vermelha pulsando → fala `mensagem_fim` (Espaço) → se `has_next_day`: `begin_transition` e
`SceneTransition.transition_to(cena atual ou cena_final, "Dia N")`.

### Rotas novas (inversas às da I4)
- **Sair da cabine:** a Marta começa escondida no `CabinStopPoint`; a cabine abre; ela aparece quando a porta
  estiver aberta e anda por `CabinStopPoint → EntryPoint → ApproachPoint → TurnPoint da cabine →
  CorridorEntry → RetreatPoint → ServicePoint`. A porta fecha depois que ela passou para fora (precisa de
  um teste de "saiu" equivalente ao `has_cleared_passage`, no sentido contrário).
- **Entrar na cabine:** a mesma rota de embarque da I4, usando a cabine 2.

### Testes esperados
Uma suíte nova (`reception_marta_test.gd`, com `--fixed-fps 60`) cobrindo:
- introdução antes do 1º visitante;
- regra anunciada depois do 2º e do 4º atendimento e ativada só depois da fala;
- regra anotada uma vez e caso da regra decidido com ela ativa;
- nenhum anúncio depois do último visitante;
- erro em cada fase (antes e depois de regra), com sprite de raiva, recarregamento no mesmo dia e sem
  regra/contagem antiga;
- dias 1 → 2 → 3 → tela final;
- cabines 1 e 2 nunca ocupadas pela pessoa errada.

I0–I4 devem continuar passando. A suíte da I4 roda com `Enable Marta` desligado.

## Deixado para quem constrói
- Velocidade da Marta (padrão: a mesma dos visitantes, 3).
- Camada (CanvasLayer) das sobreposições escura e vermelha, desde que a fala continue legível
  (o alfa máximo durante a fala é 0,42, como no 2D).
- Como abrir a prancheta automaticamente (pela consulta modal existente ou outra forma), contanto que o
  jogador veja a regra nova por ~1,8 s.
