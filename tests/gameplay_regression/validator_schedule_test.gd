extends SceneTree
## I0: real resources + isolated validator inputs. No gameplay code is replaced.

const Validator = preload("res://src/shared/scripts/rule_validator.gd")
const VisitorResource = preload("res://src/npcs/resources/scripts/visitor_data.gd")
const DialogueResource = preload("res://src/npcs/dialogue/npc_dialogue.gd")
const RuleResource = preload("res://src/gameplay/scripts/marta_rule.gd")
const InteractionResource = preload("res://src/gameplay/scripts/day_interaction.gd")
const FIXTURES := "res://tests/gameplay_regression/fixtures/"
const SEEDS := [0, 1, 2, 3, 42, 73, 20261024]

var checks: int = 0
var failures: int = 0
var sessions: int = 0


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func():
		push_error("I0 data watchdog: no completed result")
		quit(1)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _visitor(tags: Array[String] = []) -> Resource:
	var visitor = VisitorResource.new()
	visitor.tags = tags
	return visitor


func _dialogue(floor_code: int) -> Resource:
	var dialogue = DialogueResource.new()
	dialogue.andar_desejado = floor_code
	return dialogue


func _rule(requested: int, destination: int) -> Resource:
	var rule = RuleResource.new()
	rule.andar_pedido = requested
	rule.andar_destino = destination
	return rule


func _expect(visitor: Resource, dialogue: Resource, day: int, rules: Array, expected: int, name: String) -> void:
	_check(Validator.andar_esperado(visitor, dialogue, day, rules) == expected, name + ": destination")
	for decision in [1, 2, 3, 4, 5, 6, -1, 999, 0]:
		_check(Validator.validar_decisao(visitor, dialogue, decision, day, rules) == (decision == expected),
			"%s: decision %d expected destination %d" % [name, decision, expected])


func _validator_cases() -> void:
	_check(Validator.DENY_ACTION == 999 and RuleResource.NEGAR == 999, "Shared denial code remains 999")
	for floor_code in [1, 2, 3, 4, 5, 6, -1]:
		_expect(_visitor(), _dialogue(floor_code), 1, [], floor_code, "Requested floor %d" % floor_code)
	_expect(_visitor(), null, 1, [], 1, "Missing dialogue defaults to first floor")
	for tag in ["intruder", "deny_access"]:
		_expect(_visitor([tag, "delivery", "send_to_basement"]), _dialogue(5), 3,
			[_rule(5, 6)], 999, "Access denial overrides everything: " + tag)
	for tag in ["delivery", "generic_delivery"]:
		_expect(_visitor([tag]), _dialogue(4), 1, [], 4, tag + " before day two")
		_expect(_visitor([tag]), _dialogue(4), 2, [], 1, tag + " on day two")
		_expect(_visitor([tag]), _dialogue(4), 3, [_rule(4, 6)], 6, "Rule overrides " + tag)
	_expect(_visitor(["send_to_basement"]), _dialogue(6), 3, [], -1, "Basement tag")
	_expect(_visitor(["delivery", "send_to_basement"]), _dialogue(6), 3, [], -1, "Basement overrides delivery")
	_expect(_visitor(["send_to_basement"]), _dialogue(6), 3, [_rule(6, 2)], 2, "Rule can override basement")
	_expect(_visitor(), _dialogue(5), 1, [_rule(5, -1)], -1, "Marta reroutes to basement")
	_expect(_visitor(), _dialogue(3), 2, [_rule(3, 999)], 999, "Marta denies access")
	_expect(_visitor(), _dialogue(5), 1, [_rule(2, 999), _rule(0, 999), null], 5, "Unmatched/lore/null rules")
	_expect(_visitor(), _dialogue(5), 1, [_rule(5, 2), _rule(2, 999)], 2, "Rules match original request, not rerouted floor")
	_expect(_visitor(), _dialogue(5), 1, [_rule(5, -1), _rule(5, 4)], 4, "Last matching rule wins")
	_expect(_visitor(["entregador"]), _dialogue(5), 2, [], 5, "Portuguese tag does not match generic delivery")
	_expect(_visitor(["Intruder"]), _dialogue(2), 1, [], 2, "Tags remain case sensitive")
	var pending = _rule(5, -1)
	_expect(_visitor(), _dialogue(5), 1, [], 5, "Pending rule has no effect before activation")
	_expect(_visitor(), _dialogue(5), 1, [pending], -1, "Same rule affects decision only in active list")


func _check_badge(entry: Dictionary) -> void:
	var visitor = entry.visitor
	var badge: Dictionary = entry.cracha
	_check(badge.has_all(["idade", "sexo", "ocupacao"]), "Complete badge snapshot")
	if visitor.idade_aleatoria:
		_check(badge.idade >= mini(visitor.idade_min, visitor.idade_max)
			and badge.idade <= maxi(visitor.idade_min, visitor.idade_max), "Age in configured range")
	else:
		_check(badge.idade == visitor.idade, "Fixed age")
	for field in ["sexo", "ocupacao"]:
		var random_field: bool = visitor.get(field + "_aleatorio") if field == "sexo" else visitor.ocupacao_aleatoria
		var options: PackedStringArray = visitor.get("opcoes_" + field)
		if random_field and not options.is_empty():
			_check(options.has(badge[field]), "Badge option belongs to resource: " + field)
		else:
			_check(badge[field] == visitor.get(field), "Fixed/fallback badge: " + field)
	if visitor.nome_aleatorio:
		var names = visitor.lista_nomes if visitor.lista_nomes else load(VisitorResource.NOMES_PADRAO_PATH)
		_check(names.names.has(entry.nome), "Visit name belongs to selected name list")
	else:
		_check(entry.nome == visitor.nome, "Fixed name preserved")


func _snapshot(day: Resource, generated: Dictionary) -> Dictionary:
	var rows: Array = []
	for entry in generated.fila:
		rows.append({"visitor": entry.visitor.resource_path, "visitor_id": entry.visitor.id,
			"nome": entry.nome, "sprite": entry.sprite.resource_path if entry.sprite else "",
			"cracha": entry.cracha.duplicate(true), "dialogue": entry.dialogue.resource_path,
			"texto": entry.dialogue.texto, "andar": entry.dialogue.andar_desejado,
			"fixo": entry.fixo, "caso_regra": entry.get("caso_regra", false)})
	var rules: Array = []
	for rule in generated.regras:
		rules.append({"path": rule.resource_path, "fala": rule.fala,
			"texto_prancheta": rule.texto_prancheta, "pedido": rule.andar_pedido,
			"destino": rule.andar_destino})
	return {"day": day.dia_numero, "visits": rows, "rules": rules}


func _schedule_case(day: Resource, random_seed: int) -> Dictionary:
	seed(random_seed)
	# Exactly one generation for this test session; queue and rules come together.
	var generated: Dictionary = day.montar_dia()
	sessions += 1
	var queue: Array = generated.fila
	var rules: Array = generated.regras
	_check(queue.size() == 7, "Day %d seed %d: seven visits" % [day.dia_numero, random_seed])
	_check(day.interacoes.size() == 3 and day.interacoes[0].repeticoes == 4
		and day.interacoes[1].repeticoes == 2 and day.interacoes[2].repeticoes == 1, "4 + 2 + 1 interaction order")
	_check(rules.size() == 2 and rules[0].tem_efeito() and not rules[1].tem_efeito(), "One floor rule then one lore rule")
	if day.dia_numero >= 2:
		_check(rules[1] == day.regras_obrigatorias[0], "Mandatory narrative rule occupies second announcement")
	var floors: Dictionary = {}
	var texts: Dictionary = {}
	var cases := 0
	for index in queue.size():
		var entry: Dictionary = queue[index]
		_check(entry.has_all(["visitor", "dialogue", "nome", "sprite", "cracha", "fixo"]), "Complete entry")
		_check(entry.fixo == (index == 6), "Only final entry is fixed")
		_check(entry.dialogue != null and not entry.dialogue.texto.is_empty(), "A real dialogue per visit")
		_check(not texts.has(entry.dialogue.texto), "No repeated dialogue text in current agendas")
		texts[entry.dialogue.texto] = true
		_check_badge(entry)
		if index < 6:
			var pool: Array = day.pool_padrao if index < 4 else day.interacoes[1].pool
			_check(pool.has(entry.visitor), "Random visitor from correct interaction pool")
			_check(entry.visitor.sprites.has(entry.sprite), "Sprite belongs to same visitor")
			_check(day.andares_do_dia.has(entry.dialogue.andar_desejado), "Random dialogue uses allowed floor")
			floors[entry.dialogue.andar_desejado] = true
		else:
			var fixed = day.interacoes[2]
			_check(entry.visitor == fixed.visitante and entry.dialogue == fixed.dialogo
				and entry.sprite == fixed.sprite, "Fixed visitor/dialogue/sprite preserve identity")
		if entry.get("caso_regra", false):
			cases += 1
			_check(index > day.intervalo_regras and not entry.fixo, "Guaranteed case occurs after next visitor")
			_check(entry.dialogue.andar_desejado == rules[0].andar_pedido, "Guaranteed case matches effect")
			var allowed: Array = day.falas_comuns.duplicate()
			if day.usar_falas_do_visitante:
				allowed.append_array(entry.visitor.dialogos)
			allowed.append_array(rules[0].falas_caso)
			_check(allowed.has(entry.dialogue), "Guaranteed case uses an eligible authored dialogue, including fallback")
	_check(cases == 1, "One guaranteed rule case")
	for floor_code in day.andares_do_dia:
		_check(floors.has(floor_code), "Allowed floor represented: %d" % floor_code)
	_check(queue[day.intervalo_regras].dialogue.andar_desejado != rules[0].andar_pedido, "Visitor immediately after rule is not its case")
	_check(rules[0].andar_pedido != queue[6].dialogue.andar_desejado, "Effect rule does not target fixed request")
	var fixed_entry: Dictionary = queue[6]
	var expected: int = 3 if day.dia_numero == 1 else -1
	_expect(fixed_entry.visitor, fixed_entry.dialogue, day.dia_numero, rules, expected,
		"Concrete fixed visitor day %d seed %d" % [day.dia_numero, random_seed])
	var snapshot := _snapshot(day, generated)
	# Consuming/moving another visit must not resample the already-generated data.
	var consumed: Dictionary = queue.pop_front()
	queue.push_front(consumed)
	_check(_snapshot(day, generated) == snapshot, "Queue consumption preserves sampled association")
	return snapshot


func _interaction_cases() -> void:
	var day = load("res://src/gameplay/schedules/day1.tres")
	var interaction = InteractionResource.new()
	interaction.modo = InteractionResource.Modo.FIXO
	interaction.visitante = day.interacoes[2].visitante
	interaction.dialogo = day.interacoes[2].dialogo
	interaction.sprite = day.interacoes[2].sprite
	interaction.repeticoes = 2
	seed(111)
	var entries: Array = interaction.build_entries(day.pool_padrao, {})
	_check(entries.size() == 2, "Fixed interaction repetition")
	for entry in entries:
		_check(entry.visitor == interaction.visitante and entry.dialogue == interaction.dialogo
			and entry.sprite == interaction.sprite and entry.fixo, "Fixed overrides retained")
	interaction.modo = InteractionResource.Modo.ALEATORIO
	interaction.dialogo = null
	interaction.pool.assign([day.pool_padrao[0]])
	entries = interaction.build_entries(day.pool_padrao, {})
	for entry in entries:
		_check(entry.visitor == day.pool_padrao[0] and not entry.fixo, "Own random pool overrides default")
	interaction.pool.clear()
	entries = interaction.build_entries(day.pool_padrao, {})
	for entry in entries:
		_check(day.pool_padrao.has(entry.visitor) and not entry.fixo, "Empty random pool falls back to default")
	var visitor = _visitor()
	visitor.nome = "Fixture sem sorteio"
	visitor.idade = 67
	visitor.sexo = "Masculino"
	visitor.ocupacao = "Faxineiro"
	var first = _dialogue(2)
	var second = _dialogue(3)
	first.texto = "Primeira fala"
	second.texto = "Segunda fala"
	visitor.dialogos.assign([first, second])
	var used: Dictionary = {}
	var one: Dictionary = visitor.pick_visit(null, null, used)
	var two: Dictionary = visitor.pick_visit(null, null, used)
	_check(one.dialogue != two.dialogue and used.size() == 2, "VisitorData avoids used dialogue when alternatives exist")
	var three: Dictionary = visitor.pick_visit(null, null, used)
	_check(visitor.dialogos.has(three.dialogue), "VisitorData reuses dialogue only after exhaustion")
	_check(one.nome == visitor.nome and one.cracha == {"idade": 67, "sexo": "Masculino", "ocupacao": "Faxineiro"}, "Fixed visit name/badge")
	visitor.idade_aleatoria = true
	visitor.idade_min = 40
	visitor.idade_max = 18
	visitor.sexo_aleatorio = true
	visitor.opcoes_sexo = PackedStringArray()
	visitor.ocupacao_aleatoria = true
	visitor.opcoes_ocupacao = PackedStringArray()
	for index in range(8):
		var entry: Dictionary = visitor.pick_visit(first)
		_check(entry.dialogue == first and entry.cracha.idade >= 18 and entry.cracha.idade <= 40,
			"Forced dialogue and reversed age bounds")
		_check(entry.cracha.sexo == visitor.sexo and entry.cracha.ocupacao == visitor.ocupacao, "Empty option arrays use fixed fallback")


func _resource_integrity() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "resource_integrity.json"))
	_check(manifest is Dictionary and not manifest.is_empty(), "Resource integrity manifest loads")
	if not manifest is Dictionary:
		return
	for path in manifest:
		_check(FileAccess.get_sha256(path) == manifest[path], "Authored resource bytes preserved: " + path)


func _run() -> void:
	var version := Engine.get_version_info()
	_check(version.major == 4 and version.minor == 7 and version.patch == 2, "Pinned engine 4.7.2")
	_resource_integrity()
	_validator_cases()
	_interaction_cases()
	var snapshots: Array = []
	for number in [1, 2, 3]:
		var day = load("res://src/gameplay/schedules/day%d.tres" % number)
		_check(day.dia_numero == number and day.intervalo_regras == 2, "Day identity and rule interval")
		_check(day.proximo_dia.dia_numero == number + 1 if number < 3 else day.proximo_dia == null, "Day chain")
		if number == 3:
			_check(day.cena_final == "res://src/ui/menus/scenes/end_screen.tscn" and ResourceLoader.exists(day.cena_final), "Final scene reference")
		for random_seed in SEEDS:
			_schedule_case(day, random_seed)
		snapshots.append({"seed": 4200 + number, "snapshot": _schedule_case(day, 4200 + number)})
	if "--record-snapshots" in OS.get_cmdline_user_args():
		# Explicit capture only; normal runs never regenerate or accept a baseline.
		print("I0_SNAPSHOTS=", JSON.stringify({"engine": "4.7.2", "sessions": snapshots}))
	else:
		var expected = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "schedule_snapshots.json"))
		_check(expected is Dictionary, "Frozen schedule snapshots load")
		if expected is Dictionary:
			_check(JSON.parse_string(JSON.stringify(snapshots)) == expected.sessions, "Frozen seeds 4201/4202/4203 preserve complete visits and rules")
	_resource_integrity()
	print("I0_DATA_RESULT checks=%d failures=%d sessions=%d" % [checks, failures, sessions])
	quit(1 if failures else 0)
