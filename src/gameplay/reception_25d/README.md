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
