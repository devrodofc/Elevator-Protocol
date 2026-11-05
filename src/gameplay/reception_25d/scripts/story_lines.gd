extends RefCounted
## Roteiro da recepção 3D: TODAS as falas de história ficam aqui (tutorial, Marta, Godofredo, telefone).
## Tom: dia 1 parece normal, com uma ou duas coisas fora do lugar; dia 2 fica claro que tem algo errado;
## dia 3 não tem mais disfarce. As pessoas do subsolo não ligam: quem desce, não volta.
##
## Os .tres dos dias continuam com os textos antigos (usados pela recepção 2D). Na 3D, story_director.gd
## aplica estes textos em memória (nunca salva os recursos). As falas comuns dos visitantes não mudam.

## Tutorial: [falante ("" = narração), texto, destaque] (destaque = TutorialStep.Destaque:
## 0 nenhum, 1 fala, 2 livro, 3 regras, 4 crachá, 5 painel).
const TUTORIAL := [
	["", "Seis meses sem emprego. As contas chegando, a poupança no fim.", 0],
	["", "Então veio o e-mail: \"Vaga de recepcionista. Início imediato. Não é preciso experiência.\"", 0],
	["", "Um prédio comercial no centro da cidade. Seis andares. Salário acima da média.", 0],
	["", "Quando a gente precisa tanto de um emprego, não faz muitas perguntas.", 0],
	["Marta", "Oi! Você é a recepcionista nova? Eu sou a Marta, a supervisora. Seja muito bem-vinda!", 0],
	["Marta", "Funciona assim: o visitante chega no balcão e diz para onde quer ir. A fala dele aparece aqui.", 1],
	["Marta", "Na dúvida, consulte o livro. Ele mostra o que funciona em cada andar.", 2],
	["Marta", "As regras do dia ficam nesta prancheta. Elas mudam de um dia para o outro, então dê sempre uma olhada.", 3],
	["Marta", "E confira o crachá de quem está na sua frente: nome, idade, cargo.", 4],
	["Marta", "Depois é só apertar o andar no painel e confirmar. O X nega o acesso.", 5],
	["Marta", "O S é o subsolo. Quase ninguém vai para lá.", 5],
	["Marta", "Bom, é isso! Qualquer coisa, eu estou por perto.", 0],
]

## Mensagens do dia (substituem mensagem_inicio/fim/falha do dayN.tres).
const DAY_MESSAGES := {
	1: {
		"inicio": "O trabalho é simples: ouça para onde a pessoa quer ir, confira o crachá e aperte o botão certo. As regras do dia ficam na prancheta.",
		"fim": "Primeiro dia e nenhuma reclamação. Isso é raro por aqui! ...Engraçado, o elevador ficou parado no subsolo a tarde toda. Deve ser defeito. Até amanhã!",
		"falha": "Ih, esse andar não estava certo. Tudo bem, no começo todo mundo erra. Vamos de novo.",
	},
	2: {
		"inicio": "Bom dia. Hoje deve ser um dia mais corrido, fique de olho na prancheta.",
		"fim": "Ah, oi! Não repara... é katchup. O lanche chegou e eu me empolguei. O entregador? Já foi embora. Mudaram a rota dele, ele não volta mais. Bom trabalho hoje.",
		"falha": "Errou de novo? Eu defendi você hoje. Não me faz parecer boba. Recomeça.",
	},
	3: {
		"inicio": "O Seu Tião vai passar aqui hoje. Na hora certa, eu te explico o que fazer com ele.",
		"fim": "O Seu Tião já está terminando lá embaixo. Quando ele acaba, não sobra nada. Nem mancha, nem cheiro, nem ninguém para perguntar. Até amanhã. Você vem amanhã, não vem?",
		"falha": "Ainda errando? Depois de tudo? Tudo bem. O Seu Tião limpa. Começa de novo.",
	},
}

## Regras da Marta: texto original da prancheta (dayN.tres) -> [nova fala, nova prancheta ("" = manter)].
const RULES := {
	# Dia 1: tudo plausível, uma coisa ou outra estranha.
	"Pediu o 5º andar? Mande para o subsolo.": ["O Arquivo do 5º está em obra hoje. Quem pedir o 5º, manda para o subsolo: as caixas do arquivo ficaram lá embaixo.", ""],
	"Ninguém chamado Rogério trabalha aqui. Nunca trabalhou.": ["Se alguém procurar um tal de Rogério, diga que não tem ninguém com esse nome aqui.", "Ninguém chamado Rogério trabalha aqui."],
	"4º andar: negar acesso. Ignore os barulhos.": ["O Marketing pediu para não ser incomodado hoje. Quem pedir o 4º, pode negar. Eles reclamam até do barulho do elevador.", "4º andar: negar acesso."],
	"6º andar? Mande para o subsolo.": ["Quem pedir o 6º sem o seu Godofredo ter ligado, não precisa negar: manda para o subsolo. Eu converso com eles lá embaixo. Ele odeia ser incomodado.", "6º andar sem ligação do Godofredo? Subsolo, não negar."],
	"Pediu o 2º andar? Mande para o 5º.": ["O RH está sem ninguém hoje. Quem pedir o 2º, manda para o 5º, que o pessoal do Arquivo resolve a papelada.", ""],
	"Batidas no poço do elevador são normais.": ["Se ouvir umas batidas no poço do elevador, é a tubulação. Prédio velho. Não precisa chamar ninguém.", ""],
	"Sorria. As câmeras estão vendo.": ["E sorria de vez em quando! As câmeras gravam a recepção, e o seu Godofredo adora reclamar de cara feia.", "Sorria. As câmeras gravam a recepção."],
	# Dia 2: fica claro.
	"3º andar: negar acesso.": ["O 3º está sem sistema hoje. Negue quem pedir. Se insistirem, diga que caiu tudo.", ""],
	"Pediu o 1º andar? Mande para o subsolo.": ["O refeitório fechou. Quem pedir o 1º, manda para o subsolo. Eu deixei comida lá embaixo.", ""],
	"Pediu o 4º andar? Mande para o 2º.": ["O Marketing está desfalcado. Quem pedir o 4º, manda para o RH. Eles têm uns papéis de desligamento para assinar.", ""],
	"Pediu o 5º andar? Mande para o 6º.": ["Quem pedir o Arquivo hoje sobe para o 6º. O seu Godofredo quer saber quem anda mexendo nas pastas antigas.", ""],
	"A recepcionista anterior foi promovida.": ["Se perguntarem da recepcionista de antes, diga que ela foi transferida. Para outra unidade.", "A recepcionista anterior foi transferida."],
	"Botão S acendeu sozinho? Não aperte.": ["Se o botão S acender sozinho, não aperte. Ele faz isso às vezes.", ""],
	"Se os números não baterem, fique quieto.": ["Conte quantos sobem e quantos voltam. Se não bater, não comente com o Godofredo. Fala comigo.", "Se os números não baterem, fale só com a Marta."],
	"Entrega para a Marta? Mande para o subsolo.": ["Hoje chega uma encomenda para mim. Quando o entregador perguntar por mim, manda direto para o subsolo. Eu recebo lá embaixo.", ""],
	# Dia 3: sem disfarce.
	"Pediu o 2º andar? Mande para o 1º.": ["O RH foi desativado. Quem pedir o 2º, manda esperar no refeitório. Vai esperar bastante.", ""],
	"Pediu o 4º andar? Mande para o subsolo.": ["O 4º não existe mais. Quem pedir o 4º, desce. Uma hora todo mundo desce.", ""],
	"Pediu o 3º andar? Mande para o 5º.": ["A TI foi para o 5º. Quem pedir o 3º, manda para o 5º.", ""],
	"1º andar: negar acesso.": ["Ninguém entra no refeitório hoje. Negue. E não pergunte o que tem no cardápio.", ""],
	"Cheiro de produto de limpeza é normal.": ["O cheiro de produto de limpeza é do Seu Tião. Ele está trabalhando desde cedo. Tem muita coisa para limpar.", ""],
	"Nunca tivemos entregador.": ["Se perguntarem pelo entregador de ontem: nunca tivemos entregador.", ""],
	"Não abra a gaveta de baixo.": ["Não abra a gaveta de baixo da sua mesa. Guardei umas coisas do Godofredo lá.", ""],
	"Seu Tião (faxineiro)? Sempre para o subsolo.": ["Quando o Seu Tião chegar, não importa o que ele pedir: subsolo. Ele sabe o que fazer lá embaixo.", ""],
}

## Abertura de cada dia.
const GODOFREDO_INTRO_DAY1 := [
	"Você é a recepcionista nova? Hmpf. Godofredo, dono do prédio. Meu escritório é no sexto.",
	"Uma regra, e eu não repito: ninguém sobe ao sexto sem eu avisar. Eu ligo e falo o nome. Não liguei, não sobe.",
	"Esse elevador é velho. Se ele descer para o subsolo sem ninguém chamar, aperte o alarme vermelho. O subsolo é desativado.",
	"E atenda o telefone quando tocar. Três reclamações minhas e você está fora.",
]
## Índice da fala do Godofredo depois da qual a regra do 6º vai para a prancheta.
const GODOFREDO_RULE_LINE := 1
const MARTA_INTRO := {
	1: [
		"Não liga para o jeito dele. O seu Godofredo é assim com todo mundo. Qualquer coisa, me chama que eu resolvo.",
		"Ah, e o subsolo... não precisa se preocupar com ele. Essa parte é comigo.",
	],
	2: [
		"Ontem o elevador desceu algumas vezes sem ninguém chamar. Se o seu Godofredo perguntar, você não viu nada, tá? Eu cuido disso.",
	],
	3: [
		"O seu Godofredo não vem hoje. Nem amanhã. A partir de agora, quem cuida do prédio sou eu.",
		"Então eu ligo quando alguém puder subir ao sexto. Os outros, você nega. Igual a antes.",
		"E o alarme do elevador: não aperte. Se o elevador descer sozinho, deixe descer. Eu sei para onde ele vai.",
	],
}

## Telefone. kind: "guest" (anuncia {nome}, vira regra), "lore" (só história). at = atendimentos já contados.
const CALLS := {
	1: [
		{"at": 1, "caller": "Godofredo", "kind": "guest", "lines": [
			"Recepção? Godofredo. Vou receber {nome} daqui a pouco. Pode mandar subir.",
			"Só {nome}. Mais ninguém."]},
		{"at": 4, "caller": "Godofredo", "kind": "guest", "lines": [
			"Godofredo de novo. Mais uma: {nome}. Sexto andar.",
			"E agiliza essa fila, o barulho chega aqui em cima."]},
	],
	2: [
		{"at": 0, "caller": "Godofredo", "kind": "lore", "lines": [
			"Godofredo. A regra do sexto continua.",
			"Outra coisa: o elevador desceu para o subsolo ontem à noite. O subsolo está fechado há anos. Se vir alguém mexendo nisso, me avise."]},
		{"at": 1, "caller": "Godofredo", "kind": "guest", "lines": [
			"Vou receber {nome}. Só {nome}.",
			"E não comente com a Marta que eu liguei."]},
		{"at": 5, "caller": "Marta", "kind": "lore", "lines": [
			"Oi, é a Marta. O Godofredo ligou para você de novo?",
			"...Tudo bem, não precisa me dizer. Eu descubro."]},
	],
	3: [
		{"at": 1, "caller": "Marta (ramal do 6º)", "kind": "guest", "lines": [
			"Sou eu, do ramal do seu Godofredo. Hoje o sexto recebe {nome}.",
			"Só {nome}. Os outros, você já sabe."]},
		{"at": 4, "caller": "Marta (ramal do 6º)", "kind": "lore", "lines": [
			"A sala do Godofredo ficou tão vazia...",
			"O Seu Tião vai subir para dar uma limpada aqui. Depois que terminar lá embaixo."]},
	],
}

## Dia 2: o Godofredo desce para falar com você e a Marta intervém.
## Passos: ["G" ou "M", fala], ["marta_chega"], ["godofredo_sai"], ["marta_sai"].
const DAY2_VISIT := [
	["G", "Você. Preciso falar com você. Dois funcionários não vieram hoje, e o entregador de ontem não voltou para a empresa dele."],
	["G", "E o elevador continua descendo para o subsolo. Quem está mandando gente para lá?"],
	["marta_chega"],
	["M", "Godofredo, ela está trabalhando. Se você tem alguma reclamação, fala comigo."],
	["G", "Com você? Foi você que pediu a chave do subsolo semana passada, Marta."],
	["M", "Para guardar as caixas do arquivo. Você mesmo pediu. Está esquecendo as coisas de novo?"],
	["G", "...Isso não acabou."],
	["godofredo_sai"],
	["M", "Desculpa por isso. Ele anda muito estressado. Se ele te ligar de novo, me avisa, tá? Eu quero ajudar ele."],
	["marta_sai"],
]

## Reações ao alarme.
const ALARM_SAVED := {
	1: {"caller": "Godofredo", "lines": [
		"O alarme disparou. O elevador estava descendo mesmo...",
		"Isso não devia acontecer. Vou chamar o técnico de novo."]},
	2: {"caller": "Marta", "lines": [
		"Você apertou o alarme agora há pouco.",
		"Não precisava. O elevador sabe o caminho."]},
}
const ALARM_SAVED_BASEMENT := {
	1: {"caller": "Marta", "lines": [
		"Oi, é a Marta. Você parou o elevador que ia para o subsolo?",
		"Tudo bem, você ainda está aprendendo. Mas quando eu disser subsolo, é subsolo."]},
	2: {"caller": "Marta", "lines": [
		"Eu pedi para mandar para o subsolo. Você parou o elevador.",
		"Não faz mais isso."]},
}
## Second time the same reaction would happen on a day: shorter, colder.
const ALARM_REPEAT := {
	1: {"caller": "Godofredo", "lines": ["De novo esse elevador? Vou ter uma conversa séria com o técnico."]},
	2: {"caller": "Marta", "lines": ["De novo? Eu já pedi para você não se meter com o elevador."]},
}
const FALSE_ALARM := {"caller": "Godofredo", "lines": [
	"Quem apertou o alarme? O elevador estava normal.",
	"Isso custa dinheiro. Fica registrado."]}
## Dia 3: a Marta fala pelo alto-falante sempre que o alarme é apertado (e o jogador leva advertência).
const DAY3_ALARM_SPEAKER := "Marta (alto-falante)"
const DAY3_ALARM := [
	"Eu falei para não apertar.",
	"Solta esse botão.",
	"Por que você insiste? Eu pedi com educação.",
]

## Comentário da Marta na próxima vez que ela vem ao balcão, se alguém sumiu no elevador.
const MARTA_AFTER_TAKEN := {
	1: ["Alguém ficou preso no elevador? Que coisa. Deve ter saído no subsolo e subido de escada."],
	2: ["Mais um desceu sozinho. Eu já disse para você não se preocupar com isso.",
		"O elevador está com pressa hoje, né? Deixa ele."],
	3: ["Lá embaixo está ficando cheio.", "Eles não estão perdidos. Estão comigo.", "Mais um. Obrigada."],
}

## Demissão (3 advertências): a Marta "resolve" e o dia recomeça.
const FIRED := {
	1: ["O Godofredo queria te mandar embora. Eu conversei com ele e ficou tudo bem.", "Vamos de novo, do começo do dia."],
	2: ["O Godofredo queria te mandar embora. De novo eu precisei falar com ele.", "Você me deve essa. Recomeça."],
	3: ["Eu pedi para não apertar. Eu pedi com educação.", "Começa de novo."],
}

## Nota da Marta no relatório do turno.
const REPORT_NOTE := {
	1: "Marta: \"Ótimo primeiro dia. Até amanhã!\"",
	2: "Marta: \"Dia cheio, né? Amanhã vai ser mais calmo. Eu prometo.\"",
	3: "Marta: \"Você ficou até o fim. Quase ninguém fica.\"",
}

## Visitas transformadas em convidados do 6º andar (humor de escritório, nada sinistro).
const GUEST_LINES := [
	"Bom dia! Tenho reunião com o seu Godofredo. Ele mesmo marcou.",
	"Vim assinar um contrato com o diretor. Sexto andar, né?",
	"Sou da auditoria. O diretor pediu para eu subir assim que chegasse.",
	"Trouxe a apresentação para a diretoria. Se eu me atrasar, ele me demite de longe.",
	"Reunião no sexto com o chefão. Dessa vez eu até trouxe gravata.",
	"Documentos para o diretor, em mãos. Ele foi bem claro. Sexto andar.",
]
