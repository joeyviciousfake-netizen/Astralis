# 02 — PRINCÍPIOS ARQUITETURAIS

ORIGEM: spec v1.1 seções 4, 5, 6, 100, 101, 106, 107, 109

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

Limitações são design intencional do produto.

## 2.6 Anti-overengineering

Antes de abstrair, perguntar:
1. É necessária agora? 2. Resolve requisito concreto? 3. Reduz complexidade?
4. Preserva especialização? 5. Pode ser testada?

Evitar: scripting engine, plugin architecture, engine genérica, DI excessivo, ECS complexo sem necessidade, UI framework universal, linguagem própria prematura.
