# 04 — CONTRATO DE DADOS

ORIGEM: spec v1.1 seções 9, 10, 11, 12

## 4.1 Project Data

Studio produz Project Data, independente do código-fonte do Astralis. Dois formatos oficiais (detalhes em `12_DISTRIBUICAO_EXPORTACAO.md`):

TRABALHO (pasta JSON editável):

```text
project/
  project.json
  cards/ duelists/ decks/ fusions/ effects/ campaigns/ tests/ layouts/
  assets/cards/ characters/ portraits/ backgrounds/ music/ sfx/ ui/
```

DISTRIBUIÇÃO (`.astralis` único, binário trancado, não abre em texto): gerado no Exportar com manifest + hashes + assinatura + chave por jogo.

Arquivos podem evoluir. Princípio obrigatório: dados separados da lógica.

## 4.2 Schemas compartilhados

Astralis e Studio usam o mesmo contrato:
Project, Card, Duelist, Deck, Fusion, Effect, Arena (D24: slot_id fixo + x/y só desenho), Campaign, Scene, Test Scenario Schema.

Schema define: tipos, campos, referências, enums, estruturas, versões.
Studio usa para edição/validação UX. Astralis usa para carregamento/validação execução.

Owner do contrato: Systems/Data Engineer. Mudança compartilhada deve ser coordenada (ver `11_ROADMAP_AGENTES.md`).

## 4.3 Versionamento

Todo projeto tem `schema_version: 1` + `runtime_version` + `author_id` no `.astralis`.

Player e fita viajam juntos no mesmo zip para evitar mismatch. Boot falha com erro humano se versões diferirem.

Mudança incompatível exige: nova versão + migração ou incompatibilidade documentada. Nunca mudar estrutura silenciosamente.

## 4.4 IDs estáveis

Todo recurso tem ID estável, independente do nome exibido:

```text
card_dark_magician, duelist_yugi, deck_yugi_default,
fusion_dark_magician_001, campaign_chapter_01, scene_castle_intro
```

Ex.: `id: card_dark_magician / name: Dark Magician` pode virar `name: Mago Sombrio`, ID permanece. Decks referenciam Card IDs, não duplicam objetos.

## 4.5 Notas V1 (D34, Systems)

- Precedência da vida: `duel_setup.starting_lp` (obrigatório) manda na batalha; `duelist.starting_lp` (opcional) é só sugestão do Studio. Campo opcional = mudança compatível, sem bump de versão (04.3). Runtime lê só o setup hoje e ignora o campo do duelista.
- Cenas simples (`campaign/scenes/*.json`, formato no README do editor): dado provisório fora do contrato V1 — sem `scene.schema.json` ainda, sem conflito com schemas existentes, runtime ignora (R4). Schema formal + grafo/timeline ficam p/ depois (docs 08).

## 4.6 Campo de Testes — `duel_setup.test_state` (V1, compatível)

Tab "Campo de Testes" do Studio: o usuário monta mão + campo meu e do inimigo, clica Iniciar teste, e o duelo real começa sempre na MINHA fase da mão. Studio só monta DADO, Astralis executa (R1/R2/R4). Sem motor inventado.

- Contrato (`schemas/duel_setup.schema.json`, `schema_version` continua 1): campo opcional `test_state` com `my_hand[0-5]` (Card IDs), `p0_monster[5] + p0_spell[5] + p1_monster[5] + p1_spell[5]` (cada slot: `null` = vazio, ou `{card_id + face_up? + attack_position?}` — ausentes = `true`, o mínimo que o runtime já sabe mapear p/ `face_down/position` dele, sem mecânica nova), tudo opcional. Slots seguem o padrão `p0/p1 m/s 0-4` (doc 13.10); mão máx 5 (doc 13.3); IDs estáveis referenciando cartas.
- LP/seed/ordem NÃO se duplicam: valem `starting_lp/seed/turn_order` do topo. Quando `test_state` está presente, `turn_order` tem que ser `first_p1` (schema `allOf/if-then` + Studio `checar_test_state`) e o duelo começa na fase da mão de p0 (D24) — documentado aqui, executado no runtime.
- Ausente = duelo normal (dado FM `duel_fm_abertura` continua válido, sem tocar). Mudança compatível, sem migração (04.3). Validação espelhada no Studio (`checar_test_state` + `validar_projeto`); `tools/fm_import.py --check` segue verde (722/39/39/25081 intactos).

## 4.7 Pack de criação `.apack` V1 (D23, Systems — COMPATÍVEL, `schema_version` continua 1)

O pack de criação é 1 arquivo único `.apack` (textos + imagens juntos, D23).
É formato de TRANSPORTE, não contrato novo: nenhum campo/tipo/enum mudou,
nenhuma migração. Especificação exata em `docs/12_DISTRIBUICAO_EXPORTACAO.md`
§12.7; validador em `tools/apack.py` (`pack`/`unpack`/`check`).

Resumo do contrato: zip comum com `manifest.json` (magic `APACK`,
`format_version` 1, `schema_version` 1, `runtime_version` + `author_id` como
info sem trava V1, modo sempre `aberto`, contagens, SHA256 por arquivo) +
`data/pack.json` (O MESMO JSON legado, byte-idêntico) + `assets/` (imagem
repetida grava 1x, faltando = aviso) + `preview` opcional. Pack legado
`.json` = `.apack` sem assets (abre como "sem imagens").

## 4.8 Molde da carta em DADO — `card_layout.schema.json` V1 (D23 Lead, Systems — COMPATÍVEL, `schema_version` continua 1)

O layout da carta virou MOLDE EM DADO (JSON): mover, redimensionar e
reestilizar tudo sem mexer em código (R3). V1 = SÓ o molde padrão de
MONSTRO (`schemas/examples/layouts/card_layout_monster_default.json`,
medido do scan real Blue-Eyes 813x1200: nome 3,5/6,5; orbe 9% em x91;
estrelas top11,5 à direita N=level; arte 9%/16,5%/82% quadrada até ~72,8;
texto 6%/74%/88%x21%; rodapé 96-98,5).

- Contrato (`schemas/card_layout.schema.json`, `schema_version` 1): canvas
  fixo 59x86 em POR-MIL do próprio eixo (`x/w` em ‰ de 59, `y/h` em ‰ de
  86 — quadrado visual tem `w≠h`, ex: arte 820x563, orbe 90x62) + lista de
  0-9 peças de TIPOS FECHADOS amarrados aos campos da carta (R5, nada
  genérico): `name`←name, `attribute_orb`←attribute, `level_stars`←level,
  `art_window`←artwork, `type_line`←monster_type, `text_box`←description,
  `atkdef_bar`←attack/defense (só monstro), `footer`←id, `frame`←fundo/borda.
  Cada peça: `id` + `kind` + `rect{x,y,w,h}` + `style{font_size(em ‰ da
  altura),bold,color,align,z}` + `visible_when[always,monster_only]`.
  Peça ausente = default do scan; `x+w<=1000` e `y+h<=1000` + kind único
  (máx 1 por kind) não cabem em draft-07: conferem no Studio
  (`checar_card_layout`) e em `tools/fm_import.py --check`.
- Onde mora: `layouts/` no Project Data (árvore em 4.1). V1 só tem o
  default de monstro. Override por carta e fontes próprias ficam p/ V2 —
  por isso NÃO existe campo novo em `card.schema.json` (não criar).
- Quem desenha pelo molde (runtime `CardView`, editor visual do Studio)
  vem depois no plano do Lead (contrato → jogo desenha → editor visual →
  testes → docs). V1 = contrato + default + validação; nada muda no jogo
  nem no editor hoje.
- Validação espelhada no Studio (`checar_card_layout` + 7 testes Rust);
  `tools/fm_import.py --check` segue verde (722/39/39/25081 intactos).
