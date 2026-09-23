# 04 — CONTRATO DE DADOS

ORIGEM: spec v1.1 seções 9, 10, 11, 12

## 4.1 Project Data

Studio produz Project Data, independente do código-fonte do Astralis. Dois formatos oficiais (detalhes em `12_DISTRIBUICAO_EXPORTACAO.md`):

TRABALHO (pasta JSON editável):

```text
project/
  project.json
  cards/ duelists/ decks/ fusions/ effects/ campaigns/ tests/
  assets/cards/ characters/ portraits/ backgrounds/ music/ sfx/ ui/
```

DISTRIBUIÇÃO (`.astralis` único, binário trancado, não abre em texto): gerado no Exportar com manifest + hashes + assinatura + chave por jogo.

Arquivos podem evoluir. Princípio obrigatório: dados separados da lógica.

## 4.2 Schemas compartilhados

Astralis e Studio usam o mesmo contrato:
Project, Card, Duelist, Deck, Fusion, Effect, Campaign, Scene, Test Scenario Schema.

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
