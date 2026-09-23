# 06 — SISTEMA DE FUSÃO

ORIGEM: spec v1.1 seção 19

## 6.1 Princípio

Astralis implementa o algoritmo. Project Data define receitas. Receitas nunca hardcoded no runtime.

Usuário pode criar/editar/remover/duplicar/validar.

## 6.2 [MELHORIA V1.2] Receitas + regras

V1.1 priorizava só receitas explícitas. Problema: Forbidden Memories tem centenas de combinações, cadastrar tudo manualmente é inviável para usuário comum.

V1.2 mantém determinismo, com 2 camadas:

```text
1. RECEITA EXPLÍCITA (prioridade máxima):
   input: {card_a, card_b} -> result: card_c

2. REGRA GENÉRICA (fallback):
   when: {attribute_a?, type_a?, attribute_b?, type_b?, min_atk?}
   -> result: card_x
   priority: number
```

Exemplo:
- Receita: `dragao_branco + mago_negro -> dragao_supremo` sempre vence.
- Regra: `dragao + trevas -> dragao_trevas_comum (priority 10)`.

Studio: aba Receitas (lista simples) + aba Regras (form com selects). Validação acusa conflito de prioridade. Astralis resolve: procura receita exata, senão avalia regras por prioridade, senão falha.

Isso continua data, sem código, mas reduz 90% do trabalho.

## 6.3 Preview / teste

Usam FusionSystem real via TestHarness. Ver `10_PREVIEW_TESTE_DEBUG.md`. Fusion Preview é só um contexto de `Jogar a partir daqui` com 2 cartas na mão.
