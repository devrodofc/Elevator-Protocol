# Recepção 2.5D experimental

Abra `scenes/reception.tscn` no Godot **4.7.2** e pressione **F6**
(Executar cena atual). F5 continua executando a cena principal do projeto.

Mova o mouse até as bordas esquerda e direita para olhar ao redor. Quanto mais
perto da borda, maior a velocidade. No centro, o giro desacelera até parar;
a câmera mantém a direção escolhida. No modo normal, a posição e a inclinação são fixas.

Selecione `RoomViewport/Room/ReceptionCamera` para ajustar no Inspector:

- `Rotation Speed`: velocidade máxima em graus por segundo (65).
- `Smoothing`: resposta da suavização (8); valores maiores respondem mais rápido,
  e zero aplica o giro imediatamente.
- `Rotation Limit`: limite para cada lado da orientação inicial (55 graus).
- `Edge Width`: fração da largura da tela reservada a cada borda (0,18).

A sala usa caixas simples, iluminação local e um Sprite3D com o primeiro frame
do visitante masculino existente. `scripts/test_sprite.gd` cria uma textura em
memória a partir da imagem para evitar a reimportação 3D automática do recurso
original. O mundo 3D renderiza em 640×360 e é exibido por um Sprite2D com
filtro nearest, usando o stretch atual do projeto.

Não há integração com o fluxo de recepção. Ao usar F6, os autoloads globais do
projeto ainda são iniciados pela Godot, incluindo a música do menu.

## Movimentação do visitante — etapa 3

Execute `scenes/reception.tscn` com F6. O visitante começa parado na entrada
esquerda. Em `VisitorMovementTest`, `Initial Entrance` permite escolher a entrada
inicial pelo Inspector.

- **1**: posiciona o mesmo visitante na entrada esquerda e inicia o percurso.
- **2**: posiciona o mesmo visitante na entrada direita e inicia o percurso.
- **R**: cancela o percurso e retorna à última entrada selecionada, parado.

Repetir 1 ou 2 substitui imediatamente o teste em andamento. Os controles usam
eventos de teclado locais à cena, sem alterar o Input Map global.

`VisitorMovement` expõe `Movement Speed` (atualmente 5 unidades por segundo). Seu script
`visitor_movement.gd` move o nó configurado em `Visitor` por posições obtidas de
Marker3D, mantendo o deslocamento vertical original em relação a `Floor Reference`.
O trajeto de teste usa a entrada escolhida, `QueueJoinPoint` e `ServicePoint`,
sem instanciar NPCs, navegar dinamicamente ou alterar a escala e a orientação.
A mudança de tamanho aparente resulta da perspectiva da câmera.

`visitor_movement_test.gd` apenas seleciona a entrada e trata os controles.
O renderizador existente em `test_sprite.gd` permanece independente.
Para reutilizar a movimentação, configure outro nó de referência no chão, sua referência de piso
e chame `start_from(entrada, pontos)` com uma lista de Marker3D.

A rota está preparada para a geometria atual. Não há desvio automático de
obstáculos; ao mover os marcadores ou móveis, valide novamente o percurso.

## Distribuição espacial — etapa 2

`reception_25d.tscn` é o ponto de entrada para F6 e instancia `reception.tscn`,
que mantém os UIDs, a renderização e os componentes anteriormente validados.
`reception_world.tscn` permanece independente e não participa deste protótipo.

A sala tem 15 m de largura, 17 m de profundidade e 3,6 m de altura, em unidades
locais de `Room`. O fundo está em Z = -11, a frente em Z = 6 e as laterais em
X = ±7,5. O deslocamento global preexistente de `Room` foi preservado.

```text
Reception25d
├── RoomView (Sprite2D, nearest)
└── RoomViewport (640×360)
	└── Room
		├── WorldEnvironment / CeilingLight / RearLight
		├── Structure (piso, teto e paredes com aberturas)
		├── ReceptionDesk (Desk / Countertop)
		├── Entrances
		│   ├── EntranceLeft
		│   └── EntranceRight
		├── Elevators
		│   ├── Elevator01
		│   ├── Elevator02
		│   └── Elevator03
		├── WaitingArea
		│   ├── Chairs (Chair01–04)
		│   ├── Windows (Window01–03)
		│   └── SittingPositions (SittingPoint01–04)
		├── VisitorPositions
		│   ├── EntranceLeft / EntranceRight
		│   ├── ServicePoint
		│   ├── QueuePoint01–04
		│   └── QueueJoinPoint
		├── VisitorGround
		│   ├── TestVisitor
		│   └── ContactShadow
		└── ReceptionCamera
```

As entradas ficam em X = ±3,6, no fundo, com painéis duplos provisórios,
soleiras e molduras. A fila ocupa X = 0: atendimento em Z = -1,2 e espera em
Z = -3 / -4,6 / -6,2 / -7,8. `QueueJoinPoint`, em Z = -9,3, reserva o acesso
transversal entre as entradas. Os marcadores de entrada ficam no lado interno,
em Z = -9,8. Os Marker3D são referências de edição, não aparecem durante F6.

Os três elevadores estão na mesma parede direita (X = 7,5), em Z = -1,8 / -5,2 /
-8,6, separados por 3,4 m entre centros. Todos estão no mesmo nível e orientados
para dentro da sala. Cada instância de `elevator_shell.tscn` contém moldura,
soleira, nicho com profundidade, dois painéis separados em `DoorAssembly` e
`ApproachPoint`. A numeração 01–03 permite distingui-los ao olhar para a direita.

Quatro instâncias de `waiting_chair.tscn` ficam em X = -5,6, voltadas para o
centro, com marcadores de assento sobre os bancos. Três janelas com painéis azuis
opacos provisórios e montantes ocupam a parede esquerda. Não há exterior modelado.

O balcão tem 4,2 m de largura e tampo de 4,4 m, reduzidos para liberar a visão
do canto inferior do elevador mais próximo sem deslocar a câmera.

O script, o FOV, a posição, a inclinação e os parâmetros da câmera foram
preservados. O Sprite3D mantém sua textura em memória e orientação billboard.
Nenhuma porta, cadeira ou marcador implementa comportamento de gameplay.

Para validar visualmente, execute `reception_25d.tscn` com F6 e confira:

1. No centro: balcão, visitante, duas entradas e corredor livre entre elas.
2. Na borda direita: os três elevadores numerados, seus nichos e espaçamentos.
3. Na borda esquerda: quatro cadeiras e três janelas.
4. Ao alternar as bordas: ausência de cortes pela geometria, giro suave e limite
   de ±55°. Selecione os Marker3D no editor para conferir fila e assentos.

A validação headless não substitui essa avaliação visual de composição,
iluminação e sensação de escala.

## Contato do visitante com o piso

O PNG tem 256×256 pixels, mas sua região visível termina em Y = 232. Os 24 pixels
transparentes inferiores deixavam os pés 0,24 m acima do piso: a posição central
de 1,28 m considerava a borda da imagem inteira. O movimento mantinha essa folga;
todos os marcadores do percurso estão na mesma altura da superfície do piso
(Y local = 0 em `Room`, Y global ≈ 0,84453654).

`VisitorGround` é agora o nó lógico movido pelos marcadores, exatamente no piso.
Seu filho `TestVisitor` mantém o Sprite3D e calcula sua altura visual usando
`Image.get_used_rect()`, `pixel_size` e a escala vertical. Para a textura atual,
o centro fica 1,04 m acima da referência, alinhando a base dos pixels visíveis ao
chão sem alterar o PNG, a importação, a escala ou o billboard.

`ContactShadow` é uma elipse de geometria simples, com 12 segmentos e material
escuro translúcido, ligada ao mesmo nó lógico. Sua superfície fica entre 3 e 5 mm
acima do piso para evitar cintilação por sobreposição de superfícies.
Não usa billboard nem desativa o teste de profundidade.

O sprite usa descarte de pixels transparentes (`Alpha Cut = Discard`), adequado
ao alpha binário desta arte, para gravar profundidade nos pixels visíveis. O teste
de profundidade continua ativo: paredes e balcão devem ocultá-lo normalmente.
Os scripts de movimentação, os controles, a velocidade e a câmera não mudaram.

Com F6, teste 1, 2 e R e gire a câmera durante o percurso: confira o contato dos
pés e da sombra em ambas as entradas e no balcão, além da oclusão pelos móveis.
Sem animação de caminhada, o deslocamento continua sendo de uma pose estática.

## Experimento de orientação BILLBOARD / PAPER

Na cena `scenes/reception.tscn`, o nó `VisitorOrientation` expõe `Orientation Mode`
e `Rotation Speed` (graus por segundo). PAPER é o padrão; BILLBOARD restaura o
billboard Fixed Y original. P alterna entre os modos durante a execução, inclusive andando;
nessa cena, a tecla é consumida antes do menu global de cheats. 1, 2 e R continuam
controlando as entradas e o reinício do teste com as portas automáticas.

PAPER desativa o billboard e gira somente `TestVisitor` em torno do eixo Y do
mundo, seguindo o deslocamento horizontal real de `VisitorGround`. A rotação
percorre a menor diferença angular, limitada pela velocidade configurada. No
`ServicePoint`, o sprite volta suavemente para a posição da câmera e permanece
frontal durante o atendimento. Durante a caminhada, girar a câmera não muda a
orientação desejada do personagem. O cálculo dos pés, a escala, a sombra, o
descarte de pixels transparentes e o teste de profundidade são preservados.

Para comparar com F6, use as duas entradas e alterne P no trecho transversal,
no corredor e no balcão. Confira os ângulos diagonais, o estreitamento próximo
do perfil, a suavidade, a oclusão pelas portas/móveis e o contato dos pés e da
sombra. Teste também R e a troca de entrada nos dois modos. A validação headless
confere estados e transformações, mas não substitui essa avaliação visual.

É uma única imagem plana: de perfil ela pode quase desaparecer; pelo verso,
a mesma arte aparece espelhada, pois o Sprite3D permanece com desenho dos dois
lados. Não há desenho específico das costas, perfil ou três quartos. Essas
limitações exigiriam novas artes e ficam fora deste experimento.

## Seleção dos elevadores

Com F6 em `scenes/reception.tscn`, pressione 1 ou 2 e aguarde a chegada ao balcão.
Os três botões no topo ficam habilitados somente quando o visitante para no
`ServicePoint`. Clique em Elevador 1, 2 ou 3; a escolha é única para essa execução.
R cancela o percurso e limpa a seleção. Escolher outra entrada também reinicia
o teste. P continua disponível para comparar os modos de orientação.

O componente `ElevatorSelection` coordena a disponibilidade e o destino, separado
da interface `ElevatorUI/Selection`. `VisitorMovement.follow_route()` continua
da posição atual, sem reposicionamento, e emite sinais de início, reinício e
chegada. Isso permite reutilizar o movimento para futuras rotas de retorno.

Os percursos usam os marcadores de `Room/ElevatorRoutes`: recuo do balcão até
Z = -2,4, acesso ao corredor em X = 4,6 e curva na altura do elevador escolhido
(Z = -1,8 / -5,2 / -8,6). O destino é o `ApproachPoint` existente de cada elevador,
em X = 6,2, a 1,3 m da origem da porta. Essas posições são locais de `Room` e
mantêm os percursos afastados do balcão e da parede direita. A velocidade segue 3.
Os marcadores devem ser revistos se os obstáculos forem reposicionados; não há
pathfinding nem desvio dinâmico neste teste.

Em PAPER, a direção observada do movimento continua determinando o giro suave
no eixo Y. Ao parar no balcão, o sprite olha para a câmera; ao parar no destino,
olha para a origem do elevador associada ao `ApproachPoint`. A orientação final
é derivada das posições e transformações reais, sem ângulos por número de porta.
Após essa aproximação, a sequência de embarque descrita abaixo assume o controle.

A interface usa CanvasLayer, Control e Button com âncoras, sem containers. Os
botões ficam na região superior central para liberar a vista do atendimento.
Enquanto o ponteiro está sobre um botão, inclusive desabilitado, a interface
suspende o processamento da câmera e restaura seu estado ao sair; nenhum
parâmetro ou script da câmera é alterado.

Na validação visual com F6, repita os três destinos pelas duas entradas. Confira
o giro nas curvas e na chegada, a folga do sprite em relação ao balcão/portas,
o contato com o piso, a legibilidade dos estados dos botões e a câmera ao passar
o mouse sobre a interface. Teste R e troca de entrada durante cada trecho.

## Cabines e embarque automático

`elevator_shell.tscn` continua sendo o componente usado pelos três elevadores.
Mantém molduras, identificação, posição geral e `ApproachPoint` (Z local = 1,3).
O antigo fundo raso foi recuado para Z = -3,3. Piso, laterais, teto e luz interna
formam uma cabine real, com largura interna de 2,28 m e altura de 2,6 m. O piso
está em Y = 0; a soleira foi rebaixada para deixar apenas uma borda de 2 mm,
preservando o apoio dos pés e a sombra durante a travessia. A parede da recepção
já possui vãos segmentados nos três locais e não precisou ser alterada.

As folhas mantêm suas dimensões de 1,09 × 2,6 × 0,12 m. Foram recuadas para
Z local = -0,64, atrás dos acabamentos da moldura, e ajustadas para fechar sem
fresta central. Cada folha desliza 1,1 m no X local, liberando a passagem. O novo
`elevator_door.gd` usa Tween com suavização senoidal, estados CLOSED / OPENING /
OPEN / CLOSING e durações independentes de abertura/fechamento, configuráveis no
Inspector (padrão 0,6 s). Pedidos repetidos são ignorados; reversões e reinício
cancelam o Tween anterior. Cada instância mantém seu próprio estado.

`ElevatorSelection` preserva as rotas até o ApproachPoint. Ali, interrompe o
deslocamento e solicita a abertura. Quando a porta está totalmente aberta,
`VisitorMovement.follow_route()` continua sem teletransporte por `EntryPoint`
(Z = -0,64) até `CabinStopPoint` (Z = -2,1). A velocidade continua 3. A orientação
PAPER acompanha o deslocamento e, ao parar, aponta para o fundo da cabine.

O fechamento é liberado quando a posição local do visitante ultrapassa o plano
das folhas em pelo menos `Passage Clearance` (padrão 1 m). Essa margem cobre a
meia largura visível do sprite atual (0,72 m), a sombra e a espessura das folhas,
inclusive ao alternar para BILLBOARD. Para personagens com dimensões diferentes,
revise essa margem e os limites da cabine. A condição espacial permanece válida
independentemente da velocidade e não usa temporizador para presumir a passagem.

O visitante não é ocultado nem removido após o embarque. Continua no piso da
cabine, atrás das folhas fechadas; paredes e portas opacas fazem a oclusão pela
profundidade real. PNGs, importação, escala, alpha discard e teste de profundidade
permanecem intactos. Não há viagem, transporte de andar, diálogos ou áudio novo.

Para testar com F6, use 1 ou 2, espere o balcão e clique em cada um dos três
botões. Confira a pausa, abertura, entrada e fechamento com o NPC inteiramente
na cabine. R ou outra entrada reiniciam o teste durante a caminhada, abertura,
entrada, fechamento ou após o embarque, limpando seleção e animações anteriores.
P continua alternando a orientação para comparação. Os botões permanecem
desabilitados após escolher um destino, até uma nova chegada ao balcão.

Os testes headless verificam estados, percursos pelos vãos, apoio no piso,
posição final dentro da cabine, margem de fechamento e interrupções. A aparência
da profundidade, iluminação, oclusão em ângulos oblíquos e suavidade percebida
exige avaliação visual com F6; não é aprovada apenas pela validação programática.

## Identidade visual — etapa 9 (somente Elevador 1)

`scenes/elevator_01_visual.tscn` herda `elevator_shell.tscn`. Apenas a instância
Elevator01 em `scenes/reception.tscn` usa essa variante. Elevator02/03 continuam
com a cena e os materiais originais. A cena base, os scripts, os marcadores e os
parâmetros das portas não foram alterados. Não há nova lógica de gameplay.

A variante usa BoxMesh para moldura escalonada, sapatas, frisos, placa do número,
caixa do visor, corrimãos, juntas do fundo e luminária. As folhas originais
recebem material escuro e um QuadMesh frontal filho com textura de painel;
esses filhos acompanham os tweens existentes. O visor original fica oculto
somente na variante, substituído por uma caixa com frente pixel art. O Label3D
01 original permanece, agora sobre uma placa escura.

Materiais independentes em `materials/elevator_01/`:

- `door.tres`: frente desenhada com rebaixo, bordas e proteção inferior.
- `frame.tres`: metal frio fosco para moldura, soleira e corrimãos.
- `cabin.tres`: metal mais escuro para as paredes internas.
- `floor.tres`: pequenos ladrilhos dessaturados no piso da cabine.
- `dark.tres`: juntas, estrutura, rodapé e partes ocultas das folhas.
- `lamp.tres`: difusor com emissão suave; a OmniLight da cabine foi preservada.
- `indicator.tres`: visor verde discreto sem iluminação adicional sobre a sala.

Texturas em `textures/elevator_01/`: `door_panel.png` (32×64), `metal.png`
(16×16), `floor_tile.png` (16×16) e `indicator.png` (32×12), com seus `.import`.
São PNGs sem dependências de execução externas, sem ruído aleatório.
Todos os materiais usam Nearest; a importação é lossless, sem mipmaps e sem
conversão automática para compressão 3D. Portas usam aproximadamente 25 pixels
por metro. Metal e piso usam projeção triplanar local de 24 pixels por metro;
o visor tem densidade maior para preservar a leitura do pictograma.

### Comparação com F6

1. Abra `scenes/reception.tscn` e pressione F6 na Godot 4.7.2.
2. Leve o mouse à borda direita até o limite existente da câmera: compare o
   Elevador 1, mais próximo, com os elevadores 2 e 3, ainda provisórios.
3. Pressione 1 ou 2 para iniciar a entrada do visitante. Quando ele chegar ao
   atendimento, use o botão Elevador 1. Observe os detalhes nas folhas durante
   a abertura, a entrada, a cabine iluminada e o fechamento após a passagem.
4. Use R para reiniciar e repita com os elevadores 2/3. Confira o contato dos
   pés/sombra e a orientação PAPER; não é necessário alternar P.

A cabine só aparece com a porta aberta. O balcão encobre parte da soleira do
primeiro elevador na câmera atual; câmera, FOV, balcão e resolução foram
preservados. Não há navegação nem colisões novas. As adições ficam nas bordas,
no fundo ou no teto, fora do corredor central do visitante. O restante da sala
continua provisório; esta variante é a primeira referência, não aprovação
estética definitiva nem reformulação da recepção inteira.

### Validação desta etapa

Na cópia temporária, Godot 4.7.2: importação, carregamento dos recursos e
execução headless; roteiro temporário de seis percursos (duas entradas × três
elevadores), verificando chegada à cabine, os quatro estados das portas e
fechamento somente após liberação da passagem. Também foram conferidos
marcadores, parâmetros das portas, velocidade 3, PAPER, câmera/FOV, 640×360,
Nearest e a preservação das malhas/materiais dos elevadores 2/3.

Capturas reais do SubViewport em 640×360, via janela OpenGL Compatibility,
permitiram inspecionar as portas abertas/fechadas, pixels, profundidade e
comparação dos três elevadores. Isso não constitui aprovação estética do autor,
nem teste manual interativo ou auditivo. A saída de execução mantém o aviso de
duas instâncias ObjectDB e um recurso em uso ao encerrar, também presente na
execução inicial. A recepção 2D e as agendas não receberam alterações.

## Exploração livre de debug — etapa 10

Execute `scenes/reception.tscn` com **F6**. A câmera começa no posto normal.
**F** ativa a exploração e **F** novamente retorna imediatamente ao posto.
A tecla estava livre nesta cena; não foi necessário remapear controles.
Somente durante a exploração aparece um indicador discreto na base da tela.

- **W/S**: avançar/recuar na direção do olhar, projetada no plano global XZ.
- **A/D**: deslocar lateralmente; diagonais mantêm a velocidade máxima.
- **Q/E**: descer/subir; olhar para cima não altera a altura com W/S.
- **Shift**: multiplicar temporariamente a velocidade.
- **Segurar botão direito + mouse**: yaw livre e pitch limitado, sem inverter.
  Ao soltar, o cursor retorna à posição anterior e permite clicar na interface.
- **1/2**, **P**, **R** e os botões dos elevadores conservam suas funções.
  R reinicia os visitantes; somente F encerra a exploração.

Selecione o nó **DebugFreeCamera** no Inspector:

| Propriedade | Padrão | Função |
| --- | --- | --- |
| Enable Debug Exploration | habilitada nesta cena | Autoriza F; desabilitada, os controles experimentais não atuam. Desabilitar em execução também restaura o posto. |
| Movement Speed | 3 m/s | Velocidade normal da câmera, independente da velocidade dos NPCs. |
| Fast Speed Multiplier | 3 | Multiplicador com Shift. |
| Mouse Sensitivity | 0,15 °/pixel | Sensibilidade do mouse em pixels da janela, sem escala do viewport. |
| Minimum Height | 0,25 m | Altura mínima acima do piso. |
| Pitch Limit | 85° | Limite vertical nos dois sentidos. |
| Movement Response | 12 | Resposta da suavização; maior responde mais rápido. |
| Camera / Floor Reference / Indicator | referências da cena | Câmera existente, ponto na superfície do piso e indicador. |

`scripts/debug_free_camera.gd` é um componente separado, no viewport principal,
que controla temporariamente a câmera existente. `RoomViewport` continua em
640×360 e `RoomView` continua exibindo sua textura com Nearest. O mouse usa
`screen_relative`, sem depender do tamanho interno de renderização. A captura
só dura enquanto o botão direito está pressionado; perder foco também libera
o mouse e limpa teclas/velocidade para evitar movimento preso.

O componente registra a transformação **local inicial real** da câmera em
`_ready()`, antes de qualquer giro pelas bordas. Ao sair, restaura exatamente
essa transformação, respeitando o deslocamento global de Room, zera a velocidade
e o alvo de suavização do controlador normal e reinicia a interpolação física.
Assim o retorno inclui a orientação original, mesmo que a câmera já estivesse
girada antes de entrar na exploração. O FOV permanece em 70°.

O controlador normal tem apenas uma suspensão explícita e uma função para
limpar o alvo de yaw. A suspensão independe de `set_process`, pois a interface
dos elevadores já pausa/retoma esse processamento ao passar sobre seus botões.
Isso evita que os dois controladores disputem a transformação. Ao retornar,
o controle pelas bordas e a pausa por hover voltam a operar normalmente.

### Validação da etapa 10

Na cópia temporária, com Godot **4.7.2**: importação, carregamento e execução
headless, sem novos erros de GDScript ou referências. O aviso de duas instâncias
ObjectDB e um recurso em uso no encerramento da cena também ocorre no estado
anterior; não foi corrigido nesta etapa.

Teste reproduzível após importar a cópia do projeto:

```bash
"$G" --headless --path "$PROJETO" --fixed-fps 60 \
  -s res://src/gameplay/reception_25d/tests/debug_free_camera_test.gd
```

O teste verifica F e repetição de tecla, suspensão das bordas, mouse relativo e
pitch, movimento horizontal com a câmera inclinada, Shift, Q/E, piso global,
suavização a 30/144 FPS, retorno exato local/global, 20 alternâncias, limpeza
de interpolação/captura, perda de foco, desativação do debug e os atalhos
1/2/P/R. Também conduz um visitante até o Elevador 1 pelo botão durante a
exploração. Resultado: **zero falhas**. O roteiro temporário existente da etapa
9 também passou nos seis percursos (duas entradas × três elevadores), incluindo
estados das portas, chegada à cabine e preservação dos recursos. `git diff
--check` passou. Alterações locais anteriores foram preservadas.

Ainda exige **validação visual e interativa com F6**: sensação da velocidade e
suavidade, captura/soltura real do mouse com a janela redimensionada, leitura do
indicador, cliques reais nos elevadores e inspeção de cabines, balcão, cadeiras,
portas, paredes, texturas e iluminação. Esses testes manuais não foram executados.
Não há colisões, corpo físico ou limite horizontal/superior: a câmera atravessa
paredes e objetos. O único limite espacial é a altura mínima acima do piso.
Esta ferramenta é temporária e exclusiva da cena experimental; nenhuma mudança
de geometria, NPCs, materiais, renderização ou recepção 2D faz parte da etapa.

## Pipeline de texturas — referência para a equipe de arte

O [pacote técnico do Elevador 1](art_pipeline/elevator_01/README.md) reúne
inventário medido, orientação artística inicial, entrega, restrições de UV,
cinco templates PNG e seis referências/pranchas em 640×360. São guias de
produção; nenhuma imagem foi aplicada aos materiais e a paleta atual permanece
provisória. Futuras entregas ficam em `textures/elevator_01_final/`, separadas
dos provisórios de `textures/elevator_01/`. Começar pelas duas portas e pelo
visor; painéis únicos da cabine dependem de preparo de UV antes da encomenda.
