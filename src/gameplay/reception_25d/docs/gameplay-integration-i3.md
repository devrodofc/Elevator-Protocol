# I3 — atendimento por objetos no balcão

Implementado em 25/10/2026, branch `feat/2.5d-experiment`, Godot
4.7.2.stable.official.ed1daf0bf. Esta entrega segue a especificação revisada
pelo desenvolvedor: objetos físicos, consultas modais e diálogo PAPER.
Não implementa saída, embarque, conclusão da visita, Marta ou progressão.

## Cena, componentes e alterações

`scenes/reception_gameplay_test.tscn` continua herdando a recepção experimental.
`Enable Service = true` liga I3; desligá-lo mantém a prévia de chegada I2.
`Test Day` e `Initial Entrance` continuam selecionando agenda e entrada.
Não há mudança no destino do menu, no tutorial, na main_scene ou em F5.

Novos scripts em `reception_25d/scripts/` (com UIDs gerados pelo engine):

| Componente | Responsabilidade |
| --- | --- |
| `desk_picker.gd` | Conversão RoomView → SubViewport, raycast e clique. |
| `desk_interactable.gd` | Colisor exclusivo, disponibilidade, hover/pulsação e slide local. |
| `desk_models.gd` | Modelos provisórios BoxMesh: cartão/presilha, livro/capas/lombada/páginas, prancheta e botões. |
| `desk_service.gd` | Conecta chegada, snapshot, consultas, confirmação e resultado. |
| `paper_dialogue.gd` | Cena Dialogue original em textura de SubViewport sobre Sprite3D. |
| `badge_transfer.gd` | Entrega, recolhimento e cancelamento de tweens do cartão. |
| `desk_modal.gd` | Uma consulta por vez no viewport principal; clique fora/Esc e prioridade de entrada. |
| `inspection_badge.gd` | Estende o detalhe original com dados do snapshot e foto do sprite apresentado. |
| `inspection_book.gd` | Estende livro original, ocultando e limpando somente Description nesta instância. |
| `inspection_rules.gd` | Mantém arte/formatação originais; posicionamento e fechamento ficam com o modal. |

Também foram criados `tests/reception_desk_test.gd` e uma cena de configuração
`tests/reception_arrival_fixture.tscn`. A suíte I2 só mudou seu caminho de cena
para essa herança com `enable_service=false`: **todas as 359 verificações e
expectativas foram preservadas**, inclusive reload real. Ela continua verificando
o contrato de chegada; a nova suíte exercita a configuração I3 padrão.
Não foram alterados os fixtures de dados da I0/I1.

Arquivos preexistentes alterados nesta etapa: sessão compartilhada, adaptador
`reception_presentation.gd`, cena integrada e caminho de cena do teste I2.
As alterações locais da I2 foram preservadas. Não se modificaram os scripts,
cenas ou recursos originais da HUD, Dialogue, manager 2D, portas, elevadores,
movimentação, PAPER ou câmeras. Sem commit/push.

## Picking, hover e layout

O mouse chega em coordenadas lógicas do viewport principal; o stretch da janela
já foi aplicado pela Godot. O picker usa o inverso de
`RoomView.get_global_transform_with_canvas()`, o retângulo real do Sprite2D
(incluindo centralização, flips e região) e o tamanho do RoomViewport.
Não multiplica coordenadas por uma resolução fixa de janela.

`Camera3D.project_ray_origin/normal` alimenta uma consulta física no mundo do
RoomViewport. Corpos StaticBody3D usam exclusivamente a camada 20, máscara zero,
sem receber picking automático. Consultas acontecem no tick físico; vence o
colisor mais próximo. Um objeto indisponível não permite selecionar outro atrás.
Essa camada é de interação, não uma simulação de colisão com visitantes/portas.

Cada objeto duplica seu StandardMaterial3D. Hover mistura discretamente amarelo
no albedo e emissão, preservando textura e demais parâmetros; Tween senoidal de
0,7 s em cada sentido produz a pulsação. Sair restaura os valores originais;
seleção do painel mantém destaque suave. Não depende de bloom.
A prancheta desloca somente seu modelo local em `(0, 0.008, -0.14)` e volta à
origem em 0,22 s, cancelando o Tween anterior. Seu colisor cobre a região varrida,
evitando que o próprio deslocamento faça o hover oscilar.

Novos marcadores ficam em `ReceptionDesk/ServiceObjects`, relativos ao balcão:

| Marcador | Posição local | Uso |
| --- | --- | --- |
| BadgeRest | (-0.2, 1.17, 0.64) | Cartão fino, apoiado acima do tampo. |
| BookRest | (-0.83, 1.19, 0.62) | Livro à esquerda do cartão. |
| ClipboardRest | (-1.53, 1.17, 0.64) | Prancheta à esquerda do livro. |
| PanelRest | (0.8, 1.42, 0.62), X=-55° | Painel inclinado à direita, com oito opções e OK. |

O tampo original permanece em Y=1,15, ocupando X±2,2 e Z=0,05–1,15
no espaço da sala. Nenhum marcador anterior ou geometria foi movido.
As formas são provisórias; não foram criadas texturas ou artes definitivas.

## Fala e crachá

Ao receber a chegada identificada da I2, o serviço usa o snapshot da sessão.
O balão instancia **a própria cena** `autoload/dialogue/dialogue.tscn` num
SubViewport transparente 189×113. Board é deslocado para a origem dessa textura;
fontes, imagem `balão de fala vazio.png`, paginação, velocidade, texto e lógica
de avanço continuam originais. Um Sprite3D Nearest, sem iluminação e com
billboard, apresenta a textura. Ele é filho do ator, separado da rotação PAPER
do NPC, elevado pela área visível do sprite e deslocado lateralmente.

A fala global é limpa ao iniciar essa apresentação. A instância local é limpa
na decisão/cancelamento/saída da cena. O controlador no viewport principal
encaminha Espaço/Enter à lógica original; RoomView não encaminha eventos sozinho.
Durante consultas, nenhum avanço de página é enviado. A recepção 2D continua
utilizando seu Autoload normalmente.

O crachá recebe a identidade da visita e parte próximo ao corpo, a Y=1,45
acima do chão do ator. O Tween passa acima do tampo e desce ao BadgeRest,
interpolando rotação. Cliques só liberam ao terminar. Recolhimento interrompe
uma entrega ainda ativa, sobe antes de retornar ao corpo e oculta o mesmo objeto.
Nenhum desses tweens chama métodos de conclusão, contagem ou movimentação do NPC.

A consulta utiliza a cena BadgeDetails e exatamente `cracha_ab_semnada.png`
(908×1144), preservando seu layout de foto, nome, idade, sexo e ocupação.
Os dados vêm de `entry.nome`/`entry.cracha`; a foto vem de `entry.sprite`, a mesma
aparência aplicada fisicamente, sem novo sorteio. Não há autenticação de crachá.

## Consultas e controles

Os modais ficam num CanvasLayer 20 **do viewport principal**. Um fundo bloqueante
fecha com clique fora; o conteúdo consome cliques. Esc fecha. Crachá pode ser
reaberto enquanto a decisão não foi processada, mantendo o snapshot.
Livro e prancheta também podem ser consultados antes/depois da decisão.

O livro conserva `CompanyDirectory`, artes e navegação circular de dois andares
por página. Exibe andar e setor real; não há novo campo resumido no recurso,
portanto não inventa uma terceira descrição. Os textos detalhados são omitidos.
A prancheta é preenchida exclusivamente com `session.active_rules`; na prévia
atual mostra **“Nenhuma regra extra.”** Nenhuma regra pendente é anunciada.

Abrir modal bloqueia o picker e painel, suspende o processamento da câmera normal
e DebugFreeCamera e desliga temporariamente o input PAPER. Captura RMB é liberada,
velocidade/teclas da exploração são limpas; fechar restaura os modos anteriores.
F/P/Espaço/Enter ficam consumidos durante leitura. Fora dela, F e P mantêm os
comportamentos experimentais existentes. Esc sem modal não adiciona um pause
novo. Os três botões de cabine ficam ocultos somente na cena integrada; o
indicador de exploração continua disponível. Não se alteraram atalhos globais.

## Decisão e limite narrativo

Foi indispensável acrescentar `ReceptionSession.start_service_preview(config)`:
monta a mesma agenda uma vez e permite uma visita/decisão, sem chamar
`finish_intro`, sem fingir apresentação de Marta e sem ativar regras.
`start_arrival_preview` continua bloqueando decisões; `start_day` limpa os modos
experimentais e preserva o fluxo 2D. `complete_visit` é bloqueado no modo I3.

Cada botão emite um **floor_code** (1–6, -1, 999), nunca cabin_index.
Clicar novamente na mesma opção desmarca. OK exige seleção, bloqueia imediatamente
e aguarda os mesmos 0,15 s da confirmação original. Antes de resolver, confere
identidade, geração, fase, modal e transição. Somente `submit_decision` chama o
RuleValidator original. Resultado imutável fica em `DeskService.result` e é
emitido em `decision_processed(result)` para a futura I4.

Correto leva a RESOLVED; incorreto leva a FAILED, conforme a sessão original.
Ambos bloqueiam novas confirmações, limpam a fala e recolhem o cartão.
O NPC permanece no ServicePoint, fila com seis visitas, contagem zero e snapshot
preservado. Não há abertura de cabine, retorno, reload de falha, próximo visitante
ou conclusão artificial nesta etapa.

## Validação e pendências

Importação e testes em `/tmp/ep-i3/project`, usando o executável da `.godotrc`.
A importação precisou da liberação dos sockets locais fora do sandbox;
nenhum recurso original foi salvo pelo editor. Scripts com Autoloads são
carregados após a inicialização, conforme CLAUDE.md seção 12.

| Suíte | Verificações | Falhas |
| --- | ---: | ---: |
| I0: dados e seis cenários reais 2D | 4300 | 0 |
| I1: sessão e integração 2D | 836 | 0 |
| I2: chegada e controles originais | 359 | 0 |
| I3: objetos, consultas e decisões | 250 | 0 |
| **Total** | **5745** | **0** |
| DebugFreeCamera existente | Sem contador publicado | 0 |

I3 cobre três dias, acerto/erro/recusa, oito códigos, identidade antiga,
confirmação duplicada/cancelada, entrega/recolhimento, snapshots, materiais,
pulso, slide interrompido, picking físico por objeto/botão e sobreposição,
transformação/região do RoomView, janelas 640×360/960×540/1280×720, yaw,
modais por clique, câmera normal/livre, páginas longas/Espaço/Enter,
limpeza durante modal e reutilização posterior do Dialogue 2D.

Durante a verificação foram corrigidos: perda da referência exportada ao diretório
quando a instância troca de script; falta de encaminhamento de Espaço/Enter do
viewport principal ao diálogo dentro do RoomViewport. Nos testes de mouse,
`push_input(..., true)` fornece coordenadas locais, evitando aplicar stretch duas
vezes. Nenhuma expectativa de negócio foi relaxada.

Permanecem os avisos variáveis de cleanup de áudio/recurso observados nas etapas
anteriores; a execução I3 registrou 7 Objects/2 recursos no encerramento, enquanto
uma execução diagnóstica verbose terminou limpa. Não há erros de script/referência
nos resultados finais. A I2 mantém seus dois warnings negativos esperados.

Importação final sem erros/avisos de scripts ou referências. `git diff --check`
e whitespace dos novos arquivos passaram. A comparação SHA-256 com o início
da I3 confirmou somente os quatro arquivos preexistentes listados acima
como alterados; os 264 recursos/PNGs/imports/modelos do conjunto protegido
permaneceram idênticos, assim como todos os demais arquivos anteriores.
UIDs novos foram gerados na cópia; nenhum UID existente foi substituído.

Capturas com renderização OpenGL foram inspecionadas para balcão, balão, crachá
e livro. Isso **não constitui aprovação visual/interativa/auditiva** do desenvolvedor.
Materiais são provisórios; legibilidade, hover e enquadramento extremos precisam
ser revisados em F6. Formatos VisitorData.cena continuam sem suporte, com rejeição
segura herdada da I2; não se convertem cenas 2D arbitrárias.

### Roteiro F6

1. Recarregar o projeto sem salvar recursos antigos. Abrir a cena integrada,
   manter Enable Service ligado, escolher dia e entrada, executar F6.
2. Observar entrada, parada, fala real e entrega aérea do crachá até o tampo.
   Tentar clicar durante a entrega; só deve abrir depois de apoiado.
3. Conferir nome/foto/dados, fechar clicando fora ou Esc e reabrir. Conferir
   brilho suave de cartão/livro e slide reversível da prancheta com movimentos
   rápidos do mouse, inclusive perto das bordas da câmera.
4. Consultar todas as páginas do livro (sem descrições detalhadas) e a prancheta
   vazia. Durante leitura, testar F/P/Enter/Espaço e bordas: câmera e seleção
   devem ficar suspensas. Fechar deve restaurar os controles.
5. Conferir fala longa, digitação e avanço por Espaço/Enter fora dos modais.
   Redimensionar a janela e testar os cliques novamente; inspecionar com F/RMB.
6. Selecionar, desmarcar e confirmar um andar. Repetir F6 para recusa e erro.
   Conferir resultado, recolhimento e impossibilidade de confirmar novamente.
   NPC deve continuar parado, sem portas de elevador abrindo ou visita seguinte.
7. Repetir dias/entradas. Executar a cena experimental antiga com 1/2/R/P/F e
   cabines; executar a recepção 2D para sua regressão visual habitual.

I4 deverá consumir o resultado por identidade e definir a conclusão física,
rotas e política de cabine. Ainda não há essa coordenação nem narrativa de Marta.
A prévia não deve ser promovida silenciosamente a um dia completo.
