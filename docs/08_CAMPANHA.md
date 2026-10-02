# 08 — CAMPANHA

> **PLANO. 0% implementado.** Não existe `CampaignManager`, `CampaignRunner`,
> `SceneRunner`, `Dialogue`, `Choice` nem schema de campanha. A pasta
> `campaign/` do repositório tem só um README, e `astralis/campaign/` tem só um
> `.gitkeep`. Nada aqui está no jogo: o `ScenesStudio.svelte` do editor grava um
> JSON simples em `projects/default/scenes/` e avisa em comentário que o jogo
> **não lê esse formato** (R4).
>
> O modelo abaixo é o do original e serve de referência para quando for
> implementado.

## 8.1 O MODELO

Duas visões, e elas não se misturam:

- **GRAPH** — para onde ir. Grafo de nós: cena → diálogo → escolha → cena.
- **SCENE-TIMELINE** — o que acontece dentro de uma cena, em ordem linear.

```text
Scene A -> Dialogue -> Choice -> Battle -> Scene B
Choice: "Sim" -> scene_b | "Não" -> scene_c
Scene: { id, background, music, elements[] }
```

**A regra que não pode quebrar:** a timeline define o que acontece, o grafo
define para onde ir. O Studio mostra as 2 setas no grafo; **o Astralis decide o
vencedor e faz o salto**. Se o editor decidisse, a regra estaria no editor.

## 8.2 O NÓ DE BATALHA

Uma batalha dentro da campanha é um nó com saídas, porque sem elas a campanha
trava — não há como continuar depois de perder:

```text
battle: {
  duel_setup,        -> mesmo contrato do duelo normal
  on_win:   <nó de destino>,
  on_lose:  <nó de destino>,
  allow_retry: bool,
  flags_on_win:  [flags],
  flags_on_lose: [flags]
}
```

`on_lose` é **obrigatório**. `allow_retry` devolve ao mesmo nó.

## 8.3 FLAGS-LITE (V1)

Só o mínimo, sem virar linguagem de programação:

```text
flags:   { nome: bool }
counters:{ nome: int }
```

Gatilho de nó: `requires_flag: [nome]` e `requires_counter: { nome: >= N }`.

O motivo de não ter `variables` é que progressão não precisa de Turing: flags e
contadores dão final múltiplo, revanche e desbloqueio sem transformar a
campanha em interpretador. `variables` completas só depois que runtime, campanha
e preview estiverem estáveis.

## 8.4 SIMPLES E AVANÇADO

- **Simples**: modelos de cena e de batalha com `on_win`/`on_lose` já ligado; o
  usuário escolhe o modelo e preenche os nomes.
- **Avançado**: o grafo e a timeline editáveis, com o battle node completo.

Mesmo schema e mesma validação nos dois. Nenhum dos dois modos é motor separado
(R1, R2).

## 8.5 O QUE FALTA PARA EXISTIR

| Falta | Quem faz |
|---|---|
| o schema de campanha e o de cena | Systems |
| `CampaignManager` / `SceneRunner` em `astralis/campaign/` | Runtime |
| o grafo e a timeline no editor, e o formato que o jogo lê | Editor |
| playthrough do `duel_setup` a partir de um nó de batalha | Runtime |
| GUT do runner e do round-trip | QA |

Enquanto isso não existir, o botão de jogar cena **não pode** aparecer no editor.
Prometer Play de cena sem runtime é o defeito que o R4 existe para evitar.
