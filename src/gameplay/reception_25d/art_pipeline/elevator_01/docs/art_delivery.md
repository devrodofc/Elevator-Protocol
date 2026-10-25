# Guia inicial de arte e entrega

## Direção para explorar

Pixel art 2D desenhada manualmente sobre ambiente 3D low-poly: recepção de uma
empresa antiga, sombria e ligeiramente inquietante. Buscar formas simples,
contrastes legíveis e sinais de uso com intenção. A estranheza pode vir de
repetições rígidas, sinalização impessoal, desgaste assimétrico e pequenos
desvios na organização, sem depender de sujeira fotográfica.

Os pixels devem permanecer definidos. Usar agrupamentos de pixels para bordas,
rebaixos e desgaste; preferir poucos níveis de sombra bem separados. Evitar
ruído aleatório, aparência fotográfica, gradientes suaves, reflexos pintados
realistas e microdetalhes que desapareçam em 640×360. Não desenhar novamente
volumes que a geometria já comunica, a menos que seja um reforço estilizado.

**A paleta atual não é uma decisão artística definitiva.** As artistas podem
propor famílias alternativas para metal, tinta, sujeira e sinalização, mantendo
relações claras entre fundo, portas, moldura e visor. Entregar uma pequena
amostra de paleta com os PNGs ou registrar cores no documento da proposta é
útil, mas não há quantidade fixa de cores nem códigos hex obrigatórios.
Combinar portas, visor e metal na mesma proposta antes de detalhar cada peça.

## Preparar o desenho

1. Escolher o asset no [inventário](inventory.md). P1 e P2 têm templates prontos;
   P3 não é uma encomenda de arte e pode depender de preparação técnica.
2. Copiar o PNG de `templates/` para um arquivo de trabalho próprio. O canvas é
   cinza neutro e **100% utilizável**, sem padding, corte, grade embutida ou área
   escondida adicional. O cinza não é uma cor obrigatória nem uma máscara.
3. Trabalhar no tamanho nativo indicado. Aseprite, LibreSprite e qualquer outro
   editor que preserve pixels e exporte PNG servem. Camadas, guias e ferramentas
   de criação são escolha da artista. Guardar o original editável para revisões.
4. Abrir as pranchas em `references/` para orientação; nunca desenhar sobre a
   prancha ampliada e exportá-la como textura. Ela contém texto e linhas que
   não pertencem ao asset.

## Orientação e alinhamento

- Portas são vistas **de frente**, olhando para a frente local +Z do elevador.
  Topo do PNG = topo da porta; esquerda do PNG = esquerda da superfície vista.
  A borda direita da porta esquerda encontra a borda esquerda da porta direita.
  Não inverter a folha direita automaticamente; letras/símbolos não podem espelhar.
- Há uma separação geométrica de **0,01 m** entre as duas frentes fechadas:
  centros a ±0,545 m e largura 1,08 m. Cada frente fica 0,005 m para dentro
  dos limites horizontais da folha e 0,01 m dos limites verticais. Não ampliar
  o PNG para cobrir espessura nem tentar eliminar essa separação com transparência.
- Alinhar altura de faixas e detalhes entre folhas usando as mesmas linhas de
  pixel. Desenhos que cruzam o encontro devem continuar legíveis quando as portas
  se afastam e revelar a cabine quando abertas.
- Visor: topo para cima e leitura da esquerda para a direita, sem rotações.
  Usar símbolos grandes e simples; o visor não é uma tela de interface funcional.
- Metal e piso: repetir o tile em uma prévia **3×3**, sem escala, para verificar
  continuidade nas bordas opostas. Não desenhar bordas de quadro em um tile.
  Em projeção triplanar, a orientação varia por face: evitar texto, setas,
  números, objetos únicos e motivos que exijam uma direção fixa.

## Exportar e nomear

| Asset | PNG de entrega | Tamanho |
| --- | --- | --- |
| E01-01L | `ep_e01_door_left_albedo_v001.png` | 36×86 |
| E01-01R | `ep_e01_door_right_albedo_v001.png` | 36×86 |
| E01-02 | `ep_e01_display_albedo_v001.png` | 38×12 |
| E01-03, se produzido | `ep_e01_metal_tile_albedo_v001.png` | 16×16 |
| E01-04, se produzido | `ep_e01_floor_tile_albedo_v001.png` | 16×16 |

Usar minúsculas, sublinhados, sem espaços/acentos. Incrementar `v002`, `v003`…
nas revisões. Propostas alternativas podem usar `_a_v001` / `_b_v001`, com o
mesmo identificador em todas as peças do conjunto. Não incluir `_template`,
`guide` ou `ref` nos nomes das entregas artísticas.

Exportar **PNG RGB ou RGBA com alpha 255 em todos os pixels**, cores sRGB, uma
imagem por asset. Nenhuma superfície da primeira rodada precisa de transparência.
Não recortar automaticamente áreas uniformes, não adicionar margem, não usar
antialiasing, blur, interpolação bilinear, redimensionamento suave, JPEG ou
compressão com perda. Não exportar uma captura do editor nem a ampliação de
apresentação. Para previews maiores, usar múltiplos inteiros com Nearest e
identificar a ampliação separadamente.

Se for proposto um decalque com recortes transparentes no futuro, discutir antes
o modo de alpha, ordenação e a superfície de aplicação com desenvolvimento;
isso não se aplica às portas e ao visor atuais. Não perfurar a arte das portas
com alpha para simular furos inexistentes.

## Pacote e revisão

Entregar os PNGs em `textures/elevator_01_final/`, sem substituir os provisórios.
Enviar junto uma nota curta com nome da autora, versão, proposta/paleta,
assets incluídos, diferenças em relação à rodada anterior e dúvidas. Originais
editáveis podem ser guardados no local combinado pela equipe; não são requisito
para importar o PNG e não devem virar uma dependência do jogo.

Antes de entregar:

- Conferir dimensões nativas e visualização a 100% no editor, sem suavização.
- Conferir orientação, encontro das portas e continuidade 3×3 dos tiles.
- Observar formas e símbolos também reduzidos; o visor aparece em cerca de
  21×9 pixels no posto normal e a porta esquerda em uma caixa de 26×73.
  Essa redução é uma referência, pois perspectiva e oclusão alteram a leitura.
- Após a integração por desenvolvimento, comparar no posto normal e em
  exploração com luzes reais, portas abertas/fechadas e NPC em passagem.
  Inspecionar o frame interno 640×360; uma janela grande não aumenta o detalhe
  renderizado. Avaliar possíveis cintilações durante o movimento.

Qualquer mudança de tamanho deve ser combinada antes de redesenhar: preservar
a proporção física. As portas podem usar outro múltiplo de 18×43; o visor,
outro múltiplo de 19×6. Não esticar uma arte quadrada numa porta retangular.
