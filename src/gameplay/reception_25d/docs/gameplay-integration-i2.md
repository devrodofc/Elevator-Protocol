# I2 — primeira visita real no balcão 2.5D

Entrega em 25/10/2026, branch `feat/2.5d-experiment`, Godot
**4.7.2.stable.official.ed1daf0bf**, sem .NET, conforme `.godotrc`.
Implementa somente chegada de uma visita. A revisão visual/interativa F6
permanece pendente; I3 não foi iniciada.

## Cena e responsabilidades

`scenes/reception_gameplay_test.tscn` **herda** `scenes/reception.tscn`.
Acrescenta uma `ReceptionSession` local e o adaptador
`scripts/reception_presentation.gd`, mantendo a geometria, marcadores, câmeras,
sombra, portas, elevadores e parâmetros visuais herdados. A cena original
permaneceu idêntica em bytes.

No nó raiz da nova cena, o Inspector oferece:

| Propriedade | Uso |
| --- | --- |
| `Test Day` | 1, 2 ou 3; seleciona a agenda original, sem editar recursos. |
| `Initial Entrance` | Esquerda ou Direita; configuração exclusiva desta apresentação. |

A sessão monta a agenda uma vez, seleciona a **primeira** ocorrência e mantém
seu snapshot imutável. O adaptador associa `visit_id` e `visit_entry` ao
`VisitorGround` por metadados; `visit_entry` contém VisitorData, nome sorteado,
sprite, crachá e referência do diálogo. Esses dados ficam disponíveis para
inspeção e etapas futuras; não há HUD ou fala nesta entrega.

O adaptador controla somente textura, porta e percurso. Não cria fila, sorteia
nomes/aparências, valida decisões ou contabiliza atendimento. A sessão continua
sendo a única autoridade de gameplay.

## Inicialização limitada à prévia

Foi adicionado `ReceptionSession.start_arrival_preview(config)`, junto da
consulta `is_arrival_preview`. Esse contrato explícito inicializa a agenda
real em `READY`, permite uma ocorrência e **bloqueia decisões** antes de chamar
o validador. Não chama `finish_intro()` nem declara que Marta foi apresentada.
`start_day()` continua iniciando em `INTRO` e limpa o modo de prévia, preservando
o fluxo real 2D. As implementações das agendas, regras e validação não mudaram.

Após selecionar a visita, a sessão passa a `ARRIVING`. A chegada física válida
chama `service_reached(visit_id)` e passa a `SERVING`. Nessa prévia, isso significa
apenas que o visitante está no balcão: ficam seis visitas na fila, zero
atendimentos, nenhuma regra ativa e nenhuma decisão aceita. Não há próximo
visitante automático. A narrativa completa continua fora do escopo desta cena.

## Textura e percurso

`test_sprite.gd::apply_visit_texture(texture)` reaplica a imagem do snapshot
em uma **ImageTexture de execução**, mantendo o recurso 2D fora do material 3D
e evitando reimportação automática dos PNGs originais. A cada troca, recalcula
a altura pela base dos pixels visíveis:

`position.y = (used_rect.end.y - image_height / 2) * pixel_size * scale.y`

Assim, dimensões e margens transparentes diferentes não deixam os pés suspensos.
Escala, pixel_size, Nearest, alpha discard, profundidade e sombra de contato
herdados são preservados. Não houve edição de PNGs ou `.import`.

O ator é configurado e posicionado no SpawnPoint da porta selecionada; aguarda
`OPEN` parado, percorre `Entrada → QueueJoinPoint → ServicePoint` à velocidade
**3**, usando `visitor_movement.gd` e `visitor_orientation.gd` originais. A porta
fecha ao atingir o clearance de `automatic_door.gd`. PAPER gira o visual durante
o percurso; ao parar, ele encara a câmera do recepcionista.

O adaptador distingue `WAITING_FOR_DOOR`, `WALKING`, `AT_SERVICE`, `CANCELLED`
e `UNSUPPORTED`. O callback carrega execução, geração e ID; também exige fim
do movimento e posição real no ServicePoint. Só após a sessão aceitar emite
`visit_reached_service(visit_id)`, uma vez. Reset/rota externos, remoção da cena
ou transição cancelam a apresentação; callbacks antigos não abrem atendimento.
Não existem corrotinas de chegada nem temporizadores adicionais de trajeto.

## Controles e formatos suportados

`VisitorMovementTest.enabled` e `ElevatorSelection.enabled` têm padrão `true`.
Somente a cena herdada os configura como `false`: o harness não recebe 1/2/R,
a seleção não acompanha o movimento e a UI deixa os três botões desabilitados
e desconectados. Mesmo uma chamada direta de seleção não despacha o visitante.
A câmera livre F/WASD/Q/E/Shift/botão direito permanece disponível. P continua
sendo a comparação PAPER/BILLBOARD existente, sem alteração de atalhos globais.

Os pools ativos dos três dias usam texturas no snapshot e são suportados.
Foi investigado o recurso legado
`src/npcs/resources/visitors/common_npc_male1.tres`: sua `cena` aponta para
`characters/common_npcs/npc_male_1.tscn`, cujo AnimatedSprite2D usa os três frames
`npc_male_1_frame_1/2/3.png`, com escala e offset próprios. O 2D dá prioridade
a essa cena; ela não equivale automaticamente a um único Sprite3D.

Nesta I2, **qualquer VisitorData.cena é recusada explicitamente**, mesmo que
também haja sprite no snapshot. Textura ausente/vazia também falha de forma
segura: ator oculto, textura antiga removida, sessão fechada, fila preservada,
sem pular para outra visita. `presentation_error`, warning e sinal
`presentation_failed(reason)` identificam a limitação. Não se instanciam cenas
2D arbitrárias nem se sorteia uma aparência substituta.

## Testes e preservação

Importação e testes executados na cópia `/tmp/ep-i2/project`, com dados e
configuração isolados em `/tmp/ep-i2/`. A importação usou a liberação dos sockets
locais do editor, conforme a limitação do sandbox registrada na I1.
Execuções de fluxo: `--headless --fixed-fps 60`. Scripts dependentes de Autoloads
são carregados após sua inicialização, seguindo `CLAUDE.md` seção 12.

| Suíte | Antes | Depois | Falhas depois |
| --- | ---: | ---: | ---: |
| I0 integral: dados + seis cenários de fluxo | 4300 | 4300 | 0 |
| I1 integral: sessão + integração 2D | 836 | 836 | 0 |
| I2: `reception_arrival_test.gd` | — | 359 | 0 |
| **Total com contagem** | **5136** | **5495** | **0** |
| Teste existente `debug_free_camera_test.gd` | Passou | Passou | 0 |

O teste I2 exercita as duas entradas nos três dias com as seeds 4201/4202/4203,
incluindo aparências diferentes, snapshots e RNG equivalentes à agenda original,
identidade, textura, Nearest/alpha, pés, sombra, velocidade, giro PAPER,
abertura/fechamento real e uma notificação por ocorrência. Inclui sprites reais
e imagens de teste somente em memória com dimensões/margens/escalas distintas.

Também verifica ausência de decisões/avanço/contagem/regras/embarque, eventos
prematuros e antigos, reload real durante abertura/percurso, reset/rota externa,
cancelamento durante fade e formatos não suportados. A cena original completa
seus **seis percursos** (duas entradas × três cabines) com os controles existentes.
A I0/I1 preserva a cobertura 2D dos três dias, casos fixos, recusa, falha/reload,
progressão, tutorial, CheatMenu e transições.

Importação final sem erros/avisos de scripts ou referências. As execuções finais
não registraram erros de GDScript/referências. O teste I2 produz dois warnings
**esperados**, nos casos negativos de cena 2D e textura ausente. Permanecem nos
testes anteriores os avisos documentados de cleanup de áudio, com quantidades
variáveis; não foram tratados como aprovação auditiva ou corrigidos nesta etapa.

Hashes dos 68 recursos I0 preservados. Dos 472 arquivos iniciais, somente cinco
scripts mudaram: sessão, sprite, harness, seleção e UI de seleção. Nenhum arquivo
foi removido. Manager/cena 2D, cena 2.5D original, movimento, PAPER, portas,
câmeras, marcadores, agendas, arte, recursos/UIDs/imports existentes e
`project.godot` permaneceram intactos. Os UIDs dos novos scripts/cena foram
gerados com Godot. `git diff --check` e whitespace dos arquivos novos passaram.
Sem commit ou push.

Para repetir, preparar/importar uma cópia conforme o baseline I0, executar suas
sete execuções e os dois testes I1, depois:

```bash
"$G" --headless --fixed-fps 60 --path "$PROJETO" \
  -s res://src/gameplay/reception_25d/tests/debug_free_camera_test.gd
"$G" --headless --fixed-fps 60 --path "$PROJETO" \
  -s res://src/gameplay/reception_25d/tests/reception_arrival_test.gd
```

## Roteiro F6 e preparação para I3

1. Recarregar o projeto sem salvar recursos antigos. Abrir
   `scenes/reception_gameplay_test.tscn`; no nó raiz escolher `Test Day = 1`
   e `Initial Entrance = Esquerda`. Executar F6: configuração e entrada são
   automáticas, sem pressionar 1.
2. Observar porta abrindo antes da caminhada, giro PAPER, pés/sombra no piso,
   escala e oclusão pelo cenário. Ao chegar, ele deve parar e encarar o balcão;
   a porta fecha e não começa outra visita, diálogo ou embarque.
3. Tentar 1/2/R e os três botões: não devem controlar o ator. Usar F para
   inspecionar e voltar; conferir que o visitante permanece no balcão.
4. Parar e repetir com `Initial Entrance = Direita`, depois dias 2/3 e novas
   execuções para comparar aparências. Metadados `visit_id`/`visit_entry` do
   ator permitem inspecionar os dados no Remote.
5. Rodar `scenes/reception.tscn` original: conferir 1/2/R/P/F e embarque pelas
   três cabines. Rodar a recepção 2D e repetir o roteiro de regressão I1.

Headless não aprova renderização, composição, suavidade percebida, picking,
captura física de mouse ou áudio. Esses pontos continuam para revisão F6.

Para I3, snapshot e chegada já estão disponíveis, mas a HUD/crachá originais
ainda recebem Visitor 2D. Será preciso adaptar apresentação de dados/retrato,
âncora de tela e prioridade modal sem afetar câmera ou identidade. A prévia não
substitui narrativa de Marta nem deve ser usada para decisões reais; cenas 2D
animadas exigem uma política própria de aparência. Nenhum desses trabalhos foi
iniciado nesta entrega.
