# gerar_cartas_teste.py — TESTE (gera as 30 cartas-monstro novas do Starter Kit).
# Uso: a partir da raiz do repo:  python tools/gerar_cartas_teste.py
# Saída: schemas/examples/cards/card_*.json (não apaga as 10 originais).
# Pode apagar este script depois que as cartas estiverem geradas.

import json
from pathlib import Path

# (id, nome, descrição, tipo, atributo, level, atk, def)
CARTAS = [
    ("card_serpente_celeste", "Serpente Celeste", "Serpente que mora nas nuvens e desce só para caçar.", "dragon", "wind", 6, 1800, 1500),
    ("card_drake_ferrugem", "Drake Ferrugem", "Drake teimoso com escamas duras como ferro velho.", "dragon", "fire", 5, 1700, 1200),
    ("card_aprendiz_arcano", "Aprendiz Arcano", "Ainda erra o feitiço, mas já assusta.", "spellcaster", "dark", 2, 800, 600),
    ("card_oraculo_luar", "Oráculo do Luar", "Lê o futuro nas crateras da lua.", "spellcaster", "light", 4, 1400, 1600),
    ("card_bruxo_pantano", "Bruxo do Pântano", "Faz poção com água parada e mau humor.", "spellcaster", "water", 3, 1200, 1000),
    ("card_espadachim_aurora", "Espadachim da Aurora", "Saca a espada junto com o nascer do sol.", "warrior", "light", 4, 1600, 1400),
    ("card_gladiador_ferro", "Gladiador de Ferro", "Nunca perdeu uma briga de arena.", "warrior", "earth", 5, 1900, 1700),
    ("card_guardia_templo", "Guardiã do Templo", "Escudo gigante, coração maior ainda.", "warrior", "earth", 3, 500, 2000),
    ("card_cacador_sombrio", "Caçador Sombrio", "Você só percebe ele quando já perdeu.", "warrior", "dark", 6, 2000, 1500),
    ("card_lobo_alfa", "Lobo Alfa", "Uiva e a matilha inteira obedece.", "beast", "wind", 4, 1500, 1000),
    ("card_tigre_trovao", "Tigre do Trovão", "Cada passo dele parece um raio caindo.", "beast", "thunder", 6, 2100, 1400),
    ("card_urso_pedra", "Urso de Pedra", "Dormiu mil anos e acordou com fome.", "beast", "earth", 4, 1300, 1800),
    ("card_falcao_veloz", "Falcão Veloz", "Mais rápido que fofoca de vila.", "beast", "wind", 2, 900, 700),
    ("card_tubarao_abissal", "Tubarão Abissal", "Rei do fundo do mar escuro.", "aqua", "water", 6, 2200, 1600),
    ("card_polvo_tinta", "Polvo de Tinta", "Some na fumaça preta e volta com tudo.", "aqua", "water", 3, 1000, 1300),
    ("card_golem_antigo", "Golem Antigo", "Feito de pedra de templo esquecido.", "rock", "earth", 7, 2500, 2500),
    ("card_estatua_viva", "Estátua Viva", "Piscou. Ninguém viu, mas piscou.", "rock", "earth", 4, 600, 2200),
    ("card_salamandra_brava", "Salamandra Brava", "Cospe fogo quando contrariada.", "pyro", "fire", 3, 1300, 900),
    ("card_fenix_cinzas", "Fênix das Cinzas", "Renasce sempre. Sempre mesmo.", "pyro", "fire", 7, 2400, 1800),
    ("card_fagulha_travessa", "Fagulha Travessa", "Pequena, quente e impossível de pegar.", "pyro", "fire", 1, 500, 400),
    ("card_gargula_tensao", "Gárgula de Tensão", "Guarda o telhado e adora tempestade.", "thunder", "thunder", 5, 1600, 1800),
    ("card_trepadeira_espinho", "Trepadeira Espinho", "Abraça forte. Forte demais.", "plant", "earth", 3, 1200, 1400),
    ("card_flor_carnivora", "Flor Carnívora", "Cheirosa por fora, faminta por dentro.", "plant", "dark", 5, 1800, 1200),
    ("card_mumia_retorno", "Múmia do Retorno", "Voltou para buscar o que esqueceu.", "zombie", "dark", 4, 1500, 1200),
    ("card_carrasco_nevoa", "Carrasco da Névoa", "Aparece na neblina com machado afiado.", "zombie", "dark", 6, 2300, 1700),
    ("card_fada_estelar", "Fada Estelar", "Espalha poeira de estrela por onde passa.", "fairy", "light", 3, 1000, 1500),
    ("card_besouro_tita", "Besouro Titã", "Carrega dez vezes o próprio peso.", "insect", "earth", 5, 1900, 2000),
    ("card_canhao_relogio", "Canhão Relógio", "Atira em ponto. Sempre em ponto.", "machine", "fire", 5, 2000, 1000),
    ("card_diabrete_zombador", "Diabrete Zombador", "Ri da sua cara antes, durante e depois.", "fiend", "dark", 2, 900, 600),
    ("card_barao_pesadelo", "Barão do Pesadelo", "Manda nos seus sonhos ruins.", "fiend", "dark", 7, 2600, 2100),
]

# Roda a partir da raiz do repo (sem __file__, que nem todo console define).
BASE = Path("schemas") / "examples" / "cards"

for cid, nome, desc, tipo, attr, level, atk, defe in CARTAS:
    dado = {
        "schema_version": 1,
        "id": cid,
        "name": nome,
        "description": desc,
        "artwork": f"assets/cards/{cid}.png",
        "card_type": "monster",
        "monster_type": tipo,
        "attribute": attr,
        "level": level,
        "attack": atk,
        "defense": defe,
        "effects": [],
        "tags": ["teste", tipo],
    }
    caminho = BASE / f"{cid}.json"
    caminho.write_text(json.dumps(dado, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"OK: {caminho.name}")

print(f"Total: {len(CARTAS)} cartas em {BASE}")
