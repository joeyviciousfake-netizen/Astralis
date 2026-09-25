# DECISOES — SÓ O QUE VALE (sem histórico morto)

> IA: só vale o que está aqui. Se o usuário mudar algo, apague a linha antiga e renumere — nunca acumule.
> Travado p/ IA e subagentes; o usuário muda quando quiser (D23).

- D01 2026-09-23: DATA != LOGIC. Studio nunca implementa/calcula gameplay. | motivo: evitar 2 motores | impacto: todo preview/test usa Astralis real
- D02 2026-09-23: Proibido FakeDuel/Effect/Fusion/Campaign mesmo para preview. | motivo: "funcionou no editor mas não no jogo" | impacto: TestHarness só prepara/observa, chama sistema real
- D03 2026-09-23: Distribuição é `.astralis` binário (MessagePack+zlib+hash+assinatura), não JSON solto. | motivo: frágil + cópia fácil | impacto: pasta JSON trabalho vs .astralis distribuição
- D04 2026-09-23: Export protegido com cadeado por jogo (chave única no Exportar, modos Aberto/Protegido). | motivo: cópia casual | impacto: Studio gera chave, Runtime valida, QA testa tamper
- D05 2026-09-23: Player + fita no mesmo zip, versionamento junto, boot recusa se divergir. | motivo: fim do mismatch | impacto: CI publica players, Studio só copia
- D06 2026-09-23: Win/Linux = exe + .astralis lado a lado. Android V1 = APK + .astralis com importação; fundido só V2. | motivo: APK lacrado exige rebuild | impacto: sem SDK no usuário na V1
- D07 2026-09-23: Campanha com Battle on_win/on_lose/retry + flags-lite (flags + counters), sem variables na V1. | motivo: progressão sem virar linguagem | impacto: docs 08
- D08 2026-09-23: Fusão = receita explícita (prioridade) + regra genérica fallback. | motivo: menos cadastro estilo FM | impacto: docs 06
- D09 2026-09-23: IA por preset (dificuldade/agressividade/uso_fusao/protecao_lp), sem custom scripting V1. | motivo: identidade sem código | impacto: docs 05
- D10 2026-09-23: Efeitos Simples (templates) + Avançado (blocos), mesmo motor/validação. | motivo: simples p/ comum, poderoso p/ avançado | impacto: docs 07
- D11 2026-09-23: Starter Kit jogável em todo New Project + wizard 3 passos. | motivo: tirar tela em branco | impacto: docs 09
- D12 2026-09-23: Preview unificado "Jogar a partir daqui" + Test Lab mínimo (Testar agora + seed fixa). Debug completo adiado. | motivo: menos UI, mesmo motor | impacto: docs 10
- D13 2026-09-23: 6 agentes por domínio, sem micro-agentes. Feature: contrato → Astralis → Studio → testes → docs. Split só se lotar (Efeito temporário; 7º Build só se APK doer na V2). | motivo: evitar divergência | impacto: docs 11
- D14 2026-09-23: Ferramentas oficiais: Coding-Solo godot-mcp (Godot 4.7.2, sem editor aberto) + GUT 9.7.1 (astralis/testing/). | motivo: as que executam de verdade | impacto: runtime usa MCP, qa usa GUT
- D15 2026-09-23: Tabuleiro: começa no turno do jogador, mão 5, decks 40; 5 slots monstro + 5 outros por lado; lado 0 não ataca no turno 1; virada desvira ao ser atacada. (Invocação detalhada em D24.) | motivo: usuário testando e mandando | impacto: runtime faz tela; doc 13 diverge até revisão
- D16 2026-09-23: Resolução fixa 1920x1080 (viewport + stretch canvas_items). | motivo: espaço p/ campo e mão | impacto: runtime/ui; lógica intacta
- D17 2026-09-24: Slot tem ID fixo (lado+tipo+índice), posição mora no layout da arena; lógica só usa ID, desenho usa layout com fallback. | motivo: mover slot sem quebrar jogo | impacto: systems arena, runtime fallback, qa testa
- D18 2026-09-24: Campo do rival é ESPELHO só no desenho (X invertido + fileiras trocadas); IDs e lógica intactos. | motivo: pedido do usuário | impacto: runtime + arena
- D19 2026-09-24: Jogo 100% controle, ZERO mouse e teclado: só as 11 ações joypad. | motivo: ordem do usuário | impacto: runtime mesa; QA trava em teste
- D20 2026-09-24: Conteúdo oficial é 100% FM original: 722 cartas, 39 duelistas/decks; abertura Simon Muran vs Jono, 8000 LP; customs de teste no backup. | motivo: 762 foi bug da soma | impacto: systems dados; QA refez testes
- D21 2026-09-24: Schema de carta estendido (equip/ritual, 6 tipos novos, estrelas/senha/custo opcionais); vida da batalha é sempre a do setup (a do duelista só sugere). | motivo: carta FM existia e não cabia | impacto: systems contrato; editor exibe
- D22 2026-09-24: Studio é app Tauri 2 (app.bat menu dev/build; Jogar lança o Godot de verdade); IMPORTAR pack SUBSTITUI com backup automático. | motivo: app real + fim do bug da soma | impacto: editor; backups ignorados no git
- D23 2026-09-24: Quem manda no projeto é o usuário: muda qualquer decisão a qualquer hora, sem burocracia; o Lead executa e registra. | motivo: ordem do usuário | impacto: vale sobre trava de IA
- D24 2026-09-24: Fluxo fiel FM: fase da mão travada (só mão) → carta ao centro → esq/dir alterna face → slot próprio → menu estrela (2 da carta) → desce sempre em Ataque; fase de campo livre (2 campos); RB/LB troca Ataque/Defesa (só sem atacar); START passa o turno, sem fileira Passar. | motivo: usuário detalhou o original | impacto: runtime mesa + position_system; QA 5 testes; GUT 47/47
- D25 2026-09-24: Mão reta centralizada (levantada sobe + cresce + vizinhas abrem, selo 1-2-3, renumera sozinho); fusão fiel (0=avulsa, 1=bloqueia, 2+=centro em ordem, par-a-par, fundida cai/novata fica, resultado face-up); equip pendente (sem tabela). | motivo: usuário detalhou + código do decomp | impacto: runtime fusion_system + mesa; QA 13 testes; GUT 69/69
- D26 2026-09-24: Mão sempre com 5 (início 5/5 sem extra, refill até 5 todo turno pros 2 lados, deckout ao completar); fusão em fila animada (ponta direita, flash/sucesso, chacoalhada/falha, sem mudar resultado). | motivo: 2 bugs do usuário (mão curta + animação rápida) | impacto: runtime duel/turn/mesa; QA 5 testes; GUT 74/74
- D27 2026-09-24: Slot escolhido ANTES da fusão (vazio ou ocupado); final encontra o campo (falha = campo descartado, carta desce); estrela no final da combinação. | motivo: 3 correções do usuário | impacto: runtime mesa; QA 3 testes; GUT 77/77
- D28 2026-09-24: IA do rival fiel básica (direto c/ mais forte, kill c/ mais fraco diferença>0, best-margin só vs ATK margem>=0, guardiã retorna 0); resto da IA intacto, melhora depois. | motivo: ordem do usuário (só a IA agora) | impacto: runtime mesa; QA 5 testes; GUT 82/82
