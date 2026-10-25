# Templates de desenho — não são texturas finais

Os cinco PNGs deste diretório são telas neutras **opacas**, na resolução real
de trabalho. Toda a área do PNG é utilizável. Não existe padding, corte,
transparência ou área reservada. O cinza não representa uma paleta aprovada.

| PNG | Asset | Tamanho | Destino físico | Orientação |
| --- | --- | --- | --- | --- |
| `ep_e01_door_left_albedo_template.png` | E01-01L | 36×86 | Frente de 1,08×2,58 m | Topo para cima; borda direita encontra a outra folha. |
| `ep_e01_door_right_albedo_template.png` | E01-01R | 36×86 | Frente de 1,08×2,58 m | Topo para cima; borda esquerda encontra a outra folha. |
| `ep_e01_display_albedo_template.png` | E01-02 | 38×12 | Frente de 0,76×0,24 m | Topo para cima; leitura da esquerda para a direita. |
| `ep_e01_metal_tile_albedo_template.png` | E01-03, opcional | 16×16 | Tile, ciclo de 0,667 m na escala atual | Repetível nos dois eixos; evitar símbolos direcionais. |
| `ep_e01_floor_tile_albedo_template.png` | E01-04, opcional | 16×16 | Tile, ciclo de 0,667 m na escala atual | Repetível nos dois eixos. Não representa o piso inteiro. |

Abra as [pranchas de orientação](../references/README.md) para ver proporções,
grade, encontro das portas e áreas de aplicação. As linhas das pranchas não
estão nestes PNGs e não devem entrar na arte.

Copie o template e renomeie a cópia com o
[nome de entrega](../docs/art_delivery.md). Não sobrescreva os templates.
Não use a prancha 640×360 como textura. Não redimensione a arte para os antigos
32×64 ou 32×12: esses formatos provisórios têm proporções inadequadas.

Não há template de produção para painéis únicos de BoxMesh. O mapeamento
precisa ser preparado antes; veja [UV e integração](../docs/integration_uv.md).
