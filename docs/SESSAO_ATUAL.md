# SESSAO_ATUAL — CADERNO DE BORDO (mutável toda conversa)

> IA: atualize este arquivo NO FIM de toda resposta com mudança. Nunca deixe próximo_passo vazio.

```yaml
onde_estamos: "Mão reta + fusão fiel na mesa (levantar 1/2+ com selo, cadeia FM, conta como jogada)"
  acabamos_de_fazer_runtime_mao_fusao: "Runtime mão reta + fusão fiel em duel_table.gd + fusion_system.gd novo (receita ordem livre primeiro, equip pendente antes da regra, regra tipo+atributo+min_atk por priority D08; cadeia par a par em ordem, falha descarta acumulada, final face p/ cima na zona, conta como jogada; mão sempre reta sem leque, levantada sobe 38px + escala 1.15 + vizinhas afastam 26px, selo 1,2.. renumera, cima levanta/baixo abaixa/cancelar abaixa última, 0=avulsa D24, 1=bloqueia e avisa, 2+=voo ao centro em ordem + flash; só controle, sem mouse/teclado, schemas intactos, espelho e 1920x1080 intactos); mesa headless 0 SCRIPT ERROR + GUT 65/65 (1005 asserts) verde headless 4.7.2, sem Fake, R8 ok"
  acabamos_de_fazer_qa_fusao_fiel: "QA revisou test_fusao_fiel.gd (R2 ok: mesa real + Fusion/Summon/Battle/Duel reais, sem Fake, Input so simula botao; regra/desenho intactos) + completou 4 testes permanentes (cancelar abaixa ultima e renumera, mao centrada cx nos 2 lados sem rotacao, 1 levantada bloqueia e preserva sem gastar jogada, cadeia falha/equip descarta acumulada ao cemiterio e novata desce face-cima ATK contando jogada); GUT 69/69 (1089 asserts) verde headless 4.7.2, 0 SCRIPT ERROR, R8 ok"
  próximo_passo: "Aguardar ordem do usuario (sugestao: testar a mesa com fusao no controle de verdade)"
  acabamos_de_fazer_qa_3bugs: "QA travou 3 bugs do runtime em test_mesa_3bugs.gd (menu turno1 não marca+avisa e turno3 marca via can_attack real + centro desenho=centro slot 2 lados + lado1 180 frente/verso e lado0 0, DEF soma 90; mesa/carta reais, sem Fake, sem mudar regra); linha do runtime no bug6 revisada e aprovada (preparo antes de marcar); GUT 56/56 (903 asserts) verde headless 4.7.2 sem SCRIPT ERROR, R8 ok"
acabamos_de_fazer: "Fase da mão travada (centro/face/slot/estrela, sempre ATK) + campo livre + RB/LB posição + START passa; QA 5 testes; Lead verificou GUT 47/47 verde"
acabamos_de_fazer: "Runtime e QA agora têm ordem escrita p/ godot_* (MCP) + GUT headless; commitado"
acabamos_de_fazer: "R9 gravada no AGENTS (commit+push fim de tarefa); 4 commits pushed: jogo + dados FM + studio + docs; git status limpo"
acabamos_de_fazer: "QA travou 100% controle em test_gamepad.gd (2 testes novos: 11 ações zero teclado/mouse + mesa sem botão clicável via tscn+cena real); sinal clicada confirmado removido (só resta o assert em test_board_layout.gd:329, faz sentido); GUT 42/42 (602 asserts) verde headless 4.7.2, sem Fake, sem mudar regra, R8 ok"
  acabamos_de_fazer: "QA travou fluxo fiel FM em test_fluxo_fiel.gd (5 testes: cursor preso na mão, desce em ATK p/cima e p/baixo c/ estrela, RB/LB pós-ataque, START mão/campo); GUT 47/47 (682 asserts) verde headless 4.7.2, sem Fake, sem mudar regra, R8 ok"
  acabamos_de_fazer: "Runtime 6 bugs da mesa em duel_table.gd (face p/baixo desce virada p/ os 2 lados + menu estrela/alvo sempre POR CIMA do centro + campo com 20 slots magia inclusa + horizontal por posição de tela sem espelhar + trava SÓ no campo sem fugir p/ LP + direto com campo vazio p/ os 2 lados via menu alvo + IA direta; duel/ intacto, schemas intactos, sem Fake, só controle); check descartável 6/6 criado-mostrado-apagado (R8) + GUT 47/47 (682) verde headless 4.7.2 sem SCRIPT ERROR"
  acabamos_de_fazer: "Runtime 3 bugs da mesa em duel_table.gd (menu só mostra Atacar se can_attack real ok p/ qualquer trava + carta centrada no slot nos 2 lados via position+pivô + lado 1 gira 180 frente/verso, DEF soma 90; teste bug6 reordenado p/ turno 3 antes de marcar; sem Fake, regras/schemas intactos, card_view intacto); check descartável 3/3 criado-mostrado-apagado (R8) + GUT 53/53 (859 asserts) verde headless 4.7.2 sem SCRIPT ERROR"
  próximo_passo: "Aguardar ordem do usuario (sugestao: testar a mesa fiel no controle de verdade)"
 travas_e_dúvidas:
  - "D34: runtime ainda lê vida do duel_setup (starting_lp do duelista só sugere no Duelo); runtime ainda não lê campaign/scenes nem executa efeitos/fusões na mesa (D30) — Testar fusão e builder de efeito são só-dado, sem fingir (R1/R4 ok)"
  - "D34: jogar_duelo MIGRADO p/ --setup em 2026-09-24 (escreve temp_dir/duel_studio_rapido.json, lança Godot -- --setup <temp>); schemas/examples/duel_setup.json não é mais tocado (hash 41654F… intacto)"
  - "D17 diverge do doc 13: código e decks já estão em 5+5 slots e 40 cartas; doc 13 ainda diz 3+3; revisar doc 13 só após usuário aprovar tela"
  - "GUT 11/12: test_mao_inicial espera deck 20, decks têm 40 pós-D17; corrigir teste p/ 40 quando retomar (1 linha)"
  - "PERGUNTA PENDENTE ao usuário: tela 2 jogadores no mesmo PC ou contra a máquina simples?"
  - "FERRAMENTAS OFICIAIS (D18/D19): Coding-Solo godot-mcp v0.1.1 (server godot, npx, GODOT_PATH Godot 4.7.2, ~14 ferramentas godot_*, roda sem editor aberto) + GUT 9.7.1 (testes em astralis/testing/, 12 testes); Bebabin removido do repo em 2026-09-23"
  - "Não reabrir D01-D19 sem permissão; Rust/cargo ausente (só no Studio); Godot 4.7.2 exe em Godot/ ignorado no git"
  - "D24 runtime feito em 2026-09-24: XY no JSON só move desenho, carta continua indo p/ o índice escolhido; sem Fake, schemas intactos"
  - "D26 runtime feito em 2026-09-24: sair_duelo sem tela de desistencia (grep vazio, so reporta); posicao_l1/r1 + detalhes + pausar reservados sem acao; sem Fake, regras/schemas intactos"
  - "D26 parcial runtime feito em 2026-09-24: mesa sem mouse/teclado (Buttons viraram Labels sem clique, gui_input/_no_input/clicada/_na_carta_* apagados, fileira Passar só no cursor); project.godot já tinha as 11 ações só-joypad, sem edição; duel_board.gd e main.gd sem input, intactos; regras/schemas/desenho intactos; QA: 1 assert em test_board_layout.gd trocado p/ has_signal (sinal apagado)"
  - "D27 runtime feito em 2026-09-24: sem _btn_passar/FILEIRA_PASSAR, passar_turno no botão 6, _no_start_passar_turno usa advance_phase até trocar jogador; pausar removido; sem Fake, regras/schemas intactos; QA precisa trocar pausar→passar_turno no test_gamepad"
  - "FLUXO FIEL runtime feito em 2026-09-24: fase da mão travada (carta->centro, esq/dir face, 1 dos 5 slots, menu 2 guardian stars do dado gravada na instância, desce em ATK vertical via Summon real) + fase de campo livre (só próprio+rival+LP) + L1/R1 alterna ATK/DEF via PositionSystem novo (trava se has_attacked) + START passa turno (sem fileira Passar) e na mão não faz nada + não-monstro só avisa sem centro; summon liberou face_down+ATK e guarda guardian_star (aviso p/ lead/systems: lógica compartilhada, schemas intactos); mesa headless 0 SCRIPT ERROR + GUT 42/42 (602 asserts) verde + check descartável 23/23 apagado, R8 ok"
 - "MÃO RETA + FUSÃO FIEL runtime feito em 2026-09-24: duel_table.gd (mão reta sem leque, levantar cima/abaixar baixo/cancelar última, selo 1,2.., 0 avulsa/1 bloqueia/2+ combina, voo ao centro em ordem + flash, face p/ cima, zona normal, conta como jogada) + duel/fusion_system.gd novo (receita ordem livre, equip pendente, regra tipo+atributo+min_atk priority D08, cadeia descarta acumulada) + testing/test_fusao_fiel.gd 9 testes; só controle, schemas intactos, espelho e 1920x1080 intactos; headless 0 SCRIPT ERROR + GUT 65/65 (1005 asserts) verde, sem Fake, R8 ok"
 data_utc: "2026-09-24"
versão_docs: "1.5"
```

## Log curto (últimas 5)

- 2026-09-23: split monolito em docs/00-11 + melhorias v1.2 (flags-lite, battle win/lose, fusão regra, AI preset, templates, starter kit, preview unificado, test lab mínimo)
- 2026-09-23: criado 12 exportação protegida + cadeado por jogo + bundles por plataforma
- 2026-09-23: criado sistema anti-perda de contexto (AGENTS, SESSAO, DECISOES, MANIFEST)
- 2026-09-23: repo GitHub criado e push main (fcea17c) em https://github.com/joeyviciousfake-netizen/Astralis
- 2026-09-23: apagado Documentação.md legado (D14), fonte oficial = docs/00-12
- 2026-09-23: travado D15 (6 agentes) + limites de split em 11_ROADMAP_AGENTES
- 2026-09-23: criados .opencode/agents/lead+runtime+systems+campaign+editor+qa
- 2026-09-23: criado 13_TABULEIRO_DUELO.md V1 (zonas 3+3, DRAW/MAIN/BATTLE/END, mão 5/7, LP dado, win LP+deckout) via runtime+systems, bump docs v1.4
- 2026-09-23: criado projeto Godot astralis/ etapa 1 (loader+validador, STP 10/2/2 erros=0 no headless 4.7.2)
- 2026-09-23: GUT 9.7.1 instalado + teste real 3/3 verde (13 asserts) + .gitignore *.gd.uid
- 2026-09-23: duelo núcleo pronto (turn/invoca/batalha/dano/win-lose) + 12/12 GUT verde (62 asserts, seed determinística)
- 2026-09-23: GUT rodado de novo: 11/12 (1 falha esperada pós-D17: teste espera deck 20, decks agora têm 40)
- 2026-09-23: usuário propôs testar Coding-Solo/godot-mcp (npx, sem editor aberto); node 24 + pacote 0.1.1 ok; config escrita em ~/.config/opencode/opencode.json (server godot); falta reiniciar sessão e testar ferramentas ao vivo
- 2026-09-23: RESTART combinado: caderno reescrito como ponto de retomada (veredito MCP em 3 passos + pergunta da tela pendente + GUT 11/12)
- 2026-09-23: D18 veredito MCP ao vivo: Coding-Solo vence (versão 4.7.2, run STP 10/2/2 erros=0 DUELO 5 turnos 2600x0, uid+stop ok sem editor); bebabin perde (desativado, sem ferramentas na sessão)
- 2026-09-23: D19 remoção Bebabin executada + docs 03/10/11 com Coding-Solo v0.1.1 e GUT 9.7.1; run limpo pós-remoção STP 10/2/2 erros=0
- 2026-09-23: teste VN isolado em astralis/vn_test/ via MCP (cena+8 nós+script Lyra Sim/Não 2 finais); run ok 2 caminhos, errors=0; apagar após usuário ver
- 2026-09-23: D20 40 cartas no Starter (10 + 30 novas) + decks 40/40 + GUT 12/12 verde (62 asserts); base pronta p/ duelo
- 2026-09-23: D22 mesa jogável (invocar/atacar/passar/IA/LP/vitória) + 3 regras D17 no battle + 3 testes; cena 0 erros, GUT 15/15 (77 asserts)
- 2026-09-24: D24 runtime (BoardLayout + slot_rect com layout + mesa usa arena_starter); headless ok + GUT 15/15 + check descartável apagado
- 2026-09-24: D24 QA (test_board_layout.gd 6 testes) + GUT 21/21 (215 asserts) verde headless 4.7.2, sem Fake, R8 ok
- 2026-09-24: mão na mesa runtime (hand da arena p0 1240/980/95 aberta + p1 1240/20/60 mini de costas, fallback intacto); TABLE/STP 0 erros + GUT 21/21 verde
- 2026-09-24: QA mão arrumada (5 testes novos em test_board_layout.gd via Astralis real); GUT 26/26 (377 asserts) verde headless 4.7.2, sem Fake, R8 ok
- 2026-09-24: F1/F2 FM no runtime (empate ATKvsDEF nada acontece + clamp 0..9999 summon/battle) + F3 sem troca na mesa; GUT 26/26 (377 asserts) verde, nenhum teste quebrou
- 2026-09-24: QA 3 testes permanentes em test_duel_core.gd (empate ATKvsDEF, empate ATKvsATK, clamp 9999 via Summon real); GUT 29/29 (401 asserts) verde headless 4.7.2, sem Fake, R8 ok
- 2026-09-24: systems arena_starter em espelho (p1 m y=317 / s y=128 + X invertido 1536→780, p0 intacto); description atualizada; validado 20/20 espelho_ok, schema+hand intactos
- 2026-09-24: runtime espelho D25 (BoardLayout + duel_board fallback espelhados, mesa usa layout); mesa headless 0 erros + ESPELHO_OK + GUT 29/29 (401 asserts) verde, sem Fake, schemas/IDs intactos
- 2026-09-24: QA espelho D25 (3 testes permanentes em test_board_layout.gd via Astralis real); GUT 32/32 (440 asserts) verde headless 4.7.2, sem Fake, R8 ok
- 2026-09-24: runtime controle D26 (11 acoes joypad + cursor FM na mesa com auto-repeat 0.25s, confirmar/cancelar/sair, mouse fallback, sem troca); headless 0 erros + INPUT_OK + check-only ok, sem Fake, regras/schemas intactos
- 2026-09-24: QA controle D26 (test_gamepad.gd 5 testes via mesa/InputMap reais, sem gamepad fisico); GUT 37/37 (495 asserts) verde headless 4.7.2, sem Fake, R8 ok
- 2026-09-24: QA batalha FM (B1/B2/B3): 2 testes atualizados + 2 criados em test_duel_core.gd via Astralis real; GUT 43/43 (542 asserts) verde headless 4.7.2, sem Fake, R8 ok
- 2026-09-24: editor Studio Card Editor em astralis-studio/ (Vite+Svelte, node 24, src-tauri/ placeholder): lista 40 cartas + busca + DUPLICAR antes de criar, Simples/Avançado mesmo dado, validação PT-BR c/ onde clicar, salvar escreve em schemas/examples/cards/ (dev) ou baixa JSON (build), Jogar verde desabilitado; npm run build ok
- 2026-09-24: APP TAURI REAL em astralis-studio/ (dono editor): Rust 1.98 + tauri 2.11.6 + plugin-shell, janela 1400x900, comandos listar/salvar/validar/jogar + 4 testes Rust ok; frontend invoke no app c/ fallback navegador; Jogar verde salva+abre Godot 4.7.2 --path astralis (preview unificado, sem seed); app.bat menu [1] dev [2] build; exe src-tauri/target/release/astralis-studio.exe (+msi/nsis) validado abrindo; ver-editor.bat mantido p/ navegador; R1/R4/R8 ok
- 2026-09-24: REWRITE FM 1:1 no Studio (dono editor): App + CartasStudio + DuelistasLab + CenasLab + ValidacaoPainel espelhando +page/CardStudio/DuelistsLab/Lab/ValidationPanel do FM-Studio, Svelte4 + CSS próprio; dados nos comandos Tauri + snapshot (40 cartas + 2 efeitos + 2 duelistas); npm run build limpo; app.bat intacto
- 2026-09-24: BASE IGUALADA D33 (dono editor): frontend refeito em SvelteKit+Svelte5+Tailwind4+TS (base copiada do FM-Studio, Svelte4/CSS apagados); telas portadas no mesmo visual com dado Astralis; Rust +listar_duelistas/ler_deck; build limpo + check 0 + cargo test 6/6 + tauri build (exe+msi+nsis) + exe abre; app.bat opção 1/2 ok
- 2026-09-24: STUDIO COMPLETO D34 (dono editor): 8 blocos (Duelistas editável, Decks x/40, Fusões receitas+regras+Testar-dado, Efeitos galeria+builder sem executar, Duelo rápido c/ Play real, Cenas simples, Exportar validando, Assets PNG+cinza); starting_lp no schema (alinha doc 05); CenasLab/DuelistsLab apagados; cargo test 24/24 + build + check 0 nos 8 blocos
- 2026-09-24: QA pack FM importado no jogo (722/39/39/25081, 50 A+A fora, 0 erros, validado 762/41/41) + loader Starter via IDs + GUT 38/38 (507 asserts) em 7.6s, sem Fake, R8 ok
- 2026-09-24: runtime --setup (dono runtime): DataLoader aceita --setup <caminho> / --setup=<caminho>, usa se válido senão starter; duel_setup.json intacto; headless sem/com arg 0 SCRIPT ERROR; GUT 37/37 (501 asserts) verde, sem Fake, R8 ok
- 2026-09-24: QA pós-limpeza FM (Lead): test_pack_fm_* trocado de examples/ p/ pack (existe + 722 cartas fm_0001/fm_0722, sem importar, Starter limpo 0 fm_*); GUT 38/38 (512 asserts) verde headless 4.7.2, sem Fake, sem mudar regra, R8 ok
- 2026-09-24: editor DESTRAVA BOOT FM (dono editor): causa raiz = Fusões montada oculta renderizando 25.083 receitas x 3 selects x 762 options + selo com 762 validar_carta sequenciais + snapshot 4.7MB no bundle; fix = snapshot enxuto 284KB (fusions só contagem), selo via validar_projeto (1 invoke) + lotes paralelos c/ progresso, abas lazy-mount, Fusões 50/pág + busca, loading c/ fase real; medir: listar 76ms + validar 440ms (0 erros), build 6.3s, check 0, cargo 29/29, exe+msi+nsis rebuildado e janela viva; sem Fake, Rust intacto, R8 ok
- 2026-09-24: runtime D26 parcial 100% controle (dono runtime): mouse/teclado removidos da mesa (duel_table: Buttons→Labels sem clique, sem gui_input/pressed, FILEIRA_PASSAR só no cursor; card_view: sem signal clicada/gui_input, tudo IGNORE); duel_board/main sem input, intactos; project.godot 11 ações só-joypad confirmado sem edição; mesa headless 0 SCRIPT ERROR + GUT 40/40 (534 asserts) verde, sem Fake, regras/schemas/desenho intactos; QA: 1 assert ajustado p/ has_signal
- 2026-09-24: QA trava 100% controle (dono qa): 2 testes novos em test_gamepad.gd via InputMap/mesa reais (11 acoes zero teclado/mouse + tscn sem Button e cena real sem BaseButton/textos sem clique/cartas sem clicada); sinal clicada confirmado removido (só resta o assert test_board_layout.gd:329, faz sentido); GUT 42/42 (602 asserts) verde headless 4.7.2, sem Fake, sem mudar regra, R8 ok
