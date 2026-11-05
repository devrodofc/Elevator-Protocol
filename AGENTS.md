# Elevator Protocol — Instruções para o Codex

## 1. Projeto e documentação

- Projeto desenvolvido em **Godot 4.7.2**, utilizando **GDScript**. Use a versão indicada por `.godotrc`.
- `CLAUDE.md` é a referência técnica do projeto. Consulte somente as seções relevantes à tarefa, incluindo os riscos conhecidos da seção 9.
- Preserve o histórico de problemas, as decisões técnicas e os procedimentos de validação.
- Confirme caminhos e dependências diretamente no código atual, pois a documentação pode estar desatualizada.

## 2. Escopo e desenvolvimento

- Faça somente a tarefa solicitada.
- Priorize alterações pequenas, localizadas e compatíveis com a arquitetura existente.
- Reutilize scripts, recursos e sistemas já implementados.
- Evite refatorações, reformatações e correções de avisos preexistentes fora do escopo.
- Não crie abstrações, dependências ou arquivos desnecessários.
- Antes de editar, confira `git status --short` e o diff dos arquivos envolvidos.
- Preserve todas as alterações locais existentes, incluindo indentação e finais de linha.

## 3. Ferramentas de investigação

Utilize as ferramentas locais disponíveis para reduzir investigações desnecessárias:

- **ripgrep (`rg`)**: localizar arquivos, funções, classes e referências.
- **`gdlint`**: verificar problemas de estilo nos scripts GDScript.
- **`gdformat --check`**: verificar formatação sem modificar arquivos.
- **`gdformat --diff`**: visualizar diferenças de formatação quando necessário.
- **`gdparse`**: analisar sintaxe quando apropriado.
- **Godot CLI**: validar carregamento, compatibilidade e comportamento dos recursos.

Regras:

- Prefira `rg --files` e `rg -l` para localizar arquivos antes de ler conteúdos.
- Utilize `rg -n` para encontrar trechos específicos.
- Restrinja buscas aos diretórios e extensões relevantes.
- Ignore `.godot/`, `builds/` e outros arquivos gerados nas buscas comuns.
- Não leia scripts, cenas ou recursos completos sem necessidade.
- Não execute lint ou formatação no projeto inteiro sem solicitação.
- Não execute `gdformat` sem `--check` ou `--diff`, salvo autorização explícita.
- Não corrija problemas antigos de estilo fora do escopo.
- Execute somente as ferramentas relevantes para a tarefa.

## 4. Segurança dos recursos Godot

- Em `.tscn` e `.tres`, preserve UIDs, IDs de recursos, nós, sinais, propriedades e listas exportadas.
- Faça alterações textuais mínimas; não regrave recursos pelo editor apenas para trocar caminhos.
- Em agendas (`src/levels/schedules/`, quando aplicável), registre o conteúdo original e compare antes/depois.
- Qualquer alteração não autorizada em dados exportados deve interromper a etapa.
- Consulte a seção 9 de `CLAUDE.md` para os riscos conhecidos de perda de dados.
- Em movimentações autorizadas, preserve os `.gd.uid` e `.import` correspondentes.
- Preserve UIDs e parâmetros de importação, atualizando referências `res://` e `uid://` afetadas.
- Confirme os caminhos reais. A existência de UIDs não dispensa a revisão de caminhos.
- Não altere hierarquias, transformações, sinais ou propriedades de cenas sem necessidade.

## 5. Validação e testes

- Valide somente os arquivos e sistemas afetados.
- Para scripts `.gd`, utilize `gdlint` e `gdformat --check` quando relevante.
- Considere problemas preexistentes de estilo como informativos, não como autorização para reformatação.
- Priorize a Godot 4.7.2 CLI para validar carregamento e compatibilidade.
- Quando necessário, execute testes em uma cópia temporária do projeto para evitar modificações indesejadas.
- Exemplo: `"$G" --headless --path "$PROJETO" --import`, com `G` e `PROJETO` previamente definidos.
- Confira carregamento, GDScript, referências e integridade dos recursos.
- Compare erros e avisos com o estado anterior.
- Consulte a seção 12 de `CLAUDE.md` para testes envolvendo autoloads.
- Não declare testes interativos ou auditivos como aprovados sem executá-los.
- Não repita testes já aprovados sem necessidade, exceto quando alterações posteriores puderem afetá-los.

## 6. Segurança Git

- Não altere `builds/` ou `export_presets.cfg` sem solicitação específica.
- Respeite a branch atual e preserve arquivos removidos, modificados ou não rastreados.
- Não execute `reset`, `clean`, `stash` ou `merge` sem autorização explícita.
- Não execute commit ou push automaticamente.
- Para o fluxo de branches e integração, siga a seção 11 de `CLAUDE.md` e as instruções da tarefa.
- Ao concluir, confira `git diff` e `git diff --check`.

## 7. Economia de tokens e contexto

- Investigue primeiro os arquivos diretamente relacionados à tarefa.
- Utilize buscas direcionadas antes de abrir arquivos extensos.
- Aproveite o contexto, os planejamentos e as verificações já existentes.
- Consulte somente as seções necessárias de `CLAUDE.md`.
- Evite pesquisas repetidas e leituras redundantes.
- Não imprima arquivos completos ou saídas extensas de terminal sem necessidade.
- Prefira resultados resumidos de ferramentas, desde que preservem informações necessárias ao diagnóstico.
- Não analise todo o repositório quando o problema estiver localizado.
- Não execute verificações desnecessárias.
- Não crie relatórios extensos para tarefas simples.
- Não sacrifique a correção e a segurança apenas para reduzir tokens.

## 8. Resposta final

Ao concluir uma tarefa, apresente objetivamente:

1. **Alterações:** o que foi feito e quais arquivos foram modificados.
2. **Validação:** quais verificações e testes foram executados.
3. **Resultado:** se a implementação foi concluída corretamente.
4. **Pendências:** erros, riscos ou testes não realizados.

Evite reproduzir arquivos completos, logs extensos ou explicações repetitivas, salvo quando solicitado.
