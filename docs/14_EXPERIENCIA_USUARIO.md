# 14 — EXPERIÊNCIA DO USUÁRIO (SIMPLES + PODEROSO)

STATUS: AUTHORITATIVE V1.5 (consolida melhorias 2026-09-23, sem quebrar D01-D15)
OWNER: lead

## 14.1 Regra de ouro

Todo recurso tem 2 caras: Simples (2-3 campos, um clique) e Avançado (tudo). Mesmo dado, mesma validação, mesma execução no Astralis. Simples nunca é motor separado (R1/R2).

## 14.2 Checklist por editor

```text
Carta: Simples (nome, ATK/DEF, arte, 1 efeito modelo) / Avançado (tudo + blocos)
Duelista: Simples (nome, retrato, deck, vida + arquétipo Bravo/Equilibrado/Defensor) / Avançado (sliders+dropdown)
Deck: Simples (busca + duplo clique adiciona + aviso fraco/forte) / Avançado (filtros, curva, validar)
Fusão: Simples (lista A+B=C + Testar) / Avançado (regras + prioridade)
Efeito: Simples (galeria 10 modelos) / Avançado (blocos TRIGGER->... completos)
Campanha: Simples (3 modelos: rival, torneio, final múltiplo) / Avançado (grafo+timeline)
Duelo: Simples (2 duelistas + vida + Play) / Avançado (seed, arena, ordem)
Exportar: 1 tela (plataforma + Aberto/Protegido + Exportar) + checklist "testou a fita?"
```

## 14.3 Galeria de prontos (conteúdo inicial)

10 efeitos, 5 fusões, 3 duelistas arquétipo, 3 campanhas modelo, assets placeholder. Tudo duplicável. Item de galeria é dado comum, não código.

## 14.4 Erros e botões padrão

- Erro sempre em PT-BR com onde clicar; `Consertar pra mim` quando seguro.
- Botão verde `Jogar` em todo editor (lança Astralis com contexto).
- Botão `Testar agora` em carta/efeito/fusão/duelo (cenário pronto + seed fixa + `esperava X, aconteceu Y`).
- `Duplicar` antes de `Criar do zero` em toda lista.
- Assets: arrasta e solta, converte sozinho, placeholder cinza se faltar.

## 14.5 Guia 5 minutos

`Play (30s) -> Duplicar carta -> Montar deck -> Play -> Exportar`. Ver `01_VISAO_PRODUTO.md` 1.6.
