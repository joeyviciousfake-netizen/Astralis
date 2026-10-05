extends Node3D

## cursor_3d — O CURSOR DE FOCO: uma LUZ AZUL arredondada em volta da coisa
## focada, que respira suave. Um assunto so.
##
## Ele nao sabe o que esta focado: quem molda o cursor e a mesa, que mede a coisa
## (a carta da mao ou o ladrilho) e passa largura, altura, inclinacao e escala.
## Por isso o mesmo cursor serve na mao E no campo (ref, doc 15 §15.3).
##
## A luz e desenhada no PLANO DA CARTA (XY local dentro do `Grupo`), e o
## grupo gira junto com a focada - entao a luz sai colada nela, nas DUAS
## situacoes.
##
## Um quad so, sem caixa: o contorno arredondado e o caimento suave saem de um
## shader (SDF de retangulo arredondado), porque geometria chapada e o que
## deixava a selecao com cara de brinquedo de montar. Sem bloom no projeto
## (gl_compatibility tem brilho global limitado, e ele tingiria a cena
## inteira): o brilho e localizado no proprio quad, que o fundo escuro faz
## parecer glow.
##
## Zero regra (R1): isto e desenho puro.

## Cor do foco: o azul brilhante da ref.
var cor := Color(0.25, 0.55, 1.0)
## Espessura do vidro do ladrilho (a luz sai a frente dele, nao dentro).
## O DONO e a mesa, que mede a carta e passa.
var espessura_carta: float
## Material UNSHADED: a mesa passa o dela (tudo na cena e sem luz). Mantido
## porque a mesa chama com a mesma assinatura; a luz usa shader proprio.
var mat: Callable
## Fabrica de caixa da mesa. Mantida pela mesma razao (assinatura da mesa).
var caixa: Callable

## O shader da luz: contorno arredondado (SDF) + linha viva + halo que cai
## suave + pulso. `quad` e o tamanho do quad em unidades locais; `meio` e a
## metade da carta (a linha passa na borda dela); o resto e gosto medido.
const SH := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 cor : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform vec2 quad = vec2(1.2, 1.7);
uniform vec2 meio = vec2(0.5, 0.73);
uniform float raio = 0.07;
uniform float faixa = 0.035;
uniform float pulso = 0.5;
float sd_caixa(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	vec2 p = (UV - vec2(0.5)) * quad;
	float d = sd_caixa(p, meio, raio);
	float linha = 1.0 - smoothstep(0.0, faixa, abs(d));
	float halo = exp(-max(d, 0.0) * 16.0) * 0.55;
	float vivo = 0.72 + 0.38 * pulso;
	vec3 luz = cor.rgb * (linha * 2.4 + halo) * vivo;
	ALBEDO = luz;
	ALPHA = clamp(linha + halo * 0.7, 0.0, 1.0);
}
"""

var _grupo: Node3D = null
var _moldura: Node3D = null
var _brilho: MeshInstance3D = null
var _shader_mat: ShaderMaterial = null
## Fase do pulso em radianos (0..1 no shader). Dono: este arquivo.
var _pulso := 0.0


func _ready() -> void:
	name = "Cursor3D"
	_grupo = Node3D.new()
	_grupo.name = "Grupo"
	add_child(_grupo)
	_moldura = Node3D.new()
	_moldura.name = "Moldura"
	_grupo.add_child(_moldura)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.7)
	_brilho = MeshInstance3D.new()
	_brilho.name = "Brilho"
	_brilho.mesh = quad
	_shader_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SH
	_shader_mat.shader = sh
	_brilho.material_override = _shader_mat
	_moldura.add_child(_brilho)


## Redesenha a luz do foco com o tamanho e a inclinacao da focada.
## `larg`/`alt` sao as medidas da COISA focada e `rot` a rotacao dela; o quad
## cobre a carta mais a margem do caimento, e a linha passa na borda dela.
func moldar(larg: float, alt: float, rot: Vector3, escala_mao: float) -> void:
	if _grupo == null or _brilho == null or _shader_mat == null:
		return
	_grupo.rotation_degrees = rot
	var w := larg * 1.06
	var h := alt * 1.06
	var margem := maxf(larg, alt) * 0.22
	var quad := _brilho.mesh as QuadMesh
	quad.size = Vector2(w + margem * 2.0, h + margem * 2.0)
	_brilho.position = Vector3(0, 0, espessura_carta / 2.0 + 0.012)
	_shader_mat.set_shader_parameter("cor", cor)
	_shader_mat.set_shader_parameter("quad", Vector2(w + margem * 2.0, h + margem * 2.0))
	_shader_mat.set_shader_parameter("meio", Vector2(w * 0.5, h * 0.5))
	_shader_mat.set_shader_parameter("raio", minf(w, h) * 0.09)
	_shader_mat.set_shader_parameter("faixa", maxf(larg, alt) * 0.045)


## Pulso do foco: 0..1 no shader, num seno lento — a luz respira em vez de
## piscar.
func _process(delta: float) -> void:
	_pulso += delta * 2.4
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("pulso", 0.5 + 0.5 * sin(_pulso))
