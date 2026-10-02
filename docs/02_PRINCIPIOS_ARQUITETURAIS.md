# 02 — PRINCÍPIOS ARQUITETURAIS


## 2.1 DATA != LOGIC — regra absoluta

Dados definem conteúdo. Astralis define comportamento.

- DATA: card name/ATK/DEF/artwork, effect definition, deck list, fusion recipe, duelist params, cena/diálogo.
- LOGIC (Astralis): effect execution, battle resolution, turn processing, AI decision, campaign execution.

## 2.2 Studio nunca implementa gameplay

Studio: cria, edita, valida, visualiza dados; inicia Astralis; solicita preview/teste.
Astralis: interpreta dados; executa gameplay/efeitos/duelo/campanha/IA; controla game state.

Proibido no Studio: BattleSystem / EffectSystem / FusionSystem / TurnSystem / AI alternativos.

## 2.3 Sem motor paralelo

PROIBIDO mesmo para preview:
```text
FakeDuelEngine, FakeEffectEngine, FakeFusionEngine, FakeCampaignRunner
```
Preview e Test Lab devem utilizar Astralis. Usuário vê comportamento real do runtime.

Isso garante: **nunca acontece "funcionou no editor mas não no jogo"**, porque o editor não calcula resultado. Ele monta `Test/Preview Scenario` (dado) e o Astralis executa com os sistemas reais e devolve `Result/Trace/State`.

## 2.4 Fontes da verdade

- Gameplay: Astralis decide. "Quanto dano? Qual fusão? Qual cena vem depois?" -> Astralis.
- Autoria: Studio edita. "Qual ATK? Qual arte? Qual diálogo? Qual receita?" -> Studio.
- Contrato: schemas são o contrato entre os dois.

## 2.5 Poder sem scripting

Poder vem de: `DATA CONTROL + COMPOSABILITY + CONTEXTUAL OPTIONS + VISUAL AUTHORING + RUNTIME CAPABILITIES`.

Não vem de scripting, plugins arbitrários, custom code.

Studio parece: simples, moderno, visual, contextual, poderoso, especializado.
Não parece: Godot, Unreal, IDE, programming environment. Usuário não escreve GDScript/Rust/Svelte/JSON manualmente (JSON é detalhe interno).

Limitações estruturais (schema, runtime, UX e integridade do projeto) continuam sendo design intencional do produto.
Isso não significa criar uma blacklist própria de conteúdo visual: o Studio não bloqueia, troca ou reescreve personagens, franquias, estilos, marcas ou outras referências visuais apenas por sua origem.

## 2.6 Anti-overengineering

Antes de abstrair, perguntar:
1. É necessária agora? 2. Resolve requisito concreto? 3. Reduz complexidade?
4. Preserva especialização? 5. Pode ser testada?

Evitar: scripting engine, plugin architecture, engine genérica, DI excessivo, ECS complexo sem necessidade, UI framework universal, linguagem própria prematura.

## 2.7 Organização obrigatória (R8)

Todo arquivo nasce dentro da pasta do dono, com nome que diz o que é:

```text
astralis/duel|core|ui|campaign|debug -> runtime (tela e regra do jogo)
astralis/testing                     -> qa (GUT mora dentro do projeto; tests/ da raiz é só índice)
schemas/                             -> systems (contratos + examples/)
tools/ ci/                           -> qa (scripts de dev, nada de jogo)
docs/                                -> lead (fonte oficial, sem duplicata)
```

Proibido: arquivo solto na raiz (salvo `AGENTS.md`), `.tmp`/`.log` no repo,
pasta de teste fora do lugar, cena/script sem dono, dado fora de `schemas/`.
Teste descartável vive e morre na mesma sessão: cria isolado, mostra, apaga.

Auditoria: todo fim de sessão, `git status` só mostra trabalho intencional.

## 2.8 Consultar a documentacao antes de refazer a mao (D71)

Antes de escrever qualquer coisa na mao, e' a documentacao que responde se ja
existe ferramenta. A ordem e' a regra:

1. **Documentacao, quando nao se sabe ou nao se tem certeza** — o
   `docs/17_BLENDER.md` e o manual do programa (a copia local quando existe).
   Consultar antes e' o caminho curto; consultar depois de errar e' registro
   de erro. E' o passo que responde a pergunta "isto ja existe?", e por isso
   vem antes de qualquer ferramenta.
2. **Ferramenta nativa** — use o que o programa ja tem. O Blender tem bevel,
   subdiv, remesh, snap, proportional edit, boolean e Geometry Nodes: ele
   **gera a topologia por voce**. Nao e' vergonha usar; e' o caminho curto.
3. **Pesquisa** — se a documentacao nao respondeu e voce nao sabe qual
   ferramenta existe ou como se usa, pesquise na internet antes de inventar.
   Nada de reconstruir por deducao.
4. **Manual** - so em ultimo caso, so para o que a ferramenta realmente nao
   faz, e medindo a topologia antes de gravar.

**Por que 1 e 4 nao sao a mesma coisa, mesmo quando o arquivo e' o mesmo:** no
Blender a copia local e' a documentacao E o manual. O que muda e' a intencao. No
passo 1 a documentacao e' **a busca** da resposta - "isto ja existe?" - e essa
leitura vem antes de qualquer acao. No passo 4 o manual e' a **ultima tentativa**
para o que a ferramenta comprovadamente nao faz, e so vem depois de medir a
topologia para provar que o nativo chegou no limite.

**Por que isto e' principio e nao conselho:** um teste que RECUSA entrada errada
e' rede de seguranca, nao metodo de trabalho. Ele so age depois que voce ja
construiu a coisa errada — e a documentacao e' o que move o erro para antes, sem
nem chegar a construir. Um portao que recusa malha serve para provar a regra,
nao para ser o metodo.

Vale para qualquer programa com ferramenta boa, nao so para o Blender.
