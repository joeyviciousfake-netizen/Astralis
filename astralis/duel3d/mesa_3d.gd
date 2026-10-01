extends Node3D

## mesa_3d — CAMPO 3D OFICIAL do duelo (D23/D40, cena principal do projeto).
## Céu azul estilo GX, SEM MESA: nada de tampo, moldura, emblema ou vazio
## estrelado — só DESENHA o estado real
## (DuelManager/GameState + sistemas reais Summon/Battle/Position/Turn/
## Fusion) flutuando no céu azul com painéis de vidro azul. Zero regra
## aqui (R1): cada jogada chama o sistema real e redesenha.
## Controle 100% joypad (D19): só as 11 ações custom, sem mouse/teclado.
## Uso headless p/ validação: `-- --mesa3d-sair=5` sai sozinho após N segundos.
## Diagnóstico no console: `-- --debug` (doc 15 §15.6).
##
## Esta é a ÚNICA tela do duelo: a mesa 2D e a flag `--cenario3d` saíram (D54).

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
const PositionSystem := preload("res://duel/position_system.gd")
const FusionSystem := preload("res://duel/fusion_system.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")
const Faixa2D := preload("res://duel3d/faixa_2d.gd")
const Menus3D := preload("res://duel3d/menus_3d.gd")
const PainelCarta3D := preload("res://duel3d/painel_carta_3d.gd")
const Cursor3D := preload("res://duel3d/cursor_3d.gd")
const Campo3D := preload("res://duel3d/campo_3d.gd")
const Vista3D := preload("res://duel3d/vista_3d.gd")
const Carta3D := preload("res://duel3d/carta_3d.gd")

## Conversão desenho 2D->3D (só desenho): campo 2D centrado em x=1158.
## Composição ref nova (céu azul GX, SEM MESA): câmera FIXA atrás/acima do
## seu campo olhando o rival longe (profundidade); céu azul com nuvens e
## pilares de vidro ao fundo; 20 painéis de VIDRO AZUL flutuantes (5+5 por
## lado); carta virada = marrom com espiral; monstro em pé face-up; fases
## DP/SP/MP1/BP/MP2/EP metálicas no meio; mão em arco embaixo; painel 2D
## fixo à esquerda estilo carta (fundo bege, nome/tipo verdes); HUD 2D no
## topo (placa azul do seu LP esq / TURN centro / placa vermelha do rival
## dir + etiquetas Single). Zero regra aqui (R1).
const DIV := 150.0
const CENTRO_X := 1158.0
const CENTRO_Y := 540.0
const TOPO := 0.35
## ---- TRANSFORM DE APRESENTAÇÃO DO CAMPO (doc 15 §15.5) ----
## A ARENA (dado) continua mandando na COMPOSIÇÃO: qual slot fica onde em
## relação aos outros e o espelho do rival (D17/D18). O que é apresentação
## é só ESCALA (uniforme nos 2 eixos) + DESLOC (do conjunto), nunca uma
## posição nova por slot:
##   mundo_x = (arena_x - CENTRO_X) / DIV * ESCALA + DESLOC.x
##   mundo_z = (arena_y - CENTRO_Y) / DIV * ESCALA + DESLOC.z
## ESCALA/DESLOC medidos contra a REFERÊNCIA (doc 15 §15.3): com eles o
## campo ocupa x 29,3%..99,9% da tela (encosta na direita), as fileiras
## caem em 17/30/49/67% de cima p/ baixo e o vão do meio (onde entra a
## barra de fases da ref) fica em ~10% da altura.
const ESCALA_CAMPO := 1.23
const DESLOC_CAMPO := Vector2(0.0, -0.07)
## Câmera FIXA, sem órbita/balanço. Subir/afastar o FOV é
## alavanca de DESENHO autorizada (doc 15 §15.5): os valores abaixo são os
## que medem as fileiras da referência. A tríade que garante a perspectiva
## simétrica (doc 15 §15.4) continua: X = 0 (sem deslocamento), ALVO no
## centro e `frustum_offset` ZERO (abaixo).
const CAM_POS := Vector3(0, 16.8, 20.9)
const CAM_ALVO := Vector3(0, 0, 0.0)
const CAM_FOV := 20.0
## A LENTE NUNCA é deslocada (doc 15 §15.4): `frustum_offset` fica em 0 e a
## projeção fica SIMÉTRICA (mesma compressão à esquerda e à direita),
## idêntica à de quando o campo estava no meio da tela. O que joga o campo
## p/ a direita é a JANELA (SubViewport), não a lente. Deslocar a lente
## deformaria a imagem (estica um lado e comprime o outro = torta).
## O duelo segue o Forbidden Memories: sem DP/SP/MP1/BP/MP2/EP.

## ---- JANELA DO CAMPO (doc 15 §15.4 — só DESENHO, nada de regra) ----
## O mundo 3D inteiro (céu, pilares, campo, cartas, mão, cursor) é
## desenhado num SubViewport que ocupa SÓ a região do campo; o HUD 2D
## continua em tela cheia por cima (Control filho da cena, como sempre).
##   PAINEL_ESQ_PX = 29,3% da largura da tela: MEDIDA da referência
##   (doc 15 §15.3 — na imagem de 1024 px o painel esquerdo vai de 0 a
##   300 px, e 300/1024 = 29,3%; a referência põe o centro do campo em
##   ~63,5% e aqui ele cai em 29,3% + 70,7%/2 = 64,6%).
## AJUSTE FINO DO ENQUADRAMENTO É AQUI (PAINEL_ESQ_PX). Se ficar torto,
## mexe-se neste retângulo — NUNCA na câmera (doc 15 §15.4).
const TELA_L := 1920
const TELA_A := 1080
const PAINEL_ESQ_PX := 562                       # 29,3% de 1920
const JANELA_CAMPO_X := PAINEL_ESQ_PX            # começa depois do painel 2D
const JANELA_CAMPO_L := TELA_L - JANELA_CAMPO_X  # 1358 px (70,7% da tela)
const JANELA_CAMPO_A := TELA_A                   # altura toda
## Cor de fundo da faixa que sobrou à esquerda (na ref, o painel 2D é
## escuro). Só apresentação, zero regra.
const FUNDO_3D := Color(0.04, 0.05, 0.10)
## Os 17 assets da CARTA que o JOGO tem EMBUTIDOS (doc 15 §15.2: moram em
## `astralis/assets/`, cópia byte-idêntica da do Studio, com teste de
## compatibilidade travando as duas — astralis/testing/test_assets_embutidos).
## O jogo tenta o PROJETO primeiro e cai no embutido — nunca o contrário.
const ASSETS_EMBUTIDOS := [
	"assets/frames/normal.jpg", "assets/frames/effect.jpg", "assets/frames/spell.jpg",
	"assets/frames/trap.jpg", "assets/frames/ritual.jpg", "assets/frames/fusion.jpg",
	"assets/attributes/earth.png", "assets/attributes/water.png", "assets/attributes/fire.png",
	"assets/attributes/wind.png", "assets/attributes/light.png", "assets/attributes/dark.png",
	"assets/attributes/divine.png", "assets/attributes/spell.png", "assets/attributes/trap.png",
	"assets/estrelas/estrela.png", "assets/backs/verso_padrao.png",
]

const LARG_CARTA := 1.0
## Lado do ladrilho de CIMA (só o ladrilho, não o cursor): um pouco maior
## que a carta DEITADA (ALT_CARTA = 1,4576 larguras), para a carta de DEF
## caber dentro da peça em vez de encostar/cortar na borda.
const PECA_PROF_CARTAS := 1.58
## D49: o vão vertical monstro->magia NÃO é corrigido aqui, por NENHUM motivo.
## Não existe desvio escondido no código: o vão vem inteiro do
## `arena_starter.json` (y 695/958 no jogador, 305/42 no rival = 263 nos dois
## lados), o mesmo número do passo horizontal. Se algum dia o vão ficar feio, o
## dado é que se muda — não um número chutado aqui embaixo.
## ATENÇÃO (o que a tela NÃO pode prometer): o vão é igual em MUNDO, mas a
## perspectiva faz o mesmo intervalo aparecer com 276 px na fileira da frente,
## 257 px no meio e 220 px no fundo. Isso é projeção, não erro do dado (doc 15
## §15.4 proíbe mexer na lente), então NÃO use foto para julgar este número.
## COLUNAS do campo (5 slots por fileira, D15/D17 — o mesmo 5 do
## `GameState` e do `arena.schema.json`). Vive aqui porque a perspectiva
## (doc 16) espelha a COLUNA: coluna 0 <-> coluna 4, e o meio fica.
const COLUNAS_CAMPO := 5
## D47: TEMPO DA VOLTA DA MESA, em segundos (180°). MUDE AQUI À VONTADE e
## rode o jogo: é o único número que manda no ritmo do giro. 1,0 s é o que o
## usuário achou bom na primeira conta (nem curto demais para virar um corte,
## nem longo demais para atrasar o duelo). A curva é a mesma dos outros
## movimentos da tela (TRANS_CUBIC/EASE_IN_OUT) e não pula: passar a vez
## sempre gira a mesa inteira.
const VOLTA_DURACAO := 1.0

## Chão de desenho do campo: o plano da FACE DE CIMA do ladrilho (a caixa de
## vidro tem 0,05 de espessura assentada em TOPO - 0,03, ou seja o topo dela
## fica em TOPO - 0,005). É o único dono desse número no arquivo: as bordas
## de tela das fileiras (`_borda_da_fileira_px`) e a faixa 2D medem a partir
## daqui, então "a linha dos slots" é UM número, não três.
const TOPO_PISO := TOPO - 0.005
## Cores de identidade da tela (D45b): azul = voce, vermelho = rival, e o
## PRETO (borda preta que nao e preta escura, dentro um preto mais claro) nos
## DOIS cemiterios. Cada conjunto e BORDA escura + INTERIOR mais claro, e o
## MESMO conjunto vale no bloco do nome (topo) e no do LP daquele lado.
## Dono: a mesa. A faixa do meio e os retratos recebem daqui.
const COR_AZUL_BORDA := Color(0.07, 0.17, 0.40, 0.98)
const COR_AZUL_FUNDO := Color(0.16, 0.40, 0.76, 0.96)
const COR_VERM_BORDA := Color(0.40, 0.06, 0.09, 0.98)
const COR_VERM_FUNDO := Color(0.74, 0.17, 0.20, 0.96)
const COR_PRETO_BORDA := Color(0.07, 0.07, 0.08, 0.98)
const COR_PRETO_FUNDO := Color(0.21, 0.21, 0.25, 0.96)

## ---- HUD 2D (doc 15 §15.3 — TUDO medido na referência, em px do canvas
## 1920x1080; a referência é 1024x583 e o §15.3 traz os %) ----------------
## PAINEL ESQUERDO: a faixa inteira x 0..562, altura toda.
const PAINEL_ESQ_L := 562
const PAINEL_CARTA_L := 364
## BARRA SUPERIOR metálica: x 562..1920 (29,3%..100%), y 0..92 (8,5% da alt).
const BARRA_TOPO_X0 := 562
const BARRA_TOPO_Y1 := 92
const PLACA_VOCE_X0 := 576
const PLACA_VOCE_X1 := 960
const CAIXA_TURNO_X0 := 1190
const CAIXA_TURNO_X1 := 1460
const PLACA_RIVAL_X0 := 1458
const PLACA_RIVAL_X1 := 1920
## BARRA DE FASES: no meio do campo, y 497..551 (46%..51% da altura na ref).
const BARRA_FASES_Y0 := 497
const BARRA_FASES_Y1 := 551
const BARRA_FASES_L := 152      # largura de cada caixinha
const BARRA_FASES_GAP := 8
## RETRATOS: moldura no estilo da ref. O rival fica no canto superior
## DIREITO da faixa do campo; o jogador, no canto superior ESQUERDO da
## mesma faixa (simétrico ao rival), longe do painel da carta.
## D45 (item 1): "a imagem dos duelistas bem pra cima, com o mesmo espaço
## entre as laterais e a parte de cima". A margem é UM número só, usado nos
## TRÊS lugares (esquerda, direita e topo) da janela do campo — por isso os
## dois retratos ficam a MESMA distância da borda lateral e da borda de cima
## (14 px), e não "quase no canto" como antes (y 96, colado na fileira do
## rival).
const RETRATO_MARGEM := 14
const RETRATO_L := 136
const RETRATO_VOCE_X := PAINEL_ESQ_PX + RETRATO_MARGEM              # 576
const RETRATO_RIVAL_X := TELA_L - RETRATO_MARGEM - RETRATO_L        # 1770
const RETRATO_VOCE_Y := RETRATO_MARGEM                             # 14
const RETRATO_RIVAL_Y := RETRATO_MARGEM                            # 14
## D45 (item 1): a placa de NOME do duelista fica AO LADO do retrato (para
## dentro, para os dois lados ficarem espelhados), nunca invade o painel
## esquerdo (que termina em x 562) e tem o TOPO NA MESMA LINHA do topo da
## foto.
const RETRATO_NOME_L := 300
const RETRATO_NOME_A := 44
const RETRATO_NOME_VOCE_X := RETRATO_VOCE_X + RETRATO_L + 10        # 722
const RETRATO_NOME_RIVAL_X := RETRATO_RIVAL_X - 10 - RETRATO_NOME_L # 1460
## D45 (item 7): NÃO existe barra "START ? Help" na tela. A ação continua
## existindo no CONTROLE (D19, o botão START do joypad), que é o que passa o
## turno — o que não existe é o texto, que era informação repetida.
## Cores da ref (amarelo do valor/nome, verde do tipo, laranja da barra).
const COR_PAINEL := Color(0.106, 0.137, 0.251, 1.0)   # #1b2340 azul-marinho
const COR_PAINEL_BORDA := Color(0.30, 0.38, 0.62, 1.0)
const COR_METAL_TOPO := Color(0.46, 0.62, 0.96, 1.0)
const COR_METAL_BASE := Color(0.10, 0.17, 0.44, 1.0)
const COR_FASE_ATIVA := Color(1.0, 0.83, 0.00, 1.0)
const COR_FASE_TXT := Color(0.85, 0.90, 1.00, 1.0)
const COR_FOCO_AZUL := Color(0.35, 0.70, 1.0, 1.0)
## Inclinação da mão em graus no eixo X (LIVRE): mude à vontade, nada
## recalcula pela câmera. Rival usa 180 + este.
## Fase 2 (doc 15 §15.3): a mão é PEQUENA, no rodapé, DE PÉ (quase a prumo,
## não deitada) e cortada pela borda de baixo. -35° é o que deixa a carta
## "de pé" E legível com a câmera fixa de cima (a -12° a carta aparece
## achatada em 57% da altura e não dá pra ler).
const TILT_MAO_LIVRE := -35.0
## Arco da MÃO (só desenho). Passo = distância entre cartas; Z = profundidade.
## D52: estes números são dos **LUGARES** da mão, não dos lados: `PERTO` é o
## lugar de BAIXO (quem está jogando, cartas grandes, passo aberto) e `LONGE` é
## o de CIMA (a outra mão, de costas, pequena, colada). O nome diz o que é:
## lugar, não jogador.
##
## D45 (itens 4, 5 e 6): quem decide a ALTURA (Y) de cada lugar é a CÂMERA REAL
## (mesma matemática de `_x_centro_da_mao`, que já centraliza o X no centro do
## campo), porque o pedido é ALTURA DE LINHA, não número:
##   - o lugar PERTO fica COLADO na linha de baixo da fileira de magia de quem
##     está jogando (item 5);
##   - o lugar LONGE fica CENTRADO entre o topo da tela e a linha de cima dos
##     slots de magia do outro (item 4).
## `_y_da_mao` resolve os dois Y por bisseção e memoriza. O Y que está no
## Vector2 abaixo é só o FALLBACK para quando não há câmera (o desenho não
## quebra, ele só sai no lugar antigo).
const LUGAR_PERTO_YZ := Vector2(7.6, 12.7)   # Vector2(y fallback, z): lugar de baixo
## Lugar LONGE (atrás de toda a pegada do campo). Medido: a fileira de magia do
## rival (p1_s) fica em z = -4,37 e o ladrilho dela avança até z = -5,34;
## com a mão mais perto disso ela ficava DENTRO desse ladrilho e o vidro
## escuro dele (alpha 0,72) cobria a metade de baixo das cartas viradas (D3).
## O lugar é jogado para trás de toda a pegada do campo (z = -6,45).
const LUGAR_LONGE_YZ := Vector2(-0.35, -6.45)
## D45 (item 5): folga entre o topo da carta do lugar de baixo e a linha de
## baixo da fileira de magia de quem joga. 5 px = "bem próxima" sem encostar.
const LUGAR_PERTO_FOLGA_PX := 5.0
## D45 (item 6): "minhas cartas estão muito juntas, tem uma passando por
## dentro das outras" — a carta tem 1,0 de largura, então PASSO MAIOR que 1,0
## é o que abre o vão. 1,08 = 8% de carta de espaço entre elas (medido: 21 px
## de vão com a mão na profundidade de baixo). Com a mão lotando (6+ cartas) o
## passo cede para o arco caber na janela do campo (teto de largura), senão a
## carta da ponta sairia da tela.
const LUGAR_PERTO_PASSO := 1.08
const LUGAR_PERTO_PASSO_MIN := 0.55
const LUGAR_PERTO_LARG_ARCO := 4.32
const LUGAR_LONGE_PASSO := 0.86
## X de mundo do centro do arco SEM câmera (fallback: só não quebra o desenho).
const LUGAR_PERTO_X_SEM_CAM := 0.3
const LUGAR_LONGE_X_SEM_CAM := -2.8
## Proporção exata da carta real 59x86mm (0,6860). Tudo que é carta, slot
## ou pilha usa essa proporção — nenhuma carta fica de tamanho diferente.
## Janela de arte DENTRO da moldura real da carta (832x1248), em fracao: a arte
## preenche a janela sem sobra. DONO: a mesa, porque a carta 3D e o painel
## esquerdo usam a mesma janela (uma so medida para as duas pecas).
## A janela de arte DENTRO da moldura (fracao do JPG real). A MESMA medida vale
## para a carta 3D e para o painel 2D do HUD, entao fica aqui: um dono so, e os
## dois assuntos recebem por parametro.
const JANELA_ART := Vector4(0.10, 0.165, 0.90, 0.615)
const ALT_CARTA := 86.0 / 59.0
## Finura real de carta (0,3mm numa carta 59mm = 0,005 da largura).
const GROSS_CARTA := 0.005

const FILEIRA_MAO := 0
const FILEIRA_MEU_M := 1
const FILEIRA_MEU_S := 2
const FILEIRA_RIVAL_M := 3
const FILEIRA_RIVAL_S := 4
const ORDEM_FILEIRAS := [0, 1, 2, 3, 4]
## Ordem visual de cima p/ baixo só com os 20 slots (igual ao 2D):
## magia rival -> monstro rival -> meu monstro -> minha magia.
const ORDEM_CAMPO_3D := [4, 3, 1, 2]
const PAD_REPETE := 0.25

## Fluxo fiel do turno (só controle de tela, regra nos sistemas reais).
## Espelha o fluxo oficial (FASE_MAO/SUB_*): carta ao centro -> face ->
## slot (vazio OU ocupado) -> menu da estrela -> desce em Ataque.
## Fusão: 2+ levantadas -> slot PRIMEIRO -> fila -> FINAL + estrela.
const FASE_MAO := 0
const FASE_CAMPO := 1
## Fases REAIS do motor (`GameState.phase`, turn_manager.gd): o duelo é
## Forbidden Memories e NÃO tem DP/SP/MP1/BP/MP2/EP (§15.1) — a barra de
## fases do HUD mostra estas 4 e nada inventado.
const FASES_REAIS := ["DRAW", "MAIN", "BATTLE", "END"]
const SUB_MAO_ESCOLHA := 0
const SUB_FACE := 1
const SUB_SLOT := 2
const SUB_ESTRELA := 3

var _duel = null
var _st = null
var _cartas: Dictionary = {}
var _base_dir := ""
var _artes_ok := 0

var _cam: Camera3D = null
## Janela onde o mundo 3D é desenhado (doc 15 §15.4): o SubViewport com a
## região do campo (dentro de Camada3D/JanelaCampo), com a câmera dentro.
var _vp: SubViewport = null
var _no_cartas: Node3D = null
## O turno do rival está sendo conduzido agora (trava de reentrada): sem isto
## duas chamadas simultâneas fariam o turno dele rodar em paralelo.
var _rival_rodando := false
var _flash_tela: ColorRect = null
var _deck_pos := [Vector3(4.9, 0.6, 1.6), Vector3(-4.9, 0.6, -2.2)]
## D46 (prova): em qual QUADRO a foto sai (90 = o de sempre) e em quantos
## segundos a vez passa sozinha. Zero = desligado. Ver `_ver_autoquit`.
var _foto_frame_alvo := 90
var _auto_passa_em := 0.0
var _auto_passa_espera := -1.0

## D44 (item 8): o topo ficou SÓ com foto + nome de cada duelista. Estas são
## as etiquetas de nome ao lado de cada retrato (dado real do duelista).
var _lbl_placa_nome_voce: Label = null
var _lbl_placa_nome_rival: Label = null
var _lbl_mao_rival: Label = null
var _lbl_fase: Label = null
var _lbl_log: Label = null
var _lbl_dica: Label = null
var _lbl_slot: Label = null
var _lbl_fila: Label = null
## D45 (item 2): a FAIXA DO MEIO é 2D e vive em `faixa_2d.gd` (filha do
## HUD), com o VALOR sempre do GameState real.
var _retrato_rival_foto: TextureRect = null
var _retrato_rival_silhueta: Label = null
var _retrato_voce_foto: TextureRect = null
var _retrato_voce_silhueta: Label = null
var _lbl_retrato_rival_nome: Label = null
var _lbl_retrato_voce_nome: Label = null
## Cache de textura da sessao (a moldura/orbe/estrela se repetem; o que for
## lido do disco e guardado aqui, entao a tela nao relê a imagem a cada uso).
var _cache_tex: Dictionary = {}

## Identidade real do duelo (só leitura do dado): nomes + retratos dos
## duelistas vindos de duel_setup.duelist1/2 + duelists (nome/portrait).
## Sem foto no dado = silhueta com a inicial do nome (igual à ref).
var _nome_voce := "VOCÊ"
var _nome_rival := "RIVAL"
var _retrato_voce := ""
var _retrato_rival := ""
var _log: Array = []
var _fusions_data: Dictionary = {"schema_version": 1, "recipes": [], "rules": []}
var _arena_data: Dictionary = {}
var _arena_layout: Dictionary = {}

## Estado do fluxo fiel (só controle, sem regra nova).
var _fase_jogador := FASE_MAO
var _sub_mao := SUB_MAO_ESCOLHA
var _mao_idx := -1
var _face_baixo := false
var _slot_alvo := -1
var _estrela_ops: Array = []
var _levantadas: Array = []
var _combinando := false
var _fusao_ordem: Array = []
var _fusao_final: Dictionary = {}
var _fusao_descartes: Array = []
var _fusao_passos: Array = []
var _fusao_animando := false

var _fileira := FILEIRA_MAO
var _col := 0
var _sel_atk := -1
var _pad_dir := Vector2i.ZERO
var _pad_tempo := 0.0
var _foco := Vector3.ZERO
## X de mundo do centro do arco da mão (x = p0, y = p1), CALCULADO da câmera
## real e memorizado (a câmera é fixa, então o cálculo acontece UMA vez).
var _x_centro_mao := Vector2.ZERO
## instance_id da câmera usada no cálculo acima (0 = ainda não calculou).
var _x_centro_mao_cam := 0
## Y de mundo de cada mão (x = p0, y = p1), CALCULADO da câmera real para a
## linha de tela pedida (D45, itens 4 e 5) e memorizado do mesmo jeito.
var _y_mao_cache := Vector2.ZERO
var _y_mao_cam := 0
var _pulso := 0.0
var _foto_destino := ""
var _foto_frames := -1


func _ready() -> void:
	_construir_janela_campo()
	_construir_ambiente()
	_construir_hud()
	_menus = Menus3D.new()
	add_child(_menus)
	# Duelo REAL (motor de verdade): ProjectLoader + DuelManager.
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	_base_dir = str(data.get("base_dir", ""))
	_carregar_identidade(data)
	_montar_retratos()
	_duel = DuelManagerScript.new_duel(data.get("duel_setup", {}), data.get("decks", {}), data.get("cards", {}))
	_st = _duel.get_state()
	_cartas = data.get("cards", {})
	# D50: A MESA É O DADO, E HÁ SÓ UM. Não existe override por projeto nem grade
	# no código: a posição de cada slot vem do arquivo da arena oficial. O
	# `arena_id` do setup é lido só para dizer no log que ele foi ignorado (o
	# dado FM traz `arena_starter`, que é essa mesma).
	var arena_id := str((data.get("duel_setup", {}) as Dictionary).get("arena_id", "arena_starter"))
	_arena_data = BoardLayoutScript.load_arena_data(BoardLayoutScript.project_arena_path(arena_id))
	_arena_layout = (_arena_data.get("slots", {}) as Dictionary)
	var _faltando: Array = BoardLayoutScript.valida_arena_oficial(_arena_layout)
	if not _faltando.is_empty():
		# Sem os 20 slots não dá para desenhar o campo, e D50 proíbe inventar
		# posição: a mesa fica sem os painéis e o log explica por quê.
		_avisar_arena()
		print("[MESA3D] ERRO: a arena oficial não tem os 20 slots, então o campo NÃO foi desenhado (D50: uma arena só, e ela é o dado).")
		return
	_avisar_arena()
	# D51: com a arena lida, mede o plano de simetria do campo (o Z em que os
	# dois lados são espelho). A câmera do jogador não muda; a do rival vai
	# para o espelho exato dela, e é isso que deixa a faixa do meio — que é 2D
	# e fica parada — cair no vão das fileiras nas DUAS vistas.
	_vista.medir_plano_de_simetria()
	_vista.aplicar()
	# Campo DEPOIS da arena (os painéis nascem no XZ real do dado).
	_construir_campo()
	# D52: resolve a altura e o X dos DOIS lugares da mão AGORA, com a tela na
	# vista do jogador, antes de qualquer carta ser desenhada. Sem isto o cache
	# seria resolvido na primeira mão que aparecesse — e se o rival começar o
	# duelo (D42, sorteado pelo motor) isso viria com a câmera do lado errado.
	_aquecer_a_mao()
	# D45 (item 2): a faixa do meio é 2D e vive no HUD, no vão entre as duas
	# fileiras de monstro (que ela mede do dado + da câmera, não chuta).
	_construir_faixa()
	if _quer_calib_visual():
		_calib_visual(get_node_or_null(NodePath("HUD")) as Control)
	_fusions_data = _fusoes_do_data(data)
	_fala("Mesa 3D: duelo real carregado.")
	_redesenhar(false)
	_atualizar_hud()
	_iniciar_turno_do_duelo()
	if int(_st.current_player) == 0:
		_redesenhar(false)
		_atualizar_hud()
	_diag("Pronta: mão p0=%d p1=%d, artes carregadas=%d, assets embutidos=%d/17." % [
		((_st.players[0] as Dictionary)["hand"] as Array).size(),
		((_st.players[1] as Dictionary)["hand"] as Array).size(), _artes_ok,
		_conta_assets_embutidos()])
	if _cam != null:
		_diag("Cam: pos=%s fov=%s alvo=%s." % [str(_cam.global_position), str(_cam.fov), str(CAM_ALVO)])
		var px := _cam.unproject_position(_pos_slot(0, "monstro", 2))
		_diag("Slot p0_m2 na tela: janela=%s tela_x=%.1f." % [str(px), JANELA_CAMPO_X + px.x])
		_calibrar_mao()
	_ver_autoquit()


## Log de boot da mesa: uma linha por fato (arena, fusões, duelo) e o resto do
## diagnóstico só com `--debug`. As linhas do boot são contrato do
## `test_project_arg`, que roda o jogo de verdade e lê o que ele imprimiu.
func _avisar_arena() -> void:
	if _arena_layout.is_empty():
		print("[MESA3D] ERRO: a arena oficial não carregou — o campo NÃO foi desenhado (D50: uma arena só, e ela é o dado).")
	else:
		var h0: Dictionary = BoardLayoutScript.get_hand(_arena_data, 0)
		var h1: Dictionary = BoardLayoutScript.get_hand(_arena_data, 1)
		print("[MESA3D] Arena carregada: %d slots + mão p0(%d,%d,%d) p1(%d,%d,%d)." % [_arena_layout.size(), int(h0["x"]), int(h0["y"]), int(h0["step"]), int(h1["x"]), int(h1["y"]), int(h1["step"])])


## Diagnóstico: só sai com `--debug` (medidas, câmera, calibração, fila de
## fusão, foto). Sem ela o jogo só imprime o log de boot.
## A faixa do meio (D45): o no e o arquivo `faixa_2d.gd`.
var _faixa: PanelContainer = null
## Os menus sobre a cena (carta do centro + popup da estrela/alvo): o no e o
## arquivo `menus_3d.gd`.
var _menus: CanvasLayer = null
## O painel esquerdo com a carta focada: o no e o arquivo `painel_carta_3d.gd`.
var _painel: Control = null
## O cursor de foco (moldura azul + mao branca): o no e o arquivo `cursor_3d.gd`.
var _cursor: Node3D = null
## O campo de vidro (os 20 ladrilhos): o no e o arquivo `campo_3d.gd`.
var _campo: Node3D = null
## A vista e a volta (a camera no pivo): o no e o arquivo `vista_3d.gd`.
var _vista: Vista3D = null
## A fabrica das cartas 3D (o desenho da carta): `carta_3d.gd`. Carta tem
## varias na cena, entao ali mora a fabrica e aqui o botao que a chama.
var _fabrica_carta: Carta3D = null
var _debug := _quer_debug()


## A flag `--debug`, nas duas formas de escrever (o resto do jogo lê assim).
func _quer_debug() -> bool:
	for s in OS.get_cmdline_user_args():
		if str(s) == "--debug" or str(s).begins_with("--debug="):
			return true
	return false


## Uma linha de diagnóstico, só com `--debug`. O que o boot imprime SEM a
## flag é contrato do `test_project_arg` e não passa por aqui.
func _diag(texto: String) -> void:
	if _debug:
		print("[MESA3D] " + texto)


## ---------- QUEM JOGA PRIMEIRO (bug do "Aguarde o rival") ----------
##
## QUEM COMEÇA É DADO DO MOTOR (R3): a tela não sorteia nem fixa nada. O
## `GameState.current_player` já saiu do sorteio do `DuelManager`
## (first_p1 / first_p2 / random) e é o único que esta função lê.
##
## O QUE IMPORTA: a tela NÃO pode assumir que o primeiro é o jogador. Todas as
## travas do jogador caem em `current_player != 0`, então sem isto, quando o
## motor diz que o rival começa, NINGUÉM conduz o turno dele e o duelo fica
## parado para sempre em "Aguarde o rival." (o START nunca abre mão por si, e a
## IA só era chamada quando o jogador passava o turno).
##
## A CORREÇÃO é de ORQUESTRAÇÃO DA TELA (R1), não de regra: se a vez é do
## rival, a tela conduz o turno dele pelo MESMO caminho real da IA que já
## existia (`_rival_auto`: DuelManager/TurnManager + SummonSystem +
## BattleSystem) e só então abre o fluxo normal da fase da mão para você.
func _iniciar_turno_do_duelo() -> void:
	# Estado neutro do fluxo do jogador (vale para os dois caminhos).
	_fileira = FILEIRA_MAO
	_col = 0
	_sel_atk = -1
	_fase_jogador = FASE_MAO
	_sub_mao = SUB_MAO_ESCOLHA
	_mao_idx = -1
	_face_baixo = false
	_slot_alvo = -1
	if bool(_st.over):
		_fala("Duelo já acabou.")
		return
	if int(_st.current_player) != 0:
		# O RIVAL COMEÇOU (o motor sorteou ele). A tela conduz o turno dele
		# e devolve a vez — nada de esperar o jogador apertar START, porque
		# o START é dele e ninguém ia apertar.
		_fala("O rival começou o duelo. Ele vai comprar e jogar o turno dele.")
		_rival_auto()
		return
	# A vez é sua: DRAW -> MAIN pelo motor (mão 5/5 sem carta extra, D26).
	_duel.advance_phase()
	_fala("Duelo começou! Sua vez.")


func _ver_autoquit() -> void:
	# Só p/ validação headless (`-- --mesa3d-sair=5`). Sem o argumento, nada muda.
	# Foto DEV (`-- --mesa3d-foto=<caminho>`): salva o viewport e sai.
	# Só p/ conferir visual sem abrir o editor (some no final).
	#
	# D46 — as duas ferramentas que a troca de perspectiva precisou (ela só
	# aparece quando a VEZ PASSA, e a vez do jogador espera o START, que
	# ninguém aperta numa prova automática):
	#   `--mesa3d-foto-frame=N`  em qual QUADRO a foto sai (padrão 90, o de
	#                           sempre: sem a flag, nada muda);
	#   `--mesa3d-auto-passa=s`  passa a vez sozinho `s` segundos depois de a
	#                           tela ficar pronta, pelo MESMO caminho do START.
	# As duas são PROVA (doc 16 §16.6, etapa 2), zero regra: nenhum estado do
	# duelo delas vira produto, e sem a flag o jogo é exatamente o de sempre.
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--mesa3d-foto="):
			_foto_destino = s.trim_prefix("--mesa3d-foto=").strip_edges()
			_foto_frames = 0
		elif s.begins_with("--mesa3d-foto-frame="):
			_foto_frame_alvo = maxi(int(s.trim_prefix("--mesa3d-foto-frame=")), 1)
		elif s.begins_with("--mesa3d-auto-passa="):
			_auto_passa_em = maxf(float(s.trim_prefix("--mesa3d-auto-passa=")), 0.0)
			# 0 = a contagem começa agora (o `_process` só conta se for >= 0).
			_auto_passa_espera = 0.0
		if s.begins_with("--mesa3d-sair="):
			var n := float(s.trim_prefix("--mesa3d-sair="))
			if n > 0.0:
				await get_tree().create_timer(n).timeout
				_diag("Autoquit de validação após %s s." % str(n))
				get_tree().quit()


func _sem_render() -> bool:
	if not is_inside_tree():
		return true
	return DisplayServer.get_name() == "headless"


## ---------- CALIBRAÇÃO VISUAL (ferramenta de desenho, zero regra) ----------
## Pedido do D45 (item 2): um quadrado grande do tamanho de toda a mesa, com o
## topo na mesma altura dos slots do campo, para dar de ver o que está afundando.
## Então isto é um QUADRADO VERMELHO (semi-transparente) que cobre a mesa
## inteira a partir da LINHA DOS SLOTS: a base de tudo que assenta na mesa
## tem que ficar ACIMA da linha de cima do quadrado; o que entrar dentro do
## quadrado está afundado. As linhas das outras fileiras também aparecem,
## para bater o olho nelas de uma vez.
## Só DESENHO e só ligado por `--mesa3d-calib=1` (fora disso a tela fica
## limpa). Para ver: rode o jogo com a flag e tire a foto de sempre
## (`--mesa3d-foto`), que o quadrado aparece na imagem.
const CALIB_ALTURA := 3
const CALIB_COR_QUAD := Color(0.90, 0.10, 0.12, 0.20)
const CALIB_COR_LINHA := Color(1.0, 0.25, 0.15, 0.95)
const CALIB_COR_LINHA_FINA := Color(1.0, 0.85, 0.20, 0.75)


func _quer_calib_visual() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := str(a).strip_edges()
		if s == "--mesa3d-calib" or s == "--mesa3d-calib=1" or s == "--mesa3d-calib=true":
			return true
		if s.begins_with("--mesa3d-calib="):
			return s.trim_prefix("--mesa3d-calib=").strip_edges() != "0"
	return false


## Monta o quadrado de calibração dentro do HUD (por cima de tudo). Cada linha
## é a BORDA REAL de uma fileira, lida do dado + da câmera (`_borda_da_fileira_px`),
## então o desenho dele é a medida, não um número chutado.
func _calib_visual(hud: Control) -> void:
	var x0 := float(PAINEL_ESQ_L)
	var larg := float(TELA_L) - x0
	# A linha de cima do quadrado é a LINHA DOS SLOTS: a borda de cima da
	# fileira de monstro do jogador, que é o chão da mesa onde o baralho, o
	# cemitério, o LP e o turno têm que APOIAR a base. O ladrilho é um plano
	# visto de lado (tem 2 bordas na tela); a de cima é a que faz a leitura
	# do "afundado", e a de baixo aparece na lista de linhas finas.
	var linha_slots := _borda_da_fileira_px(0, "monstro", false)
	var quad := ColorRect.new()
	quad.name = "CalibQuad"
	quad.color = CALIB_COR_QUAD
	quad.position = Vector2(x0, linha_slots)
	quad.size = Vector2(larg, float(TELA_A) - linha_slots)
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(quad)
	# Linha de cima do quadrado = a linha dos slots (a mais grossa, a que
	# manda): a base de deck/cemitério/LP/turno tem que ficar nela ou acima.
	_calib_linha(hud, "CalibLinhaSlots", linha_slots, CALIB_COR_LINHA, CALIB_ALTURA, x0, larg,
		"LINHA DOS SLOTS (%.0f px): tudo ABAIXO desta linha esta AFUNDADO na mesa" % linha_slots)
	# As outras bordas, finas, para medir tudo de uma vez.
	var pares := [
		["base do monstro seu ( ladrilho)", _borda_da_fileira_px(0, "monstro", true)],
		["base da magia rival", _borda_da_fileira_px(1, "magia", true)],
		["topo da magia rival", _borda_da_fileira_px(1, "magia", false)],
		["base do monstro rival", _borda_da_fileira_px(1, "monstro", true)],
		["topo do monstro rival", _borda_da_fileira_px(1, "monstro", false)],
		["base da magia sua", _borda_da_fileira_px(0, "magia", true)],
		["topo da mao (lugar de baixo)", _borda_da_fileira_px(0, "magia", true) + LUGAR_PERTO_FOLGA_PX],
	]
	var y := 0.0
	for par in pares:
		y = float(par[1])
		_calib_linha(hud, "CalibL%s" % str(par[0]).replace(" ", ""), y, CALIB_COR_LINHA_FINA, 1, x0, larg,
			"%s: %.0f px" % [str(par[0]), y])
	_diag("Calib visual: quadrado de y=%.0f ate o rodape (linha dos slots em %.0f px)." % [
		linha_slots, linha_slots])


func _calib_linha(hud: Control, nome: String, y: float, cor: Color, alt: int, x0: float, larg: float, txt: String) -> void:
	var l := ColorRect.new()
	l.name = nome
	l.color = cor
	l.position = Vector2(x0, y - float(alt) * 0.5)
	l.size = Vector2(larg, float(alt))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(l)
	var r := _rotulo_hud(nome + "Texto", txt, Vector2(x0 + 8.0, y - 20.0), 16, Color(1, 1, 1, 0.9))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(r)


# ---- JANELA DO CAMPO (doc 15 §15.4) ----

## Move a JANELA, não a câmera (doc 15 §15.4). O mundo 3D inteiro (céu,
## pilares, campo, cartas, mão, cursor 3D) nasce dentro de um SubViewport
## com o tamanho da região do campo, e esse viewport é mostrado por baixo
## do HUD 2D (camada -1). A câmera fica EXATAMENTE onde já estava, sem
## deslocamento de lente: por isso a perspectiva é idêntica à de quando o
## campo estava no meio da tela — só mudou a janela que mostra o mundo.
func _construir_janela_campo() -> void:
	_vp = SubViewport.new()
	_vp.name = "Viewport3D"
	_vp.size = Vector2(JANELA_CAMPO_L, JANELA_CAMPO_A)
	_vp.own_world_3d = true   # mundo 3D só desta janela (o céu não invade o HUD)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	# Camada -1 = ATRÁS do HUD 2D (que fica na camada 0, tela cheia).
	var camada := CanvasLayer.new()
	camada.name = "Camada3D"
	camada.layer = -1
	add_child(camada)
	# Fundo escuro da faixa do painel esquerdo (na ref, essa faixa é escura).
	var fundo := ColorRect.new()
	fundo.name = "Fundo3D"
	fundo.color = FUNDO_3D
	fundo.position = Vector2.ZERO
	fundo.size = Vector2(TELA_L, TELA_A)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fundo)
	var janela := SubViewportContainer.new()
	janela.name = "JanelaCampo"
	janela.position = Vector2(JANELA_CAMPO_X, 0.0)
	janela.size = Vector2(JANELA_CAMPO_L, JANELA_CAMPO_A)
	# Textura 1:1 (mesmo tamanho do retângulo): sem escala/rotação na imagem.
	janela.stretch = true
	janela.stretch_shrink = 1
	janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	janela.add_child(_vp)
	camada.add_child(janela)
	# O tamanho do viewport é o do container (stretch 1:1) = o retângulo medido.
	_diag("Janela do campo: x=%d..%d px (%.1f%%..100%% da tela), %dx%d, altura toda. Centro do campo = %.1f%% da tela. Camera SEM deslocamento." % [
		JANELA_CAMPO_X, TELA_L, float(JANELA_CAMPO_X) / float(TELA_L) * 100.0,
		JANELA_CAMPO_L, JANELA_CAMPO_A,
		(float(JANELA_CAMPO_X) + float(JANELA_CAMPO_L) * 0.5) / float(TELA_L) * 100.0])


# ---- AMBIENTE (WorldEnvironment + luzes + câmera) ----

func _construir_ambiente() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	# Céu azul claro (SEM MESA, SEM vazio estrelado): céu procedural azul com
	# GRADIENTE VERTICAL (mais escuro em cima, mais claro no horizonte — doc 15
	# §15.3) + neblina azul-clara p/ profundidade + sol branco. Sem imagem
	# externa.
	var ceu := Sky.new()
	var mat_ceu := ProceduralSkyMaterial.new()
	mat_ceu.sky_top_color = Color(0.10, 0.30, 0.72)
	mat_ceu.sky_horizon_color = Color(0.62, 0.82, 0.99)
	mat_ceu.sky_curve = 0.18
	mat_ceu.ground_bottom_color = Color(0.16, 0.30, 0.56)
	mat_ceu.ground_horizon_color = Color(0.46, 0.64, 0.88)
	mat_ceu.sun_angle_max = 30.0
	mat_ceu.energy_multiplier = 0.85
	ceu.sky_material = mat_ceu
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	# Luz PROFISSIONAL (ref tem volume, não clarão): ambient baixo e
	# neutro, sol modelando com sombra suave, Healing por zona.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.52, 0.58)
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	we.environment = env
	_vp.add_child(we)
	_construir_cenario_ceu()
	# SEM LUZES: tudo é UNSHADED, luz não faz nada — nem sol nem omnis. Só o
	# flash de tela (overlay 2D, ver HUD).
	#
	# A VOLTA DA MESA (D47) mora em `vista_3d.gd`, junto com a câmera e com o
	# número que manda nela.
	# A lente continua NO EIXO e o `frustum_offset` continua ZERO (doc 15
	# §15.4), então a perspectiva é simétrica e o campo tem a MESMA cara dos
	# dois lados, só espelhado.
	# A FABRICA DAS CARTAS 3D (`carta_3d.gd`): ela sabe desenhar a carta e
	# nao sabe onde a carta fica. As texturas/cores chegam por Callable porque
	# o painel 2D do HUD usa as MESMAS, e o dono delas continua sendo a mesa.
	_fabrica_carta = Carta3D.new()
	_fabrica_carta.larg_carta = LARG_CARTA
	_fabrica_carta.alt_carta = ALT_CARTA
	_fabrica_carta.gross_carta = GROSS_CARTA
	_fabrica_carta.janela_art = JANELA_ART
	_fabrica_carta.textura = Callable(self, "_tex_cache")
	_fabrica_carta.moldura_da_carta = Callable(self, "_moldura_da_carta")
	_fabrica_carta.cor_de_atributo = Callable(self, "_cor_atributo")
	_fabrica_carta.textura_arte = Callable(self, "_textura_arte")
	_fabrica_carta.mat = Callable(self, "_mat")
	# A VISTA E A VOLTA (a câmera pendurada no pivô da mesa, D47): o no e o
	# arquivo dele (`vista_3d.gd`). A câmera é filha DO PIVÔ, e quem gira é o
	# pivô - por isso o no inteiro é o próprio `PivoMesa`.
	_vista = Vista3D.new()
	_vista.cam_pos = CAM_POS
	_vista.cam_alvo = CAM_ALVO
	_vista.cam_fov = CAM_FOV
	_vista.volta_duracao = VOLTA_DURACAO
	_vista.pos_slot = Callable(self, "_pos_slot")
	_vista.sem_render = Callable(self, "_sem_render")
	_vista.ao_virar = Callable(self, "_aplicar_vista_da_mao_entao_hud")
	_vp.add_child(_vista)
	_cam = _vista.cam
	_diag("Ambiente: céu azul + neblina + pilares + câmera no PIVÔ da mesa (a volta da mesa, D47).")


## Cenário do céu da ref (só desenho): pilares altos de vidro azulado ao
## fundo + nuvens brancas suaves, sem textura externa. Sem mesa: o campo
## de vidro flutua aqui.
func _construir_cenario_ceu() -> void:
	var no := Node3D.new()
	no.name = "Ceu"
	_vp.add_child(no)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260707
	# Pilares de vidro ao longe (ref tem torres translúcidas no horizonte).
	var mat_vidro_fundo := StandardMaterial3D.new()
	mat_vidro_fundo.albedo_color = Color(0.35, 0.55, 0.85, 0.7)
	mat_vidro_fundo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_vidro_fundo.roughness = 0.15
	mat_vidro_fundo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(10):
		var mi := MeshInstance3D.new()
		mi.name = "Pilar%d" % i
		var malha := BoxMesh.new()
		malha.size = Vector3(1.2 + rng.randf() * 1.6, 9.0 + rng.randf() * 7.0, 1.2 + rng.randf() * 1.6)
		mi.mesh = malha
		var ang := -0.5 + float(i) * 0.35 + rng.randf() * 0.1
		mi.position = Vector3(sin(ang) * 22.0, 2.0, -14.0 - rng.randf() * 8.0)
		mi.material_override = mat_vidro_fundo
		no.add_child(mi)
	# Nuvens: discos brancos achatados e suaves no alto.
	var mat_nuvem := StandardMaterial3D.new()
	mat_nuvem.albedo_color = Color(1, 1, 1, 0.75)
	mat_nuvem.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_nuvem.roughness = 1.0
	mat_nuvem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(14):
		var mi := MeshInstance3D.new()
		mi.name = "Nuvem%d" % i
		var malha := SphereMesh.new()
		malha.radius = 1.6 + rng.randf() * 2.2
		malha.height = 0.9 + rng.randf() * 0.7
		mi.mesh = malha
		mi.position = Vector3(-20.0 + rng.randf() * 40.0, 9.0 + rng.randf() * 7.0, -10.0 - rng.randf() * 14.0)
		mi.material_override = mat_nuvem
		no.add_child(mi)


# ---- CAMPO (SEM MESA: 20 painéis escuros flutuantes + laterais + fases) ----

func _mat(cor: Color, emissao: float = 0.0, _metal: float = 0.0, alfa: float = 1.0) -> StandardMaterial3D:
	# Tudo UNSHADED (a cena não tem luz): cor pura estilo anime, zero cálculo
	# de luz — nada escurece, nada estoura.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	if alfa < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	return m


## Vidro azul da ref (só desenho): painéis e cartas flutuam como vidro
## claro com brilho suave. Sem textura externa.
func _vidro(cor: Color, alfa: float = 0.45, brilho: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	return m


func _caixa(nome: String, tamanho: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var malha := BoxMesh.new()
	malha.size = tamanho
	mi.mesh = malha
	mi.position = pos
	mi.material_override = material
	return mi


func _construir_campo() -> void:
	# O CAMPO DE VIDRO (os 20 paineis + o guarda-chuva das laterais): o no e
	# o arquivo dele (`campo_3d.gd`). Quem sabe ONDE o vidro fica e o arquivo;
	# quem sabe a medida do DADO (a posicao de cada slot em XZ) e a mesa.
	_campo = Campo3D.new()
	_campo.pos_slot = Callable(self, "_pos_slot")
	_campo.caixa = Callable(self, "_caixa")
	_campo.vidro = Callable(self, "_vidro")
	_campo.topo = TOPO
	_campo.escala_campo = ESCALA_CAMPO
	_campo.peca_prof_cartas = PECA_PROF_CARTAS
	_vp.add_child(_campo)
	_no_cartas = Node3D.new()
	_no_cartas.name = "Cartas"
	_vp.add_child(_no_cartas)
	# Cursor = retângulo AZUL BRILHANTE que ABRAÇA a coisa focada (doc 15
	# §15.3) + a MÃO BRANCA no centro dela. `_cursor_grupo` gira junto com a
	# focada, então a moldura é desenhada no PLANO DA CARTA (XY local) e
	# sai colada nela — na mão E no ladrilho. Antes a moldura era um
	# quadrado chapado no chão, maior que a carta, e aparecia só como dois
	# trilhos azuis nas laterais.
	_cursor = Cursor3D.new()
	_cursor.espessura_carta = GROSS_CARTA
	_cursor.cor = COR_FOCO_AZUL
	_cursor.mat = Callable(self, "_mat")
	_cursor.caixa = Callable(self, "_caixa")
	_cursor.position = Vector3(0, TOPO, _ponto_lateral(0.0, 0.0, 4.15).z)
	_vp.add_child(_cursor)
	_diag("Campo: 20 painéis + faixa do meio (7 itens) + Cursor3D.")


func _peca_prof_carta() -> float:
	return PECA_PROF_CARTAS * ESCALA_CAMPO


## X de mundo de um slot do DADO. Para quem anda pela POSIÇÃO visível (o
## vizinho pela direita/esquerda, a troca de fileira preservando a coluna da
## tela) e não pelo índice. É o X do `_pos_slot`: como a câmera é que muda de
## lado (D47), este número é o mesmo nos dois pontos de vista — e é por isso
## que o cursor "anda para a direita que se vê" nos dois lados sem nenhum
## código de espelho.
func _pos_slotx(lado: int, tipo: String, i: int) -> float:
	return _pos_slot(lado, tipo, i).x


func _pos_slot(lado: int, tipo: String, indice: int) -> Vector3:
	# Lê o XY oficial (BoardLayout real + layout da arena, com espelho do
	# rival) e converte p/ XZ. `lado`/`indice` são do DADO e valem sempre: quem
	# muda de ponto de vista é a câmera (D47), não o desenho. Marca E carta usam
	# este ponto: a carta fica EXATAMENTE na marca (mesmo XZ, só o Y muda).
	# A conversão passa pelo TRANSFORM DE APRESENTAÇÃO (escala uniforme +
	# deslocamento do conjunto): a composição e o espelho do DADO ficam
	# intactos, só o tamanho/posição do campo na tela mudam.
	var sid := BoardLayoutScript.slot_id(lado, tipo, indice)
	# D50: a posição vem SÓ do arquivo da arena oficial. Sem ela, o jogo já
	# avisou no boot e não desenhou o campo — aqui devolve o centro como
	# último recurso, para nunca multiplicar uma posição inventada.
	var p2 := BoardLayoutScript.get_pos(_arena_layout, sid)
	if p2 == BoardLayoutScript.NULO:
		push_warning("[MESA3D] Slot '%s' sem posição na arena oficial (D50: sem grade no código)." % sid)
		p2 = Vector2(BoardLayoutScript.NULO.x, BoardLayoutScript.NULO.y)
	# D49: a conversão é PURA e igual para os 4 tipos de slot (monstro/magia,
	# jogador/rival). O vão vertical monstro->magia é o do DADO (263 = o mesmo
	# do passo horizontal) e a fileira de monstro fica exatamente onde o dado
	# diz. Não existe nenhum desvio por tipo aqui: se a tela mostrar um vão
	# torto, a causa é a perspectiva da câmera (doc 15 §15.4), não este código.
	var z := (p2.y - CENTRO_Y) / DIV * ESCALA_CAMPO + DESLOC_CAMPO.y
	return Vector3(
		(p2.x - CENTRO_X) / DIV * ESCALA_CAMPO + DESLOC_CAMPO.x,
		TOPO, z)


## Ponto LATERAL ao campo (decks, cemitérios, fichas X/N): a mesma escala
## do campo, para essas peças ficarem AO LADO do vidro e nunca em cima dele
## quando o campo cresce. Só apresentação.
func _ponto_lateral(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * ESCALA_CAMPO, y, z * ESCALA_CAMPO)


func _fusoes_do_data(data: Dictionary) -> Dictionary:
	# Só DADO, nunca regra (igual ao 2D): usa o que o DataLoader JÁ leu.
	var bruto = data.get("fusions", null)
	if not (bruto is Dictionary) or (bruto as Dictionary).is_empty():
		print("[MESA3D] Aviso: fusões não vieram no projeto (sem fusão).")
		return {"schema_version": 1, "recipes": [], "rules": []}
	var out: Dictionary = (bruto as Dictionary).duplicate()
	if not (out.get("recipes", []) is Array):
		out["recipes"] = []
	if not (out.get("rules", []) is Array):
		out["rules"] = []
	print("[MESA3D] Fusões carregadas: %d receitas + %d regras." % [(out["recipes"] as Array).size(), (out["rules"] as Array).size()])
	return out


# ---- CARTA 3D (caixa fina + frente com arte/nome/ATK + verso) ----

func _cor_atributo(attr: String) -> Color:
	match attr:
		"light":
			return Color(0.85, 0.78, 0.45)
		"dark":
			return Color(0.45, 0.30, 0.70)
		"fire":
			return Color(0.85, 0.35, 0.15)
		"water":
			return Color(0.20, 0.50, 0.90)
		"earth":
			return Color(0.55, 0.42, 0.25)
		"wind":
			return Color(0.45, 0.85, 0.70)
		"thunder":
			return Color(0.95, 0.85, 0.25)
	return Color(0.50, 0.50, 0.60)


## Textura do projeto com cache de sessão (moldura/orbe/estrela se
## repetem; lê do disco 1x). Sem nada no projeto = nulo (fallback de cor).
func _tex_cache(rel: String) -> Texture2D:
	var chave := rel.strip_edges().to_lower()
	if chave.is_empty():
		return null
	if _cache_tex.has(chave):
		return _cache_tex[chave] as Texture2D
	var tex := _textura_arquivo(chave)
	_cache_tex[chave] = tex
	return tex


func _textura_arquivo(rel: String) -> Texture2D:
	# Foto REAL do projeto (caminho do dado, relativo à base).
	# Inexistente (dívida conhecida: FM sem assets) = volta nulo.
	var arq := rel.strip_edges()
	if arq.is_empty():
		return null
	var tentativas: Array = []
	if not _base_dir.is_empty():
		tentativas.append(_base_dir.path_join(arq))
	tentativas.append(ProjectSettings.globalize_path("res://").path_join(arq))
	tentativas.append(ProjectSettings.globalize_path("res://").path_join("../schemas/examples").path_join(arq))
	for t in tentativas:
		if FileAccess.file_exists(str(t)):
			var img := Image.load_from_file(str(t))
			if img != null:
				return ImageTexture.create_from_image(img)
	return null


func _textura_arte(carta: Dictionary) -> Texture2D:
	# Tenta a arte REAL do projeto (caminho do dado, relativo à base).
	# Inexistente (dívida conhecida: FM sem assets) = volta nulo e usa cor.
	var tex := _textura_arquivo(str(carta.get("artwork", "")))
	if tex != null:
		_artes_ok += 1
	return tex


## Identidade real do duelo (só leitura do dado, sem regra): nomes e
## retratos vêm de duel_setup.duelist1/2 + duelists (name/portrait).
## Sem duelista no dado = "VOCÊ"/"RIVAL" + silhueta com a inicial.
func _carregar_identidade(data: Dictionary) -> void:
	_nome_voce = "VOCÊ"
	_nome_rival = "RIVAL"
	_retrato_voce = ""
	_retrato_rival = ""
	var setup: Dictionary = data.get("duel_setup", {})
	var duelists: Dictionary = data.get("duelists", {})
	for par in [[setup.get("duelist1", {}), 0], [setup.get("duelist2", {}), 1]]:
		var slot = par[0]
		var lado := int(par[1])
		if not (slot is Dictionary):
			continue
		var did := str((slot as Dictionary).get("duelist_id", ""))
		if did.is_empty() or not duelists.has(did):
			continue
		var duo := duelists[did] as Dictionary
		var nome := str(duo.get("name", "")).strip_edges()
		var retrato := str(duo.get("portrait", "")).strip_edges()
		if lado == 0:
			if not nome.is_empty():
				_nome_voce = nome
			_retrato_voce = retrato
		else:
			if not nome.is_empty():
				_nome_rival = nome
			_retrato_rival = retrato
	print("[MESA3D] Duelo: %s x %s." % [_nome_voce, _nome_rival])


## Preenche os 2 retratos do HUD: foto real do dado ou silhueta com a
## inicial do nome (moldura laranja, igual à ref). Só desenho.
func _montar_retratos() -> void:
	_montar_retrato(_retrato_voce_foto, _retrato_voce_silhueta, _retrato_voce, _nome_voce)
	_montar_retrato(_retrato_rival_foto, _retrato_rival_silhueta, _retrato_rival, _nome_rival)
	if _lbl_retrato_voce_nome != null:
		_lbl_retrato_voce_nome.text = _nome_voce
	if _lbl_retrato_rival_nome != null:
		_lbl_retrato_rival_nome.text = _nome_rival


func _montar_retrato(foto: TextureRect, silhueta: Label, caminho: String, nome: String) -> void:
	if foto == null or silhueta == null:
		return
	var tex := _textura_arquivo(caminho)
	if tex != null:
		foto.texture = tex
		foto.visible = true
		silhueta.visible = false
	else:
		foto.visible = false
		var inicial := "?"
		if not nome.strip_edges().is_empty():
			inicial = nome.strip_edges().substr(0, 1).to_upper()
		silhueta.text = inicial
		silhueta.visible = true


func _moldura_da_carta(dado: Dictionary) -> String:
	var t := str(dado.get("card_type", "monster"))
	if t == "spell" or t == "equip":
		return "assets/frames/spell.jpg"
	if t == "trap":
		return "assets/frames/trap.jpg"
	if t == "ritual":
		return "assets/frames/ritual.jpg"
	var tags := ""
	for g in (dado.get("tags", []) as Array):
		tags += " " + str(g)
	if tags.match("*fusao*") or tags.match("*fusão*") or tags.match("*fusion*"):
		return "assets/frames/fusion.jpg"
	if not (dado.get("effects", []) as Array).is_empty():
		return "assets/frames/effect.jpg"
	return "assets/frames/normal.jpg"


## Monta UMA carta 3D. Quem sabe MONTAR e a fabrica (`carta_3d.gd`): ela le
## o dado e imprime nome/ATK/DEF/estrelas, sem saber onde a carta vai ficar.
func _fazer_carta(dado: Dictionary, face_down: bool, em_defesa: bool) -> Node3D:
	return _fabrica_carta.montar(dado, face_down, em_defesa)


func _fantasia(inst: Dictionary) -> Dictionary:
	# O motor guarda instância enxuta; a roupa vem do dado real (igual ao 2D).
	var cid := str(inst.get("card_id", ""))
	if not cid.is_empty() and _cartas.has(cid):
		return _cartas[cid] as Dictionary
	return {"name": str(inst.get("nome", cid)), "monster_type": "beast",
		"attribute": "earth", "attack": int(inst.get("atk", 0)), "defense": int(inst.get("def", 0))}


# ---- DESENHO A PARTIR DO ESTADO REAL (só leitura, sem regra) ----

## D52: QUEM OCUPA O LUGAR DE BAIXO (o perto) na vista em que a tela está.
## É a mão de QUEM ESTÁ JOGANDO: 0 (você) na sua visão, 1 (o rival) na dele.
## Sai do mesmo número que manda a volta inteira (`_giro_campo`, pelos 90°,
## D47) — nada guardado em outro lugar, e o mesmo número que a tela 3D usa.
func _dono_do_lugar_perto() -> int:
	return 1 if _vista.invertida() else 0


## D52: A POSE DE UM LUGAR DA MÃO na vista em que a tela está. `perto` = o
## lugar de baixo (quem joga, cartas grandes, de frente na sua visão), longe =
## o de cima (a outra mão, pequena e de costas).
## Chave: `x` (centro do arco), `y`, `z`, `tilt` (graus no eixo X) e `verso`
## (a carta mostra o VERSO = tapada). É o DONO ÚNICO desses valores: quem
## posiciona e quem desenha leem daqui, para a carta nunca ter uma pose no
## lugar e outra no desenho.
##
## NA VISTA DO RIVAL o lugar é o ESPELHO do lugar da sua vista (D51 deixou as
## duas vistas espelhadas uma da outra): o Z espelha em torno do plano de
## simetria do campo e a inclinação espelha. O Y e o X NÃO mudam, e não é
## milagre: a câmera do rival é o espelho exato da sua, então o mesmo ponto de
## mundo aparece na MESMA linha de tela dos dois lados (por isso `_y_da_mao` e
## `_x_centro_da_mao`, resolvidos uma vez na sua visão, valem para as duas).
##
## A CARA: na vista do rival as DUAS mãos mostram o VERSO, e as duas ficam de
## pé (mesma inclinação). Não é gosto, é geometria: o verso de uma carta não é
## o espelho da frente dela, então uma carta vista por trás não pode ser a
## imagem espelhada de uma carta vista pela frente. A alternativa (virada de
## cabeça para baixo, como a mão do rival aparece na sua visão) mostraria a
## ARTE da carta do jogador em vez do verso — e o verso é o que o D52 exige.
func _pose_da_mao(perto: bool) -> Dictionary:
	var c := _x_centro_da_mao()
	var z := LUGAR_PERTO_YZ.y if perto else LUGAR_LONGE_YZ.y
	var tilt := TILT_MAO_LIVRE if perto else 180.0 + TILT_MAO_LIVRE
	var verso := not perto
	if _vista.invertida():
		z = 2.0 * _vista.z_simetria - z
		tilt = -TILT_MAO_LIVRE
		verso = true
	return {
		"x": c.x if perto else c.y,
		"y": _y_da_mao(perto),
		"z": z,
		"tilt": tilt,
		"verso": verso,
	}


func _pos_mao_arco(i: int, n: int, lado: int) -> Vector3:
	# Mão em arco SIMÉTRICO (t=0 no meio: 1ª e última equidistantes do centro),
	# CENTRALIZADO NA TELA e na ALTURA DE LINHA do D45 — o X e o Y saem da
	# CÂMERA REAL, porque chutados "no olho" a mão saía torta e altura de linha
	# não é número (D45, itens 4 e 5).
	# D52: `lado` é o DONO da carta no DADO (0 = você, 1 = rival) e quem decide
	# o LUGAR é a vista (quem joga fica embaixo). Na sua vista os dois coincidem,
	# que é por isso que a vista do jogador não muda um milímetro.
	# D45 (item 8): a ordem do arco do lugar LONGE é ESPELHADA. Ele joga do
	# outro lado da mesa, então a 5ª carta DA MÃO DELE é a que aparece na
	# ESQUERDA da tela. A compra entra sempre na última posição do dado (o
	# `TurnManager` compra pro fim), então: você vê a comprada na DIREITA
	# (5ª posição sua) e o rival vê a dele na ESQUERDA (5ª posição dele).
	var t := float(i) - float(maxi(n - 1, 0)) / 2.0
	var perto := lado == _dono_do_lugar_perto()
	var pose := _pose_da_mao(perto)
	var passo := _passo_mao(n, perto)
	# D52: o SENTIDO do arco é o da VISTA, não o do lugar. A câmera do rival
	# espelha o X do mundo (por isso o índice 0 do dado cairia na DIREITA da
	# tela dele), e quem joga tem que ver a PRÓPRIA mão na ordem normal nas DUAS
	# vistas (D45 item 8 + o cancelamento do D18). Logo: índice 0 sempre à
	# esquerda da tela, e o lugar de cima sempre espelhado — que é a regra do
	# D45, agora valendo dos dois lados.
	var s := 1.0 if not _vista.invertida() else -1.0
	var x := float(pose["x"]) + (s * t * passo if perto else -s * t * passo)
	return Vector3(x, float(pose["y"]), float(pose["z"]))


## Passo entre cartas da mão. D45 (item 6): o passo do lugar de BAIXO é MAIOR
## que a largura da carta (1,0), então abre um VÃO de verdade entre elas; só
## cede quando a mão lota e o arco não caberia na janela do campo (aí o que
## encolhe é o passo, nunca a carta). O do lugar de CIMA é o de sempre: cartas
## de costas, pequenas, coladas. D52: é do LUGAR, não do lado — quem joga usa o
## passo largo nas DUAS vistas, para a carta dele aparecer igual à sua na sua
## tela.
func _passo_mao(n: int, perto: bool) -> float:
	if not perto:
		return LUGAR_LONGE_PASSO
	return clampf(LUGAR_PERTO_LARG_ARCO / float(maxi(n - 1, 1)),
		LUGAR_PERTO_PASSO_MIN, LUGAR_PERTO_PASSO)


## ALTURA (Y de mundo) de cada LUGAR da mão, resolvida da CÂMERA REAL para as
## LINHAS do D45 (itens 4 e 5):
##   perto — o TOPO da carta na linha de baixo da fileira de magia de quem
##           joga, mais a folga de LUGAR_PERTO_FOLGA_PX (a mão não cobre a
##           fileira nem fica pendurada no vazio embaixo dela);
##   longe — o CENTRO da carta no meio entre o topo da tela e a linha de cima
##           dos slots de magia do outro.
## As DUAS linhas saem do dado real (posição dos ladrilhos) + da projeção da
## câmera. Sem câmera, cai no Y antigo do const (o desenho não quebra).
##
## D52: isto é resolvido na VISTA DO JOGADOR e vale para as DUAS. Não é
## otimização, é consequência da D51: as duas vistas são espelhos uma da
## outra, então o mesmo Y de mundo põe a carta na MESMA linha de tela nas duas.
## E é por isso que o `_borda_da_fileira_px` aqui é chamado com o sentido de
## "perto/longe" DA VISTA DO JOGADOR (ele se INVERTE quando a câmera vira, e
## medir com a câmera do lado errado guardaria a altura errada para sempre).
## Por isso o `_ready` chama `_aquecer_a_mao()` antes de qualquer desenho, e o
## `_ready` também roda antes da volta: o cache nunca é resolvido na vista do
## rival. No redesenho isto vira a leitura de 1 float.
func _y_da_mao(perto: bool) -> float:
	var id_cam := 0
	if _cam != null and is_instance_valid(_cam):
		id_cam = _cam.get_instance_id()
	if id_cam != 0 and id_cam == _y_mao_cam:
		return _y_mao_cache[0 if perto else 1]
	var y0 := LUGAR_PERTO_YZ.x
	var y1 := LUGAR_LONGE_YZ.x
	if id_cam != 0:
		y0 = _y_mao_na_linha(LUGAR_PERTO_YZ.y, TILT_MAO_LIVRE,
			_borda_da_fileira_px(0, "magia", true) + LUGAR_PERTO_FOLGA_PX, false)
		y1 = _y_mao_na_linha(LUGAR_LONGE_YZ.y, 180.0 + TILT_MAO_LIVRE,
			_borda_da_fileira_px(1, "magia", false) * 0.5, true)
	_y_mao_cache = Vector2(y0, y1)
	_y_mao_cam = id_cam
	return _y_mao_cache[0 if perto else 1]


## Y de mundo (com o Z travado) que põe a carta da mão — de pé, na inclinação
## da mão — numa LINHA DE TELA: o topo dela (`pelo_centro` falso) ou o centro
## dela (verdadeiro).
## É BISSEÇÃO, não secante: a projeção tem divisão de perspectiva, então a
## linha de tela NÃO é linear no Y e a secante de 2 pontos erra 20 px quando o
## chute inicial está longe (foi exatamente o que aconteceu na 1ª vez). A
## linha é monótona no Y, então a bisseção dá o mesmo resultado em qualquer
## máquina. São 30 passos, UMA vez por câmera (memorizado em `_y_da_mao`).
func _y_mao_na_linha(z: float, tilt_graus: float, alvo: float, pelo_centro: bool) -> float:
	var lo := -8.0
	var hi := 20.0
	var f_lo := _erro_linha_mao(lo, z, tilt_graus, alvo, pelo_centro)
	var f_hi := _erro_linha_mao(hi, z, tilt_graus, alvo, pelo_centro)
	# Alvo fora do intervalo (nunca acontece com as linhas do jogo, mas a
	# função não pode devolver lixo se um dia acontecer): abre a faixa.
	var guarda := 0
	while f_lo * f_hi > 0.0 and guarda < 12:
		lo -= 10.0
		hi += 10.0
		f_lo = _erro_linha_mao(lo, z, tilt_graus, alvo, pelo_centro)
		f_hi = _erro_linha_mao(hi, z, tilt_graus, alvo, pelo_centro)
		guarda += 1
	for _k in range(30):
		var meio := (lo + hi) * 0.5
		var f_meio := _erro_linha_mao(meio, z, tilt_graus, alvo, pelo_centro)
		if absf(f_meio) < 0.01:
			return meio
		if (f_meio > 0.0) == (f_lo > 0.0):
			lo = meio
			f_lo = f_meio
		else:
			hi = meio
	return (lo + hi) * 0.5


func _erro_linha_mao(y: float, z: float, tilt_graus: float, alvo: float, pelo_centro: bool) -> float:
	var b := _caixa_carta_tela(Vector3(0.0, y, z), tilt_graus)
	return ((b.y + b.w) * 0.5 if pelo_centro else b.y) - alvo


## LINHA DE TELA (y em px) da borda de uma fileira de ladrilhos: `perto` = a
## borda de BAIXO (a mais perto da câmera, que é a "base" que se vê embaixo da
## fileira) e `perto` falso = a de CIMA. Sai do dado real (os 5 ladrilhos da
## fileira) + da projeção da câmera — nenhuma linha da tela é chutada.
## Medida na FACE DE CIMA do ladrilho (TOPO_PISO), que é a superfície que a
## faixa do meio encosta e que a mão do jogador fica logo abaixo.
func _borda_da_fileira_px(lado: int, tipo: String, perto: bool) -> float:
	if _cam == null or not is_instance_valid(_cam):
		return float(TELA_A)
	var peca := _peca_prof_carta()
	var linha := -1e9 if perto else 1e9
	for i in range(5):
		# `_pos_slot` com o LADO VISUAL: a fileira é medida onde ela está na
		# tela. A faixa do meio NÃO espelha (D8/doc 16 D8 — ela é sempre o
		# painel do jogador), e o vão entre as duas fileiras de monstro dá a
		# MESMA medida nas duas perspectivas porque a vista do rival é o
		# espelho exato da do jogador (D51: a câmera volta para o espelho em
		# torno do plano de simetria do campo, não em torno da origem).
		var p := _pos_slot(lado, tipo, i)
		for sx in [-1.0, 1.0]:
			var dz := peca * 0.5 if perto else -peca * 0.5
			var q := _cam.unproject_position(p + Vector3(sx * peca * 0.5, TOPO_PISO - TOPO, dz))
			linha = maxf(linha, q.y) if perto else minf(linha, q.y)
	return linha


## X de mundo do centro do arco de CADA LUGAR, calculado para o centro do arco
## cair no MESMO X de tela do centro do campo (as DUAS mãos centralizadas).
## D52: resolvido na vista do jogador e válido nas duas (mesma razão do
## `_y_da_mao`: as vistas são espelhos, e o X nem é espelhado). Roda UMA vez e
## fica memorizado: no redesenho vira só a leitura de 2 floats. Sem câmera = X
## antigo, o desenho não quebra.
func _x_centro_da_mao() -> Vector2:
	var id_cam := 0
	if _cam != null and is_instance_valid(_cam):
		id_cam = _cam.get_instance_id()
	if id_cam != 0 and id_cam == _x_centro_mao_cam:
		return _x_centro_mao
	if id_cam == 0:
		_x_centro_mao = Vector2(LUGAR_PERTO_X_SEM_CAM, LUGAR_LONGE_X_SEM_CAM)
	else:
		# Alvo = X de tela onde o centro do campo cai (o próprio ponto (0,*,0)).
		var alvo := _cam.unproject_position(Vector3(0.0, TOPO, 0.0)).x
		_x_centro_mao = Vector2(
			_x_mao_no_alvo(_y_da_mao(true), LUGAR_PERTO_YZ.y, alvo),
			_x_mao_no_alvo(_y_da_mao(false), LUGAR_LONGE_YZ.y, alvo))
	_x_centro_mao_cam = id_cam
	return _x_centro_mao


## D52: resolve o Y e o X dos DOIS lugares AGORA, na vista do jogador, e
## memoriza. Chama no boot antes de qualquer desenho: sem isto o cache seria
## resolvido na primeira mão que aparecesse, e se o RIVAL começar o duelo (D42,
## sorteado pelo motor) isso aconteceria com a câmera do lado errado — com o
## `_borda_da_fileira_px` invertido e uma altura guardada para sempre.
func _aquecer_a_mao() -> void:
	_y_da_mao(true)
	_y_da_mao(false)
	_x_centro_da_mao()


## X de mundo (com Y e Z travados) que faz o ponto cair em `alvo_x` na tela.
## Secante de 2 passos sobre a projeção da câmera — unproject_position é
## matemática pura (roda igual com render e headless).
func _x_mao_no_alvo(y: float, z: float, alvo_x: float) -> float:
	var x0 := 0.0
	var x1 := 1.0
	var f0 := _cam.unproject_position(Vector3(x0, y, z)).x - alvo_x
	var f1 := _cam.unproject_position(Vector3(x1, y, z)).x - alvo_x
	for _k in range(2):
		if absf(f1 - f0) < 0.00001:
			return x1
		var x := x1 - f1 * (x1 - x0) / (f1 - f0)
		var f := _cam.unproject_position(Vector3(x, y, z)).x - alvo_x
		x0 = x1
		f0 = f1
		x1 = x
		f1 = f
	return x1


## Calibração do DESENHO (prova + ferramenta de ajuste futuro): mede, em
## PIXELS de tela, o quanto o centro do arco de cada mão sai do centro do
## campo. Os dois `erro` em ~0.00 = as DUAS mãos centralizadas. `escala` diz
## quantos pixels vale 1 unidade de mundo na mão (para mexer em
## LUGAR_PERTO_PASSO/LUGAR_LONGE_PASSO) e `arco` é a largura que o arco ocupa na tela.
## Texto só-ASCII de propósito: a saída do jogo lido como processo filho vem
## no code page do Windows (ver test_project_arg).
func _calibrar_mao() -> void:
	if _cam == null or not is_instance_valid(_cam):
		_diag("Calib: sem câmera, arco no X de fallback.")
		return
	var n := [5, 5]
	if _st != null:
		n[0] = maxi(((_st.players[0] as Dictionary)["hand"] as Array).size(), 1)
		n[1] = maxi(((_st.players[1] as Dictionary)["hand"] as Array).size(), 1)
	var janela := _cam.get_viewport().get_visible_rect().size
	var alvo := _cam.unproject_position(Vector3(0.0, TOPO, 0.0)).x
	# X do centro do campo na TELA REAL: a janela do campo começa em
	# JANELA_CAMPO_X, então é só somar a origem da janela ao X projetado.
	var alvo_tela := JANELA_CAMPO_X + alvo
	_diag("Calib: janela=%dx%d em x=%d | tela=%dx%d centro_da_tela=%.1f centro_do_campo=%.1f (%.2f%% da tela)" % [
		int(janela.x), int(janela.y), JANELA_CAMPO_X, TELA_L, TELA_A,
		float(TELA_L) * 0.5, alvo_tela, alvo_tela / float(TELA_L) * 100.0])
	for lado in [0, 1]:
		var q: int = n[lado]
		# Índice do MEIO do arco (com número par o meio cai entre 2 cartas).
		var meio := int(ceil(float(maxi(q - 1, 0)) / 2.0))
		var centro := _pos_mao_arco(meio, q, lado)
		var sx := _cam.unproject_position(centro).x
		_diag("Calib:   p%d cartas=%d x_mundo=%.3f tela=%.2f tela_x=%.1f erro=%.2fpx escala=%.1fpx/u arco=[%.0f..%.0f]px" % [
			lado, q, centro.x, sx, JANELA_CAMPO_X + sx, sx - alvo,
			absf(_cam.unproject_position(centro + Vector3(1, 0, 0)).x - sx),
			_cam.unproject_position(_pos_mao_arco(0, q, lado)).x,
			_cam.unproject_position(_pos_mao_arco(maxi(q - 1, 0), q, lado)).x])
		var cx := _cam.unproject_position(centro).x
		var dx_ := absf(_cam.unproject_position(centro + Vector3(LARG_CARTA, 0, 0)).x - cx)
		# D52: a inclinação vem do LUGAR que a mão ocupa na vista atual (é o
		# `_pose_da_mao` que manda), não do lado.
		var tilt_ := float(_pose_da_mao(lado == _dono_do_lugar_perto())["tilt"])
		var caixa := _caixa_carta_tela(centro, tilt_)
		_diag("Calib:   p%d carta_na_tela: x=[%.0f..%.0f] y=[%.0f..%.0f] px | largura=%.0fpx (%.1f%% da tela) | em%% da altura: %.1f..%.1f" % [
			lado, caixa.x + JANELA_CAMPO_X, caixa.z + JANELA_CAMPO_X,
			caixa.y, caixa.w, dx_, dx_ / float(TELA_L) * 100.0,
			caixa.y / float(TELA_A) * 100.0, caixa.w / float(TELA_A) * 100.0])


## Caixa de uma carta DE PÉ na TELA (px): x = esq..dir, y = cima..baixo.
## Ferramenta de ajuste da mão (doc 15 §15.3: mão pequena no rodapé, de pé,
## cortada embaixo) — matemática pura, roda headless.
func _caixa_carta_tela(centro: Vector3, tilt_graus: float) -> Vector4:
	var t := deg_to_rad(tilt_graus)
	var eixo_y := Vector3(0.0, cos(t), sin(t))
	var e := _cam.unproject_position(centro)
	var d := _cam.unproject_position(centro + Vector3(LARG_CARTA, 0, 0))
	var c := _cam.unproject_position(centro + eixo_y * (ALT_CARTA / 2.0))
	var b := _cam.unproject_position(centro - eixo_y * (ALT_CARTA / 2.0))
	return Vector4(minf(e.x, d.x), minf(c.y, b.y), maxf(e.x, d.x), maxf(c.y, b.y))


## Quantos assets embutidos o jogo achou de verdade agora (a cascata de
## `_textura_arquivo`: projeto -> embutido -> nada). Prova de que o jogo
## mostra a carta real SOZINHO, sem `--project`. Só leitura, zero regra.
func _conta_assets_embutidos() -> int:
	var n := 0
	for rel in ASSETS_EMBUTIDOS:
		if _tex_cache(str(rel)) != null:
			n += 1
	return n


func _limpar_cartas() -> void:
	for f in _no_cartas.get_children():
		(f as Node).queue_free()


## Pose da carta DEITADA no painel de vidro (doc 15 §15.3: na referência as
## cartas do campo estão deitadas na peça, não em pé). Só DESENHO:
##   virada  -> só o verso pra cima (a carta some, não vaza nome);
##   aberta  -> topo da carta virado pro DONO do slot (o dono é quem está
##              jogando, e o lado que decide é o LADO VISUAL — doc 16 §16.5;
##              na tela de hoje ele é o espelho do rival, D18) e a de DEFESA
##              gira um quarto de volta no lugar, que é como o jogo mostra
##              Ataque x Defesa (D24) sem texto flutuando.
## `lado` aqui é o LADO VISUAL (saído de `_vis`), nunca o lado do dado.
func _deitar_carta(carta: Node3D, face_down: bool, em_defesa: bool, lado: int) -> void:
	if face_down:
		carta.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		return
	var giro := 0.0
	if lado == 1:
		giro = 180.0
	if em_defesa:
		giro = fmod(giro + 90.0, 360.0)
	carta.rotation_degrees = Vector3(-90.0, giro, 0.0)


# ---- D47: A VOLTA DA MESA ----

var _blocos_voce: Array[Control] = []
var _blocos_rival: Array[Control] = []
var _vista_trocada := false


## APlica a "vista" no HUD 2D (D47). A tela 3D gira com a câmera; o HUD NÃO
## gira (ele vira de carta): encolhe no eixo X até sumir nos 90° e volta
## crescendo do outro lado, com o conteúdo do outro jogador. Uma regra só
## (`escala_do_virar` da vista) para tudo que tem nome ou número, e a troca
## acontece exatamente na largura ZERO — ou seja, ninguém vê o instante em que
## o conteúdo muda.
##
## O que inverte e o que NÃO inverte, e por quê:
##   * retratos e plaquinhas de nome/LP: invertem as POSIÇÕES (o seu vai para
##     a direita, o dele para a esquerda) — para cada um ver o seu do lado dele;
##   * a faixa do meio: a ORDEM das 7 células se espelha, então o seu deck e o
##     seu LP ficam do lado que agora é o seu na tela, e a cor viaja com o
##     número (azul = você, sempre);
##   * a barra de fases: NÃO inverte, de propósito. Ela mostra a fase REAL de
##     quem está jogando (D13/doc 13), e espelhar um dado de regra seria a tela
##     mentir. Fica como âncora visual do meio da mesa.
func _aplicar_vista_hud() -> void:
	var esc: float = _vista.escala_do_virar()
	var invertido: bool = _vista.invertida()
	if _faixa != null:
		_faixa.virar(esc)
	for b in _blocos_voce:
		_virar_bloco(b, esc)
	for b in _blocos_rival:
		_virar_bloco(b, esc)
	if invertido != _vista_trocada:
		_vista_trocada = invertido
		_trocar_lado_das_blocos()
		if _faixa != null and is_instance_valid(_faixa):
			_faixa.espelhar()


## Um bloco do HUD que vira de carta: pivô no meio dele (para encolher para os
## dois lados, como uma carta virando) e a escala do giro.
func _virar_bloco(b: Control, esc: float) -> void:
	if b == null or not is_instance_valid(b):
		return
	b.pivot_offset = Vector2(b.size.x * 0.5, b.size.y * 0.5)
	b.scale = Vector2(esc, 1.0)


## Nos 90°, as posições dos blocos trocam de lado (a sua foto vai para a direita
## e a dele para a esquerda). As posições originais ficam em meta no primeiro
## giro, então isto é idempotente e não depende de nada guardado fora.
func _trocar_lado_das_blocos() -> void:
	for grupo in [_blocos_voce, _blocos_rival]:
		for b in grupo:
			if b == null or not is_instance_valid(b):
				continue
			if not b.has_meta("x_normal"):
				b.set_meta("x_normal", b.position.x)
	for i in range(mini(_blocos_voce.size(), _blocos_rival.size())):
		var a: Control = _blocos_voce[i]
		var b2: Control = _blocos_rival[i]
		if a == null or b2 == null or not is_instance_valid(a) or not is_instance_valid(b2):
			continue
		var xa := float(a.get_meta("x_normal"))
		var xb := float(b2.get_meta("x_normal"))
		if _vista.invertida():
			a.position.x = xb
			b2.position.x = xa
		else:
			a.position.x = xa
			b2.position.x = xb


## A ORDEM das 7 células da faixa se espelha na virada. Como o `Celulas` é um
## HBoxContainer, a ordem dos filhos É a ordem na tela: espelhar é reordenar.
## O turno fica no meio (é o único que não tem dono) e a cor viaja com o
## número, então o azul continua sendo "você" — só muda de lado na tela.
## Redesenha as cartas 3D do estado real.
## `com_efeito` = a compra deve ANIMAR (a carta nova voa do baralho para a mão).
## `dono_efeito` = de QUEM é a compra (0 = você, 1 = rival): a animação é da
## MÃO QUE COMPROU, e só dela. Bug corrigido aqui (D53): ela estava fixa na
## mão do JOGADOR, então na vez do RIVAL a animação da compra dele mexia na SUA
## mão — que, com a D52, está no LUGAR DE CIMA da tela dele, e saía voando pelo
## meio do campo. E `_terminar_jogada_mao` (a invocação) também usava
## `com_efeito = true` sem ter comprado nada: a mão só PERDEU uma carta.
func _redesenhar(com_efeito: bool, dono_efeito: int = 0) -> void:
	# D47: o desenho do campo é SEMPRE o mesmo — lado do dado = lado do mundo.
	# Quem muda o ponto de vista é a câmera (a volta da mesa), então aqui não há
	# nenhum "lado visual" para decidir: cada carta fica onde o DADO manda.
	_limpar_cartas()
	if _st == null:
		return
	_artes_ok = 0
	# Campo: 5+5 monstros + magias (se houver, ex. test_state) por lado.
	for lado in [0, 1]:
		for zona_nome in ["monster", "spell"]:
			var zona := _zona_do_jogador(lado, zona_nome)
			for i in range(zona.size()):
				if zona[i] == null:
					continue
				var m := zona[i] as Dictionary
				var tipo := "monstro" if zona_nome == "monster" else "magia"
				var virada := bool(m.get("face_down", false))
				var em_defesa := str(m.get("position", "ATK")) == "DEF"
				var carta := _fazer_carta(_fantasia(m), virada, em_defesa)
				# A carta do campo cresce com o campo (mesma proporção dentro
				# do vidro) e fica apoiada na peça, não flutuando.
				carta.scale = Vector3.ONE * ESCALA_CAMPO
				carta.position = _pos_slot(lado, tipo, i) + Vector3(0, 0.015 * ESCALA_CAMPO, 0)
				_deitar_carta(carta, virada, em_defesa, lado)
				carta.set_meta("slot_id", "p%d_%s%d" % [lado, ("m" if zona_nome == "monster" else "s"), i])
				carta.set_meta("card_id", str(m.get("card_id", "")))
				_no_cartas.add_child(carta)
	# Mãos em arco: DUAS na tela, uma embaixo e outra em cima, e QUEM ESTÁ
	# JOGANDO é a de baixo (D52). O que decide o lugar é a VISTA (o
	# `giro_campo` do no da vista, pelos 90°), e a troca acontece com a tela sem
	# mostrar nada: nos 90° as mãos estão a 32,7° do eixo (o FOV é de 20°) e o
	# HUD 2D está com largura zero. A mão do rival é sempre um VERSO genérico
	# (você nunca lê a mão do adversário); na vista do rival as DUAS mãos
	# mostram o verso, porque o verso de uma carta não é o espelho da frente.
	# Efeito-bônus que o dado já dava: o espelho do rival (D18) + a troca dos
	# lugares se cancelam, e cada um vê a PRÓPRIA mão na ordem normal.
	# Rotação LIVRE: valor fixo editável, sem nenhum cálculo da câmera. Mude
	# TILT_MAO_LIVRE à vontade (graus no eixo X).
	var mao0: Array = (_st.players[0] as Dictionary)["hand"]
	for i in range(mao0.size()):
		var c := _fazer_carta(mao0[i] as Dictionary, false, false)
		# Mão PEQUENA no rodapé (fase 2/doc 15 §15.3): o X acompanha o
		# centro do campo (calculado da câmera) e o Y/Z é o do LUGAR perto
		# (LUGAR_PERTO_YZ) — a carta nasce cortada pela borda de baixo.
		c.position = _pos_mao_arco(i, mao0.size(), 0)
		# Levantada p/ fusão: só o selo na etiqueta (posição não muda). A
		# etiqueta nasce escondida (o ATK/DEF já é impresso na carta): o
		# selo é a única coisa que precisa aparecer flutuando.
		var selo := _levantadas.find(i) + 1
		if selo > 0:
			var tag := c.get_node("TagPos") as Label3D
			tag.text = "SELO %d" % selo
			tag.visible = true
		c.set_meta("mao_idx", i)
		c.set_meta("mao_dono", 0)
		_no_cartas.add_child(c)
		_pose_da_carta_da_mao(c, 0)
		_animar_compra(c, 0, com_efeito, dono_efeito)
	var mao1: Array = (_st.players[1] as Dictionary)["hand"]
	for j in range(mao1.size()):
		var v := _fazer_carta({}, true, false)
		v.position = _pos_mao_arco(j, mao1.size(), 1)
		v.set_meta("mao_idx", j)
		v.set_meta("mao_dono", 1)
		_no_cartas.add_child(v)
		_pose_da_carta_da_mao(v, 1)
		_animar_compra(v, 1, com_efeito, dono_efeito)
	_atualizar_hud()
	_posicionar_cursor()


## D53: A COMPRA ANIMADA É DA MÃO QUE COMPROU, e só dela. A carta nasce no
## baralho do dono e voa (0,35 s) para o lugar dela na mão. A trava importa: se
## a compra animasse sempre a mão de baixo, na vez do rival ela animaria o
## LUGAR DE CIMA da tela dele e as cartas dele atravessariam a tela voando.
func _animar_compra(carta: Node3D, dono: int, com_efeito: bool, dono_efeito: int) -> void:
	# Sem trava de `_sem_render` de propósito (mesmo motivo do `_sacudir`): o
	# tween é de 0,35 s e não depende de render, e assim o GUT vê QUEM animou.
	if not com_efeito or dono != dono_efeito or carta == null or not is_instance_valid(carta):
		return
	var alvo: Vector3 = carta.position
	carta.position = _deck_pos[dono]
	var tw := carta.create_tween().set_parallel(true)
	tw.tween_property(carta, "position", alvo, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## D52: aplica na carta da mão a POSE do lugar que ela ocupa na vista atual
## (rotação + cara). O dono único é `_pose_da_mao`: quem posiciona e quem
## desenha leem o mesmo número, então a carta não pode ter uma pose no lugar e
## outra no desenho. `dono` = 0 (você) ou 1 (rival) no DADO.
##
## D3: as DUAS mãos são uma camada de MÃO — sempre desenhada por cima do
## campo. Sem isso, o ladrilho de magia (o vidro escuro, alpha 0,72) ficava NA
## FRENTE da mão de cima na tela e pintava a metade de baixo das cartas
## viradas, que na ref não tem nada atrás. No lugar de baixo o `no_depth_test`
## é inofensivo (ele já é a coisa mais perto da câmera), e assim a troca dos
## 90° não precisa mexer em material de nada.
func _pose_da_carta_da_mao(carta: Node3D, dono: int) -> void:
	var perto := dono == _dono_do_lugar_perto()
	var pose := _pose_da_mao(perto)
	carta.rotation_degrees = Vector3(float(pose["tilt"]), 0.0, 0.0)
	# D3: o LUGAR DE CIMA é uma camada de mão (o vidro do campo o pintaria por
	# cima). O de baixo é a coisa mais perto da câmera e fica com sombra e
	# profundidade normais — é o que garante que a SUA visão não muda nada.
	_camada_da_mao(carta, not perto)
	# A CARA: carta virada não mostra nome nem ATK/DEF. Não é vaidade: os
	# rótulos são filhos da carta 0,002 à frente do quad do verso, e sem esta
	# linha eles apareceriam ESPELHADOS em cima do verso. O SELO de fusão
	# some na vista do rival pelo mesmo motivo (ele denunciaria a carta que
	# você está combinando); na vista do jogador ele é o que o `_redesenhar`
	# já decided, então aqui não é mexido.
	var verso := bool(pose["verso"])
	for nome_filho in ["Nome", "Stats"]:
		var l := carta.get_node_or_null(nome_filho) as Label3D
		if l != null:
			l.visible = not verso
	if verso:
		var tag := carta.get_node_or_null("TagPos") as Label3D
		if tag != null:
			tag.visible = false


## D52: a vista do rival TAMBÉM é a mão: quem joga embaixo, o outro em cima, o
## Z de cada lugar espelhado e as duas de costas. Aplica nas cartas já
## desenhadas (sem redesenhar tudo), e é o que roda na troca dos 90°. some com
## o cursor junto, porque o cursor fica preso na carta da sua mão e, com as
## mãos trocadas, ele ficaria em cima da mão do rival denunciando a sua
## escolha.
func _aplicar_vista_da_mao() -> void:
	if _no_cartas == null or _st == null:
		return
	for f in _no_cartas.get_children():
		var carta := f as Node3D
		if carta == null or not carta.has_meta("mao_dono"):
			continue
		var dono := int(carta.get_meta("mao_dono"))
		var mao: Array = ((_st.players[dono] as Dictionary)["hand"] as Array)
		carta.position = _pos_mao_arco(int(carta.get_meta("mao_idx")), mao.size(), dono)
		_pose_da_carta_da_mao(carta, dono)
	if _cursor != null and is_instance_valid(_cursor):
		_cursor.visible = not _vista.invertida()


## Pinta a carta SEM teste de profundidade, como camada de MÃO (D3): a mão de
## CIMA é mais distante que o campo, e o vidro escuro do ladrilho apareceria na
## frente dela. É SÓ ordem de desenho — não muda posição, tamanho, cor nem dado.
## D52: isto é do LUGAR (o de cima), e por isso tem uma chave liga/desliga: a
## carta que vai para o lugar de baixo volta a ter sombra e profundidade de
## verdade, senão a SUA visão mudaria (a sombra da sua mão sumiria).
func _camada_da_mao(no: Node, sem_profundidade: bool) -> void:
	for f in no.get_children():
		if f is GeometryInstance3D:
			var gi := f as GeometryInstance3D
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if sem_profundidade \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			var m := gi.material_override
			if m is BaseMaterial3D:
				(m as BaseMaterial3D).no_depth_test = sem_profundidade
				(m as BaseMaterial3D).render_priority = 4 if sem_profundidade else 0
		elif f is Label3D:
			var l := f as Label3D
			l.no_depth_test = sem_profundidade
			l.render_priority = 4 if sem_profundidade else 0
		elif f is Node3D:
			_camada_da_mao(f, sem_profundidade)


## Redesenha a moldura do foco. Quem sabe DESENHAR o cursor e o arquivo dele
## (`cursor_3d.gd`): ele nao sabe o que esta focado, so recebe a medida da
## coisa, a inclinacao dela e a escala da mao.
func _moldar_foco(larg: float, alt: float, rot: Vector3, escala_mao: float) -> void:
	if _cursor != null and is_instance_valid(_cursor):
		_cursor.moldar(larg, alt, rot, escala_mao)


## A vista da mesa inteira a partir de UM número, e só isso: quem manda girar
## (o START e os testes) chama ISTO, e nunca mexe no pivô por conta própria.
func _girar_campo(alvo: float) -> void:
	if _vista != null and is_instance_valid(_vista):
		_vista.girar_para(alvo)


## O que a mesa faz a CADA PASSO da volta, na ordem do D52: a mão troca de
## lugar nos 90° e o HUD 2D vira de carta. A vista não conhece nenhum dos dois
## assuntos, então quem orquestra é a mesa.
func _aplicar_vista_da_mao_entao_hud() -> void:
	_aplicar_vista_da_mao()
	_aplicar_vista_hud()


func _posicionar_cursor() -> void:
	if _cursor == null or not is_instance_valid(_cursor) or _st == null:
		return
	var alvo := Vector3(0, TOPO, _ponto_lateral(0.0, 0.0, 4.15).z)
	# A moldura é do tamanho e da INCLINAÇÃO da coisa focada (doc 15 §15.3):
	# na mão é a CARTA (com a inclinação da mão), no campo é o LADRILHO
	# (deitado, girando junto se a carta estiver em DEFESA).
	match _fileira:
		FILEIRA_MAO:
			var n: int = ((_st.players[0] as Dictionary)["hand"] as Array).size()
			if n > 0:
				# A moldura de foco fica NA CARTA (a mão é cortada pela borda
				# de baixo; abaixo dela a moldura saía da tela virando um
				# traço branco solto no canto).
				alvo = _pos_mao_arco(clampi(_col, 0, n - 1), n, 0)
				_moldar_foco(LARG_CARTA, ALT_CARTA, Vector3(TILT_MAO_LIVRE, 0, 0), LARG_CARTA)
		FILEIRA_MEU_M:
			alvo = _pos_slot(0, "monstro", clampi(_col, 0, 4))
			_moldar_foco(_peca_prof_carta(), _peca_prof_carta(), _rot_deitada(false, 0, 0), _peca_prof_carta())
		FILEIRA_MEU_S:
			alvo = _pos_slot(0, "magia", clampi(_col, 0, 4))
			_moldar_foco(_peca_prof_carta(), _peca_prof_carta(), _rot_deitada(false, 0, 0), _peca_prof_carta())
		FILEIRA_RIVAL_M:
			alvo = _pos_slot(1, "monstro", clampi(_col, 0, 4))
			_moldar_foco(_peca_prof_carta(), _peca_prof_carta(), _rot_deitada(false, 1, _em_defesa(1, "monstro", clampi(_col, 0, 4))), _peca_prof_carta())
		FILEIRA_RIVAL_S:
			alvo = _pos_slot(1, "magia", clampi(_col, 0, 4))
			_moldar_foco(_peca_prof_carta(), _peca_prof_carta(), _rot_deitada(false, 1, _em_defesa(1, "magia", clampi(_col, 0, 4))), _peca_prof_carta())
		_:
			_moldar_foco(_peca_prof_carta(), _peca_prof_carta(), _rot_deitada(false, 0, 0), _peca_prof_carta())
	_foco = alvo
	_cursor.position = alvo


## Rotação de uma carta DEITADA no ladrilho — a mesma que `_deitar_carta`
## aplica na carta, para a moldura do foco sair girada junto (quem está em
## DEFESA tem a moldura atravessada como a carta). `lado` é o LADO VISUAL
## (saído de `_vis`), como em `_deitar_carta`.
func _rot_deitada(face_down: bool, lado: int, em_defesa: bool) -> Vector3:
	if face_down:
		return Vector3(90.0, 0.0, 0.0)
	var giro := 0.0
	if lado == 1:
		giro = 180.0
	if em_defesa:
		giro = fmod(giro + 90.0, 360.0)
	return Vector3(-90.0, giro, 0.0)


# ---- LEITURA DO ESTADO: UM SÓ PONTO, E BLINDADO (R1) ----
#
# Existem DOIS dialetos no jogo e é fácil trocar um pelo outro:
#   - BoardLayout (slot_id / posição do ladrilho): "monstro" / "magia" (PT);
#   - GameState.players[...]:                      "monster" / "spell" (EN).
# Passar o nome PT para dentro de `players[]` procurava uma chave que NÃO
# EXISTE e derrubava o jogo (Invalid access to property or key 'monstro').
# Estas funções são o ÚNICO ponto de tradução e de leitura, e nenhuma delas
# consegue falhar por valor de entrada: lado fora de 0..1, chave
# desconhecida ou chave ausente viram lista vazia / 0 em vez de crash.

## PT e EN das zonas do estado. Devolve "" para o que não for zona conhecida.
func _chave_zona(nome: String) -> String:
	match nome:
		"monstro", "monster":
			return "monster"
		"magia", "spell":
			return "spell"
	return ""


## O jogador do estado, com blindagem (lado fora de 0..1 = vazio).
func _jogador(lado: int) -> Dictionary:
	if _st == null:
		return {}
	var ps: Array = _st.players
	if lado < 0 or lado >= ps.size():
		return {}
	return ps[lado] as Dictionary


## Lista do jogador por chave QUALQUER (hand, deck, monster, spell,
## graveyard, banished...), já blindada: sempre devolve um Array.
func _lista_do_jogador(lado: int, chave: String) -> Array:
	var p := _jogador(lado)
	if p.is_empty():
		return []
	var v = p.get(chave, null)
	return v as Array if v is Array else []


## Número do jogador (lp, max_lp) blindado: sempre devolve um int.
func _int_do_jogador(lado: int, chave: String, padrao: int = 0) -> int:
	var p := _jogador(lado)
	if p.is_empty() or not p.has(chave):
		return padrao
	return int(p[chave])


## Zona do jogador com a chave JÁ TRADUZIDA (aceita "monstro" ou
## "monster"). É esta que todo mundo deve usar para ler monstro/magia.
func _zona_do_jogador(lado: int, nome: String) -> Array:
	return _lista_do_jogador(lado, _chave_zona(nome))


## O slot REAL está em DEFESA? (só leitura do estado, para a moldura do
## foco ficar na mesma pose da carta). Traduz o nome da fileira e usa a
## leitura blindada — nenhum valor de entrada derruba o jogo.
func _em_defesa(lado: int, zona_nome: String, slot: int) -> bool:
	if _st == null:
		return false
	var zona := _zona_do_jogador(lado, zona_nome)
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return false
	return str((zona[slot] as Dictionary).get("position", "ATK")) == "DEF"


# ---- HUD (só mostra: LP, fase, turno, log, dica) ----

func _rotulo_hud(nome: String, texto: String, pos: Vector2, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.name = nome
	l.text = texto
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo_placa(fundo: Color = Color(0.62, 0.64, 0.70), borda: Color = Color(0.18, 0.19, 0.24)) -> StyleBoxFlat:
	# Placa metálica do topo (ref nova): azul (você), azul-escuro (turno),
	# vermelha (rival). Texto claro gravado.
	var est := StyleBoxFlat.new()
	est.bg_color = fundo
	est.border_color = borda
	est.set_border_width_all(2)
	est.set_corner_radius_all(6)
	est.content_margin_left = 14
	est.content_margin_right = 14
	est.content_margin_top = 6
	est.content_margin_bottom = 6
	return est


func _rotulo_placa_clara(nome: String, texto: String, tam: int) -> Label:
	# Texto CLARO gravado na placa colorida (ref nova).
	var l := Label.new()
	l.name = nome
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Retratos 2D no estilo da ref: moldura metálica clara com gradiente
## escuro e a INICIAL do nome (o pack NÃO tem retrato de duelista — os 39
## duelistas do FM vêm com `portrait` vazio, então nunca há foto; se um dia
## vier, a foto real aparece no lugar do placeholder).
## Moldura do retrato no estilo da ref (D6): metal claro com BISEL de verdade —
## aro externo grosso e claro, um fio escuro por dentro (o degrau do bisel) e o
## miolo escuro onde entra a foto/placeholder.
func _estilo_retrato() -> StyleBoxFlat:
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.03, 0.03, 0.07, 0.95)
	est.border_color = Color(0.86, 0.91, 1.0)
	est.set_border_width_all(6)
	est.set_corner_radius_all(8)
	est.content_margin_left = 8
	est.content_margin_right = 8
	est.content_margin_top = 8
	est.content_margin_bottom = 8
	return est


## Aro de metal do retrato, desenhado ATRÁS do miolo: um retângulo claro
## maior que o miolo, para o miolo "entrar" nele com sombra de um lado só —
## é o que dá a leitura de bisel da ref.
func _aro_retrato() -> TextureRect:
	var tr := _fundo_retrato(Color(0.88, 0.93, 1.0))
	tr.name = "Aro"
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = -7.0
	tr.offset_top = -7.0
	tr.offset_right = 7.0
	tr.offset_bottom = 7.0
	return tr


## Gradiente do placeholder do retrato (mesma linguagem do metal do HUD).
func _fundo_retrato(tom: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, tom.darkened(0.55))
	g.set_color(1, tom.darkened(0.80))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 8
	gt.height = 64
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## D44 (item 8): o topo da tela tem SÓ a foto de cada duelista + o nome dele:
## o seu à ESQUERDA e o do rival à DIREITA. Toda a informação (LP, TURN, fases)
## fica na faixa do meio. O pack não tem foto de duelista, então o que aparece é
## o placeholder com a inicial do nome dentro da moldura (nada de rosto
## inventado) e o nome real do dado ao lado.
func _construir_retratos(hud: Control) -> void:
	# RIVAL: foto na direita (x 1770) e nome à ESQUERDA dela, alinhado à
	# direita, para os dois lados ficarem espelhados. D45 (item 1): as fotos
	# subiram para a beirada de cima da janela do campo (RETRATO_MARGEM dos
	# três lados: esquerda, direita e topo) e a placa de nome tem o TOPO na
	# MESMA LINHA do topo da foto.
	var ret_rival := PanelContainer.new()
	ret_rival.name = "RetratoRival"
	ret_rival.add_theme_stylebox_override("panel", _estilo_retrato())
	ret_rival.position = Vector2(RETRATO_RIVAL_X, RETRATO_RIVAL_Y)
	ret_rival.size = Vector2(RETRATO_L, RETRATO_L)
	ret_rival.custom_minimum_size = Vector2(RETRATO_L, RETRATO_L)
	ret_rival.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ret_rival.add_child(_aro_retrato())
	var fundo_r := _fundo_retrato(Color(0.96, 0.56, 0.30))
	fundo_r.name = "Fundo"
	ret_rival.add_child(fundo_r)
	_retrato_rival_foto = TextureRect.new()
	_retrato_rival_foto.name = "Foto"
	_retrato_rival_foto.custom_minimum_size = Vector2(120, 120)
	_retrato_rival_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato_rival_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_retrato_rival_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato_rival_foto.visible = false
	ret_rival.add_child(_retrato_rival_foto)
	_retrato_rival_silhueta = _rotulo_hud("Silhueta", "?", Vector2.ZERO, 52, Color(0.96, 0.62, 0.38))
	_retrato_rival_silhueta.custom_minimum_size = Vector2(120, 120)
	_retrato_rival_silhueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_retrato_rival_silhueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ret_rival.add_child(_retrato_rival_silhueta)
	hud.add_child(ret_rival)
	_blocos_rival.append(ret_rival)
	# D47: a placa de nome e o retrato sao blocos que viram de carta na volta.
	_lbl_placa_nome_rival = _placa_nome_retrato(hud, "NomeRival", RETRATO_NOME_RIVAL_X, RETRATO_RIVAL_Y,
		RETRATO_NOME_L, RETRATO_NOME_A, HORIZONTAL_ALIGNMENT_RIGHT, COR_VERM_BORDA, COR_VERM_FUNDO)
	if _lbl_placa_nome_rival != null and _lbl_placa_nome_rival.get_parent() != null:
		_blocos_rival.append(_lbl_placa_nome_rival.get_parent() as Control)
	# VOCÊ: foto na esquerda (x 578) e nome à DIREITA dela, alinhado à
	# esquerda (espelho do rival).
	var ret_voce := PanelContainer.new()
	ret_voce.name = "RetratoVoce"
	ret_voce.add_theme_stylebox_override("panel", _estilo_retrato())
	ret_voce.position = Vector2(RETRATO_VOCE_X, RETRATO_VOCE_Y)
	ret_voce.size = Vector2(RETRATO_L, RETRATO_L)
	ret_voce.custom_minimum_size = Vector2(RETRATO_L, RETRATO_L)
	ret_voce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ret_voce.add_child(_aro_retrato())
	var fundo_v := _fundo_retrato(Color(0.55, 0.85, 1.0))
	fundo_v.name = "Fundo"
	ret_voce.add_child(fundo_v)
	_retrato_voce_foto = TextureRect.new()
	_retrato_voce_foto.name = "Foto"
	_retrato_voce_foto.custom_minimum_size = Vector2(120, 120)
	_retrato_voce_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato_voce_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_retrato_voce_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato_voce_foto.visible = false
	ret_voce.add_child(_retrato_voce_foto)
	_retrato_voce_silhueta = _rotulo_hud("Silhueta", "?", Vector2.ZERO, 52, Color(0.60, 0.88, 1.0))
	_retrato_voce_silhueta.custom_minimum_size = Vector2(120, 120)
	_retrato_voce_silhueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_retrato_voce_silhueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ret_voce.add_child(_retrato_voce_silhueta)
	hud.add_child(ret_voce)
	_blocos_voce.append(ret_voce)
	_lbl_placa_nome_voce = _placa_nome_retrato(hud, "NomeVoce", RETRATO_NOME_VOCE_X, RETRATO_VOCE_Y,
		RETRATO_NOME_L, RETRATO_NOME_A, HORIZONTAL_ALIGNMENT_LEFT, COR_AZUL_BORDA, COR_AZUL_FUNDO)
	# D47: a placa de nome e o retrato sao blocos que viram de carta na volta.
	if _lbl_placa_nome_voce != null and _lbl_placa_nome_voce.get_parent() != null:
		_blocos_voce.append(_lbl_placa_nome_voce.get_parent() as Control)


## Placa de NOME ao lado do retrato (D44, item 8; cores em D45, item 2): o MESMO
## conjunto de cor do bloco de LP daquele lado — borda escura (azul a sua,
## vermelha a do rival) e interior mais claro. O nome é o REAL do dado.
func _placa_nome_retrato(hud: Control, nome: String, x: float, y: float, larg: float, alt: float,
		align: int, cor_borda: Color, cor_fundo: Color) -> Label:
	var p := PanelContainer.new()
	p.name = nome
	p.add_theme_stylebox_override("panel", _estilo_placa(cor_fundo, cor_borda))
	p.position = Vector2(x, y)
	p.size = Vector2(larg, alt)
	p.custom_minimum_size = Vector2(larg, alt)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _rotulo_placa_clara("Texto", "", 24)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	hud.add_child(p)
	return l


## A FAIXA DO MEIO é 2D e vive em `faixa_2d.gd` (D45, item 2), filha do HUD.
## A barra é posicionada no VÃO entre as duas fileiras de monstro, e o vão não é
## chutado: ele sai das bordas REAIS das fileiras (dado + câmera, em
## `_borda_da_fileira_px`). A largura sai da fileira real
## (`_extensao_da_fileira_px`).
## As 7 células seguem a ordem travada no D44 e cada uma mostra:
##   deck       -> CONTAGEM de cartas do baralho real
##   cemitério  -> CONTAGEM de cartas do cemitério real
##   LP         -> número do GameState
##   TURNO      -> número do GameState
## Nada aqui calcula regra: é só leitura (R1/R3), como toda a tela.

## Extensão (x de tela) de uma fileira de ladrilhos: da coluna 0 até a 4, já em
## pixel do canvas (a janela do campo começa em PAINEL_ESQ_L). É MEDIÇÃO (câmera
## + layout da arena), então mora aqui; quem usa é a faixa do meio
## (`faixa_2d.gd`), que é sempre o painel do jogador (D8/doc 16) e por isso
## mede a fileira como ela está desenhada agora.
func _extensao_da_fileira_px(lado: int, tipo: String) -> Vector2:
	var x0 := 1e9
	var x1 := -1e9
	if _cam == null or not is_instance_valid(_cam):
		return Vector2(float(PAINEL_ESQ_L), float(TELA_L))
	var peca := _peca_prof_carta()
	for i in range(5):
		var p := _pos_slot(lado, tipo, i)
		for sz in [-1.0, 1.0]:
			var q := _cam.unproject_position(p + Vector3(sz * peca * 0.5, 0.0, 0.0))
			x0 = minf(x0, q.x)
			x1 = maxf(x1, q.x)
	return Vector2(x0 + float(PAINEL_ESQ_L), x1 + float(PAINEL_ESQ_L))


## Cria a FAIXA DO MEIO (D45) como o no `faixa_2d.gd` dentro do HUD. Ela e um
## assunto so - posicao, celulas, cores, numeros do estado e o espelhamento da
## volta - e por isso mora no arquivo dela, nao aqui.
func _construir_faixa() -> void:
	var hud := get_node_or_null(NodePath("HUD")) as Control
	_faixa = Faixa2D.new()
	_faixa.estado = Callable(self, "_pegar_estado")
	_faixa.cartas_de = Callable(self, "_pegar_cartas")
	_faixa.medir_borda = Callable(self, "_borda_da_fileira_px")
	_faixa.medir_extensao = Callable(self, "_extensao_da_fileira_px")
	_faixa.tex_cache = Callable(self, "_tex_cache")
	_faixa.avisar = Callable(self, "_diag")
	_faixa.cor_azul_borda = COR_AZUL_BORDA
	_faixa.cor_azul_fundo = COR_AZUL_FUNDO
	_faixa.cor_verm_borda = COR_VERM_BORDA
	_faixa.cor_verm_fundo = COR_VERM_FUNDO
	_faixa.cor_preto_borda = COR_PRETO_BORDA
	_faixa.cor_preto_fundo = COR_PRETO_FUNDO
	_faixa.construir(hud)


## O GameState e o dicionario de cartas, do jeito que a tela inteira le: por
## funcao, e nao por copia. A faixa pergunta aqui a cada atualizacao, entao
## trocar o duelo em tempo de execucao (D42) nao deixa numero velho na tela.
func _pegar_estado():
	return _st


func _pegar_cartas() -> Dictionary:
	return _cartas


## A faixa escreve o estado real na tela (D45). Delegado: quem sabe escrever
## na faixa e o arquivo dela.
func _atualizar_faixa() -> void:
	if _faixa != null and is_instance_valid(_faixa):
		_faixa.atualizar()


func _construir_hud() -> void:
	# HUD 2D na referência (doc 15 §15.3): o que existe são o painel esquerdo
	# com a carta focada, os retratos com nome e a faixa do meio. Tudo IGNORE
	# (D19). D44/D45: NÃO existem a barra superior com LP/TURN, a barra de fases
	# DRAW/MAIN/BATTLE/END nem a barra START ? Help — essa informação vive na
	# faixa do meio (`faixa_2d.gd`).
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_construir_fundo_painel(hud)
	_construir_retratos(hud)
	# NÃO existem textos inventados nesta tela (a referência não tem): MaoRival,
	# Fase, Log, InfoSlot, FilaFusao, Dica. D44: a fase do motor não é desenhada
	# em lugar nenhum.
	_lbl_mao_rival = null
	_lbl_fase = null
	_lbl_log = null
	_lbl_slot = null
	_lbl_fila = null
	_lbl_dica = null
	# D45 (item 7): NÃO existe barra "START ? Help" na tela. A ação de passar o
	# turno continua no CONTROLE (D19: botão START do joypad) — o que não existe
	# é o texto, que era informação repetida.
	_flash_tela = ColorRect.new()
	_flash_tela.name = "FlashTela"
	_flash_tela.color = Color(1, 1, 1)
	_flash_tela.modulate.a = 0.0
	_flash_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_flash_tela)
	_painel = PainelCarta3D.new()
	_painel.largura = PAINEL_ESQ_L
	_painel.altura = TELA_A
	_painel.janela_art = JANELA_ART
	_painel.estado = Callable(self, "_pegar_estado")
	_painel.cartas_de = Callable(self, "_pegar_cartas")
	_painel.foco = Callable(self, "_carta_focada")
	_painel.tex_cache = Callable(self, "_tex_cache")
	_painel.cor_de_atributo = Callable(self, "_cor_atributo")
	_painel.textura_arte = Callable(self, "_textura_arte")
	_painel.moldura_da_carta = Callable(self, "_moldura_da_carta")
	_painel.estrelas_da_carta = Callable(self, "_estrelas_da_carta")
	hud.add_child(_painel)


## Fundo do painel esquerdo: azul-marinho escuro (ref) ocupando a faixa
## inteira x 0..562, altura toda, com um fio de brilho na borda direita.
func _construir_fundo_painel(hud: Control) -> void:
	var fundo := ColorRect.new()
	fundo.name = "FundoPainelEsq"
	fundo.color = COR_PAINEL
	fundo.position = Vector2.ZERO
	fundo.size = Vector2(PAINEL_ESQ_L, TELA_A)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fundo)
	var brilho := ColorRect.new()
	brilho.name = "BrilhoPainel"
	brilho.color = COR_PAINEL_BORDA
	brilho.position = Vector2(PAINEL_ESQ_L - 3, 0)
	brilho.size = Vector2(3, TELA_A)
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(brilho)


func _mostrar_centro3d(face_baixo: bool) -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.mostrar_centro(_texto_do_centro(face_baixo))


## O texto da carta do centro. O NOME vem do cursor (logo, da mesa) e o menu
## so escreve o que a mesa montou.
func _texto_do_centro(face_baixo: bool) -> String:
	return "Centro: %s (%s)" % [_nome_carta_mao(_mao_idx), ("face p/ baixo" if face_baixo else "face p/ cima")]


func _atualizar_centro_face() -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.mostrar_centro(_texto_do_centro(_face_baixo))


func _esconder_centro3d() -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.esconder_centro()


func _mostrar_popup_estrela() -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.mostrar_estrela(_estrela_ops)


func _mostrar_popup_alvo() -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.mostrar_alvo()


func _esconder_popup() -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.esconder_popup()


## O popup esta aberto? A mesa usa para travar o controle (D47).
func _popup_aberto() -> bool:
	return _menus != null and is_instance_valid(_menus) and _menus.popup_aberto()


## O "> " do popup: a opcao sob o cursor. E estado do MENU, e o menu e o dono -
## a mesa le e escreve por aqui e nao guarda uma copia (D59).
func _pad_popup_idx() -> int:
	return _menus.idx if _menus != null and is_instance_valid(_menus) else 0


func _set_pad_popup_idx(v: int) -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.idx = v


## O modo do popup ("estrela" ou "alvo"), pelo mesmo motivo do indice.
func _popup_modo() -> String:
	return _menus.modo if _menus != null and is_instance_valid(_menus) else "estrela"


func _set_popup_modo(m: String) -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.modo = m


func _atualizar_menus() -> void:
	if _menus != null and is_instance_valid(_menus):
		_menus.atualizar()


func _fala(texto: String) -> void:
	_log.append(texto)
	while _log.size() > 4:
		_log.pop_front()
	if _lbl_log != null:
		_lbl_log.text = "\n".join(_log)
	# A fala vai para o log SEMPRE, mesmo sem `--debug`: é a linha que prova
	# que o jogo chegou na sua vez (contrato do test_project_arg).
	print("[MESA3D] " + texto)


func _atualizar_hud() -> void:
	if _st == null:
		return
	# D44: quem escreve o dado real na tela são a FAIXA DO MEIO (LP dos dois
	# lados, turno e a espessura/carta do topo de cada pilha) e os NOMES ao lado
	# dos retratos. A barra de fases e as placas do topo NÃO existem nesta tela.
	if _lbl_placa_nome_voce != null:
		_lbl_placa_nome_voce.text = _nome_voce.to_upper()
	if _lbl_placa_nome_rival != null:
		_lbl_placa_nome_rival.text = _nome_rival.to_upper()
	_atualizar_faixa()
	_atualizar_painel_foco()


## O painel esquerdo PERGUNTA a mesa o que esta sob o cursor e escreve. Quem
## sabe desenhar o painel e o arquivo dele (`painel_carta_3d.gd`).
func _atualizar_painel_foco() -> void:
	if _painel != null and is_instance_valid(_painel):
		_painel.atualizar()


## D44 (itens 3, 4 e 11): NÃO existe placa de contador solta na tela. O número
## de cartas do baralho/cemitério e a ALTURA da pilha são mostrados na faixa do
## meio (`_atualizar_faixa`), e a mão não tem contagem nenhuma.

## Carta focada pelo cursor (só leitura): mão, campo próprio ou rival.
## Rival de costas / virada = dado oculto (mostra "?" sem vazar).
func _carta_focada() -> Dictionary:
	if _st == null:
		return {}
	if _fase_jogador == FASE_MAO and _sub_mao != SUB_MAO_ESCOLHA and _mao_idx >= 0:
		var mao_c: Array = (_st.players[0] as Dictionary)["hand"]
		if _mao_idx >= 0 and _mao_idx < mao_c.size():
			return {"dado": mao_c[_mao_idx] as Dictionary, "aberta": true, "lado": 0}
	if _fileira == FILEIRA_MAO:
		var mao: Array = (_st.players[0] as Dictionary)["hand"]
		var i := clampi(_col, 0, maxi(int(mao.size()) - 1, 0))
		if i >= 0 and i < mao.size():
			return {"dado": mao[i] as Dictionary, "aberta": true, "lado": 0}
	var lt := _lado_tipo_da_fileira(_fileira)
	if lt.is_empty():
		return {}
	var lado := int(lt[0])
	# _lado_tipo_da_fileira fala PT ("monstro"/"magia"); o estado real usa EN.
	var zona_nome := "monster" if str(lt[1]) == "monstro" else "spell"
	var zona := _zona_do_jogador(lado, str(lt[1]))
	var slot := clampi(_col, 0, 4)
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return {}
	var inst := zona[slot] as Dictionary
	var aberta := not bool(inst.get("face_down", false))
	if lado == 1 and not aberta:
		return {"dado": {}, "aberta": false, "lado": lado}
	return {"dado": _fantasia(inst), "aberta": aberta, "lado": lado, "inst": inst}


## As 2 guardian stars do DADO (fm guardian_star_1/2). Sem inventar: se o dado
## nao tem, usa "-" para nao travar o fluxo. E o DONO desta leitura porque o
## FLUXO precisa delas (sao as opcoes do menu da estrela) e o painel tambem.
## As 2 guardian stars do DADO (fm guardian_star_1/2). Sem inventar: se o dado
## nao tem, usa "-" para nao travar o fluxo. E o DONO desta leitura porque o
## FLUXO precisa delas (sao as opcoes do menu da estrela) e o painel tambem.
func _estrelas_da_carta(carta: Dictionary) -> Array:
	var cartas: Dictionary = _cartas
	var real: Dictionary = {}
	var cid := str(carta.get("id", ""))
	if not cid.is_empty() and cartas.has(cid):
		real = cartas[cid] as Dictionary
	var s1 := str(carta.get("guardian_star_1", real.get("guardian_star_1", "")))
	var s2 := str(carta.get("guardian_star_2", real.get("guardian_star_2", "")))
	if s1.strip_edges().is_empty():
		s1 = "\u2014"
	if s2.strip_edges().is_empty():
		s2 = "\u2014"
	return [s1, s2]


func _texto_inst_slot(lado: int, zona_nome: String, slot: int) -> String:
	var zona := _zona_do_jogador(lado, zona_nome)
	var sid := "p%d_%s%d" % [lado, ("m" if zona_nome == "monster" else "s"), slot]
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return "Slot %s: vazio." % sid
	var m := zona[slot] as Dictionary
	var face := "virada" if bool(m.get("face_down", false)) else "aberta"
	var pos := str(m.get("position", "ATK"))
	return "Slot %s: %s em %s %s." % [sid, _nome_no_slot_lado(lado, zona_nome, slot), pos, face]


## Nome curto da carta da mão (só leitura).
func _nome_carta_mao(idx: int) -> String:
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if idx < 0 or idx >= mao.size():
		return "?"
	var c := mao[idx] as Dictionary
	var cid := str(c.get("id", ""))
	if not cid.is_empty() and _cartas.has(cid):
		return str((_cartas[cid] as Dictionary).get("name", cid))
	return str(c.get("name", cid))


## Nome curto do que está no slot (mostra qual tem carta, sem regra nova).
func _nome_no_slot_lado(lado: int, zona_nome: String, slot: int) -> String:
	var zona := _zona_do_jogador(lado, zona_nome)
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return "vazio"
	var m := zona[slot] as Dictionary
	var cid := str(m.get("card_id", ""))
	if not cid.is_empty() and _cartas.has(cid):
		return str((_cartas[cid] as Dictionary).get("name", cid))
	var nome := str(m.get("nome", cid))
	return nome if not nome.is_empty() else cid


func _resumo_slots() -> String:
	if _st == null:
		return "5 slots"
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	var vazios: Array = []
	var ocupados: Array = []
	for i in range(zona.size()):
		if zona[i] == null:
			vazios.append(str(i))
		else:
			ocupados.append("%d:%s" % [i, _nome_no_slot_lado(0, "monster", i)])
	var txt := "vazios %s" % ("+".join(vazios) if not vazios.is_empty() else "nenhum")
	if not ocupados.is_empty():
		txt += " | ocupados %s" % (" ".join(ocupados))
	return txt


func _carta_completa_do_campo(inst: Dictionary) -> Dictionary:
	var cid := str(inst.get("card_id", ""))
	var base: Dictionary = {}
	if not cid.is_empty() and _cartas.has(cid):
		base = (_cartas[cid] as Dictionary).duplicate(true)
	else:
		base = {"id": cid, "name": str(inst.get("nome", cid)), "card_type": "monster",
			"monster_type": "beast", "attribute": "earth",
			"attack": int(inst.get("atk", 0)), "defense": int(inst.get("def", 0))}
	if str(base.get("id", "")).is_empty():
		base["id"] = cid
	return base


func _flash_efeito() -> void:
	if _sem_render() or _flash_tela == null:
		return
	_flash_tela.modulate.a = 0.85
	var tw := _flash_tela.create_tween()
	tw.tween_property(_flash_tela, "modulate:a", 0.0, 0.4)


func _sacudir(no: Node3D) -> void:
	# D53: NUNCA a mesa inteira. `_no_cartas` é o guarda-chuva das 20+ cartas (as
	# 4 fileiras e as DUAS mãos), então sacudi-lo moveria as duas mãos e as
	# fileiras JUNTAS. A trava é AQUI dentro, e não no chamador, para nenhum
	# ponto novo do código reintroduzir o tremor da mesa inteira. E nunca um nó
	# que não existe.
	# Sem a trava de `_sem_render` de propósito: é um tween de 0,22 s que não
	# depende de render, e assim o GUT consegue ver se alguma coisa sacudiu.
	if no == null or not is_instance_valid(no) or no == _no_cartas:
		return
	var x0: float = no.position.x
	var tw := no.create_tween()
	tw.tween_property(no, "position:x", x0 - 0.25, 0.07)
	tw.tween_property(no, "position:x", x0 + 0.25, 0.07)
	tw.tween_property(no, "position:x", x0, 0.08)


func _achar_carta_campo(lado: int, zona_nome: String, slot: int) -> Node3D:
	var sid := "p%d_%s%d" % [lado, ("m" if zona_nome == "monster" else "s"), slot]
	for f in _no_cartas.get_children():
		if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == sid:
			return f as Node3D
	return null


# ---- JOGADAS (só chamam os sistemas reais e redesenham) ----

func _limpar_levantadas() -> void:
	# Tira índices inválidos (mão encolheu após invocar/fundir/comprar).
	if _st == null:
		_levantadas = []
		return
	var n: int = (((_st.players[0] as Dictionary)["hand"]) as Array).size()
	var novas: Array = []
	for h in _levantadas:
		if h is int and int(h) >= 0 and int(h) < n and not novas.has(int(h)):
			novas.append(int(h))
	_levantadas = novas


## 1) Confirmar carta monstro -> ela vai ao CENTRO e para (igual ao 2D).
func _fluxo_escolher_carta() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "MAIN":
		_fala("Invocação só na sua MAIN.")
		return
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if _col < 0 or _col >= mao.size():
		return
	var carta = mao[_col] as Dictionary
	if str(carta.get("card_type", "")) != "monster":
		_fala("Só monstro pode ser invocado.")
		return
	_mao_idx = _col
	_sel_atk = -1
	_face_baixo = false
	_combinando = false
	_sub_mao = SUB_FACE
	_mostrar_centro3d(false)
	_fala("Carta no centro. Esq/dir: face p/ cima / p/ baixo. Confirme.")
	_redesenhar(false)


## 2) Confirmar trava a face -> escolhe 1 dos 5 slots próprios.
func _fluxo_travar_face() -> void:
	if _mao_idx < 0:
		_sub_mao = SUB_MAO_ESCOLHA
		_redesenhar(false)
		return
	_sub_mao = SUB_SLOT
	_combinando = false
	_slot_alvo = -1
	_fileira = FILEIRA_MEU_M
	var livre := SummonSystem.free_monster_slot(_st, 0)
	_col = clampi(livre, 0, 4) if livre >= 0 else 0
	_fala("Face travada (%s). Escolha 1 dos 5 slots (%s)." % [("p/ baixo" if _face_baixo else "p/ cima"), _resumo_slots()])
	_redesenhar(false)


## 3) 1 dos 5 slots próprios (vazio OU ocupado) -> menu da estrela.
func _fluxo_escolher_slot() -> void:
	if _mao_idx < 0:
		_sub_mao = SUB_MAO_ESCOLHA
		_redesenhar(false)
		return
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	var slot := clampi(_col, 0, 4)
	if slot < 0 or slot >= zona.size():
		return
	_slot_alvo = slot
	_combinando = false
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if _mao_idx < 0 or _mao_idx >= mao.size():
		_fala("Carta saiu da mão.")
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_esconder_centro3d()
		_redesenhar(false)
		return
	_estrela_ops = _estrelas_da_carta(mao[_mao_idx] as Dictionary)
	_set_pad_popup_idx(0)
	_sub_mao = SUB_ESTRELA
	_mostrar_popup_estrela()
	if zona[slot] != null:
		_fala("Slot %d ocupado por %s: vai tentar fusão. Escolha a estrela." % [slot, _nome_no_slot_lado(0, "monster", slot)])
	else:
		_fala("Escolha 1 das 2 guardian stars.")
	_redesenhar(false)


## 4) Menu da estrela: 1 das 2 guardian stars -> desce em Ataque.
func _confirmar_estrela() -> void:
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	if _sub_mao != SUB_ESTRELA or _slot_alvo < 0:
		_esconder_popup()
		return
	if _combinando and _fusao_final.is_empty():
		_esconder_popup()
		return
	if not _combinando and _mao_idx < 0:
		_esconder_popup()
		return
	if _pad_popup_idx() == 2:
		_esconder_popup()
		_sub_mao = SUB_SLOT
		_fileira = FILEIRA_MEU_M
		_col = clampi(_slot_alvo, 0, 4)
		_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
		_redesenhar(false)
		return
	var estrela := str(_estrela_ops[clampi(_pad_popup_idx(), 0, 1)])
	if _combinando:
		_executar_fusao_fiel(estrela)
	else:
		_executar_summon_fiel(estrela)


## 5) Carta vai ao slot COM a face, SEMPRE em Ataque. Slot OCUPADO =
## encontro (try_fuse_pair real; falhou -> campo descartado e a da mão desce).
func _executar_summon_fiel(estrela: String) -> void:
	_esconder_popup()
	if _mao_idx < 0 or _slot_alvo < 0:
		return
	var hand_idx := _mao_idx
	var slot_n := _slot_alvo
	var face: bool = _face_baixo
	var p: Dictionary = _st.players[0] as Dictionary
	var mao: Array = p["hand"]
	var zona: Array = p["monster"]
	if hand_idx < 0 or hand_idx >= mao.size():
		_fala("Carta saiu da mão.")
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_slot_alvo = -1
		_esconder_centro3d()
		_fileira = FILEIRA_MAO
		_col = 0
		_redesenhar(false)
		return
	if slot_n < 0 or slot_n >= zona.size():
		_fala("Slot inválido.")
		return
	var carta_mao := (mao[hand_idx] as Dictionary).duplicate(true)
	if zona[slot_n] == null:
		var r: Dictionary = SummonSystem.normal_summon(_st, 0, hand_idx, slot_n, face, "ATK", estrela)
		if not bool(r.get("ok", false)):
			_fala("Não deu: " + str(r.get("erro", "")))
			_sub_mao = SUB_MAO_ESCOLHA
			_mao_idx = -1
			_slot_alvo = -1
			_esconder_centro3d()
			_fileira = FILEIRA_MAO
			_col = 0
			_redesenhar(false)
			return
		_fala("Invocou %s em Ataque (estrela %s)!" % [("virada p/ baixo" if face else "p/ cima"), estrela])
		_terminar_jogada_mao(slot_n)
		return
	if bool(_st.normal_summon_used):
		_fala("Não deu: Só 1 invocação normal por turno.")
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_slot_alvo = -1
		_esconder_centro3d()
		_fileira = FILEIRA_MAO
		_col = 0
		_redesenhar(false)
		return
	var ocupante := zona[slot_n] as Dictionary
	var nome_campo := _nome_no_slot_lado(0, "monster", slot_n)
	var campo_full := _carta_completa_do_campo(ocupante)
	var tent: Dictionary = FusionSystem.try_fuse_pair(campo_full, carta_mao, _fusions_data, _cartas)
	if bool(tent.get("ok", false)):
		var rid := str(tent.get("result_id", ""))
		var dado: Dictionary = (tent.get("result_card", {}) as Dictionary).duplicate(true) if (tent.get("result_card", {}) is Dictionary) else {}
		var real: Dictionary = (_cartas.get(rid, {}) as Dictionary) if _cartas.has(rid) else dado
		if str(real.get("card_type", dado.get("card_type", "monster"))) == "monster":
			mao.remove_at(hand_idx)
			zona[slot_n] = SummonSystem.construir_instancia(dado, face, "ATK", estrela, real, rid)
			_st.normal_summon_used = true
			_fala("Fusão com campo! %s + %s = %s." % [nome_campo, str(carta_mao.get("id", "?")), rid])
			_fala("Desceu %s em Ataque (estrela %s)!" % [("virada p/ baixo" if face else "p/ cima"), estrela])
		else:
			(p["graveyard"] as Array).append(str(ocupante.get("card_id", "")))
			mao.remove_at(hand_idx)
			zona[slot_n] = SummonSystem.construir_instancia(carta_mao, face, "ATK", estrela)
			_st.normal_summon_used = true
			_fala("Resultado %s não é monstro: %s descartado, a da mão desce." % [rid, nome_campo])
	else:
		(p["graveyard"] as Array).append(str(ocupante.get("card_id", "")))
		mao.remove_at(hand_idx)
		zona[slot_n] = SummonSystem.construir_instancia(carta_mao, face, "ATK", estrela)
		_st.normal_summon_used = true
		_fala("Não fundiu: %s descartado." % nome_campo)
		_fala("Desceu %s em Ataque (estrela %s)!" % [("virada p/ baixo" if face else "p/ cima"), estrela])
	_terminar_jogada_mao(slot_n)


func _terminar_jogada_mao(slot_n: int) -> void:
	_esconder_centro3d()
	_mao_idx = -1
	_slot_alvo = -1
	_combinando = false
	_estrela_ops = []
	_levantadas = []
	_sub_mao = SUB_MAO_ESCOLHA
	_duel.advance_phase() # MAIN -> BATTLE (igual ao 2D após descer).
	_fase_jogador = FASE_CAMPO
	_sel_atk = -1
	_fileira = FILEIRA_MEU_M
	_col = clampi(slot_n, 0, 4)
	# D53: aqui não houve compra nenhuma (a carta DESCEU da mão para o campo), e
	# sim a mão ficou com uma carta a menos — então nada anima. Antes isto era
	# `com_efeito = true` e a mão do jogador saía voando do baralho sozinha.
	_redesenhar(false)
	_flash_efeito()


## FUSÃO (2+ levantadas): escolhe o SLOT primeiro, depois fila + estrela.
func _iniciar_escolha_slot_fusao() -> void:
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	_limpar_levantadas()
	if _levantadas.size() < 2:
		return
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "MAIN":
		_fala("Fusão só na sua MAIN.")
		return
	if bool(_st.normal_summon_used):
		_fala("Só 1 jogada por turno (fusão conta como a jogada).")
		return
	_combinando = true
	_fusao_ordem = _levantadas.duplicate()
	_fusao_final = {}
	_fusao_descartes = []
	_fusao_passos = []
	_mao_idx = -1
	_sub_mao = SUB_SLOT
	_slot_alvo = -1
	_fileira = FILEIRA_MEU_M
	_col = 0
	_fala("Fusão: escolha 1 dos 5 slots (%s)." % _resumo_slots())
	_redesenhar(false)


func _fluxo_escolher_slot_fusao() -> void:
	if not _combinando:
		_fluxo_escolher_slot()
		return
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	_limpar_levantadas()
	var ordem: Array = _fusao_ordem.duplicate() if not _fusao_ordem.is_empty() else _levantadas.duplicate()
	if ordem.size() < 2:
		_fala("Fusão precisa de 2+ levantadas.")
		_combinando = false
		_sub_mao = SUB_MAO_ESCOLHA
		_redesenhar(false)
		return
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		_combinando = false
		_fusao_animando = false
		_redesenhar(false)
		return
	var slot := clampi(_col, 0, 4)
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	if slot < 0 or slot >= zona.size():
		return
	_slot_alvo = slot
	var mao_atual: Array = (_st.players[0] as Dictionary)["hand"]
	var em_ordem: Array = []
	for h in ordem:
		var hi := int(h)
		if hi >= 0 and hi < mao_atual.size() and (mao_atual[hi] is Dictionary):
			em_ordem.append((mao_atual[hi] as Dictionary).duplicate(true))
	if em_ordem.size() < 2:
		_fala("Cartas saíram da mão.")
		_combinando = false
		_sub_mao = SUB_MAO_ESCOLHA
		_slot_alvo = -1
		_redesenhar(false)
		return
	var previa: Dictionary = FusionSystem.resolve_chain(em_ordem, _fusions_data, _cartas)
	if not bool(previa.get("ok", false)):
		_fala("Não deu: " + str(previa.get("erro", "Fusão falhou.")))
		_combinando = false
		_sub_mao = SUB_MAO_ESCOLHA
		_slot_alvo = -1
		_redesenhar(false)
		return
	_fusao_animando = true
	await _animar_fila_fusao(previa.get("passos", []) as Array, slot)
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		_fusao_animando = false
		_combinando = false
		_redesenhar(false)
		return
	var final_card: Dictionary = (previa.get("final_card", {}) as Dictionary).duplicate(true)
	var final_id := str(previa.get("final_id", ""))
	var real: Dictionary = (_cartas.get(final_id, {}) as Dictionary) if _cartas.has(final_id) else final_card
	if str(real.get("card_type", final_card.get("card_type", "monster"))) != "monster":
		_fusao_animando = false
		_combinando = false
		_slot_alvo = -1
		_fala("Equip ainda sem tabela: resultado %s não desce (pendente)." % final_id)
		_fileira = FILEIRA_MAO
		_col = 0
		_sub_mao = SUB_MAO_ESCOLHA
		_redesenhar(false)
		return
	_fusao_final = final_card
	if str(_fusao_final.get("id", "")).is_empty():
		_fusao_final["id"] = final_id
	_fusao_descartes = (previa.get("descartes", []) as Array).duplicate()
	_fusao_passos = (previa.get("passos", []) as Array).duplicate()
	for p in _fusao_passos:
		if not (p is Dictionary):
			continue
		var pd: Dictionary = p as Dictionary
		var tipo_p := str(pd.get("tipo", ""))
		if tipo_p == "receita" or tipo_p == "regra":
			_fala("Fusão! %s + %s = %s." % [str(pd.get("a", "")), str(pd.get("b", "")), str(pd.get("result_id", ""))])
		elif tipo_p == "equip_pendente":
			_fala("Equip pendente: %s + %s não fundiu." % [str(pd.get("a", "")), str(pd.get("b", ""))])
		else:
			_fala("Não fundiu: %s + %s (descarta %s)." % [str(pd.get("a", "")), str(pd.get("b", "")), str(pd.get("a", ""))])
	if _fusao_descartes.size() > 0:
		_fala("%d acumulada(s) ao cemitério." % _fusao_descartes.size())
	_fusao_animando = false
	_estrela_ops = _estrelas_da_carta(_fusao_final)
	_set_pad_popup_idx(0)
	_sub_mao = SUB_ESTRELA
	_mostrar_popup_estrela()
	if zona[slot] != null:
		_fala("FINAL %s no slot %d ocupado por %s: escolha a estrela." % [final_id, slot, _nome_no_slot_lado(0, "monster", slot)])
	else:
		_fala("FINAL %s: escolha 1 das 2 guardian stars." % final_id)
	_redesenhar(false)


## FINAL desce ao slot face-up em Ataque (com a estrela do menu).
func _executar_fusao_fiel(estrela: String) -> void:
	_esconder_popup()
	if not _combinando or _fusao_final.is_empty() or _slot_alvo < 0:
		return
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		return
	if bool(_st.normal_summon_used):
		_fala("Não deu: Só 1 jogada por turno.")
		_combinando = false
		_fusao_final = {}
		_sub_mao = SUB_MAO_ESCOLHA
		_slot_alvo = -1
		_redesenhar(false)
		return
	var ordem: Array = _fusao_ordem.duplicate() if not _fusao_ordem.is_empty() else _levantadas.duplicate()
	var p: Dictionary = _st.players[0] as Dictionary
	var mao: Array = p["hand"]
	var zona: Array = p["monster"]
	var slot_n := _slot_alvo
	for h in ordem:
		var hi := int(h)
		if hi < 0 or hi >= mao.size():
			_fala("Cartas saíram da mão.")
			_combinando = false
			_fusao_final = {}
			_sub_mao = SUB_MAO_ESCOLHA
			_slot_alvo = -1
			_redesenhar(false)
			return
	var final_id := str(_fusao_final.get("id", ""))
	if final_id.is_empty():
		final_id = str(_fusao_final.get("card_id", "?"))
	var final_carta := _fusao_final.duplicate(true)
	final_carta["id"] = final_id
	var para_tirar: Array = ordem.duplicate()
	para_tirar.sort()
	para_tirar.reverse()
	for h in para_tirar:
		mao.remove_at(int(h))
	for d in _fusao_descartes:
		(p["graveyard"] as Array).append(str(d))
	var descer_id := final_id
	var descer_carta := final_carta.duplicate(true)
	if zona[slot_n] != null:
		var nome_campo := _nome_no_slot_lado(0, "monster", slot_n)
		var campo_full := _carta_completa_do_campo(zona[slot_n] as Dictionary)
		var tent: Dictionary = FusionSystem.try_fuse_pair(campo_full, final_carta, _fusions_data, _cartas)
		if bool(tent.get("ok", false)):
			var rid := str(tent.get("result_id", ""))
			var dado: Dictionary = (tent.get("result_card", {}) as Dictionary).duplicate(true) if (tent.get("result_card", {}) is Dictionary) else {}
			var real2: Dictionary = (_cartas.get(rid, {}) as Dictionary) if _cartas.has(rid) else dado
			if str(real2.get("card_type", dado.get("card_type", "monster"))) == "monster":
				descer_id = rid
				descer_carta = dado.duplicate(true) if not dado.is_empty() else real2.duplicate(true)
				descer_carta["id"] = rid
				_fala("Fusão com campo! %s + %s = %s." % [nome_campo, final_id, rid])
			else:
				(p["graveyard"] as Array).append(str((zona[slot_n] as Dictionary).get("card_id", "")))
				_fala("Resultado %s não é monstro: %s descartado, a FINAL desce." % [rid, nome_campo])
		else:
			(p["graveyard"] as Array).append(str((zona[slot_n] as Dictionary).get("card_id", "")))
			_fala("Não fundiu com campo: %s descartado." % nome_campo)
	var real_f: Dictionary = (_cartas.get(descer_id, {}) as Dictionary) if _cartas.has(descer_id) else descer_carta
	zona[slot_n] = SummonSystem.construir_instancia(descer_carta, false, "ATK", estrela, real_f, descer_id)
	_st.normal_summon_used = true
	_fala("Fundiu %s em Ataque p/ cima (estrela %s)!" % [descer_id, estrela])
	_combinando = false
	_fusao_ordem = []
	_fusao_final = {}
	_fusao_descartes = []
	_fusao_passos = []
	_levantadas = []
	_mao_idx = -1
	_sel_atk = -1
	_slot_alvo = -1
	_estrela_ops = []
	_esconder_centro3d()
	_sub_mao = SUB_MAO_ESCOLHA
	_duel.advance_phase()
	_fase_jogador = FASE_CAMPO
	_fileira = FILEIRA_MEU_M
	_col = clampi(slot_n, 0, 4)
	_redesenhar(false) # D53: descida da carta, não é compra -> não anima.
	_flash_efeito()


## Fila da fusão (só visual + som, sem regra): mostra cada passo no HUD
## com flash no sucesso e chacoalhada na falha. Headless: só prints.
## D53: a chacoalhada é do SLOT onde a carta desceu, e NUNCA da mesa inteira —
## `_no_cartas` é o guarda-chuva de TODAS as cartas (as 4 fileiras e as DUAS
## mãos), então sacudi-lo move as duas mãos e as fileiras JUNTAS.
func _animar_fila_fusao(passos: Array, slot_n: int) -> void:
	_fusao_passos = (passos as Array).duplicate()
	_redesenhar(false)
	if _sem_render():
		for p in _fusao_passos:
			if p is Dictionary:
				_diag("Fusão: %s + %s = %s." % [str((p as Dictionary).get("a", "?")), str((p as Dictionary).get("b", "?")), str((p as Dictionary).get("result_id", "?"))])
		return
	for p in _fusao_passos:
		if not (p is Dictionary):
			continue
		var pd: Dictionary = p as Dictionary
		_redesenhar(false)
		if str(pd.get("tipo", "")) == "receita" or str(pd.get("tipo", "")) == "regra":
			_flash_efeito()
		else:
			# D53: só a carta do slot treme (e `_sacudir` já ignora o vazio).
			_sacudir(_achar_carta_campo(0, "monstro", slot_n))
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return


func _atacar3d(alvo_slot: int) -> void:
	var r: Dictionary = BattleSystem.attack(_st, 0, _sel_atk, 1, alvo_slot)
	if not bool(r.get("ok", false)):
		_fala("Não deu: " + str(r.get("erro", "")))
		_sel_atk = -1
		_redesenhar(false)
		return
	# Voo de ataque (só visual): avança e volta.
	var no_atk := _achar_carta_campo(0, "monster", _sel_atk)
	if no_atk != null and not _sem_render():
		var p0: Vector3 = no_atk.position
		var tw := no_atk.create_tween()
		tw.tween_property(no_atk, "position", p0 + Vector3(0, 0.4, -1.2), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(no_atk, "position", p0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return
	if bool(r.get("direto", false)):
		_fala("Direto! %d de dano no rival." % int(r.get("dano", 0)))
	elif bool(r.get("destruiu_alvo", false)) and bool(r.get("destruiu_atacante", false)):
		_fala("Empate: os dois caíram.")
	elif bool(r.get("destruiu_alvo", false)):
		_fala("Destruiu! %d de dano no rival." % int(r.get("dano", 0)))
	elif bool(r.get("destruiu_atacante", false)):
		_fala("Seu monstro caiu! %d de dano em você." % int(r.get("dano", 0)))
	else:
		_fala("Nada acontece.")
	_flash_efeito()
	_sel_atk = -1
	_redesenhar(false)


func _rival_auto() -> void:
	# Rival automático simples (padrão do main.gd: invoca + ataca com o
	# núcleo real). A escolha fina da IA mora no 2D; aqui é só p/ testar.
	# É o MESMO caminho tanto quando o jogador aperta START e passa o turno
	# quanto quando o RIVAL COMEÇOU o duelo: em ambos os casos aqui o turno
	# do rival entra em DRAW, e este é quem o conduz até a vez voltar a ser
	# do jogador. Regra nenhuma mora aqui — quem decide fase, compra, turno
	# e vencedor é o motor (DuelManager/TurnManager/Summon/Battle/Damage).
	if not is_inside_tree() or _st == null:
		return
	# Trava de reentrada: o turno do rival é conduzido UMA vez por vez. Sem
	# isto, duas chamadas (início do duelo + START) fariam o turno dele
	# rodar duas vezes em paralelo.
	if _rival_rodando:
		return
	_rival_rodando = true
	# D47: se a mesa ainda está na SUA visão (o caso do RIVAL COMEÇAR o duelo),
	# dá a volta antes dele jogar. No caminho normal (START) a volta já foi
	# feita, então aqui não acontece nada.
	await _girar_campo(180.0)
	if not is_inside_tree():
		_rival_rodando = false
		return
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree() or bool(_st.over):
		_rival_rodando = false
		_redesenhar(false)
		return
	_duel.advance_phase() # -> MAIN do rival
	_redesenhar(false) # a barra de fases mostra a fase REAL (não a anterior)
	var mao: Array = (_st.players[1] as Dictionary)["hand"]
	var idx := -1
	for i in range(mao.size()):
		if str((mao[i] as Dictionary).get("card_type", "")) == "monster":
			idx = i
			break
	var slot := SummonSystem.free_monster_slot(_st, 1)
	if idx >= 0 and slot >= 0:
		var r: Dictionary = SummonSystem.normal_summon(_st, 1, idx, slot, false, "ATK")
		if bool(r.get("ok", false)):
			_fala("Rival invocou %s em Ataque." % str((r.get("nome", (mao[idx] as Dictionary).get("name", "um monstro")) as String)))
	elif mao.is_empty():
		_fala("Rival está com a mão vazia neste turno.")
	else:
		_fala("Rival não tem monstro na mão para invocar.")
	# D53: a compra do turno é DELE, então a animação da compra é da mão DELE
	# (que, com a D52, é o lugar de baixo da tela dele). Antes esta chamada
	# animava a MÃO DO JOGADOR, que na tela do rival é o lugar de cima: as
	# cartas dela saíam do baralho e atravessavam o campo voando.
	_redesenhar(true, 1)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree() or bool(_st.over):
		_rival_rodando = false
		_redesenhar(false)
		return
	_duel.advance_phase() # MAIN -> BATTLE
	_redesenhar(false)
	var atacou := false
	var zona: Array = (_st.players[1] as Dictionary)["monster"]
	for s in range(zona.size()):
		if bool(_st.over):
			break
		if zona[s] == null:
			continue
		var alvo: int = BattleSystem.first_monster_slot(_st, 0)
		var ra: Dictionary = BattleSystem.attack(_st, 1, s, 0, alvo)
		if not bool(ra.get("ok", false)):
			continue
		atacou = true
		if bool(ra.get("direto", false)):
			_fala("Rival direto: %d em você!" % int(ra.get("dano", 0)))
		elif bool(ra.get("destruiu_alvo", false)):
			_fala("Rival destruiu seu monstro (%d de dano)." % int(ra.get("dano", 0)))
		elif bool(ra.get("destruiu_atacante", false)):
			_fala("Rival quebrou a cara no seu monstro!")
		else:
			_fala("Rival atacou: nada acontece.")
		_redesenhar(false)
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			_rival_rodando = false
			return
	if not atacou:
		_fala("Rival não atacou neste turno.")
	if bool(_st.over):
		_rival_rodando = false
		_fala("Duelo acabou!")
		_redesenhar(false)
		return
	_duel.advance_phase() # BATTLE -> END
	_redesenhar(false)
	# D47: a volta DE VOLTA, para a tela voltar a ser a do jogador. Entra
	# ANTES de abrir o fluxo dele, para o primeiro cardápio já nascer na tela
	# certa e o jogador não ver a mão dele de lado nenhum.
	await _girar_campo(0.0)
	if not is_inside_tree():
		_rival_rodando = false
		return
	_levar_vez_para_o_jogador()
	_rival_rodando = false


## ENTREGA DE VEZ: leva a máquina de fases até a MAIN do JOGADOR e só aí
## abre o fluxo dele (carta ao centro -> face -> slot -> estrela, D24).
## É a trava de progresso do bug reportado: o turno do rival SEMPRE volta
## para `current_player == 0`. Avança pelo `advance_phase` do motor (nada de
## fase forçada aqui) e com teto de passos, para nunca travar a tela.
func _levar_vez_para_o_jogador() -> void:
	# Entrega de vez: avança a máquina de fases pelo `advance_phase` do MOTOR
	# até a MAIN do JOGADOR e só aí abre o fluxo dele. Parar só em
	# "current_player == 0" não bastava: o END entrega a vez já no DRAW (com o
	# refill até 5 do TurnManager, D26), e o jogador tem de receber na MAIN
	# para poder jogar. Teto de passos, para nunca travar a tela.
	var guarda := 0
	while not bool(_st.over) and guarda < 12:
		if int(_st.current_player) == 0 and String(_st.phase) == "MAIN":
			break
		_duel.advance_phase()
		guarda += 1
	if bool(_st.over):
		_fala("Duelo acabou!")
		_redesenhar(false)
		return
	# Fala a FASE REAL em que o jogador entrou (doc 13: a fase é do motor).
	_fala("Sua vez! %s, turno %d. Mão com %d carta(s)." % [
		_rotulo_fase_pt(String(_st.phase)), int(_st.turn_number),
		((_st.players[0] as Dictionary)["hand"] as Array).size()])
	_sel_atk = -1
	_fase_jogador = FASE_MAO
	_sub_mao = SUB_MAO_ESCOLHA
	_mao_idx = -1
	_slot_alvo = -1
	_combinando = false
	_levantadas = []
	_esconder_popup()
	_esconder_centro3d()
	_fileira = FILEIRA_MAO
	_col = 0
	_redesenhar(true, 0) # D53: a compra do turno é a SUA, então a animação é da sua mão.
	_atualizar_hud()


## Nome da fase em PT-BR para a fala (o valor vem do motor, isto é só o
## rótulo em português — não inventa fase, não inventa dado).
func _rotulo_fase_pt(fase: String) -> String:
	match fase:
		"DRAW":
			return "Sorteio/compra"
		"MAIN":
			return "Principal"
		"BATTLE":
			return "Batalha"
		"END":
			return "Final"
	return fase


func _passar_turno() -> void:
	if int(_st.current_player) != 0 or bool(_st.over):
		return
	if String(_st.phase) == "DRAW":
		_fala("Aguarde a fase passar.")
		return
	# START na fase da mão não faz nada (igual ao 2D: tem que descer 1 carta).
	if _fase_jogador == FASE_MAO and String(_st.phase) == "MAIN":
		_fala("Desça 1 carta antes de passar (START bloqueado na fase da mão).")
		return
	if _popup_aberto():
		_fala("Feche o menu antes de passar.")
		return
	_sel_atk = -1
	_esconder_popup()
	_esconder_centro3d()
	_mao_idx = -1
	_slot_alvo = -1
	_combinando = false
	_levantadas = []
	_sub_mao = SUB_MAO_ESCOLHA
	var dono := int(_st.current_player)
	var guarda := 0
	while int(_st.current_player) == dono and not bool(_st.over) and guarda < 8:
		_duel.advance_phase()
		guarda += 1
	if bool(_st.over):
		_redesenhar(false)
		return
	_fala("Turno do rival... (START)")
	_redesenhar(false)
	# D47: A VOLTA DA MESA. A câmera dá a volta de 180° em torno do centro do
	# campo e a tela passa a ser a visão DO RIVAL. As cartas não se mexem (é a
	# câmera que anda), e o START só segue depois que a volta acaba — o giro
	# não pula (D46b: não existe pular a volta).
	await _girar_campo(180.0)
	if not is_inside_tree():
		return
	_rival_auto()


# ---- CONTROLE (D19: só as 11 ações joypad) ----

func _larg_fileira(f: int) -> int:
	match f:
		FILEIRA_MAO:
			if _st == null:
				return 1
			return maxi((((_st.players[0] as Dictionary)["hand"]) as Array).size(), 1)
		FILEIRA_MEU_M, FILEIRA_MEU_S, FILEIRA_RIVAL_M, FILEIRA_RIVAL_S:
			return 5
	return 1


## Vizinho por POSIÇÃO visível (igual ao 2D): direita sempre anda p/ a
## direita que se vê. Anda pelo X de TELA do slot como ele é DESENHADO agora
## (`_x_do_slot`, que já passa pela perspectiva), nunca pelo índice: o espelho
## do D18 e a troca de perspectiva do doc 16 viram a ordem visível, e quem
## decide isso tem que ser a MESMA função que desenha.
func _vizinho3d(lado: int, tipo: String, col_atual: int, dx: int) -> int:
	var atual := _pos_slotx(lado, tipo, clampi(col_atual, 0, 4))
	var melhor := clampi(col_atual, 0, 4)
	var melhor_dist := 1e20
	var achou := false
	for i in range(5):
		if i == clampi(col_atual, 0, 4):
			continue
		var delta := _pos_slotx(lado, tipo, i) - atual
		if dx > 0 and delta > 0.001 and absf(delta) < melhor_dist:
			melhor_dist = absf(delta)
			melhor = i
			achou = true
		elif dx < 0 and delta < -0.001 and absf(delta) < melhor_dist:
			melhor_dist = absf(delta)
			melhor = i
			achou = true
	if achou:
		return melhor
	if dx > 0:
		var minx := 1e20
		var mini_idx := clampi(col_atual, 0, 4)
		for i in range(5):
			var cx := _pos_slotx(lado, tipo, i)
			if cx < minx:
				minx = cx
				mini_idx = i
		return mini_idx
	var maxx := -1e20
	var maxi_idx := clampi(col_atual, 0, 4)
	for i in range(5):
		var cx2 := _pos_slotx(lado, tipo, i)
		if cx2 > maxx:
			maxx = cx2
			maxi_idx = i
	return maxi_idx


func _lado_tipo_da_fileira(f: int) -> Array:
	match f:
		FILEIRA_RIVAL_S:
			return [1, "magia"]
		FILEIRA_RIVAL_M:
			return [1, "monstro"]
		FILEIRA_MEU_M:
			return [0, "monstro"]
		FILEIRA_MEU_S:
			return [0, "magia"]
	return []


func _mover(dx: int, dy: int) -> void:
	if _st == null or bool(_st.over):
		return
	# Menu central (estrela ou alvo): só cima/baixo troca a opção.
	if _popup_aberto():
		if dy != 0:
			var max_idx := 1
			if _popup_modo() == "estrela":
				max_idx = 2
				if _estrela_ops.size() < 2:
					max_idx = 1
			else:
				max_idx = 1
			_set_pad_popup_idx(posmod(_pad_popup_idx() + dy, max_idx + 1))
			_atualizar_menus()
			_redesenhar(false)
		return
	var meu_turno: bool = int(_st.current_player) == 0
	# FASE DA MÃO (seu MAIN): trava total, igual ao 2D.
	if _fase_jogador == FASE_MAO and meu_turno and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_FACE:
				if dx != 0:
					_face_baixo = not _face_baixo
					_atualizar_centro_face()
					_fala("Face p/ baixo." if _face_baixo else "Face p/ cima.")
					_redesenhar(false)
				return
			SUB_SLOT, SUB_ESTRELA:
				if dx != 0:
					_fileira = FILEIRA_MEU_M
					_col = _vizinho3d(0, "monstro", _col, dx)
					_redesenhar(false)
				return
			_:
				if dy < 0:
					_fileira = FILEIRA_MAO
					_levantar3d(clampi(_col, 0, maxi(_larg_fileira(_fileira) - 1, 0)))
					return
				if dy > 0:
					_fileira = FILEIRA_MAO
					_abaixar3d(clampi(_col, 0, maxi(_larg_fileira(_fileira) - 1, 0)))
					return
				if dx != 0:
					_fileira = FILEIRA_MAO
					var larg := _larg_fileira(_fileira)
					if larg > 1:
						_col = posmod(_col + dx, larg)
						# D53: andar na mão NÃO é redesenho. `_redesenhar`
						# destrói e recria as 20+ cartas 3D (com `queue_free`),
						# e o que muda aqui é só o cursor e o painel da esquerda.
						# Redesenhar tudo por passo de cursor é o que fazia a
						# mão do outro lado da mesa "se mexer junto" (o desenho
						# inteiro é refeito a cada tecla) e custava caro.
						_posicionar_cursor()
						_atualizar_painel_foco()
				return
	# FASE DE CAMPO (seu turno): SÓ os 20 slots (igual ao 2D: sem LP e sem mão).
	if _fase_jogador == FASE_CAMPO and meu_turno:
		if _lado_tipo_da_fileira(_fileira).is_empty():
			_fileira = FILEIRA_MEU_M
			_col = clampi(_col, 0, 4)
		if dx != 0:
			var lt := _lado_tipo_da_fileira(_fileira)
			_col = _vizinho3d(int(lt[0]), str(lt[1]), _col, dx)
			_posicionar_cursor()
			_redesenhar(false)
		if dy != 0:
			var idx := ORDEM_CAMPO_3D.find(_fileira)
			if idx < 0:
				idx = ORDEM_CAMPO_3D.find(FILEIRA_MEU_M)
			var novo_idx := clampi(idx + dy, 0, ORDEM_CAMPO_3D.size() - 1)
			if novo_idx != idx:
				var nova := int(ORDEM_CAMPO_3D[novo_idx])
				# Preserva a COLUNA VISÍVEL (X de tela, igual ao 2D).
				var atual_x := _pos_slotx(int((_lado_tipo_da_fileira(_fileira) as Array)[0]), str((_lado_tipo_da_fileira(_fileira) as Array)[1]), clampi(_col, 0, 4))
				var mln := int((_lado_tipo_da_fileira(nova) as Array)[0])
				var mlt := str((_lado_tipo_da_fileira(nova) as Array)[1])
				var melhor := 0
				var melhor_dist := 1e20
				for i in range(5):
					var d := absf(_pos_slotx(mln, mlt, i) - atual_x)
					if d < melhor_dist:
						melhor_dist = d
						melhor = i
				_fileira = nova
				_col = melhor
				_posicionar_cursor()
				_redesenhar(false)
		return
	# Fora do seu fluxo (vez do rival): cursor anda livre p/ observar.
	if dx != 0:
		var lt2 := _lado_tipo_da_fileira(_fileira)
		if not lt2.is_empty():
			_col = _vizinho3d(int(lt2[0]), str(lt2[1]), _col, dx)
		else:
			_col = posmod(_col + dx, _larg_fileira(_fileira))
		_posicionar_cursor()
		_redesenhar(false)
		return
	if dy != 0:
		var idx2 := ORDEM_FILEIRAS.find(_fileira)
		if idx2 < 0:
			idx2 = 0
		var novo2 := clampi(idx2 + dy, 0, ORDEM_FILEIRAS.size() - 1)
		if novo2 != idx2:
			_fileira = int(ORDEM_FILEIRAS[novo2])
			_col = clampi(_col, 0, _larg_fileira(_fileira) - 1)
			_posicionar_cursor()
			_redesenhar(false)


## Levantar p/ fusão (só controle/visual, sem regra): selo 1,2,3 na ordem.
func _levantar3d(hand_idx: int) -> void:
	_limpar_levantadas()
	if _levantadas.has(hand_idx):
		return
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if hand_idx < 0 or hand_idx >= mao.size():
		return
	_levantadas.append(hand_idx)
	_fala("Levantada %d (%d p/ fundir)." % [_levantadas.size(), _levantadas.size()])
	_redesenhar(false)


func _abaixar3d(hand_idx: int) -> void:
	_limpar_levantadas()
	if not _levantadas.has(hand_idx):
		return
	_levantadas.erase(hand_idx)
	_fala("Abaixou. Restam %d levantadas." % _levantadas.size())
	_redesenhar(false)


func _confirmar() -> void:
	if _st == null:
		return
	if bool(_st.over):
		get_tree().reload_current_scene()
		return
	if _popup_aberto():
		if _popup_modo() == "alvo":
			_confirmar_alvo_menu()
		else:
			_confirmar_estrela()
		return
	if int(_st.current_player) != 0:
		_fala("Aguarde o rival.")
		return
	# FASE DA MÃO: avulsa = centro -> face -> slot -> estrela;
	# 1 levantada bloqueia; 2+ = fusão (slot primeiro, depois fila+estrela).
	if _fase_jogador == FASE_MAO and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_MAO_ESCOLHA:
				_limpar_levantadas()
				if _levantadas.size() == 1:
					_fala("Só 1 levantada: levante +1 p/ fundir ou abaixe p/ invocar avulsa.")
					return
				if _levantadas.size() >= 2:
					_iniciar_escolha_slot_fusao()
					return
				_fileira = FILEIRA_MAO
				_fluxo_escolher_carta()
				return
			SUB_FACE:
				_fluxo_travar_face()
				return
			SUB_SLOT:
				if _combinando:
					_fluxo_escolher_slot_fusao()
				else:
					_fluxo_escolher_slot()
				return
			SUB_ESTRELA:
				_fala("Escolha a estrela no menu.")
				return
		return
	# FASE DE CAMPO: SÓ os 20 slots (igual ao 2D, sem LP e sem mão).
	if _fase_jogador == FASE_CAMPO:
		match _fileira:
			FILEIRA_MEU_M:
				_confirmar_meu_campo3d()
				return
			FILEIRA_MEU_S:
				_fala("Magia: sem ação na mesa (só navega).")
				return
			FILEIRA_RIVAL_M:
				_confirmar_alvo_rival3d(clampi(_col, 0, 4))
				return
			FILEIRA_RIVAL_S:
				_confirmar_alvo_rival_magia3d()
				return
			_:
				_fala("Fase de campo: use os 20 slots do campo.")
		return


func _confirmar_meu_campo3d() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	var slot := clampi(_col, 0, 4)
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		_fala("Slot vazio, sem atacante.")
		return
	var pode: Dictionary = BattleSystem.can_attack(_st, 0, slot)
	if not bool(pode.get("ok", false)):
		_sel_atk = -1
		_fala("Não pode atacar: " + str(pode.get("erro", "")))
		_redesenhar(false)
		return
	_sel_atk = slot
	_fala("Atacante escolhido. Mire no campo rival.")
	_fileira = FILEIRA_RIVAL_M
	_posicionar_cursor()
	_redesenhar(false)


func _confirmar_alvo_rival3d(alvo_slot: int) -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		return
	# Campo rival vazio -> menu de alvo oferece o LP (igual ao 2D).
	if not BattleSystem.has_monsters(_st, 1):
		_mostrar_popup_alvo()
		_fala("Rival sem monstros: mire no LP p/ ataque direto.")
		_redesenhar(false)
		return
	var zr: Array = (_st.players[1] as Dictionary)["monster"]
	var alvo := clampi(alvo_slot, 0, 4)
	if alvo < 0 or alvo >= zr.size() or zr[alvo] == null:
		_fala("Escolha um monstro rival (slot vazio).")
		return
	_atacar3d(alvo)


func _confirmar_alvo_rival_magia3d() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		return
	if not BattleSystem.has_monsters(_st, 1):
		_mostrar_popup_alvo()
		_fala("Rival sem monstros: mire no LP p/ ataque direto.")
		_redesenhar(false)
		return
	_fala("Magia não é alvo: mire num monstro rival.")


func _confirmar_alvo_menu() -> void:
	if _popup_modo() != "alvo":
		return
	if _pad_popup_idx() == 1:
		_esconder_popup()
		_fala("Ataque direto cancelado. Mire de novo.")
		_redesenhar(false)
		return
	_esconder_popup()
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		_redesenhar(false)
		return
	if BattleSystem.has_monsters(_st, 1):
		_fala("Rival tem monstros: direto bloqueado.")
		_redesenhar(false)
		return
	_atacar3d(-1)


func _cancelar() -> void:
	if _st == null:
		return
	# Fusão animando: nenhum cancelar reescreve o fluxo (igual ao 2D).
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	if _popup_aberto():
		if _popup_modo() == "alvo":
			_esconder_popup()
			_fala("Ataque direto cancelado. Mire de novo.")
			_redesenhar(false)
			return
		_esconder_popup()
		if _fase_jogador == FASE_MAO and _sub_mao == SUB_ESTRELA:
			_sub_mao = SUB_SLOT
			_fileira = FILEIRA_MEU_M
			_col = clampi(_slot_alvo, 0, 4)
			_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
			_redesenhar(false)
			return
		_fala("Invocação cancelada.")
		_redesenhar(false)
		return
	if _fase_jogador == FASE_MAO and int(_st.current_player) == 0:
		match _sub_mao:
			SUB_MAO_ESCOLHA:
				if not _levantadas.is_empty():
					var ultima := int(_levantadas.back())
					_levantadas.pop_back()
					_fala("Abaixou a última. Restam %d levantadas." % _levantadas.size())
					_redesenhar(false)
					return
			SUB_ESTRELA:
				_sub_mao = SUB_SLOT
				_fileira = FILEIRA_MEU_M
				_col = clampi(_slot_alvo, 0, 4)
				_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
				_redesenhar(false)
				return
			SUB_SLOT:
				if _combinando:
					_combinando = false
					_fusao_ordem = []
					_fusao_final = {}
					_fusao_descartes = []
					_fusao_passos = []
					_slot_alvo = -1
					_sub_mao = SUB_MAO_ESCOLHA
					_fileira = FILEIRA_MAO
					_col = 0
					_fala("Fusão cancelada. Escolha de novo.")
					_redesenhar(false)
					return
				_sub_mao = SUB_FACE
				_fileira = FILEIRA_MAO
				_col = clampi(_mao_idx, 0, maxi(_larg_fileira(FILEIRA_MAO) - 1, 0))
				_fala("Face de novo: esq/dir.")
				_redesenhar(false)
				return
			SUB_FACE:
				_sub_mao = SUB_MAO_ESCOLHA
				_mao_idx = -1
				_sel_atk = -1
				_esconder_centro3d()
				_fileira = FILEIRA_MAO
				_fala("Escolha desfeita.")
				_redesenhar(false)
				return
	if _sel_atk >= 0:
		_sel_atk = -1
		_fala("Ataque desfeito.")
		_redesenhar(false)


func _alternar_posicao() -> void:
	if _st == null or bool(_st.over) or int(_st.current_player) != 0:
		return
	# Só no campo (fase de campo, carta própria), igual ao 2D.
	if _fase_jogador != FASE_CAMPO or _fileira != FILEIRA_MEU_M:
		_fala("Mire numa carta sua p/ trocar Ataque/Defesa.")
		return
	var r: Dictionary = PositionSystem.toggle_position(_st, 0, clampi(_col, 0, 4))
	if not bool(r.get("ok", false)):
		_fala("Não deu: " + str(r.get("erro", "")))
		return
	_fala("Agora em %s." % ("Ataque" if str(r.get("position", "ATK")) == "ATK" else "Defesa"))
	_redesenhar(false)


func _detalhes() -> void:
	if _st == null:
		return
	var txt := "Detalhes: "
	if _fileira == FILEIRA_MAO:
		var mao: Array = (_st.players[0] as Dictionary)["hand"]
		var i := clampi(_col, 0, maxi(int(mao.size()) - 1, 0))
		if i >= 0 and i < mao.size():
			var c := mao[i] as Dictionary
			var ops := _estrelas_da_carta(c)
			txt += "%s A%d/D%d estrela %s/%s" % [str(c.get("name", "?")), int(c.get("attack", 0)), int(c.get("defense", 0)), str(ops[0]), str(ops[1])]
	else:
		var lt := _lado_tipo_da_fileira(_fileira)
		if not lt.is_empty():
			txt += _texto_inst_slot(int(lt[0]), str(lt[1]), clampi(_col, 0, 4))
		else:
			txt += "slot %d fileira %d" % [_col, _fileira]
	_fala(txt)


func _auto_passa() -> void:
	# D46 (PROVA, não jogabilidade): passa a vez pelo MESMO caminho do START.
	# A fase da mão trava o START de propósito (D24/D26: tem que descer as 5
	# cartas), então aqui o motor é levado até a MAIN do jogador primeiro — o
	# `advance_phase` é o do motor, nada é forçado.
	if _st == null or bool(_st.over):
		return
	var guarda := 0
	while int(_st.current_player) == 0 and String(_st.phase) != "MAIN" and guarda < 8:
		_duel.advance_phase()
		guarda += 1
	_fase_jogador = FASE_CAMPO
	_passar_turno()


func _process(delta: float) -> void:
	# A CÂMERA não é mexida aqui. Quem se mexe é o PIVÔ, e só na volta da
	# mesa (`_girar_campo`): a inclinação é a rotação local da câmera dentro do
	# pivô (D47), então um `look_at` por frame brigaria com o giro.
	# O cursor segue pulsando (é o único movimento próprio da tela).
	_pulso += delta * 4.0
	if _vista.girando:
		_aplicar_vista_hud()
	if not _foto_destino.is_empty():
		_foto_frames += 1
		if _auto_passa_espera >= 0.0:
			_auto_passa_espera += delta
			if _auto_passa_espera >= _auto_passa_em:
				_auto_passa_espera = -1.0
				_auto_passa()
		if _foto_frames >= _foto_frame_alvo:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_foto_destino)
			_diag("Foto salva (quadro %d, volta %.0f graus): %s" % [
				_foto_frames, _vista.giro_campo, _foto_destino])
			get_tree().quit()
	if _cursor != null and is_instance_valid(_cursor):
		var s := 1.0 + 0.04 * sin(_pulso)
		_cursor.scale = Vector3(s, 1.0, s)
	if _st == null:
		return
	# Repetição do direcional (igual ao 2D). D47: nada de andar o cursor
	# enquanto a mesa está girando.
	var dx := 0
	var dy := 0
	if not _vista.girando:
		if Input.is_action_pressed("mover_esq"):
			dx -= 1
		if Input.is_action_pressed("mover_dir"):
			dx += 1
		if Input.is_action_pressed("mover_cima"):
			dy -= 1
		if Input.is_action_pressed("mover_baixo"):
			dy += 1
	var desejado := Vector2i(dx, dy)
	if desejado == Vector2i.ZERO:
		_pad_dir = Vector2i.ZERO
		_pad_tempo = 0.0
		return
	if desejado != _pad_dir:
		_pad_dir = desejado
		_pad_tempo = 0.0
		_mover(desejado.x, desejado.y)
		return
	_pad_tempo += delta
	if _pad_tempo >= PAD_REPETE:
		_pad_tempo = 0.0
		_mover(desejado.x, desejado.y)


func _unhandled_input(evento: InputEvent) -> void:
	# D47: com a mesa girando, o controle fica TRAVADO. Sem isto a carta focada
	# andaria de um lado para o outro da tela no meio do giro, e um START
	# passando por cima da volta quebraria a sequência.
	if _vista.girando:
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("confirmar"):
		_confirmar()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("cancelar"):
		_cancelar()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("sair_duelo"):
		_diag("sair_duelo sem tela de desistência (não existe).")
		_fala("Sair do duelo: sem tela de desistência (não existe).")
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("pausar"):
		_passar_turno()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("posicao_l1") or evento.is_action_pressed("posicao_r1"):
		_alternar_posicao()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("detalhes"):
		_detalhes()
		get_viewport().set_input_as_handled()
		return
