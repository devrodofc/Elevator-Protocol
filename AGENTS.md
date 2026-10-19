# Elevator Protocol — instruções para o Codex

- Projeto Godot **4.7.2**, em **GDScript**. Use a versão instalada indicada por `.godotrc`.
- `CLAUDE.md` é a referência técnica. Consulte as seções relevantes para a tarefa,
  incluindo os riscos conhecidos da seção 9; preserve o histórico de problemas, as decisões
  e os procedimentos de validação.
- Faça somente a tarefa solicitada. Evite refatorações, reformatação e correções de
  avisos preexistentes fora do escopo.
- Antes de editar, confira `git status --short` e o diff dos arquivos envolvidos.
  Preserve alterações locais, inclusive as de indentação e fim de linha.
- Em `.tscn`/`.tres`, preserve UIDs, IDs de recursos, nós, sinais, propriedades e
  listas exportadas. Faça alterações textuais mínimas; não regrave recursos pelo
  editor para trocar um caminho. Em agendas (`src/levels/schedules/`), registre o
  original e compare antes/depois: qualquer diferença não autorizada deve interromper
  a etapa. Veja os riscos de perda de dados na seção 9 de `CLAUDE.md`.
- Em movimentações autorizadas, leve os `.gd.uid` ou `.import` correspondentes,
  preserve os UIDs e parâmetros de importação e atualize referências `res://` e
  `uid://` afetadas. Confirme os caminhos reais; UIDs não dispensam corrigir caminhos.
- Valide apenas o necessário com Godot 4.7.2 CLI, preferindo uma cópia temporária:
  `"$G" --headless --path "$PROJETO" --import` (`G`: executável; `PROJETO`: cópia).
  Confira carregamento, GDScript, referências e integridade dos recursos; compare
  erros/avisos com o estado inicial. Consulte a seção 12 de `CLAUDE.md` para testes
  com autoloads. Não declare testes interativos ou auditivos sem executá-los.
- Não altere `builds/` ou `export_presets.cfg` sem solicitação específica. Respeite a
  branch solicitada e preserve arquivos removidos ou não rastreados. Não execute
  `reset`, `clean`, `stash`, `merge`, commit ou push sem pedido explícito; para o fluxo
  de branches e integração, siga a seção 11 de `CLAUDE.md` e as instruções da tarefa.
- Economize contexto: use `rg`, buscas direcionadas e trechos relevantes; aproveite
  o planejamento e as verificações existentes. Não imprima arquivos completos nem
  repita análises ou testes sem motivo. Ao terminar, confira o diff e
  `git diff --check`; relate mudanças, validações, riscos e pendências de forma breve.
