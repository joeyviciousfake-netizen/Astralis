# 01 — VISÃO DE PRODUTO

ORIGEM: spec v1.1 seções 1, 2, 103, 104, 110

## 1.1 Identidade

Astralis é runtime 2D especializado em:
- duelo de cartas inspirado em Yu-Gi-Oh! Forbidden Memories;
- campanha em formato visual novel;
- cartas, duelistas, decks, fusões, efeitos (linguagem visual declarativa), campanha, UIs especializadas, assets — tudo configurável.

Astralis Studio é o software de autoria para projetos Astralis.

NÃO é: engine genérica de TCG, novo Godot/Unreal, engine de RPG, ferramenta para qualquer jogo, scripting genérico.

Objetivo: "Permitir que usuários criem seus próprios jogos baseados no modelo que Astralis conhece, sem programar."

## 1.2 Modelo fundamental

```text
ASTRALIS STUDIO -> Project Data -> ASTRALIS -> GAME
```

Studio cria/modifica dados. Astralis interpreta/executa. Studio NÃO contém implementação paralela de gameplay. Astralis é autoridade da execução.

## 1.3 Experiência do usuário final

```text
Instala Studio -> New Project -> Create Cards/Duelists/Decks/Fusions/Effects/Campaign
-> Validate -> Play/Preview -> Export/Package
```

Usuário não precisa saber: Godot, GDScript, Rust, Tauri, Svelte, MCP, GUT.

[MELHORIA V1.2]: todo New Project já vem com Starter Kit jogável (ver `09_STUDIO_EDITOR.md`). Primeira coisa que o usuário faz é `Play`, depois duplica e edita.

## 1.4 Definição final

ASTRALIS: "Runtime 2D especializado em duelo de cartas + campanha visual novel, capaz de interpretar projetos autorados pelo Studio."

ASTRALIS STUDIO: "Editor visual especializado que permite criar projetos Astralis via dados, blocos, graphs e propriedades, sem programar."

Não é engine genérica. É plataforma de autoria especializada em torno de um modelo fixo de runtime.

Regra final:
- "Se Astralis sabe fazer, Studio deve permitir configurar."
- "Se Astralis não sabe fazer, Studio não deve fingir que sabe."
- "Nova capacidade primeiro no Astralis, depois exposta no Studio."

## 1.5 Critérios de sucesso

Arquitetura vence quando:
1. nova carta/duelista/deck/fusão/cena/campanha não exige código;
2. novo efeito suportado não exige programação do usuário;
3. Astralis carrega Project Data externo;
4. Studio não implementa gameplay;
5. Preview e Test Lab usam Astralis;
6. GUT testa internals;
7. editor e runtime usam contrato compatível;
8. projeto evolui sem Godot instalado no usuário.
