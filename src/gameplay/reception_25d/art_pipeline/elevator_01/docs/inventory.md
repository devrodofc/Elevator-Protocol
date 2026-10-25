# Inventário artístico — Elevador 1

Dimensões em unidades de cena, tratadas como metros. Fontes verificadas:
`scenes/elevator_shell.tscn`, variante `scenes/elevator_01_visual.tscn`, materiais
em `materials/elevator_01/` e arrays reais de UV na Godot 4.7.2.
Os caminhos abaixo partem da instância
`RoomViewport/Room/Elevators/Elevator01` de `scenes/reception.tscn`.

**P1**: primeira rodada; **P2**: opcional após portas/visor; **P3**: avaliar
futuramente, depende de preparação ou pode continuar só com material.
Largura × altura nos planos; X × Y × Z nos volumes. Resolução de trabalho =
resolução final do PNG, sem ampliação de apresentação e sem exigência de potência de 2.

| ID | Objeto | Superfície | Localização relativa | Dimensões / proporção | Resolução sugerida | Formato | Transparência | Prioridade | Integração |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E01-01L | Porta esquerda | Frente visível, QuadMesh | `DoorAssembly/LeftPanel/PixelFaceLeft` | 1,08×2,58 m; 18:43. Folha física 1,09×2,60×0,12 m | **36×86 px**, 33,33 px/m | PNG RGB ou RGBA opaco | Não | P1 | Template pronto, UV 0–1. Precisa material próprio para desenho distinto da direita; hoje compartilham `door.tres`. |
| E01-01R | Porta direita | Frente visível, QuadMesh | `DoorAssembly/RightPanel/PixelFaceRight` | 1,08×2,58 m; 18:43 | **36×86 px**, 33,33 px/m | PNG RGB ou RGBA opaco | Não | P1 | Template pronto; não espelhar automaticamente letras, sujeira ou símbolos. Filha móvel da folha. |
| E01-02 | Visor | Frente, QuadMesh | `VisualDetails/PixelDisplay` | 0,76×0,24 m; 19:6. Caixa externa 0,84×0,28×0,09 m | **38×12 px**, 50 px/m | PNG RGB ou RGBA opaco | Não | P1 | Template pronto; `indicator.tres`, unshaded. Não gera iluminação na cabine. |
| E01-03 | Metal comum | Padrão pequeno sem direção narrativa | `FrameLeft`, `FrameRight`, `Lintel`, `Threshold`, `VisualDetails/BackRail`, `SideRailLeft/Right`; `Cabin/WallLeft/Right` e `DoorAssembly/RecessBack` | Montantes 0,20×2,70×0,65 m; lintel 2,60×0,20×0,65 m; corrimão traseiro 2,12×0,07×0,07 m; lateral 0,06×0,07×2,24 m | **16×16 px repetível**, 24 px/m na escala atual; ciclo de 0,667 m | PNG RGB ou RGBA opaco | Não | P2 | Template pronto. Compartilhado por `frame.tres` e `cabin.tres` com tintas diferentes. Pode ser dispensado em favor de cor sólida. |
| E01-04 | Piso da cabine | Padrão repetível na face superior XZ | `Cabin/Floor` | Volume 2,50×0,10×3,40 m; topo 25:34; área interna sofre oclusão das paredes | **16×16 px repetível**, 24 px/m; cerca de 3,75×5,10 ciclos no volume | PNG RGB ou RGBA opaco | Não | P2 | Template pronto; `floor.tres` triplanar. Não é uma imagem esticada por todo o piso. |
| E01-05 | Parede do fundo | Possível painel ilustrado exclusivo | `DoorAssembly/RecessBack`, frente local +Z | 2,50×2,60 m; 25:26. Lambril e corrimão encobrem parte inferior | **50×52 px**, 20 px/m, somente após UV aprovado | PNG opaco, se solicitado | Não | P3, bloqueado por UV | Sem template de produção. Hoje recebe tile triplanar, não arte única; requer material/UV específico. |
| E01-06 | Paredes laterais | Possível painel exclusivo, faces internas ±X | `Cabin/WallLeft`, `Cabin/WallRight` | Espessura 0,12 m; profundidade 2,62×altura 2,60 m; proporção 131:130 | **131×130 px** é o menor tamanho inteiro exato; adiar e negociar densidade/UV | PNG opaco, se solicitado | Não | P3, bloqueado por UV | Não pedir esse tamanho como padrão: é alto para 640×360. 52×52 exigiria aceitar ~0,77% de diferença. Preferir tile/material até definir painel e tolerância. |
| E01-07 | Piso completo exclusivo | Alternativa ao tile, não pedido adicional | `Cabin/Floor`, topo +Y | 2,50×3,40 m; 25:34 | **50×68 px**, 20 px/m, só após UV aprovado | PNG opaco, se solicitado | Não | P3, bloqueado por UV | Alternativa a E01-04. Não produzir ambos sem decisão; UV atual é atlas de BoxMesh ignorado pelo triplanar. |
| E01-08 | Placa do número | Placa frontal e texto independente | `VisualDetails/NumberPlaque` + `Identification` | Placa 0,64×0,43×0,04 m; texto 01 é Label3D da recepção | **Nenhuma por enquanto** | — | — | P3 | Material sólido `dark.tres` + texto atual bastam. Não incorporar 01 no tile ou visor. Se virar ilustração, preparar face/UV e evitar número duplicado. |
| E01-09 | Lambril do fundo | Faixa inferior | `VisualDetails/BackWainscot` | 2,26×1,04×0,035 m | **Nenhuma por enquanto** | — | — | P3 | Cor sólida escura preserva separação visual; não é obrigatório criar asset. Pode encobrir arte do fundo até Y≈1,04 m. |
| E01-10 | Frisos, sapatas e juntas | Volumes pequenos e recessos | `VisualDetails/OuterTrimLeft/Right`, `FrameFootLeft/Right`, `FrameCapLeft/Right`, `HeaderCrown`, `BackJointLeft/Right`, `SillGroove0..3`; `DoorAssembly/RevealLeft/Right` | Friso 0,07×2,74×0,40; sapata 0,20×0,32×0,05; capa 0,20×0,06×0,05; coroa 2,74×0,08×0,40; junta 0,025×1,50×0,025; sulco 2,15×0,002×0,018 m | **Nenhuma por enquanto** | — | — | P3 | Manter `dark.tres`. Não gastar textura com elementos menores que poucos pixels na vista normal. |
| E01-11 | Luminária / teto | Difusor, bandeja e teto | `VisualDetails/LightDiffuser`, `LightTray`; `Cabin/Ceiling` | Difusor 1,30×0,02×0,36; bandeja 1,50×0,05×0,52; teto 2,50×0,10×3,40 m | **Nenhuma por enquanto** | — | — | P3 | `lamp.tres` emissivo e `dark.tres` bastam. A luz real vem de `Cabin/Light`; não pintar luz fotográfica na textura. |
| E01-12 | Verso / espessura das portas | Laterais e verso dos volumes móveis | `DoorAssembly/LeftPanel`, `RightPanel` | Cada volume 1,09×2,60×0,12 m | **Nenhuma por enquanto** | — | — | P3 | As artes E01-01 só cobrem a frente. Manter material escuro no resto; não alterar volume ou curso das portas. |

## Por que essas resoluções

As frentes já têm UV simples: `(U,V)=(0,0)` no canto superior esquerdo visto de
frente, `(1,1)` no inferior direito. Para pixels com escala física igual nas duas
direções, `largura_px / largura_m = altura_px / altura_m`.

- Porta: `1,08 / 2,58 = 18 / 43`; `36 / 1,08 = 86 / 2,58 = 33,33 px/m`.
  O provisório 32×64 usa 29,63 px/m no eixo horizontal e 24,81 no vertical:
  pixels fisicamente retangulares. **Não copiar essa proporção.**
- Visor: `0,76 / 0,24 = 19 / 6`; 38×12 mantém os 12 pixels verticais atuais
  e corrige a largura. O provisório 32×12 tem 42,11 e 50 px/m.
- Tiles: 16×16 na projeção local atual de 1,5 ciclos/m fornecem 24 px/m,
  independentemente da proporção total da parede/piso. A mesma imagem repete,
  em vez de esticar, e por isso precisa conectar os quatro lados.

Essas densidades são pontos de partida, não uma regra universal de arte.
Na câmera normal em seu limite direito, a porta esquerda ocupa uma caixa de
aproximadamente 26×73 pixels e o visor 21×9. Os templates de porta preservam
detalhes próximos sem criar imagens muito grandes; o visor admite densidade
maior para símbolos. Mesmo assim, detalhes de um pixel podem desaparecer ou
oscilar durante o movimento. Validar em 640×360 com a iluminação e oclusão reais.

Não há atlas exclusivo desenhado para o Elevador 1. Os BoxMesh possuem um atlas
automático 3×2 de faces, mas os materiais texturizados desses volumes usam
triplanar e ignoram esse atlas. Veja [UV e integração](integration_uv.md).
