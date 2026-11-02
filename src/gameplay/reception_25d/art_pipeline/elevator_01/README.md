# Elevador 1 — pacote técnico para pixel art

**Referências e telas de trabalho; nenhuma imagem deste pacote é arte definitiva.**
A paleta e os desenhos do elevador atual são provisórios. A equipe de arte pode
propor alternativas. Nenhum template está conectado aos materiais do jogo.

Comece pelo [inventário](docs/inventory.md), consulte o
[guia de arte e entrega](docs/art_delivery.md) e veja as
[restrições de UV e integração](docs/integration_uv.md).

## Estrutura

- `docs/`: inventário, direção inicial, entrega e integração.
- [references/](references/README.md): capturas reais da Godot, mapas numerados,
  pranchas de orientação e medições/UV em JSON.
- [templates/](templates/README.md): cinco PNGs neutros no tamanho de desenho.
  Toda a área é útil; a grade só existe nas pranchas de referência.
- `tools/build_reference_pack.gd`: utilitário de desenvolvimento para reproduzir
  o pacote em uma cópia temporária; não participa da execução do jogo.
- Provisórios usados atualmente: [textures/elevator_01/](../../textures/elevator_01/)
  dentro de `reception_25d/`.
  Não mover, renomear nem sobrescrever esses arquivos.
- [Futuras entregas](../../textures/elevator_01_final/README.md): destino reservado
  para PNGs aprovados, separado dos provisórios; ainda sem ligação com materiais.

## Primeira rodada sugerida

1. Portas esquerda/direita como conjunto, **36×86 px cada**: desenho reconhecível,
   desgaste e alinhamento. São duas frentes independentes e móveis.
2. Visor, **38×12 px**: símbolos grandes e contraste; testar leitura a distância.
3. Metal repetível, **16×16 px**, somente se acrescentar informação útil.
   Molduras e cabine podem continuar com materiais simples.
4. Piso repetível, **16×16 px**, se necessário para a identidade da cabine.
5. Painéis exclusivos de cabine, placa e outros detalhes: avaliar depois da
   primeira integração; superfícies em BoxMesh precisam de preparação para arte
   única. Não iniciar essas peças com o mapeamento atual como se fossem planos.

## Como avaliar

No jogo, abra `scenes/reception.tscn` com F6. O controle pelas bordas permite
comparar a leitura do Elevador 1 com os demais; F ativa a exploração para chegar
perto, WASD move, Q/E muda a altura e botão direito permite olhar. F retorna ao
posto. Use 1/2 e o botão Elevador 1 para observar abertura, cabine e fechamento.

Avalie **a imagem interna em 640×360**, além da aproximação. Os limites projetados
da frente esquerda medem aproximadamente **26×73 pixels**, e os do visor,
**21×9 pixels**, no limite direito da câmera normal. São caixas projetadas sem
descontar a oclusão pelo balcão/moldura, não contagens de pixels visíveis.
As capturas preservam a luz atual; elas não aprovam a paleta como definitiva.

## Reprodução e validação técnica

Use o executável de `.godotrc` (**4.7.2-stable no-dotnet**). Trabalhe em cópia
temporária para não atualizar imports ou recursos existentes no projeto original.
`G` é o executável e `PROJETO` é essa cópia:

```bash
"$G" --headless --path "$PROJETO" --import
# Gera os cinco PNGs neutros e audita UVs; não captura imagens no driver dummy.
"$G" --headless --path "$PROJETO" \
  -s res://src/gameplay/reception_25d/art_pipeline/elevator_01/tools/build_reference_pack.gd
# Capturas reais e pranchas: abre janela e usa Compatibility só nesta execução.
"$G" --path "$PROJETO" --rendering-method gl_compatibility \
  --windowed --resolution 640x360 --fixed-fps 60 \
  -s res://src/gameplay/reception_25d/art_pipeline/elevator_01/tools/build_reference_pack.gd \
  -- --render-references
```

O utilitário sobrescreve apenas seus cinco templates e o relatório, mais as seis
referências quando solicitado. Não o use sobre um template que recebeu desenho:
copie o template para o nome de entrega antes de trabalhar. A execução sem render
gera somente o relatório de UV; a execução com render inclui as medidas projetadas.
Revise os resultados antes de trazê-los da cópia para o projeto.

Validação desta entrega: geração determinística dos templates, conferência de
dimensões e UVs reais, capturas OpenGL Compatibility em 640×360, importação da
cópia com os arquivos novos, carregamento da cena e `git diff --check`.
Os avisos de duas instâncias ObjectDB e um recurso em uso no encerramento já
existiam antes desta etapa. Não houve teste manual interativo/auditivo nem
aprovação artística; houve inspeção das imagens capturadas. Nenhum script de
gameplay, cena, material, textura provisória ou `.import` existente foi alterado.
