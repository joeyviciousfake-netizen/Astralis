# DECISOES — TRAVADAS (append-only, só usuário destrava)

> IA: não reabra, não questione, não proponha o contrário sem permissão explícita.
> Nova decisão: anexe no fim como Dnn mantendo histórico.

- D01 2026-09-23: DATA != LOGIC. Studio nunca implementa/calcula gameplay. | motivo: evitar 2 motores | impacto: todo preview/test usa Astralis real
- D02 2026-09-23: Proibido FakeDuel/Effect/Fusion/Campaign mesmo para preview. | motivo: "funcionou no editor mas não no jogo" | impacto: TestHarness só prepara/observa, chama sistema real
- D03 2026-09-23: Distribuição é `.astralis` binário (MessagePack+zlib+hash+assinatura), não JSON solto. | motivo: frágil + cópia fácil | impacto: 2 formatos (pasta JSON trabalho vs .astralis distribuição)
- D04 2026-09-23: Export protegido com cadeado por jogo: chave única gerada no Exportar, fita trancada, chave embutida no player da caixa. Modos Aberto/Protegido. | motivo: cópia casual na internet | impacto: Studio gera chave, Runtime valida, QA testa tamper
- D05 2026-09-23: Player + fita viajam juntos no mesmo zip. Versionamento junto (schema_version+runtime_version+author_id), boot recusa se divergir. | motivo: fim do mismatch | impacto: CI publica players win/linux/android, Studio só copia
- D06 2026-09-23: Win/Linux = exe + .astralis lado a lado. Android V1 = APK + .astralis com importação (auto-detect Download). APK fundido só V2 via build server. | motivo: APK lacrado exige rebuild/assinatura | impacto: sem SDK no usuário na V1
- D07 2026-09-23: Campanha com Battle on_win/on_lose/retry + flags-lite (flags booleanas + counters). Sem variables completas na V1. | motivo: progressão/finais sem virar linguagem | impacto: docs 08
- D08 2026-09-23: Fusão = receita explícita (prioridade) + regra genérica fallback. | motivo: reduzir 90% cadastro estilo Forbidden Memories | impacto: docs 06
- D09 2026-09-23: IA por preset (dificuldade/agressividade/uso_fusao/protecao_lp), sem custom scripting V1. | motivo: identidade sem código | impacto: docs 05
- D10 2026-09-23: Efeitos com Modo Simples (templates) + Avançado (blocos), mesmo motor/validação. | motivo: simples p/ comum, poderoso p/ avançado | impacto: docs 07
- D11 2026-09-23: Starter Kit jogável em todo New Project + wizard 3 passos. | motivo: tirar tela em branco | impacto: docs 09
- D12 2026-09-23: Preview unificado "Jogar a partir daqui" (1 mecanismo launch with context). Test Lab mínimo com botão Testar agora + seed fixa. Debug completo adiado. | motivo: menos UI, mesmo motor | impacto: docs 10
- D13 2026-09-23: 6 agentes por domínio, sem micro-agentes. Feature: contrato → Astralis → Studio → testes → docs. | motivo: evitar divergência | impacto: docs 11
- D14 2026-09-23: Removido Documentação.md monolito, fonte oficial passa a ser docs/00-12 + MANIFEST. | motivo: já dividido + evitar duplicidade | impacto: raiz só tem AGENTS.md + docs/
- D15 2026-09-23: Manter 6 agentes na V1, sem criar nem remover. Distribuição como força-tarefa (Systems+Runtime+Editor+QA, Lead coordena). Split só se lotar: Runtime→efeito vira especialista temporário; 7º Build/Release só se APK fundido virar dor recorrente na V2. | motivo: evitar briga de fronteira e micro-agentes | impacto: docs 11
