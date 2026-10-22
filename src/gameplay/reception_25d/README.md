# Recepção 2.5D experimental

Abra `scenes/reception.tscn` no Godot **4.7.2** e pressione **F6**
(Executar cena atual). F5 continua executando a cena principal do projeto.

Mova o mouse até as bordas esquerda e direita para olhar ao redor. Quanto mais
perto da borda, maior a velocidade. No centro, o giro desacelera até parar;
a câmera mantém a direção escolhida. A posição e a inclinação são fixas.

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
