# 06 — SISTEMA DE FUSÃO


## 6.1 Princípio

Astralis implementa o algoritmo. Project Data define receitas. Receitas nunca hardcoded no runtime.

Usuário pode criar/editar/remover/duplicar/validar.

## 6.2 Receitas + regras

A resolução tem 2 camadas, e é determinística nas duas. A camada da regra genérica
existe porque o FM tem centenas de combinações e cadastrar todas é inviável para o
usuário comum:

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

A fusão é resolvida pelo `FusionSystem` real. O botão `Testar fusão` do Studio **confere o dado** (receita exata vence, regra genérica é o fallback) e devolve "validado no dado, sem jogar" — ele não executa jogo. Fusion Preview é só um contexto de `Jogar a partir daqui` com 2 cartas na mão. Ver `10_PREVIEW_TESTE_DEBUG.md`.

## 6.4 Fusão Simples/Avançado

Simples: lista de receitas `A+B=C` + busca + botão `Testar fusão` (lança duelo preparado com as 2 cartas na mão). Avançado: aba Regras (form com selects + prioridade + aviso de conflito). Mesmo schema, mesma resolução no Astralis (receita exata primeiro, regra por prioridade, senão falha).
