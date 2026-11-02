# UV, materiais e integração futura

Este documento descreve a preparação posterior. **Nenhuma troca de material,
textura ou geometria foi aplicada nesta entrega.**

## Superfícies prontas

`PixelFaceLeft`, `PixelFaceRight` e `PixelDisplay` são QuadMesh planos, com UV
ocupando todo o retângulo 0–1. A consulta a `get_mesh_arrays()` na Godot 4.7.2
confirmou: posição superior esquerda → UV `(0,0)`, superior direita → `(1,0)`,
inferior esquerda → `(0,1)`, inferior direita → `(1,1)`. Normais apontam para
o +Z local. O relatório completo está em `references/measurements.json`.

Não é necessário um atlas de desdobramento para essas três frentes. Templates
com proporção correta evitam esticar pixels. A arte cobre somente o QuadMesh:
não se estende às bordas/verso da folha nem à caixa externa do visor.

As frentes das portas estão em Z=0,064 relativo à folha; o volume tem espessura
0,12, portanto há **0,004 m** entre a face frontal do volume e o plano texturizado.
Esse afastamento evita coplanaridade. Manter o plano como filho da folha: ele já
acompanha o tween de abertura. Não mover o plano para `VisualDetails`, não
centralizar os marcadores e não alterar o curso da porta para acomodar arte.

## BoxMesh: há UV, mas não é o mapeamento usado hoje

Molduras, piso e paredes são BoxMesh. O UV automático distribui as seis faces
em **atlas 3×2**; as faces não são seis telas completas 0–1. A proporção do
retângulo UV de cada face não leva em conta a proporção física do volume.
Exemplos consultados:

| Superfície | Área UV observada | Consequência para arte única |
| --- | --- | --- |
| Frente +Z de `FrameLeft` e `RecessBack` | U=0…1/3, V=0…1/2 | Um PNG completo aplicado sem preparo só aparece parcialmente na face. |
| Topo +Y de `Cabin/Floor` | U=1/3…2/3, V=1/2…1 | O piso não usa a imagem completa; sua orientação também precisa ser conferida. |
| Face interna +X de `Cabin/WallLeft` | U=1/3…2/3, V=0…1/2 | Painel desenhado 0–1 não cabe sem remapeamento específico. |

Os materiais `frame.tres`, `cabin.tres` e `floor.tres` usam **triplanar local**,
`uv1_triplanar=true`, `uv1_scale=(1.5,1.5,1.5)` e tiles de 16×16. Isso ignora o UV
automático: cada eixo projeta e repete a textura. Na escala atual das instâncias,
são 1,5 repetições por unidade e **24 px/m**; um ciclo mede aproximadamente
0,667 m. A variante está sem escala adicional, com rotação/posição na recepção.

O tile de metal é compartilhado entre molduras e cabine, mas passa por tintas
de albedo diferentes. Uma placa, texto, pintura ou mancha exclusiva pode repetir,
rodar, inverter sua leitura em faces diferentes ou misturar projeções perto das
quinas. O triplanar é adequado a **padrões pequenos e repetíveis**; não é uma
base segura para encomendar painéis ilustrados únicos.

## Como resolver arte única nos volumes, se for solicitada

Antes de encomendar E01-05/06/07, desenvolvimento deve escolher e validar uma
das abordagens, sem mexer nos volumes funcionais, marcadores ou animação:

1. Preparar uma malha visual independente com UV por face e aplicar material
   próprio, preservando a geometria funcional; gerar uma nova prancha UV medida.
2. Usar um plano visual sobre a face desejada, com UV 0–1, dimensões físicas
   verificadas, orientação/normal correta e pequeno afastamento contra z-fighting.
   Avaliar faces visíveis dos dois lados, iluminação e oclusão antes de adotar.
3. Manter o BoxMesh e desenhar um atlas que respeite as seis ilhas, com densidade
   por face e padding planejados. Desabilitar o triplanar apenas no novo material
   específico, depois de auditar orientação e escala de todas as faces usadas.

Nenhuma dessas soluções foi implementada. Não basta desmarcar triplanar e
colocar o PNG de uma parede no material compartilhado: isso recorta a arte e
afeta outras faces. O fundo ainda tem lambril até cerca de Y=1,04 m, corrimão
a Y=1,02 m e juntas na parte alta; o topo e as bordas também sofrem oclusão.
As faces laterais têm proporção 131:130, cujo menor PNG inteiro exato é grande
para a resolução do jogo. Negociar densidade/recorte ou tolerância antes de
produzir; até lá, usar tile ou cor sólida. Não há template aprovado de painel.

## Aplicação das primeiras entregas

1. Conferir nome, dimensões, orientação, alpha e versão em
   `textures/elevator_01_final/`; preservar os PNGs e `.import` provisórios.
2. Importar os PNGs novos com compressão **Lossless**, sem mipmaps e sem redução
   de tamanho; desligar a conversão automática de compressão 3D
   (`detect_3d/compress_to=0`). Incluir seus `.import` com UIDs e parâmetros.
   Isso preserva os pixels da rodada inicial. Se ocorrer cintilação a distância,
   avaliar filtragem/mipmaps numa etapa própria, sem aplicar blur à arte original.
3. Criar materiais StandardMaterial3D independentes para a variante do Elevador 1,
   usando os atuais como referência, com **Texture Filter = Nearest**.
   Não editar um material/mesh compartilhado com os elevadores 2/3.
4. Portas: hoje as duas frentes usam `door.tres` e a mesma imagem. Se receberem
   artes distintas, criar **dois materiais** ou duas variantes locais, um para
   cada frente. Aplicar em `PixelFaceLeft/Right`, com triplanar desligado,
   escala UV=(1,1,1), offset zero e alpha desabilitado. Verificar continuidade
   entre folhas fechadas e movimento com portas abertas.
5. Visor: aplicar em `PixelDisplay`, UV 0–1 e material próprio. O atual
   `indicator.tres` é **unshaded**, não emissivo; trocar sua imagem não ilumina
   a sala. O antigo nó `Indicator` permanece oculto.
6. Tiles: testar o novo metal nos materiais próprios de moldura/cabine e o novo
   piso no material próprio do piso, preservando inicialmente escala/projeção.
   Cor sólida continua válida para elementos pequenos. Não aplicar uma textura
   exclusiva de parede como se fosse um tile.

O albedo do PNG é multiplicado pelo `albedo_color` e depois afetado pela luz
nos materiais shaded. Hoje `frame.tres` usa `(0.72,0.8,0.86)` e `cabin.tres`,
`(0.6,0.7,0.73)`; portas/piso não têm essa tinta extra. Para preservar a paleta
entregue, começar a avaliação de um **novo** material com albedo branco ou
combinar a tinta com as artistas. Não clarear arbitrariamente o PNG para
compensar uma iluminação que pode mudar. Rugosidade/metallic também influenciam
o resultado. Não é necessário encomendar normal, roughness ou metallic maps.

Não pintar sombras fortes com direção global, oclusão do NPC ou reflexos
fotográficos: a geometria e a luz já variam com o ponto de vista. Sombreamento
estilizado pode reforçar formas, desde que funcione com as luzes atuais.

## Revisão dentro da Godot

Comparar porta/visor no posto normal, no limite direito de yaw e em aproximação.
Usar portas abertas/fechadas para ver espessura, encontro e interior; verificar
o balcão e o NPC ocluindo a frente. Observar tiles em quinas e perto dos
corrimãos. A exploração permite atravessar geometria: imagens obtidas dentro
de uma parede não representam o ponto de vista normal.

Registrar a proposta, o frame nativo 640×360 e o resultado da revisão com arte.
Não comparar apenas PNG ampliado sem luz com uma janela 3D maior. Confirmar
que não mudaram FOV, câmera, orientação PAPER, velocidade 3, percursos,
marcadores, portas, seleção dos elevadores ou recursos da recepção 2D.
