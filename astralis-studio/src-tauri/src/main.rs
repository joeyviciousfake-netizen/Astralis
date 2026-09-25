// Astralis Studio — backend Tauri REAL (dono: Editor Engineer).
//
// O que este backend faz (e o que NÃO faz):
// - FAZ: ler/escrever/validar DADO do projeto do editor em
//   astralis-studio/projects/default/ (boot VAZIO: só o que importar aparece)
//   e lançar o Astralis de verdade com --project <pasta> (preview unificado,
//   doc 10). Nunca lê nem escreve em schemas/examples/ (jogo embutido).
// - NÃO FAZ: calcular jogo, dano, efeito, fusão ou turno (R1). O editor nunca
//   simula; só prepara dado e pede execução ao Astralis (R4).
//
// Comandos expostos ao frontend (invoke):
// - listar_cartas    -> [{ file, data }] lidos do disco
// - salvar_carta     -> valida id snake_case e escreve <id>.json
// - validar_carta    -> confere obrigatórios do card.schema.json, erros em PT-BR
// - jogar_carta      -> valida tudo + salva + lança Godot --path astralis
// - listar_duelistas -> [{ file, data }] somente leitura (R1: sem editar)
// - ler_deck         -> { name, cards } de um deck_id (somente leitura)

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

// Pack de criação `.apack` V1 (docs/12 §12.7): zip + manifest + SHA256.
// O dado continua entrando pelo `importar_pack_valor` atual (passo 3).
mod apack;

#[derive(Debug, Serialize, Deserialize, Clone)]
struct CartaArquivo {
    file: String,
    data: serde_json::Value,
}

// `nivel` separa o que BARRA (erro) do que só AVISA (aviso). Antes tudo era
// erro e o Studio não tinha como falar "isso aqui é só um aviso" — o gate de
// efeitos (R4) precisa exatamente disso: projeto sem efeitos cadastrados
// avisa, projeto com efeitos e id errado barra.
fn nivel_padrao() -> String {
    "erro".to_string()
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct ErroValidacao {
    campo: String,
    #[serde(rename = "campoId")]
    campo_id: String,
    mensagem: String,
    /// "erro" (trava salvar/jogar) ou "aviso" (mostra, não trava).
    #[serde(default = "nivel_padrao")]
    nivel: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct ResultadoOk {
    ok: bool,
    file: String,
    mensagem: String,
}

fn erro(campo: &str, campo_id: &str, mensagem: &str) -> ErroValidacao {
    ErroValidacao {
        campo: campo.to_string(),
        campo_id: campo_id.to_string(),
        mensagem: mensagem.to_string(),
        nivel: "erro".to_string(),
    }
}

fn aviso(campo: &str, campo_id: &str, mensagem: &str) -> ErroValidacao {
    ErroValidacao {
        campo: campo.to_string(),
        campo_id: campo_id.to_string(),
        mensagem: mensagem.to_string(),
        nivel: "aviso".to_string(),
    }
}

fn eh_erro(e: &ErroValidacao) -> bool {
    e.nivel != "aviso"
}

// Só os que barram (erros) — é o que trava salvar/jogar/importar.
fn so_erros(lista: &[ErroValidacao]) -> Vec<&ErroValidacao> {
    lista.iter().filter(|e| eh_erro(e)).collect()
}

fn so_avisos(lista: &[ErroValidacao]) -> Vec<&ErroValidacao> {
    lista.iter().filter(|e| !eh_erro(e)).collect()
}

// "Arruma antes de salvar:\n- …" (mesma frase em todos os salvar_*).
fn mensagem_bloqueio(erros: &[&ErroValidacao]) -> String {
    let lista: Vec<String> = erros.iter().map(|e| format!("- {}", e.mensagem)).collect();
    format!("Arruma antes de salvar:\n{}", lista.join("\n"))
}

// Avisos num texto só (append na mensagem de sucesso, sem travar).
fn texto_avisos(avisos: &[&ErroValidacao]) -> String {
    avisos.iter().map(|a| format!("- {}", a.mensagem)).collect::<Vec<String>>().join("\n")
}

fn eh_id_snake(s: &str) -> bool {
    let mut letras = s.chars();
    match letras.next() {
        Some(c) if c.is_ascii_lowercase() => {}
        _ => return false,
    }
    s.chars()
        .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
}

// Acha a raiz do repo (pasta que contém astralis/ + Godot/) subindo a partir
// do exe e do diretório atual. Só para LANCAR o jogo (exe + pasta astralis).
// O DADO do editor mora em astralis-studio/projects/default/ (pasta_projeto).
fn raiz_projeto() -> Option<PathBuf> {
    let mut bases: Vec<PathBuf> = Vec::new();
    if let Ok(exe) = std::env::current_exe() {
        let mut p = exe.as_path();
        for _ in 0..8 {
            match p.parent() {
                Some(par) => {
                    p = par;
                    bases.push(p.to_path_buf());
                }
                None => break,
            }
        }
    }
    if let Ok(cwd) = std::env::current_dir() {
        let mut p = cwd.as_path();
        bases.push(p.to_path_buf());
        for _ in 0..6 {
            match p.parent() {
                Some(par) => {
                    p = par;
                    bases.push(p.to_path_buf());
                }
                None => break,
            }
        }
    }
    for b in bases {
        if b.join("astralis").is_dir() {
            return Some(b);
        }
    }
    None
}

// Acha a pasta astralis-studio/ (dona do projeto do editor) subindo a partir
// do exe e do diretório atual. Funciona no `cargo tauri dev`, no exe em
// src-tauri/target/release/ e no bundle instalado dentro do repo.
fn raiz_studio() -> Option<PathBuf> {
    let mut bases: Vec<PathBuf> = Vec::new();
    if let Ok(exe) = std::env::current_exe() {
        let mut p = exe.as_path();
        for _ in 0..10 {
            match p.parent() {
                Some(par) => {
                    p = par;
                    bases.push(p.to_path_buf());
                }
                None => break,
            }
        }
    }
    if let Ok(cwd) = std::env::current_dir() {
        let mut p = cwd.as_path();
        bases.push(p.to_path_buf());
        for _ in 0..8 {
            match p.parent() {
                Some(par) => {
                    p = par;
                    bases.push(p.to_path_buf());
                }
                None => break,
            }
        }
    }
    for b in &bases {
        if b.file_name().and_then(|n| n.to_str()) == Some("astralis-studio") {
            return Some(b.clone());
        }
        if b.join("astralis-studio").is_dir() {
            return Some(b.join("astralis-studio"));
        }
    }
    None
}

// Projeto do editor: astralis-studio/projects/default/ (boot VAZIO — só o que
// importar aparece). Cria a estrutura se faltar (pastas + .gitkeep para o git
// continuar rastreando + fusions/effects vazios válidos). Todo comando de dado
// lê/escreve AQUI, nunca no jogo.
fn pasta_projeto() -> Result<PathBuf, String> {
    let studio = raiz_studio().ok_or_else(|| "Não achei a pasta astralis-studio/ a partir daqui. Rode o app de dentro do projeto Astralis.".to_string())?;
    let proj = studio.join("projects").join("default");
    garantir_projeto(&proj)?;
    Ok(proj)
}

// As pastas do esqueleto: as 8 com .gitkeep versionado no repo (fonte da
// verdade: `git ls-files astralis-studio/projects/default/`) + layouts/ (o
// molde da carta é CONTEÚDO do usuário como cards/*.json — ignorado no git
// em .gitignore — mas a PASTA precisa existir, senão o 1º Salvar do molde
// não acha onde gravar).
const PASTAS_ESQUELETO: [&str; 9] = [
    "cards", "duelists", "decks", "arenas", "scenes", "layouts",
    "assets/cards", "assets/portraits", "assets/backgrounds",
];

fn garantir_projeto(proj: &std::path::Path) -> Result<(), String> {
    for sub in PASTAS_ESQUELETO {
        let dir = proj.join(sub);
        std::fs::create_dir_all(&dir)
            .map_err(|e| format!("Não consegui criar projects/default/{sub}: {e}"))?;
        // ---- POR QUE O .gitkeep É RECRIADO AQUI (não "otimizar" isto) ----
        // O boot (D29) apaga TODO o conteúdo do projeto a cada abertura e,
        // nas pastas de arte, `apagar_tudo_da_pasta` leva o .gitkeep junto
        // (para ele é um arquivo comum). Pasta vazia = pasta que some do
        // git: então todo `git status` mostrava os .gitkeep como DELETADOS
        // só de ABRIR o Studio — o app sujava o repositório sozinha e fazia
        // um agente futuro concluir que alguém tinha mexido no conteúdo.
        // O .gitkeep NÃO é conteúdo: é o marcador que mantém a pasta
        // rastreável. Por isso o esqueleto volta COM ele. Só cria se não
        // existir; nunca sobrescreve nada.
        let marca = dir.join(".gitkeep");
        if !marca.exists() {
            std::fs::write(&marca, b"")
                .map_err(|e| format!("Não consegui criar projects/default/{sub}/.gitkeep: {e}"))?;
        }
    }
    for (nome, base) in [
        ("fusions.json", "{\"schema_version\": 1, \"recipes\": [], \"rules\": []}\n"),
        ("effects.json", "{\"schema_version\": 1, \"effects\": []}\n"),
    ] {
        let arq = proj.join(nome);
        if !arq.is_file() {
            std::fs::write(&arq, base)
                .map_err(|e| format!("Não consegui criar projects/default/{nome}: {e}"))?;
        }
    }
    Ok(())
}

fn projeto_sub(sub: &str) -> Result<PathBuf, String> {
    let proj = pasta_projeto()?;
    let p = proj.join(sub);
    std::fs::create_dir_all(&p)
        .map_err(|e| format!("Não consegui abrir projects/default/{sub}: {e}"))?;
    Ok(p)
}

fn projeto_arquivo(nome: &str) -> Result<PathBuf, String> {
    Ok(pasta_projeto()?.join(nome))
}

fn pasta_cartas() -> Result<PathBuf, String> {
    projeto_sub("cards")
}

// ---- GATE DE CATÁLOGO (R4) ----
// O que a carta / o deck / o duelista / a fusão pode citar = o que o PROJETO
// tem de verdade (efeitos em effects.json; cartas/decks/arenas nas pastas).
// Antes CADA ponto fazia `if !lista.is_empty() && !lista.contains(id)` —
// fail-open: como o projeto nasce VAZIO (D29), a lista ficava sempre vazia e
// a checamento INTEIRA pulava (qualquer id inventado passava). Agora o
// catálogo distingue os dois estados e todo gate passa pelo mesmo helper.
#[derive(Debug, Clone, PartialEq)]
enum Catalogo {
    /// O projeto TEM itens: id fora da lista é ERRO.
    Listado(std::collections::HashSet<String>),
    /// Projeto novo/zerado (sem arquivo, sem a lista, ou lista vazia): ainda
    /// não dá para dizer "não existe" — só "ainda não tem". É AVISO, porque
    /// erro aqui travaria o projeto em branco do D29 logo no primeiro clique.
    Vazio,
}

impl Catalogo {
    fn de_set(ids: &std::collections::HashSet<String>) -> Catalogo {
        if ids.is_empty() {
            Catalogo::Vazio
        } else {
            Catalogo::Listado(ids.clone())
        }
    }

    fn de_ids(ids: impl IntoIterator<Item = String>) -> Catalogo {
        Catalogo::de_set(&ids.into_iter().collect())
    }

    fn tem(&self, id: &str) -> bool {
        match self {
            Catalogo::Listado(lista) => lista.contains(id),
            Catalogo::Vazio => false,
        }
    }
}

// Lê projects/default/effects.json UMA vez por validação. Todo mundo que
// precisa do gate usa isto (nada de ler o arquivo espalhado pelos comandos).
fn catalogo_efeitos() -> Catalogo {
    match pasta_projeto() {
        Ok(p) => catalogo_efeitos_de(&p),
        Err(_) => Catalogo::Vazio,
    }
}

fn catalogo_efeitos_de(proj: &std::path::Path) -> Catalogo {
    let caminho = proj.join("effects.json");
    let texto = match std::fs::read_to_string(&caminho) {
        Ok(t) => t,
        Err(_) => return Catalogo::Vazio,
    };
    let v: serde_json::Value = match serde_json::from_str(&texto) {
        Ok(v) => v,
        Err(_) => return Catalogo::Vazio,
    };
    let ids: Vec<String> = match v.get("effects") {
        Some(serde_json::Value::Array(lista)) => lista
            .iter()
            .filter_map(|e| e.get("id")?.as_str().map(|s| s.to_string()))
            .collect(),
        _ => Vec::new(),
    };
    Catalogo::de_ids(ids)
}

/// GATE ÚNICO do R4 para "este id existe no projeto?" — efeitos na carta,
/// deck no duelista, carta no deck e na fusão, arena no duelo. Sem este
/// helper os pontos voltam a ser fail-open um a um (o bug que ele fecha).
/// - catálogo listado + id na lista -> None (vale a pena).
/// - catálogo listado + id fora -> ERRO (msg_erro já vem com o id e onde clicar).
/// - catálogo vazio (projeto novo, D29) -> AVISO: o projeto ainda não tem nada
///   cadastrado, e msg_vazio diz onde resolver. NUNCA erro aqui: barra-error
///   quebraria o fluxo de quem acabou de abrir o editor em branco.
fn checar_catalogo(
    catalogo: &Catalogo,
    id: &str,
    campo: &str,
    campo_id: &str,
    msg_erro: &str,
    msg_vazio: &str,
) -> Option<ErroValidacao> {
    if catalogo.tem(id) {
        return None;
    }
    Some(match catalogo {
        Catalogo::Listado(_) => erro(campo, campo_id, msg_erro),
        Catalogo::Vazio => aviso(campo, campo_id, msg_vazio),
    })
}

/// O gate de efeito da carta É o gate único, com os textos do efeito (mesmo
/// formato de antes: id fora da lista = erro; projeto sem efeitos = aviso
/// dizendo onde pegar um modelo da galeria).
fn checar_efeito_da_carta(catalogo: &Catalogo, id: &str) -> Option<ErroValidacao> {
    checar_catalogo(
        catalogo,
        id,
        "Efeitos",
        "field-effects",
        &format!("Efeito \"{id}\" não existe neste projeto (só vale o que o Astralis sabe executar). Clique em Efeitos e escolha um modelo da lista — ou crie o efeito na aba Efeitos."),
        &format!("Efeito \"{id}\" não pode existir ainda: este projeto não tem nenhum efeito cadastrado. Clique na aba Efeitos e pegue um modelo da galeria (ou crie o seu) antes de salvar a carta."),
    )
}

fn inteiro_em(v: &serde_json::Value, chave: &str) -> Option<i64> {
    v.get(chave)?.as_i64()
}

// Lê um JSON do disco com erro em PT-BR simples.
fn ler_arquivo_json(caminho: &std::path::Path, o_que: &str) -> Result<serde_json::Value, String> {
    let texto = std::fs::read_to_string(caminho)
        .map_err(|_| format!("Não achei {o_que} em {}.", caminho.display()))?;
    serde_json::from_str(&texto)
        .map_err(|e| format!("{o_que} tem JSON quebrado: {e}. Abra o arquivo e confira vírgulas e chaves."))
}

// Escreve um JSON bonito com erro em PT-BR simples.
fn escrever_json_valor(caminho: &std::path::Path, valor: &serde_json::Value, o_que: &str) -> Result<(), String> {
    let texto = serde_json::to_string_pretty(valor)
        .map_err(|e| format!("Não consegui montar o JSON de {o_que}: {e}"))?
        + "\n";
    std::fs::write(caminho, texto)
        .map_err(|e| format!("Não consegui salvar {o_que} em {}: {e}", caminho.display()))
}

// IDs de carta que existem de verdade em projects/default/cards/*.json.
// Usado para conferir refs de deck/fusão (R4: só vale o que existe).
fn cartas_ids() -> Result<std::collections::HashSet<String>, String> {
    let pasta = pasta_cartas()?;
    let mut ids = std::collections::HashSet::new();
    let entries = std::fs::read_dir(&pasta)
        .map_err(|e| format!("Não consegui abrir {}: {e}", pasta.display()))?;
    for e in entries.flatten() {
        let p = e.path();
        if p.extension().and_then(|x| x.to_str()) != Some("json") {
            continue;
        }
        let texto = std::fs::read_to_string(&p)
            .map_err(|err| format!("Não consegui ler {}: {err}", p.display()))?;
        let v: serde_json::Value = serde_json::from_str(&texto)
            .map_err(|err| format!("{} tem JSON quebrado: {err}", p.display()))?;
        if let Some(id) = v.get("id").and_then(|x| x.as_str()) {
            ids.insert(id.to_string());
        }
    }
    Ok(ids)
}

// Carta completa por id (para o Testar fusão ler tipo/atributo/ATK do dado).
fn cartas_por_id() -> Result<std::collections::HashMap<String, serde_json::Value>, String> {
    let pasta = pasta_cartas()?;
    let mut mapa = std::collections::HashMap::new();
    let entries = std::fs::read_dir(&pasta)
        .map_err(|e| format!("Não consegui abrir {}: {e}", pasta.display()))?;
    for e in entries.flatten() {
        let p = e.path();
        if p.extension().and_then(|x| x.to_str()) != Some("json") {
            continue;
        }
        if let Ok(texto) = std::fs::read_to_string(&p) {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&texto) {
                if let Some(id) = v.get("id").and_then(|x| x.as_str()) {
                    mapa.insert(id.to_string(), v);
                }
            }
        }
    }
    Ok(mapa)
}

fn ids_de_projeto(sub: &str) -> Result<std::collections::HashSet<String>, String> {
    let pasta = projeto_sub(sub)?;
    let mut ids = std::collections::HashSet::new();
    let entries = std::fs::read_dir(&pasta)
        .map_err(|e| format!("Não consegui abrir {}: {e}", pasta.display()))?;
    for e in entries.flatten() {
        let p = e.path();
        if p.extension().and_then(|x| x.to_str()) != Some("json") {
            continue;
        }
        let stem = p.file_stem().and_then(|x| x.to_str()).unwrap_or("").to_string();
        if eh_id_snake(&stem) {
            ids.insert(stem);
        }
        if let Ok(texto) = std::fs::read_to_string(&p) {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&texto) {
                if let Some(id) = v.get("id").and_then(|x| x.as_str()) {
                    ids.insert(id.to_string());
                }
            }
        }
    }
    Ok(ids)
}

fn arenas_ids() -> std::collections::HashSet<String> {
    ids_de_projeto("arenas").unwrap_or_default()
}

// Monta o trecho do jogo: --project <pasta do editor> (+ --setup <temp> no
// duelo, por cima). O jogo lê TUDO da pasta do --project (doc: runtime
// --project). Sem fingir: quem executa é o Astralis (R1/R4).
fn montar_args_jogo(projeto: &str, setup: Option<&str>) -> Vec<String> {
    let mut args = vec!["--project".to_string(), projeto.to_string()];
    if let Some(s) = setup {
        args.push("--setup".to_string());
        args.push(s.to_string());
    }
    args
}

// Procura o executável do Godot (D14: 4.7.2 oficial, exe em Godot/).
// Um helper só para os dois lugares que lançam o jogo (jogar_carta e
// jogar_duelo) — antes o nome do exe estava repetido 4x, sem fallback.
// Ordem: GODOT_PATH -> Godot/Godot_v4.7.2-stable_win64.exe -> qualquer
// Godot_v*_win64*.exe na pasta Godot/ (versão mais nova primeiro).
fn achar_godot(raiz: &std::path::Path) -> Result<PathBuf, String> {
    let godot_dir = raiz.join("Godot");
    if let Some(do_env) = std::env::var_os("GODOT_PATH") {
        let p = PathBuf::from(do_env);
        if p.is_file() {
            return Ok(p);
        }
    }
    let oficial = godot_dir.join("Godot_v4.7.2-stable_win64.exe");
    if oficial.is_file() {
        return Ok(oficial);
    }
    // Qualquer outro win64 na pasta, do mais novo pro mais antigo.
    let mut outros: Vec<PathBuf> = Vec::new();
    if let Ok(entries) = std::fs::read_dir(&godot_dir) {
        for e in entries.flatten() {
            let nome = e.file_name().to_string_lossy().to_string();
            if nome.starts_with("Godot_v") && nome.contains("win64") && nome.ends_with(".exe") {
                outros.push(e.path());
            }
        }
    }
    outros.sort_by(|a, b| {
        versao_godot(&b.file_name().unwrap_or_default().to_string_lossy())
            .cmp(&versao_godot(&a.file_name().unwrap_or_default().to_string_lossy()))
    });
    if let Some(p) = outros.into_iter().next() {
        return Ok(p);
    }
    Err(format!(
        "Não achei o Godot. Procurei a variável GODOT_PATH, o arquivo {} e qualquer Godot_v*_win64*.exe na mesma pasta. Baixe o Godot 4.7.2 e coloque o exe em {}, ou defina a variável de ambiente GODOT_PATH apontando pro exe.",
        oficial.display(),
        godot_dir.display()
    ))
}

// "Godot_v4.7.2-stable_win64.exe" -> (4, 7, 2) (ordena 4.10 > 4.7, não 4 > 4).
fn versao_godot(nome: &str) -> (u32, u32, u32) {
    let meio = match nome.strip_prefix("Godot_v") {
        Some(m) => m,
        None => return (0, 0, 0),
    };
    let numeros: String = meio
        .chars()
        .take_while(|c| c.is_ascii_digit() || *c == '.')
        .collect();
    let partes = numeros.split('.');
    let pega = |i: usize| partes.clone().nth(i).and_then(|p| p.parse::<u32>().ok()).unwrap_or(0);
    (pega(0), pega(1), pega(2))
}

/// Lança um processo numa janela normal, solto do Studio (o alvo primário é
/// o Windows: `cmd /C start` abre janela independente e o jogo continua
/// rodando depois de fechar o editor). Em Unix não existe `start` — lá
/// chamamos o programa direto, que já é o comportamento certo.
fn abrir_processo(programa: &std::path::Path, args: &[String]) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        let mut cmd = std::process::Command::new("cmd");
        cmd.args(["/C", "start", ""]);
        cmd.arg(programa);
        cmd.args(args);
        cmd.spawn()
            .map(|_| ())
            .map_err(|e| format!("Não consegui abrir {}: {e}", programa.display()))
    }
    #[cfg(not(target_os = "windows"))]
    {
        std::process::Command::new(programa)
            .args(args)
            .spawn()
            .map(|_| ())
            .map_err(|e| format!("Não consegui abrir {}: {e}", programa.display()))
    }
}

// Lança o Astralis de verdade com um setup rápido externo (--setup <temp>)
// POR CIMA do projeto do editor (--project <projects/default>).
// O jogo já aceita os dois. Nunca toca no duel_setup do jogo (starter intacto).
fn lancar_astralis_com_setup(setup: &std::path::Path) -> Result<String, String> {
    let raiz = raiz_projeto().ok_or_else(|| "Não achei a raiz do projeto para lançar o jogo.".to_string())?;
    let godot = achar_godot(&raiz)?;
    let projeto = raiz.join("astralis");
    if !projeto.is_dir() {
        return Err("Não achei a pasta astralis/ do jogo.".to_string());
    }
    let pasta_ed = pasta_projeto()?;
    let extra = montar_args_jogo(&pasta_ed.to_string_lossy(), Some(&setup.to_string_lossy()));
    let mut args = vec!["--path".to_string(), projeto.to_string_lossy().to_string(), "--".to_string()];
    args.extend(extra);
    abrir_processo(&godot, &args)?;
    Ok("Astralis aberto de verdade (lendo projects/default + setup do duelo). Bom jogo!".to_string())
}

// Espelha schemas/card.schema.json com mensagens em PT-BR simples dizendo
// onde clicar (mesmo texto do frontend em src/lib/validacao.js).
// `catalogo` é o gate de efeitos (R4) — sai de `catalogo_efeitos()`.
fn checar_carta(carta: &serde_json::Value, catalogo: &Catalogo) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();

    if !carta.is_object() {
        return vec![erro(
            "Carta",
            "field-name",
            "Carta vazia. Clique em Criar nova para começar.",
        )];
    }

    match carta.get("schema_version") {
        Some(serde_json::Value::Number(n)) if n.as_i64() == Some(1) => {}
        _ => erros.push(erro(
            "Versão",
            "field-id",
            "Versão precisa ser 1. Não mexa neste campo (ele é automático).",
        )),
    }

    match carta.get("id").and_then(|v| v.as_str()) {
        Some(id) if eh_id_snake(id) => {}
        _ => erros.push(erro(
            "ID",
            "field-id",
            "Falta um ID válido. Clique no campo ID e use só letra minúscula, número e underline — exemplo: card_meu_dragao.",
        )),
    }

    match carta.get("name").and_then(|v| v.as_str()) {
        Some(nome) if !nome.trim().is_empty() => {}
        _ => erros.push(erro(
            "Nome",
            "field-name",
            "Falta o Nome. Clique no campo Nome e digite como a carta vai aparecer no jogo.",
        )),
    }

    let tipo = carta.get("card_type").and_then(|v| v.as_str()).unwrap_or("");
    if !["monster", "spell", "trap", "equip", "ritual"].contains(&tipo) {
        erros.push(erro(
            "Tipo",
            "field-card_type",
            "Escolha o Tipo. Clique em Tipo e selecione Monstro, Magia, Armadilha, Equipamento ou Ritual.",
        ));
    }

    if tipo == "monster" {
        let mt = carta.get("monster_type").and_then(|v| v.as_str()).unwrap_or("");
        let tipos = [
            "dragon", "spellcaster", "warrior", "beast", "aqua", "rock", "pyro",
            "thunder", "plant", "zombie", "fairy", "insect", "machine", "fiend",
            "beast-warrior", "winged-beast", "dinosaur", "reptile", "sea-serpent", "fish",
        ];
        if !tipos.contains(&mt) {
            erros.push(erro(
                "Tipo de monstro",
                "field-monster_type",
                "Carta monstro precisa do Tipo de monstro. Clique em Tipo de monstro e escolha um da lista.",
            ));
        }
        let at = carta.get("attribute").and_then(|v| v.as_str()).unwrap_or("");
        let attrs = ["light", "dark", "fire", "water", "earth", "wind", "divine"];
        if !attrs.contains(&at) {
            erros.push(erro(
                "Atributo",
                "field-attribute",
                "Carta monstro precisa do Atributo. Clique em Atributo e escolha um da lista.",
            ));
        }
        match inteiro_em(carta, "level") {
            Some(n) if (1..=12).contains(&n) => {}
            _ => erros.push(erro(
                "Nível",
                "field-level",
                "Nível precisa ser um número de 1 a 12. Clique em Nível e ajuste.",
            )),
        }
        match inteiro_em(carta, "attack") {
            Some(n) if (0..=9999).contains(&n) => {}
            _ => erros.push(erro(
                "ATK",
                "field-atk",
                "ATK precisa ser um número de 0 a 9999. Clique em ATK e ajuste.",
            )),
        }
        match inteiro_em(carta, "defense") {
            Some(n) if (0..=9999).contains(&n) => {}
            _ => erros.push(erro(
                "DEF",
                "field-def",
                "DEF precisa ser um número de 0 a 9999. Clique em DEF e ajuste.",
            )),
        }
    }

    match carta.get("effects") {
        Some(serde_json::Value::Array(lista)) => {
            for ef in lista {
                match ef.as_str() {
                    Some(id) if eh_id_snake(id) => {
                        if let Some(e) = checar_efeito_da_carta(catalogo, id) {
                            erros.push(e);
                        }
                    }
                    _ => erros.push(erro(
                        "Efeitos",
                        "field-effects",
                        "Tem um efeito com nome inválido. Clique em Efeitos e escolha um modelo da lista.",
                    )),
                }
            }
        }
        _ => erros.push(erro(
            "Efeitos",
            "field-effects",
            "Efeitos precisa ser uma lista (pode ser vazia). Clique em Efeitos e escolha da lista — não digite à mão.",
        )),
    }

    // Extensão FM (schemas/rule 11, dado puro; o jogo ignora na mesa V1).
    // guardian_star_1/2, password e starchip_cost são opcionais: ausente = N/A.
    const ESTRELAS_FM: [&str; 10] = [
        "sun", "moon", "mars", "jupiter", "mercury",
        "venus", "saturn", "uranus", "neptune", "pluto",
    ];
    for chave in ["guardian_star_1", "guardian_star_2"] {
        match carta.get(chave) {
            None => {}
            Some(serde_json::Value::String(s)) if ESTRELAS_FM.contains(&s.as_str()) => {}
            _ => erros.push(erro(
                "Estrela guardiã",
                "field-guardian",
                "Estrela guardiã inválida. Clique na estrela e escolha uma da lista (Sol, Lua, Marte…) ou deixe em branco (sem estrela).",
            )),
        }
    }
    match carta.get("password") {
        None => {}
        Some(serde_json::Value::String(s))
            if s.len() == 8 && s.bytes().all(|b| b.is_ascii_digit()) => {}
        _ => erros.push(erro(
            "Senha",
            "field-password",
            "Senha precisa ter 8 números (ex.: 89631139). Clique em Senha e digite 8 dígitos — ou deixe em branco (sem senha).",
        )),
    }
    match carta.get("starchip_cost") {
        None => {}
        Some(serde_json::Value::Number(n)) if n.as_i64().map(|v| v >= 0).unwrap_or(false) => {}
        _ => erros.push(erro(
            "Starchips",
            "field-starchip",
            "Custo em starchips precisa ser 0 ou mais (999999 = não comprável). Clique em Starchips e ajuste — ou deixe em branco.",
        )),
    }

    if let Some(tags) = carta.get("tags") {
        if !tags.is_array() {
            erros.push(erro(
                "Tags",
                "field-tags",
                "Tags precisa ser uma lista separada por vírgula. Clique em Tags — exemplo: starter, dragao.",
            ));
        }
    }

    erros
}

fn escrever_carta(pasta: &std::path::Path, carta: &serde_json::Value, id: &str) -> Result<String, String> {
    let destino = pasta.join(format!("{id}.json"));
    // Confere que o arquivo cai DENTRO da pasta mesmo com caminho curto do
    // Windows (8.3): canonicaliza o PAR (que existe) e junta o nome, em vez de
    // comparar o caminho cru do arquivo que ainda nem foi criado.
    let base = pasta.canonicalize().unwrap_or_else(|_| pasta.to_path_buf());
    let pai = destino
        .parent()
        .and_then(|p| p.canonicalize().ok())
        .unwrap_or_else(|| base.clone());
    let nome = destino.file_name().map(|n| n.to_os_string()).unwrap_or_default();
    if !pai.join(&nome).starts_with(&base) {
        return Err("ID fora da pasta de cartas. Use só letra minúscula, número e underline.".to_string());
    }
    let texto = serde_json::to_string_pretty(carta).map_err(|e| format!("Não consegui montar o JSON: {e}"))? + "\n";
    std::fs::write(&destino, texto).map_err(|e| format!("Não consegui salvar {}: {e}", destino.display()))?;
    Ok(format!("{id}.json"))
}

#[tauri::command]
fn listar_cartas() -> Result<Vec<CartaArquivo>, String> {
    let pasta = pasta_cartas()?;
    let mut nomes: Vec<String> = Vec::new();
    let entries = std::fs::read_dir(&pasta).map_err(|e| format!("Não consegui abrir {}: {e}", pasta.display()))?;
    for e in entries.flatten() {
        let p = e.path();
        if p.extension().and_then(|x| x.to_str()) == Some("json") {
            if let Some(n) = p.file_name().and_then(|x| x.to_str()) {
                nomes.push(n.to_string());
            }
        }
    }
    nomes.sort();
    let mut cartas = Vec::new();
    for nome in nomes {
        let texto = std::fs::read_to_string(pasta.join(&nome)).map_err(|e| format!("Não consegui ler {nome}: {e}"))?;
        let data: serde_json::Value =
            serde_json::from_str(&texto).map_err(|e| format!("{nome} tem JSON quebrado: {e}"))?;
        cartas.push(CartaArquivo { file: nome, data });
    }
    Ok(cartas)
}

#[tauri::command]
fn salvar_carta(carta: serde_json::Value) -> Result<ResultadoOk, String> {
    let pasta = pasta_cartas()?;
    salvar_carta_para(&pasta, &carta)
}

// Valida ANTES de gravar (mesma trava/mensagem dos outros salvar_*) e devolve
// o nome do arquivo. Aviso (ex.: carta citando efeito que o projeto ainda não
// tem) não impede o save: ele vai na mensagem.
fn salvar_carta_para(pasta: &std::path::Path, carta: &serde_json::Value) -> Result<ResultadoOk, String> {
    let id = carta.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    if !eh_id_snake(&id) {
        return Err("ID inválido: use só letra minúscula, número e underline — exemplo: card_meu_dragao.".to_string());
    }
    // Antes salvar_carta era o ÚNIMO salvar_* que não validava: carta inválida
    // ia pro disco sem reclamar.
    let revisao = checar_carta(carta, &catalogo_efeitos());
    let erros = so_erros(&revisao);
    if !erros.is_empty() {
        return Err(mensagem_bloqueio(&erros));
    }
    let file = escrever_carta(pasta, carta, &id)?;
    let mut mensagem = format!("Salvo em projects/default/cards/{file} (dado puro, sem mexer no jogo).");
    let avisos = so_avisos(&revisao);
    if !avisos.is_empty() {
        mensagem.push_str(&format!("\nAviso:\n{}", texto_avisos(&avisos)));
    }
    Ok(ResultadoOk { ok: true, file: file.clone(), mensagem })
}

#[tauri::command]
fn validar_carta(carta: serde_json::Value) -> Vec<ErroValidacao> {
    checar_carta(&carta, &catalogo_efeitos())
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct DuelistaArquivo {
    file: String,
    data: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct DeckLido {
    name: String,
    cards: Vec<String>,
}

fn listar_arquivos(pasta: &std::path::Path, o_que: &str) -> Result<Vec<DuelistaArquivo>, String> {
    let mut nomes: Vec<String> = Vec::new();
    let entries =
        std::fs::read_dir(pasta).map_err(|e| format!("Não consegui abrir {}: {e}", pasta.display()))?;
    for e in entries.flatten() {
        let p = e.path();
        if p.extension().and_then(|x| x.to_str()) == Some("json") {
            if let Some(n) = p.file_name().and_then(|x| x.to_str()) {
                nomes.push(n.to_string());
            }
        }
    }
    nomes.sort();
    let mut itens = Vec::new();
    for nome in nomes {
        let texto = std::fs::read_to_string(pasta.join(&nome))
            .map_err(|e| format!("Não consegui ler {nome}: {e}"))?;
        let data: serde_json::Value = serde_json::from_str(&texto)
            .map_err(|e| format!("{nome} tem JSON quebrado: {e}"))?;
        if data.get("id").and_then(|v| v.as_str()).is_none() {
            return Err(format!("{nome} não tem id ({o_que} inválido)."));
        }
        itens.push(DuelistaArquivo { file: nome, data });
    }
    Ok(itens)
}

// Somente leitura: o Studio mostra duelistas/decks, nunca edita (R1/R4).
#[tauri::command]
fn listar_duelistas() -> Result<Vec<DuelistaArquivo>, String> {
    let pasta = projeto_sub("duelists")?;
    listar_arquivos(&pasta, "duelista")
}

#[tauri::command]
fn ler_deck(deck_id: String) -> Result<DeckLido, String> {
    if !eh_id_snake(&deck_id) {
        return Err("ID de deck inválido.".to_string());
    }
    let pasta = projeto_sub("decks")?;
    let caminho = pasta.join(format!("{deck_id}.json"));
    let texto = std::fs::read_to_string(&caminho)
        .map_err(|_| format!("Deck \"{deck_id}\" não encontrado em projects/default/decks/."))?;
    let v: serde_json::Value =
        serde_json::from_str(&texto).map_err(|e| format!("{deck_id}.json tem JSON quebrado: {e}"))?;
    let nome = v.get("name").and_then(|x| x.as_str()).unwrap_or(&deck_id).to_string();
    let cartas = match v.get("cards") {
        Some(serde_json::Value::Array(lista)) => lista
            .iter()
            .filter_map(|c| c.as_str().map(|s| s.to_string()))
            .collect(),
        _ => Vec::new(),
    };
    Ok(DeckLido { name: nome, cards: cartas })
}

// Espelha schemas/duelist.schema.json com mensagens em PT-BR simples dizendo
// onde clicar. Vida (starting_lp) é dado do duelista (doc 05 §5.3); quem usa
// em batalha é o Astralis via duel_setup (Duelo rápido sugere esse valor).
fn checar_duelista(d: &serde_json::Value, decks: &Catalogo) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();
    if !d.is_object() {
        return vec![erro("Duelista", "field-name", "Duelista vazio. Clique em Criar novo para começar.")];
    }
    match d.get("schema_version") {
        Some(serde_json::Value::Number(n)) if n.as_i64() == Some(1) => {}
        _ => erros.push(erro("Versão", "field-id", "Versão precisa ser 1. Não mexa neste campo (ele é automático).")),
    }
    match d.get("id").and_then(|v| v.as_str()) {
        Some(id) if eh_id_snake(id) => {}
        _ => erros.push(erro("ID", "field-id", "Falta um ID válido. Clique no campo ID e use só letra minúscula, número e underline — exemplo: duelist_meu_rival.")),
    }
    match d.get("name").and_then(|v| v.as_str()) {
        Some(nome) if !nome.trim().is_empty() => {}
        _ => erros.push(erro("Nome", "field-name", "Falta o Nome. Clique no campo Nome e digite como o duelista aparece no jogo.")),
    }
    match d.get("deck_id").and_then(|v| v.as_str()) {
        Some(deck) if eh_id_snake(deck) => {
            // Gate único (R4): projeto COM decks e id fora da lista é erro;
            // projeto ainda sem nenhum deck é aviso (D29 abre vazio).
            if let Some(e) = checar_catalogo(
                decks,
                deck,
                "Deck",
                "field-deck",
                &format!("Deck \"{deck}\" não existe. Clique em Deck e escolha um da lista — ou crie na aba Decks."),
                &format!("Deck \"{deck}\" não pode existir ainda: este projeto não tem nenhum deck cadastrado. Clique na aba Decks e monte um baralho antes."),
            ) {
                erros.push(e);
            }
        }
        _ => erros.push(erro("Deck", "field-deck", "Falta o Deck. Clique em Deck e escolha um da lista.")),
    }
    match d.get("starting_lp") {
        None => {}
        Some(serde_json::Value::Number(n)) => {
            match n.as_i64() {
                Some(lp) if lp > 0 && lp <= 99999 => {}
                _ => erros.push(erro("Vida", "field-lp", "Vida precisa ser um número maior que 0 (ex.: 4000). Clique em Vida e ajuste.")),
            }
        }
        _ => erros.push(erro("Vida", "field-lp", "Vida precisa ser um número maior que 0 (ex.: 4000). Clique em Vida e ajuste.")),
    }
    match d.get("ai_preset") {
        Some(p) if p.is_object() => {
            match p.get("dificuldade").and_then(|v| v.as_str()) {
                Some(x) if ["facil", "normal", "dificil"].contains(&x) => {}
                _ => erros.push(erro("Dificuldade", "field-dificuldade", "Escolha a Dificuldade. Clique em Dificuldade e selecione Fácil, Normal ou Difícil.")),
            }
            for (chave, rotulo, campo_id) in [
                ("agressividade", "Agressividade", "field-agressividade"),
                ("uso_fusao", "Uso de fusão", "field-uso_fusao"),
                ("protecao_lp", "Proteção de LP", "field-protecao_lp"),
            ] {
                match p.get(chave).and_then(|v| v.as_i64()) {
                    Some(n) if (0..=100).contains(&n) => {}
                    _ => erros.push(erro(rotulo, campo_id, &format!("{rotulo} precisa ser um número de 0 a 100. Vá em Avançado e arraste o controle de {rotulo}."))),
                }
            }
        }
        _ => erros.push(erro("Estilo de jogo", "field-arquetipo", "Falta o estilo de jogo. Clique num arquétipo (Bravo, Equilibrado ou Defensor) — ele preenche tudo sozinho.")),
    }
    erros
}

fn escrever_duelista(pasta: &std::path::Path, d: &serde_json::Value, id: &str) -> Result<String, String> {
    let destino = pasta.join(format!("{id}.json"));
    // Mesmo cuidado de caminho do escrever_carta (canonicaliza o par, que
    // existe, em vez do arquivo que ainda não foi criado).
    let base = pasta.canonicalize().unwrap_or_else(|_| pasta.to_path_buf());
    let pai = destino
        .parent()
        .and_then(|p| p.canonicalize().ok())
        .unwrap_or_else(|| base.clone());
    let nome = destino.file_name().map(|n| n.to_os_string()).unwrap_or_default();
    if !pai.join(&nome).starts_with(&base) {
        return Err("ID fora da pasta de duelistas. Use só letra minúscula, número e underline.".to_string());
    }
    escrever_json_valor(&destino, d, &format!("duelista {id}"))?;
    Ok(format!("{id}.json"))
}

#[tauri::command]
fn salvar_duelista(duelista: serde_json::Value) -> Result<ResultadoOk, String> {
    let id = duelista.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    if !eh_id_snake(&id) {
        return Err("ID inválido: use só letra minúscula, número e underline — exemplo: duelist_meu_rival.".to_string());
    }
    let decks = Catalogo::de_set(&ids_de_projeto("decks").unwrap_or_default());
    let erros = checar_duelista(&duelista, &decks);
    let bloqueios = so_erros(&erros);
    if !bloqueios.is_empty() {
        return Err(mensagem_bloqueio(&bloqueios));
    }
    let pasta = projeto_sub("duelists")?;
    let file = escrever_duelista(&pasta, &duelista, &id)?;
    Ok(ResultadoOk {
        ok: true,
        file: file.clone(),
        mensagem: format!("Salvo em projects/default/duelists/{file} (dado puro, sem mexer no jogo)."),
    })
}

#[tauri::command]
fn validar_duelista(duelista: serde_json::Value) -> Vec<ErroValidacao> {
    let decks = Catalogo::de_set(&ids_de_projeto("decks").unwrap_or_default());
    checar_duelista(&duelista, &decks)
}

// Preview unificado (doc 10), contexto mínimo V1: valida tudo, salva o dado
// e lança o Astralis de verdade. Sem seed ainda. O editor não calcula nada:
// só entrega o dado e abre o jogo.
#[tauri::command]
fn jogar_carta(carta: serde_json::Value) -> Result<ResultadoOk, String> {
    let revisao = checar_carta(&carta, &catalogo_efeitos());
    let erros = so_erros(&revisao);
    if !erros.is_empty() {
        let lista: Vec<String> = erros.iter().map(|e| format!("- {}", e.mensagem)).collect();
        return Err(format!("Arruma antes de jogar:\n{}", lista.join("\n")));
    }
    let avisos = so_avisos(&revisao);
    let aviso_txt = if avisos.is_empty() { String::new() } else { format!("\nAviso:\n{}", texto_avisos(&avisos)) };
    let id = carta.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let pasta = pasta_cartas()?;
    let file = escrever_carta(&pasta, &carta, &id)?;

    let raiz = raiz_projeto().ok_or_else(|| "Não achei a raiz do projeto para lançar o jogo.".to_string())?;
    let godot = achar_godot(&raiz).map_err(|e| format!("Salvei a carta, mas {e}"))?;
    let projeto = raiz.join("astralis");
    if !projeto.is_dir() {
        return Err("Salvei a carta, mas não achei a pasta astralis/ do jogo.".to_string());
    }
    let pasta_ed = pasta_projeto()
        .map_err(|e| format!("Salvei a carta, mas {e}"))?;
    let extra = montar_args_jogo(&pasta_ed.to_string_lossy(), None);
    let mut args = vec!["--path".to_string(), projeto.to_string_lossy().to_string(), "--".to_string()];
    args.extend(extra);

    // Lança solto do Studio (janela normal, sobrevive ao fechar o editor).
    // O jogo lê TUDO de projects/default/ via --project (só o que importar).
    abrir_processo(&godot, &args).map_err(|e| format!("Salvei a carta, mas o jogo não abriu: {e}"))?;
    Ok(ResultadoOk {
        ok: true,
        file,
        mensagem: format!("Carta salva e Astralis aberto de verdade (lendo projects/default). Bom jogo!{aviso_txt}"),
    })
}

// ---- DECKS (bloco 2) ----
// Espelha schemas/deck.schema.json. Alvo do jogo: 40 cartas (doc 14 conta
// "contador 40"); schema aceita 20..60, então fora disso é ERRO e diferente
// de 40 é só AVISO mostrado na tela (não trava o salvar).
fn checar_deck(deck: &serde_json::Value, cartas: &Catalogo) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();
    if !deck.is_object() {
        return vec![erro("Deck", "field-name", "Deck vazio. Clique em Criar novo para começar.")];
    }
    match deck.get("schema_version") {
        Some(serde_json::Value::Number(n)) if n.as_i64() == Some(1) => {}
        _ => erros.push(erro("Versão", "field-id", "Versão precisa ser 1. Não mexa neste campo (ele é automático).")),
    }
    match deck.get("id").and_then(|v| v.as_str()) {
        Some(id) if eh_id_snake(id) => {}
        _ => erros.push(erro("ID", "field-id", "Falta um ID válido. Clique no campo ID e use só letra minúscula, número e underline — exemplo: deck_meu_baralho.")),
    }
    match deck.get("name").and_then(|v| v.as_str()) {
        Some(nome) if !nome.trim().is_empty() => {}
        _ => erros.push(erro("Nome", "field-name", "Falta o Nome. Clique no campo Nome e digite como o deck aparece no jogo.")),
    }
    match deck.get("cards") {
        Some(serde_json::Value::Array(lista)) => {
            if lista.len() < 20 || lista.len() > 60 {
                erros.push(erro("Cartas", "field-cards", &format!("O deck tem {} cartas e o jogo aceita de 20 a 60. Clique na lista e adicione ou remova cartas (alvo: 40).", lista.len())));
            }
            for c in lista {
                match c.as_str() {
                    Some(id) if eh_id_snake(id) => {
                        // Gate único (R4): projeto COM cartas e id fora da
                        // lista é erro; projeto sem nenhuma carta é aviso.
                        if let Some(e) = checar_catalogo(
                            cartas,
                            id,
                            "Cartas",
                            "field-cards",
                            &format!("Carta \"{id}\" não existe no projeto. Remova ela do deck (clique no ✕) ou crie a carta na aba Cartas."),
                            &format!("Carta \"{id}\" não pode existir ainda: este projeto não tem nenhuma carta cadastrada. Importe um pack (botão Importar… no topo, aba Exportar) ou crie a carta na aba Cartas."),
                        ) {
                            erros.push(e);
                        }
                    }
                    _ => erros.push(erro("Cartas", "field-cards", "Tem uma carta com nome inválido no deck. Remova ela (clique no ✕) e adicione de novo pela busca.")),
                }
            }
        }
        _ => erros.push(erro("Cartas", "field-cards", "O deck precisa de uma lista de cartas. Clique na busca, ache a carta e dê duplo clique para adicionar.")),
    }
    erros
}

#[tauri::command]
fn listar_decks() -> Result<Vec<DuelistaArquivo>, String> {
    let pasta = projeto_sub("decks")?;
    listar_arquivos(&pasta, "deck")
}

#[tauri::command]
fn salvar_deck(deck: serde_json::Value) -> Result<ResultadoOk, String> {
    let id = deck.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    if !eh_id_snake(&id) {
        return Err("ID inválido: use só letra minúscula, número e underline — exemplo: deck_meu_baralho.".to_string());
    }
    let cartas = Catalogo::de_set(&cartas_ids().unwrap_or_default());
    let erros = checar_deck(&deck, &cartas);
    let bloqueios = so_erros(&erros);
    if !bloqueios.is_empty() {
        return Err(mensagem_bloqueio(&bloqueios));
    }
    let pasta = projeto_sub("decks")?;
    let destino = pasta.join(format!("{id}.json"));
    escrever_json_valor(&destino, &deck, &format!("deck {id}"))?;
    Ok(ResultadoOk {
        ok: true,
        file: format!("{id}.json"),
        mensagem: format!("Salvo em projects/default/decks/{id}.json (dado puro, sem mexer no jogo)."),
    })
}

#[tauri::command]
fn validar_deck(deck: serde_json::Value) -> Vec<ErroValidacao> {
    let cartas = Catalogo::de_set(&cartas_ids().unwrap_or_default());
    checar_deck(&deck, &cartas)
}

// ---- FUSÕES (bloco 3) ----
// Formato preservado de projects/default/fusions.json:
// { schema_version, recipes: [{id, input:{card_a,card_b}, result}], rules: [...] }.
// Testar fusão NÃO executa jogo (R1): só confere o dado — receita exata vence,
// regra genérica é fallback por prioridade, ordem de A/B não importa.
fn caminho_fusoes() -> Result<std::path::PathBuf, String> {
    projeto_arquivo("fusions.json")
}

fn checar_fusoes(dado: &serde_json::Value, cartas: &Catalogo) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();
    if !dado.is_object() {
        return vec![erro("Fusões", "field-recipes", "Arquivo de fusões vazio. Adicione uma receita A+B=C para começar.")];
    }
    match dado.get("schema_version") {
        Some(serde_json::Value::Number(n)) if n.as_i64() == Some(1) => {}
        _ => erros.push(erro("Versão", "field-recipes", "Versão precisa ser 1. Não mexa neste campo (ele é automático).")),
    }
    let mut ids_vistos: std::collections::HashSet<String> = std::collections::HashSet::new();
    match dado.get("recipes") {
        Some(serde_json::Value::Array(lista)) => {
            for (i, r) in lista.iter().enumerate() {
                let onde = format!("Receita {}", i + 1);
                match r.get("id").and_then(|v| v.as_str()) {
                    Some(id) if eh_id_snake(id) => {
                        if !ids_vistos.insert(id.to_string()) {
                            erros.push(erro(&onde, "field-recipes", &format!("ID \"{id}\" repetido. Cada receita precisa de um ID único.")));
                        }
                    }
                    _ => erros.push(erro(&onde, "field-recipes", &format!("{onde} sem ID válido. Use só letra minúscula, número e underline."))),
                }
                let par = |chave: &str| r.get("input").and_then(|x| x.get(chave)).and_then(|v| v.as_str()).unwrap_or("").to_string();
                let (a, b) = (par("card_a"), par("card_b"));
                for (qual, id) in [("carta A", a.as_str()), ("carta B", b.as_str())] {
                    if !eh_id_snake(id) {
                        erros.push(erro(&onde, "field-recipes", &format!("{onde}: {qual} inválida. Escolha duas cartas da lista.")));
                    } else if let Some(e) = checar_catalogo(
                        cartas,
                        id,
                        &onde,
                        "field-recipes",
                        &format!("{onde}: carta \"{id}\" não existe no projeto. Escolha outra na lista."),
                        &format!("{onde}: carta \"{id}\" não pode existir ainda: este projeto não tem nenhuma carta cadastrada. Importe um pack (botão Importar… no topo, aba Exportar) ou crie a carta na aba Cartas."),
                    ) {
                        erros.push(e);
                    }
                }
                if !a.is_empty() && a == b {
                    erros.push(erro(&onde, "field-recipes", &format!("{onde}: carta A e B são a mesma ({a}). Fusão precisa de duas cartas diferentes.")));
                }
                match r.get("result").and_then(|v| v.as_str()) {
                    Some(id) if eh_id_snake(id) => {
                        if let Some(e) = checar_catalogo(
                            cartas,
                            id,
                            &onde,
                            "field-recipes",
                            &format!("{onde}: resultado \"{id}\" não existe no projeto. Crie a carta na aba Cartas ou escolha outra."),
                            &format!("{onde}: resultado \"{id}\" não pode existir ainda: este projeto não tem nenhuma carta cadastrada. Importe um pack (botão Importar… no topo, aba Exportar) ou crie a carta na aba Cartas."),
                        ) {
                            erros.push(e);
                        }
                    }
                    _ => erros.push(erro(&onde, "field-recipes", &format!("{onde} sem resultado. Escolha a carta que nasce da fusão."))),
                }
            }
        }
        _ => erros.push(erro("Receitas", "field-recipes", "Receitas precisa ser uma lista (pode ser vazia).")),
    }
    match dado.get("rules") {
        Some(serde_json::Value::Array(lista)) => {
            for (i, r) in lista.iter().enumerate() {
                let onde = format!("Regra {}", i + 1);
                match r.get("id").and_then(|v| v.as_str()) {
                    Some(id) if eh_id_snake(id) => {
                        if !ids_vistos.insert(id.to_string()) {
                            erros.push(erro(&onde, "field-rules", &format!("ID \"{id}\" repetido. Cada regra precisa de um ID único.")));
                        }
                    }
                    _ => erros.push(erro(&onde, "field-rules", &format!("{onde} sem ID válido. Use só letra minúscula, número e underline."))),
                }
                match r.get("when") {
                    Some(w) if w.is_object() && w.as_object().map(|o| o.len()).unwrap_or(0) >= 1 => {}
                    _ => erros.push(erro(&onde, "field-rules", &format!("{onde} sem condição. Escolha pelo menos tipo ou atributo (campo vazio = coringa)."))),
                }
                match r.get("result").and_then(|v| v.as_str()) {
                    Some(id) if eh_id_snake(id) => {
                        if let Some(e) = checar_catalogo(
                            cartas,
                            id,
                            &onde,
                            "field-rules",
                            &format!("{onde}: resultado \"{id}\" não existe no projeto. Crie a carta na aba Cartas ou escolha outra."),
                            &format!("{onde}: resultado \"{id}\" não pode existir ainda: este projeto não tem nenhuma carta cadastrada. Importe um pack (botão Importar… no topo, aba Exportar) ou crie a carta na aba Cartas."),
                        ) {
                            erros.push(e);
                        }
                    }
                    _ => erros.push(erro(&onde, "field-rules", &format!("{onde} sem resultado. Escolha a carta que nasce da fusão."))),
                }
                match r.get("priority").and_then(|v| v.as_i64()) {
                    Some(n) if n >= 0 => {}
                    _ => erros.push(erro(&onde, "field-rules", &format!("{onde}: prioridade precisa ser 0 ou mais (maior vence)."))),
                }
            }
        }
        _ => erros.push(erro("Regras", "field-rules", "Regras precisa ser uma lista (pode ser vazia).")),
    }
    erros
}

#[tauri::command]
fn ler_fusoes() -> Result<serde_json::Value, String> {
    let caminho = caminho_fusoes()?;
    if !caminho.is_file() {
        return Ok(serde_json::json!({"schema_version": 1, "recipes": [], "rules": []}));
    }
    ler_arquivo_json(&caminho, "fusions.json")
}

#[tauri::command]
fn salvar_fusoes(dado: serde_json::Value) -> Result<ResultadoOk, String> {
    let cartas = Catalogo::de_set(&cartas_ids().unwrap_or_default());
    let erros = checar_fusoes(&dado, &cartas);
    let bloqueios = so_erros(&erros);
    if !bloqueios.is_empty() {
        return Err(mensagem_bloqueio(&bloqueios));
    }
    let caminho = caminho_fusoes()?;
    escrever_json_valor(&caminho, &dado, "fusions.json")?;
    Ok(ResultadoOk {
        ok: true,
        file: "fusions.json".to_string(),
        mensagem: "Salvo em projects/default/fusions.json (dado puro, sem mexer no jogo).".to_string(),
    })
}

#[derive(Debug, serde::Serialize)]
struct ResultadoFusao {
    achou: bool,
    tipo: String,
    resultado: String,
    nome: String,
    mensagem: String,
}

fn carta_campo(cartas: &std::collections::HashMap<String, serde_json::Value>, id: &str, campo: &str) -> Option<String> {
    cartas.get(id)?.get(campo)?.as_str().map(|s| s.to_string())
}

fn carta_atk(cartas: &std::collections::HashMap<String, serde_json::Value>, id: &str) -> i64 {
    cartas.get(id).and_then(|c| c.get("attack")).and_then(|v| v.as_i64()).unwrap_or(0)
}

fn regra_casa(
    when: &serde_json::Value,
    a: &str,
    b: &str,
    cartas: &std::collections::HashMap<String, serde_json::Value>,
) -> bool {
    let confere = |chave: &str, carta: &str, campo_carta: &str| -> bool {
        match when.get(chave).and_then(|v| v.as_str()) {
            None => true,
            Some("") => true,
            Some(esperado) => carta_campo(cartas, carta, campo_carta).as_deref() == Some(esperado),
        }
    };
    if !confere("type_a", a, "monster_type") {
        return false;
    }
    if !confere("attribute_a", a, "attribute") {
        return false;
    }
    if !confere("type_b", b, "monster_type") {
        return false;
    }
    if !confere("attribute_b", b, "attribute") {
        return false;
    }
    if let Some(min) = when.get("min_atk").and_then(|v| v.as_i64()) {
        // min_atk olha a maior ATK das duas cartas (documentado na tela).
        if carta_atk(cartas, a).max(carta_atk(cartas, b)) < min {
            return false;
        }
    }
    true
}

// Só lê o dado: receita exata (A/B em qualquer ordem) vence; senão a regra de
// maior prioridade que casar; senão "não fundem". Nunca executa jogo (R1).
#[tauri::command]
fn testar_fusao(card_a: String, card_b: String) -> Result<ResultadoFusao, String> {
    if !eh_id_snake(&card_a) || !eh_id_snake(&card_b) {
        return Err("Escolha duas cartas válidas da lista antes de testar.".to_string());
    }
    if card_a == card_b {
        return Err("Escolha duas cartas diferentes — fusão precisa de um par.".to_string());
    }
    let cartas = cartas_por_id()?;
    if !cartas.contains_key(&card_a) {
        return Err(format!("Carta \"{card_a}\" não existe no projeto."));
    }
    if !cartas.contains_key(&card_b) {
        return Err(format!("Carta \"{card_b}\" não existe no projeto."));
    }
    let caminho = caminho_fusoes()?;
    let dado = ler_arquivo_json(&caminho, "fusions.json")?;
    let nome_de = |id: &str| -> String {
        cartas.get(id).and_then(|c| c.get("name")).and_then(|v| v.as_str()).unwrap_or(id).to_string()
    };
    if let Some(serde_json::Value::Array(lista)) = dado.get("recipes") {
        for r in lista {
            let a = r.get("input").and_then(|x| x.get("card_a")).and_then(|v| v.as_str()).unwrap_or("");
            let b = r.get("input").and_then(|x| x.get("card_b")).and_then(|v| v.as_str()).unwrap_or("");
            if (a == card_a && b == card_b) || (a == card_b && b == card_a) {
                let res = r.get("result").and_then(|v| v.as_str()).unwrap_or("").to_string();
                return Ok(ResultadoFusao {
                    achou: true,
                    tipo: "receita".to_string(),
                    resultado: res.clone(),
                    nome: nome_de(&res),
                    mensagem: format!("Receita exata: {} + {} = {} ({}). Validado no dado, sem jogar.", nome_de(&card_a), nome_de(&card_b), nome_de(&res), res),
                });
            }
        }
    }
    if let Some(serde_json::Value::Array(lista)) = dado.get("rules") {
        let mut ordenadas: Vec<&serde_json::Value> = lista.iter().collect();
        ordenadas.sort_by_key(|r| -(r.get("priority").and_then(|v| v.as_i64()).unwrap_or(0)));
        for r in ordenadas {
            let when = match r.get("when") {
                Some(w) => w,
                None => continue,
            };
            if regra_casa(when, &card_a, &card_b, &cartas) || regra_casa(when, &card_b, &card_a, &cartas) {
                let res = r.get("result").and_then(|v| v.as_str()).unwrap_or("").to_string();
                let rid = r.get("id").and_then(|v| v.as_str()).unwrap_or("?").to_string();
                return Ok(ResultadoFusao {
                    achou: true,
                    tipo: "regra".to_string(),
                    resultado: res.clone(),
                    nome: nome_de(&res),
                    mensagem: format!("Sem receita exata, mas a regra \"{rid}\" casa: {} + {} = {} ({}). Validado no dado, sem jogar.", nome_de(&card_a), nome_de(&card_b), nome_de(&res), res),
                });
            }
        }
    }
    Ok(ResultadoFusao {
        achou: false,
        tipo: "nenhuma".to_string(),
        resultado: "".to_string(),
        nome: "".to_string(),
        mensagem: format!("{} + {} não fundem: sem receita exata e nenhuma regra casa. Adicione uma receita na lista para criar essa fusão.", nome_de(&card_a), nome_de(&card_b)),
    })
}

// ---- EFEITOS (bloco 4) ----
// Galeria + builder salvam o MESMO dado de projects/default/effects.json
// (blocos trigger→conditions→target→actions→flow, effect.schema.json).
// SEM Testar/Play de efeito: o motor não existe no runtime (R4) — a tela
// avisa "execução vem depois". Aqui só valida o dado.
fn caminho_efeitos() -> Result<std::path::PathBuf, String> {
    projeto_arquivo("effects.json")
}

const TRIGGERS_OK: [&str; 6] = ["card_summoned", "card_destroyed", "turn_started", "turn_finished", "attack_started", "damage_dealt"];
const TARGETS_OK: [&str; 11] = ["self", "self_player", "opponent", "ally_monster", "enemy_monster", "all_ally_monsters", "all_enemy_monsters", "selected_card", "random_card", "card_in_graveyard", "card_in_hand"];
const ACTIONS_OK: [&str; 7] = ["modify_attack", "modify_defense", "damage", "heal", "destroy", "draw", "discard"];
const OPERADORES_OK: [&str; 6] = [">", "<", ">=", "<=", "==", "!="];

fn checar_um_efeito(ef: &serde_json::Value, onde: &str) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();
    match ef.get("id").and_then(|v| v.as_str()) {
        Some(id) if eh_id_snake(id) => {}
        _ => erros.push(erro(onde, "field-trigger", &format!("{onde} sem ID válido. Use só letra minúscula, número e underline — exemplo: effect_meu_efeito."))),
    }
    match ef.get("name").and_then(|v| v.as_str()) {
        Some(n) if !n.trim().is_empty() => {}
        _ => erros.push(erro(onde, "field-name", &format!("{onde} sem nome. Dê um nome que explique o efeito (ex.: Dano ao invocar)."))),
    }
    match ef.get("trigger").and_then(|v| v.as_str()) {
        Some(t) if TRIGGERS_OK.contains(&t) => {}
        _ => erros.push(erro(onde, "field-trigger", &format!("{onde}: gatilho inválido. Clique em Quando e escolha um da lista (só vale o que o Astralis sabe executar)."))),
    }
    match ef.get("conditions") {
        Some(serde_json::Value::Array(lista)) => {
            for (i, c) in lista.iter().enumerate() {
                let tem_campo = c.get("field").and_then(|v| v.as_str()).map(|s| !s.trim().is_empty()).unwrap_or(false);
                let op_ok = c.get("operator").and_then(|v| v.as_str()).map(|s| OPERADORES_OK.contains(&s)).unwrap_or(false);
                let tem_valor = c.get("value").map(|v| !(v.is_null() || (v.is_string() && v.as_str().unwrap_or("").trim().is_empty()))).unwrap_or(false);
                if !tem_campo || !op_ok || !tem_valor {
                    erros.push(erro(onde, "field-conditions", &format!("{onde}: condição {} incompleta. Preencha campo + comparação + valor (ex.: ataque do monstro inimigo >= 1000).", i + 1)));
                }
            }
        }
        _ => erros.push(erro(onde, "field-conditions", &format!("{onde}: condições precisa ser uma lista (pode ser vazia = sempre vale)."))),
    }
    match ef.get("target").and_then(|v| v.as_str()) {
        Some(t) if TARGETS_OK.contains(&t) => {}
        _ => erros.push(erro(onde, "field-target", &format!("{onde}: alvo inválido. Clique em Alvo e escolha um da lista."))),
    }
    match ef.get("actions") {
        Some(serde_json::Value::Array(lista)) if !lista.is_empty() => {
            for (i, a) in lista.iter().enumerate() {
                let acao = a.get("action").and_then(|v| v.as_str()).unwrap_or("");
                if !ACTIONS_OK.contains(&acao) {
                    erros.push(erro(onde, "field-actions", &format!("{onde}: ação {} inválida. Clique em Ação e escolha uma da lista.", i + 1)));
                    continue;
                }
                let alvo = ef.get("target").and_then(|v| v.as_str()).unwrap_or("");
                // Compatibilidade declarada alvo↔ação (effect.schema.json).
                let compativel = match acao {
                    "draw" => ["self_player", "self"].contains(&alvo),
                    "modify_attack" | "modify_defense" => ["self", "ally_monster", "enemy_monster", "all_ally_monsters", "all_enemy_monsters", "selected_card", "random_card"].contains(&alvo),
                    "destroy" => ["ally_monster", "enemy_monster", "all_ally_monsters", "all_enemy_monsters", "selected_card", "random_card", "card_in_hand", "card_in_graveyard"].contains(&alvo),
                    _ => true,
                };
                if !compativel {
                    erros.push(erro(onde, "field-actions", &format!("{onde}: ação \"{acao}\" não combina com esse alvo. Troque o Alvo (ex.: comprar carta só mira o próprio jogador).")));
                }
                // Campos contextuais: draw/damage/heal/discard pedem valor; modify pede valor+duração.
                match acao {
                    "draw" | "damage" | "heal" | "discard" => {
                        if a.get("amount").and_then(|v| v.as_i64()).is_none() {
                            erros.push(erro(onde, "field-actions", &format!("{onde}: ação \"{acao}\" precisa de um valor (ex.: comprar 1 carta). Preencha o número.")));
                        }
                    }
                    "modify_attack" | "modify_defense" => {
                        if a.get("amount").and_then(|v| v.as_i64()).is_none() {
                            erros.push(erro(onde, "field-actions", &format!("{onde}: ação \"{acao}\" precisa de um valor (ex.: -500). Preencha o número.")));
                        }
                        match a.get("duration").and_then(|v| v.as_str()).unwrap_or("") {
                            "until_end_of_turn" | "this_turn" | "permanent" => {}
                            _ => erros.push(erro(onde, "field-actions", &format!("{onde}: ação \"{acao}\" precisa de duração. Escolha: até o fim do turno ou permanente."))),
                        }
                    }
                    _ => {}
                }
            }
        }
        _ => erros.push(erro(onde, "field-actions", &format!("{onde} sem ação. Todo efeito precisa de pelo menos 1 ação (ex.: causar dano)."))),
    }
    match ef.get("flow").and_then(|v| v.get("mode")).and_then(|v| v.as_str()) {
        Some("sequence") => {}
        _ => erros.push(erro(onde, "field-actions", &format!("{onde}: fluxo precisa ser em sequência (if/else vem depois, ainda não existe)."))),
    }
    erros
}

fn checar_efeitos(dado: &serde_json::Value) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();
    if !dado.is_object() {
        return vec![erro("Efeitos", "field-name", "Arquivo de efeitos vazio. Escolha um modelo da galeria para começar.")];
    }
    match dado.get("schema_version") {
        Some(serde_json::Value::Number(n)) if n.as_i64() == Some(1) => {}
        _ => erros.push(erro("Versão", "field-name", "Versão precisa ser 1. Não mexa neste campo (ele é automático).")),
    }
    match dado.get("effects") {
        Some(serde_json::Value::Array(lista)) => {
            let mut vistos: std::collections::HashSet<String> = std::collections::HashSet::new();
            for (i, ef) in lista.iter().enumerate() {
                let onde = format!("Efeito {}", i + 1);
                if let Some(id) = ef.get("id").and_then(|v| v.as_str()) {
                    if !vistos.insert(id.to_string()) {
                        erros.push(erro(&onde, "field-name", &format!("ID \"{id}\" repetido. Cada efeito precisa de um ID único.")));
                    }
                }
                erros.extend(checar_um_efeito(ef, &onde));
            }
        }
        _ => erros.push(erro("Efeitos", "field-name", "Efeitos precisa ser uma lista (pode ser vazia).")),
    }
    erros
}

#[tauri::command]
fn ler_efeitos() -> Result<serde_json::Value, String> {
    let caminho = caminho_efeitos()?;
    if !caminho.is_file() {
        return Ok(serde_json::json!({"schema_version": 1, "effects": []}));
    }
    ler_arquivo_json(&caminho, "effects.json")
}

#[tauri::command]
fn salvar_efeitos(dado: serde_json::Value) -> Result<ResultadoOk, String> {
    let erros = checar_efeitos(&dado);
    let bloqueios = so_erros(&erros);
    if !bloqueios.is_empty() {
        return Err(mensagem_bloqueio(&bloqueios));
    }
    let caminho = caminho_efeitos()?;
    escrever_json_valor(&caminho, &dado, "effects.json")?;
    Ok(ResultadoOk {
        ok: true,
        file: "effects.json".to_string(),
        mensagem: "Salvo em projects/default/effects.json (dado puro, sem mexer no jogo).".to_string(),
    })
}

#[tauri::command]
fn validar_efeito(efeito: serde_json::Value) -> Vec<ErroValidacao> {
    checar_um_efeito(&efeito, "Efeito")
}

// ---- DUELO RÁPIDO (bloco 5) ----
// Preview unificado (doc 10): valida, escreve o setup rápido num arquivo
// temporário do SO (std::env::temp_dir()/duel_studio_rapido_<pid>_<seg>.json)
// e lança o Godot com --project <projects/default> + --setup <temp> (o jogo já
// aceita os dois: lê o projeto e põe o setup por cima). Nunca toca no
// duel_setup do jogo (starter intacto). O editor nunca simula duelo (R1).
//
// Nome por invocação: o nome fixo duel_studio_rapido.json fazia dois cliques
// rápidos em "Jogar agora" se atropelarem (o segundo sobrescreve o setup antes
// do primeiro Godot ler). Com pid+timestamp cada duelo tem o seu arquivo.
// Limpeza: apagamos na chamada SEGUINTE (todo duelo começa varrendo o que
// ficou >1h no temp) e não com atraso de thread — `cmd start` solta o processo
// e não esperamos o Godot ler, então apagar cedo quebraria o duelo em curso.
// O jogo só lê o --setup no boot, então 1h depois ele é lixo garantido.
const PREFIXO_SETUP: &str = "duel_studio_rapido_";
const SETUP_MAX_IDADE_SEGS: u64 = 3600;

fn agora_em_segundos() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn novo_setup_temporario(agora: u64) -> PathBuf {
    // pid + segundos + contador: o relógio só tem resolução de 1s, então dois
    // dueles no mesmo segundo ainda precisam de arquivos diferentes.
    let n = CONTADOR_SETUP.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    std::env::temp_dir().join(format!("{PREFIXO_SETUP}{}_{agora}_{n}.json", std::process::id()))
}

static CONTADOR_SETUP: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

// Idade em segundos do arquivo de setup (None = não é nosso/não dá para ler).
fn idade_setup(caminho: &std::path::Path, agora: u64) -> Option<u64> {
    let nome = caminho.file_name()?.to_str()?;
    let meio = nome.strip_prefix(PREFIXO_SETUP)?.strip_suffix(".json")?;
    let partes: Vec<&str> = meio.split('_').collect();
    // <pid>_<segundos>_<contador>
    if partes.len() < 3 {
        return None;
    }
    let secs: u64 = partes[1].parse().ok()?;
    Some(agora.saturating_sub(secs))
}

// Apaga os duel_studio_rapido_*.json velhos do temp. Devolve quantos apagou.
fn limpar_setups_antigos(agora: u64, max_idade: u64) -> usize {
    let temp = std::env::temp_dir();
    let mut n = 0;
    if let Ok(entries) = std::fs::read_dir(&temp) {
        for e in entries.flatten() {
            let p = e.path();
            if !p.is_file() {
                continue;
            }
            if let Some(idade) = idade_setup(&p, agora) {
                if idade > max_idade && std::fs::remove_file(&p).is_ok() {
                    n += 1;
                }
            }
        }
    }
    n
}

#[derive(Debug, serde::Deserialize)]
struct PedidoDuelo {
    #[serde(default)]
    duelista1: String,
    #[serde(default)]
    duelista2: String,
    #[serde(default)]
    vida: i64,
    #[serde(default)]
    seed: Option<i64>,
    #[serde(default)]
    arena: String,
    #[serde(default)]
    ordem: String,
    /// Campo de Testes (contrato systems `duel_setup.test_state` V1): o setup
    /// de teste montado na aba Testes (my_hand + 4 zonas p0/p1). Ausente, null
    /// ou vazio = duelo normal (Duelo rápido, igual a antes). Preenchido =
    /// força first_p1 (o teste começa sempre na SUA fase da mão, doc 04.6/D24)
    /// e viaja DENTRO do duel_setup temporário (--setup por cima do --project,
    /// mesmo caminho do Jogar). Só dado, nunca cálculo (R1/R4).
    #[serde(default)]
    test_state: Option<serde_json::Value>,
}

#[tauri::command]
fn listar_arenas() -> Vec<String> {
    let mut v: Vec<String> = arenas_ids().into_iter().collect();
    v.sort();
    if v.is_empty() {
        v.push("arena_starter".to_string());
    }
    v
}

/// Gate da arena do duelo rápido (R4) — o gate único com os textos da arena.
/// Fica em função própria porque `jogar_duelo` é o único gate que devolve
/// Result<…, String> (erro x aviso, e não lista de níveis), e assim os dois
/// lados são testáveis sem abrir o jogo.
fn checar_arena_do_duelo(catalogo: &Catalogo, arena: &str) -> Option<ErroValidacao> {
    checar_catalogo(
        catalogo,
        arena,
        "Arena",
        "field-arena",
        &format!("Arena \"{arena}\" não existe neste projeto. Clique em Duelo, aperte Avançado e escolha uma arena da lista."),
        &format!("Este projeto ainda não tem arena própria: o Astralis vai usar a arena padrão dele ({arena}). Para usar a sua, coloque um arquivo .json em projects/default/arenas/."),
    )
}

/// Gate do Campo de Testes (contrato systems `duel_setup.test_state` V1) —
/// o espelho da mesma regra do schema (schemas/duel_setup.schema.json).
/// Só valida DADO (R1/R4: nunca calcula jogo). Ausente = duelo normal, válido.
/// Quando presente: my_hand 0-5 Card IDs; p0/p1 monster/spell com exatos 5
/// slots (null = vazio, ou {card_id + face_up? + attack_position?}); refs de
/// carta passam pelo gate único (R4); turn_order tem que ser first_p1 (o teste
/// sempre começa na SUA fase da mão, doc 13.3 + D24 — documentado aqui,
/// executado no runtime). LP/seed valem os do topo, não se duplicam aqui.
fn checar_test_state(setup: &serde_json::Value, cartas: &Catalogo) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();
    let ts = match setup.get("test_state") {
        None => return erros,
        Some(v) => v,
    };
    let obj = match ts.as_object() {
        Some(o) => o,
        None => {
            return vec![erro(
                "Campo de Testes",
                "field-test-field",
                "Campo de Testes com formato inválido. Apague o teste e monte de novo na aba Campo de Testes (mão + campo).",
            )]
        }
    };
    // Teste sempre começa na SUA fase da mão: turn_order tem que ser first_p1.
    match setup.get("turn_order").and_then(|v| v.as_str()) {
        Some("first_p1") => {}
        _ => erros.push(erro(
            "Ordem do teste",
            "field-ordem",
            "Teste sempre começa na sua fase da mão. Deixe Quem começa em \"Você primeiro\" (first_p1) quando o Campo de Testes está preenchido.",
        )),
    }
    for k in obj.keys() {
        if !["my_hand", "p0_monster", "p0_spell", "p1_monster", "p1_spell"].contains(&k.as_str()) {
            erros.push(erro(
                "Campo de Testes",
                "field-test-field",
                &format!("Campo de Testes com campo desconhecido \"{k}\". Apague o teste e monte de novo na aba Campo de Testes."),
            ));
        }
    }
    if let Some(mh) = obj.get("my_hand") {
        match mh.as_array() {
            Some(lista) if lista.len() <= 5 => {
                for id_v in lista {
                    match id_v.as_str() {
                        Some(id) if eh_id_snake(id) => {
                            if let Some(e) = checar_catalogo(
                                cartas,
                                id,
                                "Mão do teste",
                                "field-test-hand",
                                &format!("Carta \"{id}\" da mão do teste não existe neste projeto. Clique em Campo de Testes e escolha uma carta da lista."),
                                &format!("Carta \"{id}\" ainda não pode existir: este projeto não tem nenhuma carta cadastrada. Clique na aba Cartas e importe um pack antes de montar o teste."),
                            ) {
                                erros.push(e);
                            }
                        }
                        _ => erros.push(erro(
                            "Mão do teste",
                            "field-test-hand",
                            "Mão do teste com carta inválida. Clique em Campo de Testes e escolha as cartas da lista (máximo 5).",
                        )),
                    }
                }
            }
            _ => erros.push(erro(
                "Mão do teste",
                "field-test-hand",
                "Mão do teste precisa ser uma lista de 0 a 5 cartas. Clique em Campo de Testes e escolha até 5 cartas da lista.",
            )),
        }
    }
    for chave in ["p0_monster", "p0_spell", "p1_monster", "p1_spell"] {
        let zona = match obj.get(chave) {
            None => continue,
            Some(z) => z,
        };
        let lista = match zona.as_array() {
            Some(l) => l,
            None => {
                erros.push(erro(
                    "Campo do teste",
                    "field-test-field",
                    &format!("\"{chave}\" precisa ter exatos 5 espaços (vazio ou com carta). Apague o teste e monte de novo na aba Campo de Testes."),
                ));
                continue;
            }
        };
        if lista.len() != 5 {
            erros.push(erro(
                "Campo do teste",
                "field-test-field",
                &format!("\"{chave}\" precisa ter exatos 5 espaços (achou {}). Apague o teste e monte de novo na aba Campo de Testes.", lista.len()),
            ));
            continue;
        }
        let rotulo = match chave {
            "p0_monster" => "seus monstros",
            "p0_spell" => "suas magias",
            "p1_monster" => "monstros do rival",
            _ => "magias do rival",
        };
        for (i, slot) in lista.iter().enumerate() {
            if slot.is_null() {
                continue;
            }
            let o = match slot.as_object() {
                Some(o) => o,
                None => {
                    erros.push(erro(
                        "Campo do teste",
                        "field-test-field",
                        &format!("Espaço {} de {rotulo} com formato inválido (vale vazio ou carta). Clique em Campo de Testes e escolha a carta da lista.", i + 1),
                    ));
                    continue;
                }
            };
            match o.get("card_id").and_then(|v| v.as_str()) {
                Some(id) if eh_id_snake(id) => {
                    if let Some(e) = checar_catalogo(
                        cartas,
                        id,
                        "Campo do teste",
                        "field-test-field",
                        &format!("Carta \"{id}\" do campo do teste não existe neste projeto. Clique em Campo de Testes e escolha uma carta da lista."),
                        &format!("Carta \"{id}\" ainda não pode existir: este projeto não tem nenhuma carta cadastrada. Clique na aba Cartas e importe um pack antes de montar o teste."),
                    ) {
                        erros.push(e);
                    }
                }
                _ => erros.push(erro(
                    "Campo do teste",
                    "field-test-field",
                    &format!("Espaço {} de {rotulo} sem carta válida. Clique em Campo de Testes e escolha a carta da lista (ou deixe vazio).", i + 1),
                )),
            }
            for b in ["face_up", "attack_position"] {
                if let Some(v) = o.get(b) {
                    if !v.is_boolean() {
                        let o_que = if b == "face_up" { "virada p/ cima" } else { "posição de ataque" };
                        erros.push(erro(
                            "Campo do teste",
                            "field-test-field",
                            &format!("Espaço {} de {rotulo}: \"{o_que}\" precisa ser ligado/desligado. Clique em Campo de Testes e ajuste (ou deixe em branco = virada p/ cima em Ataque).", i + 1),
                        ));
                    }
                }
            }
            for k in o.keys() {
                if !["card_id", "face_up", "attack_position"].contains(&k.as_str()) {
                    erros.push(erro(
                        "Campo do teste",
                        "field-test-field",
                        &format!("Espaço {} de {rotulo} com campo desconhecido \"{k}\". Apague o teste e monte de novo na aba Campo de Testes.", i + 1),
                    ));
                }
            }
        }
    }
    erros
}

/// Número 0-1000 do rect/style do molde (por-mil do próprio eixo, V1).
fn num_molde(v: &serde_json::Value) -> Option<f64> {
    match v {
        serde_json::Value::Number(n) => n.as_f64().filter(|f| (0.0..=1000.0).contains(f)),
        _ => None,
    }
}

/// Molde da carta em DADO (contrato systems `card_layout.schema.json` V1) —
/// o espelho da mesma regra do schema. Só valida DADO (R1/R4: nunca desenha,
/// nunca calcula jogo). V1 = molde padrão de monstro; peça ausente = default
/// do scan, então aqui só confere o que VEIO: schema_version==1, id snake,
/// name, layout_for==monster (V1), canvas=={59,86,per_mil}, pieces 0-9 com
/// kind do enum fechado (máx 1 por kind), rect 0-1000 com x+w/y+h<=1000,
/// style nos limites, visible_when do enum. O draft-07 não faz soma nem
/// unicidade de kind: essas duas conferem aqui + tools/fm_import.py --check.
/// V2 (molde por carta + editor visual) liga este gate no salvar/validar.
fn checar_card_layout(molde: &serde_json::Value) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();
    let obj = match molde.as_object() {
        Some(o) => o,
        None => {
            return vec![erro(
                "Molde",
                "field-layout",
                "Molde da carta vazio. O molde padrão de monstro já vem no projeto (V1 só tem ele).",
            )]
        }
    };
    match obj.get("schema_version").and_then(|v| v.as_i64()) {
        Some(1) => {}
        _ => erros.push(erro(
            "Versão do molde",
            "field-layout",
            "Versão do molde precisa ser 1. Não mexa neste campo (ele é automático).",
        )),
    }
    match obj.get("id").and_then(|v| v.as_str()) {
        Some(id) if eh_id_snake(id) && id.len() <= 64 => {}
        Some(id) if id.chars().count() > 64 => erros.push(erro(
            "ID do molde",
            "field-layout",
            "ID do molde longo demais. Use no máximo 64 caracteres (só letra minúscula, número e underline).",
        )),
        _ => erros.push(erro(
            "ID do molde",
            "field-layout",
            "Falta um ID válido no molde. Use só letra minúscula, número e underline — exemplo: card_layout_monster_default.",
        )),
    }
    match obj.get("name").and_then(|v| v.as_str()) {
        Some(nome) if !nome.trim().is_empty() => {}
        _ => erros.push(erro(
            "Nome do molde",
            "field-layout",
            "Falta o Nome do molde. Diga como o molde vai aparecer na lista (ex: Molde padrão de monstro).",
        )),
    }
    for k in obj.keys() {
        if !["schema_version", "id", "name", "description", "layout_for", "canvas", "pieces"]
            .contains(&k.as_str())
        {
            erros.push(erro(
                "Molde",
                "field-layout",
                &format!("Molde com campo desconhecido \"{k}\". O molde V1 só aceita: name, description, layout_for, canvas, pieces."),
            ));
        }
    }
    if let Some(lf) = obj.get("layout_for") {
        if lf.as_str() != Some("monster") {
            erros.push(erro(
                "Molde",
                "field-layout",
                "V1 só tem molde de monstro. Deixe layout_for em \"monster\" (outros tipos chegam depois).",
            ));
        }
    }
    if let Some(cv) = obj.get("canvas") {
        let ok = cv.as_object().map(|o| {
            o.len() == 3
                && o.get("w").and_then(|v| v.as_f64()) == Some(59.0)
                && o.get("h").and_then(|v| v.as_f64()) == Some(86.0)
                && o.get("unit").and_then(|v| v.as_str()) == Some("per_mil")
        });
        if ok != Some(true) {
            erros.push(erro(
                "Tamanho do molde",
                "field-layout",
                "O tamanho do molde é fixo na V1: 59x86 em por-mil. Não mexa no canvas.",
            ));
        }
    }
    let pecas = match obj.get("pieces") {
        None => return erros,
        Some(v) => v,
    };
    let lista = match pecas.as_array() {
        Some(l) if l.len() <= 9 => l,
        _ => {
            erros.push(erro(
                "Peças do molde",
                "field-layout",
                "O molde precisa ter de 0 a 9 peças (uma por tipo: nome, orbe, estrelas, arte, tipo, texto, ATK/DEF, rodapé, moldura).",
            ));
            return erros;
        }
    };
    let kinds = [
        "name", "attribute_orb", "level_stars", "art_window", "type_line",
        "text_box", "atkdef_bar", "footer", "frame",
    ];
    let mut vistos: Vec<&str> = Vec::new();
    for p in lista {
        let o = match p.as_object() {
            Some(o) => o,
            None => {
                erros.push(erro(
                    "Peças do molde",
                    "field-layout",
                    "Peça do molde fora de formato (vale só objeto com id + kind).",
                ));
                continue;
            }
        };
        for k in o.keys() {
            if !["id", "kind", "rect", "style", "visible_when"].contains(&k.as_str()) {
                erros.push(erro(
                    "Peças do molde",
                    "field-layout",
                    &format!("Peça com campo desconhecido \"{k}\". Vale só: id, kind, rect, style, visible_when."),
                ));
            }
        }
        match o.get("id").and_then(|v| v.as_str()) {
            Some(id) if eh_id_snake(id) && id.len() <= 64 => {}
            Some(id) if id.chars().count() > 64 => erros.push(erro(
                "Peças do molde",
                "field-layout",
                "Peça com ID longo demais. Use no máximo 64 caracteres (só letra minúscula, número e underline) — exemplo: name_bar.",
            )),
            _ => erros.push(erro(
                "Peças do molde",
                "field-layout",
                "Peça sem ID válido. Use só letra minúscula, número e underline — exemplo: name_bar.",
            )),
        }
        match o.get("kind").and_then(|v| v.as_str()) {
            Some(k) if kinds.contains(&k) => {
                if vistos.contains(&k) {
                    erros.push(erro(
                        "Peças do molde",
                        "field-layout",
                        &format!("Peça \"{k}\" repetida (vale no máximo 1 por tipo). Apague a cópia."),
                    ));
                } else {
                    vistos.push(k);
                }
            }
            _ => erros.push(erro(
                "Peças do molde",
                "field-layout",
                "Peça com tipo fora da lista. Os 9 tipos são: nome, orbe, estrelas, arte, tipo, texto, ATK/DEF, rodapé e moldura.",
            )),
        }
        if let Some(r) = o.get("rect") {
            let nums = ["x", "y", "w", "h"]
                .iter()
                .filter_map(|k| r.get(*k).and_then(num_molde))
                .collect::<Vec<f64>>();
            let chaves_ok = r.as_object().map(|o| o.len() == 4).unwrap_or(false);
            if nums.len() != 4 || !chaves_ok {
                erros.push(erro(
                    "Posição da peça",
                    "field-layout",
                    "Posição (rect) precisa ter x, y, w e h de 0 a 1000 (por-mil da carta).",
                ));
            } else if nums[0] + nums[2] > 1000.0 || nums[1] + nums[3] > 1000.0 {
                erros.push(erro(
                    "Posição da peça",
                    "field-layout",
                    "Peça saindo da carta (x+largura e y+altura precisam caber em 1000). Diminua ou mova a peça.",
                ));
            }
        }
        if let Some(s) = o.get("style") {
            match s.as_object() {
                None => erros.push(erro(
                    "Visual da peça",
                    "field-layout",
                    "Visual (style) fora de formato. Vale só: font_size, bold, color, align, z.",
                )),
                Some(so) => {
                    for k in so.keys() {
                        if !["font_size", "bold", "color", "align", "z"].contains(&k.as_str()) {
                            erros.push(erro(
                                "Visual da peça",
                                "field-layout",
                                &format!("Visual com campo desconhecido \"{k}\". Vale só: font_size, bold, color, align, z."),
                            ));
                        }
                    }
                    if let Some(v) = so.get("font_size") {
                        if num_molde(v).is_none() {
                            erros.push(erro(
                                "Visual da peça",
                                "field-layout",
                                "Tamanho da letra (font_size) precisa ser de 0 a 1000 (por-mil da altura).",
                            ));
                        }
                    }
                    if let Some(v) = so.get("bold") {
                        if !v.is_boolean() {
                            erros.push(erro(
                                "Visual da peça",
                                "field-layout",
                                "Negrito (bold) precisa ser ligado/desligado.",
                            ));
                        }
                    }
                    if let Some(v) = so.get("color") {
                        let ok = v.as_str().map(|c| {
                            c.len() == 7
                                && c.starts_with('#')
                                && c[1..].chars().all(|ch| ch.is_ascii_hexdigit())
                        });
                        if ok != Some(true) {
                            erros.push(erro(
                                "Visual da peça",
                                "field-layout",
                                "Cor (color) precisa ser hex — exemplo: #2a1c08.",
                            ));
                        }
                    }
                    if let Some(v) = so.get("align") {
                        if !["left", "center", "right"].contains(&v.as_str().unwrap_or("")) {
                            erros.push(erro(
                                "Visual da peça",
                                "field-layout",
                                "Alinhamento (align) só aceita: left, center, right.",
                            ));
                        }
                    }
                    if let Some(v) = so.get("z") {
                        match v.as_i64() {
                            Some(z) if (0..=10).contains(&z) => {}
                            _ => erros.push(erro(
                                "Visual da peça",
                                "field-layout",
                                "Ordem de desenho (z) precisa ser de 0 a 10 (moldura 0 primeiro, orbe 6 por cima).",
                            )),
                        }
                    }
                }
            }
        }
        if let Some(v) = o.get("visible_when") {
            if !["always", "monster_only"].contains(&v.as_str().unwrap_or("")) {
                erros.push(erro(
                    "Peças do molde",
                    "field-layout",
                    "Quando mostrar (visible_when) só aceita: always, monster_only (ATK/DEF é só de monstro).",
                ));
            }
        }
    }
    erros
}

// ---- MOLDE DA CARTA (bloco do layout V1) ----
// O molde (contrato systems `card_layout.schema.json` V1) mora em
// projects/default/layouts/card_layout_monster_default.json. O jogo lê de lá
// via --project e cai no default embutido sem ele (projeto legado); o Studio
// EDITA aqui. Só dado, nunca desenho nem regra (R1/R4). V1 = só este molde;
// sem peça nova (kinds fechados), sem campo novo na carta.
const MOLDE_ARQUIVO: &str = "card_layout_monster_default.json";

fn caminho_molde_de(proj: &std::path::Path) -> PathBuf {
    proj.join("layouts").join(MOLDE_ARQUIVO)
}

fn caminho_molde() -> Result<PathBuf, String> {
    Ok(caminho_molde_de(&pasta_projeto()?))
}

// Default oficial (schemas/examples/layouts/...): o que o `ler` devolve
// quando o projeto ainda não tem molde (projeto vazio D29 ou legado). Lido
// do repo — sem copiar os números para dentro do Rust (fonte única, igual
// ao teste do default oficial). O jogo faz o mesmo com o default embutido.
fn molde_padrao_oficial() -> Result<serde_json::Value, String> {
    let raiz = raiz_studio()
        .and_then(|s| s.parent().map(|p| p.to_path_buf()))
        .ok_or_else(|| "Não achei a pasta astralis-studio/ a partir daqui. Rode o app de dentro do projeto Astralis.".to_string())?;
    let oficial = raiz.join("schemas").join("examples").join("layouts").join(MOLDE_ARQUIVO);
    ler_arquivo_json(&oficial, "molde padrão oficial (schemas/examples/layouts)")
}

fn ler_molde_de(proj: &std::path::Path) -> Result<serde_json::Value, String> {
    let caminho = caminho_molde_de(proj);
    if !caminho.is_file() {
        return molde_padrao_oficial();
    }
    ler_arquivo_json(&caminho, "molde da carta (layouts/card_layout_monster_default.json)")
}

fn salvar_molde_para(proj: &std::path::Path, molde: &serde_json::Value) -> Result<ResultadoOk, String> {
    // Valida ANTES de gravar (mesma trava dos outros salvar_*): inválido não
    // grava, e a mensagem diz onde clicar (vem do checar_card_layout).
    let erros = checar_card_layout(molde);
    let bloqueios = so_erros(&erros);
    if !bloqueios.is_empty() {
        return Err(mensagem_bloqueio(&bloqueios));
    }
    let pasta = proj.join("layouts");
    std::fs::create_dir_all(&pasta)
        .map_err(|e| format!("Não consegui criar projects/default/layouts/: {e}"))?;
    escrever_json_valor(&caminho_molde_de(proj), molde, "molde da carta")?;
    Ok(ResultadoOk {
        ok: true,
        file: format!("layouts/{MOLDE_ARQUIVO}"),
        mensagem: "Molde salvo em projects/default/layouts/card_layout_monster_default.json (só o desenho; o jogo lê via --project).".to_string(),
    })
}

#[tauri::command]
fn ler_card_layout() -> Result<serde_json::Value, String> {
    ler_molde_de(&pasta_projeto()?)
}

#[tauri::command]
fn validar_molde(molde: serde_json::Value) -> Vec<ErroValidacao> {
    checar_card_layout(&molde)
}

#[tauri::command]
fn salvar_card_layout(molde: serde_json::Value) -> Result<ResultadoOk, String> {
    salvar_molde_para(&pasta_projeto()?, &molde)
}

 /// Diz se o test_state do pedido é "vazio" (ausente, null, {} ou só com mão
/// vazia e zonas ausentes/só-null) — vazio = duelo normal, sem test_state no
/// setup. Evita mandar `{}` à toa e mantém o --setup idêntico ao do Duelo
/// rápido quando o usuário não preencheu nada no Campo de Testes. Formato
/// quebrado (ex.: string no lugar do objeto) NÃO é vazio: cai no gate, que
/// barra com a msg PT-BR de onde clicar.
fn test_state_vazio(ts: Option<&serde_json::Value>) -> bool {
    let v = match ts {
        None => return true,
        Some(v) => v,
    };
    if v.is_null() {
        return true;
    }
    let obj = match v.as_object() {
        None => return false,
        Some(o) => o,
    };
    if obj.is_empty() {
        return true;
    }
    let mao_vazia = match obj.get("my_hand") {
        None => true,
        Some(mh) => mh.as_array().map(|l| l.is_empty()).unwrap_or(false),
    };
    if !mao_vazia {
        return false;
    }
    for chave in ["p0_monster", "p0_spell", "p1_monster", "p1_spell"] {
        match obj.get(chave) {
            None => {}
            Some(z) => {
                let tem_carta = z
                    .as_array()
                    .map(|l| l.iter().any(|s| !s.is_null()))
                    .unwrap_or(true);
                if tem_carta {
                    return false;
                }
            }
        }
    }
    true
}

/// Monta o duel_setup do duelo rápido/teste (o MESMO JSON que viaja no
/// --setup temporário por cima do --project). Com teste preenchido, o
/// turn_order é sempre first_p1 (doc 04.6: o teste começa na sua fase da mão,
/// D24) e o test_state viaja dentro; sem teste, idêntico ao setup do Duelo
/// rápido (sem a chave test_state).
fn montar_setup_duelo(
    duelista1: &str,
    deck1: &str,
    duelista2: &str,
    deck2: &str,
    vida: i64,
    ordem: &str,
    seed: i64,
    arena: &str,
    test_state: Option<&serde_json::Value>,
) -> serde_json::Value {
    let tem_teste = !test_state_vazio(test_state);
    let mut setup = serde_json::json!({
        "schema_version": 1,
        "duel_id": "duel_studio_rapido",
        "duelist1": { "duelist_id": duelista1, "deck_id": deck1 },
        "duelist2": { "duelist_id": duelista2, "deck_id": deck2 },
        "starting_lp": vida,
        "turn_order": if tem_teste { "first_p1".to_string() } else { ordem.to_string() },
        "seed": seed,
        "arena_id": arena,
        "win": { "on_lp_zero": true, "on_deckout": true }
    });
    if tem_teste {
        if let Some(ts) = test_state {
            setup["test_state"] = ts.clone();
        }
    }
    setup
}

/// Validação viva do Campo de Testes (aba Testes): recebe o duel_setup
/// montado na tela (com test_state + turn_order) e devolve a mesma lista
/// PT-BR de onde clicar do gate checar_test_state. Só valida dado (R1/R4).
#[tauri::command]
fn validar_test_state(setup: serde_json::Value) -> Vec<ErroValidacao> {
    let cartas = Catalogo::de_set(&cartas_ids().unwrap_or_default());
    checar_test_state(&setup, &cartas)
}

#[tauri::command]
fn jogar_duelo(pedido: PedidoDuelo) -> Result<ResultadoOk, String> {
    if !eh_id_snake(&pedido.duelista1) || !eh_id_snake(&pedido.duelista2) {
        return Err("Escolha os dois duelistas da lista antes de jogar.".to_string());
    }
    if pedido.duelista1 == pedido.duelista2 {
        return Err("Escolha dois duelistas diferentes — ninguém duela contra si mesmo.".to_string());
    }
    if pedido.vida <= 0 || pedido.vida > 99999 {
        return Err("Vida precisa ser um número maior que 0 (ex.: 4000). Ajuste em Vida e tente de novo.".to_string());
    }
    // Campo de Testes: com teste preenchido a ordem é SEMPRE first_p1 (sua
    // fase da mão, doc 04.6/D24) — o que veio no pedido é ignorado. Sem
    // teste, vale a ordem pedida (Duelo rápido normal).
    let tem_teste = !test_state_vazio(pedido.test_state.as_ref());
    let ordem = if tem_teste {
        "first_p1".to_string()
    } else {
        let o = if pedido.ordem.trim().is_empty() { "first_p1".to_string() } else { pedido.ordem.trim().to_string() };
        if !["first_p1", "first_p2", "random"].contains(&o.as_str()) {
            return Err("Ordem de turno inválida. Escolha quem começa na lista.".to_string());
        }
        o
    };
    // Validação do teste ANTES de ler os decks do disco (mesmo gate da
    // validação viva): mão/campo/ordem quebrados barram aqui com a msg PT-BR
    // de onde clicar, sem depender de mais nada.
    if tem_teste {
        let sonda = serde_json::json!({ "turn_order": ordem, "test_state": pedido.test_state.clone().unwrap() });
        let cartas = Catalogo::de_set(&cartas_ids().unwrap_or_default());
        let rev_teste = checar_test_state(&sonda, &cartas);
        let bloqueios = so_erros(&rev_teste);
        if !bloqueios.is_empty() {
            return Err(mensagem_bloqueio(&bloqueios));
        }
    }
    let arena = if pedido.arena.trim().is_empty() { "arena_starter".to_string() } else { pedido.arena.trim().to_string() };
    // Gate único (R4) também na arena — com uma diferença real: aqui não pode
    // ser só erro. O projeto do editor NUNCA traz arena (o pack não tem) e a
    // própria lista de arenas oferece "arena_starter" quando não há nenhuma
    // (listar_arenas). Então: projeto COM arenas e id fora = erro; projeto
    // SEM arena nenhuma = aviso que viaja na mensagem de sucesso do duelo —
    // o jogo usa a arena padrão dele. Barra-error aqui deixaria ninguém jogar
    // depois do D29.
    let arenas = Catalogo::de_set(&arenas_ids());
    let checagem_arena = checar_arena_do_duelo(&arenas, &arena);
    if let Some(e) = &checagem_arena {
        if eh_erro(e) {
            return Err(e.mensagem.clone());
        }
    }
    let pasta_duel = projeto_sub("duelists")?;
    let deck_de = |duel_id: &str| -> Result<String, String> {
        let caminho = pasta_duel.join(format!("{duel_id}.json"));
        let v = ler_arquivo_json(&caminho, &format!("duelista {duel_id}"))?;
        v.get("deck_id").and_then(|x| x.as_str()).map(|s| s.to_string())
            .ok_or_else(|| format!("Duelista \"{duel_id}\" não tem deck ligado. Abra a aba Duelistas e escolha um deck."))
    };
    let deck1 = deck_de(&pedido.duelista1)?;
    let deck2 = deck_de(&pedido.duelista2)?;
    let decks = ids_de_projeto("decks")?;
    for (duel_id, deck) in [(&pedido.duelista1, &deck1), (&pedido.duelista2, &deck2)] {
        if !decks.contains(deck) {
            return Err(format!("Deck \"{deck}\" do duelista \"{duel_id}\" não existe. Abra a aba Decks e confira."));
        }
    }
    let setup = montar_setup_duelo(
        &pedido.duelista1,
        &deck1,
        &pedido.duelista2,
        &deck2,
        pedido.vida,
        &ordem,
        pedido.seed.unwrap_or(42),
        &arena,
        pedido.test_state.as_ref(),
    );
    let agora = agora_em_segundos();
    // Vira o lixo do duelo anterior (o jogo já leu o setup dele).
    let _ = limpar_setups_antigos(agora, SETUP_MAX_IDADE_SEGS);
    let temp = novo_setup_temporario(agora);
    escrever_json_valor(&temp, &setup, "duelo rápido (temporário)")?;
    // O aviso de arena (projeto sem arena própria) não trava o jogo: entra
    // na mensagem de sucesso, igual ao aviso que o jogar_carta imprime.
    let aviso_txt = checagem_arena
        .iter()
        .filter(|e| !eh_erro(e))
        .map(|e| format!("\nAviso:\n- {}", e.mensagem))
        .collect::<String>();
    match lancar_astralis_com_setup(&temp) {
        Ok(msg) => Ok(ResultadoOk {
            ok: true,
            file: temp.to_string_lossy().to_string(),
            mensagem: format!("Duelo rápido salvo no temporário ({}) e {msg}{aviso_txt}", temp.display()),
        }),
        Err(e) => Err(format!("Duelo rápido salvo no temporário, mas {e}")),
    }
}

// ---- CENAS SIMPLES (bloco 6) ----
// JSON simples em projects/default/scenes/<id>.json (formato no README do
// editor; schema formal fica p/ depois). Sem grafo/timeline agora: só lista de
// falas (personagem, texto, fundo opcional). Sem Play de cena (o Astralis ainda
// não lê esse formato — R4, sem fingir).
fn pasta_cenas() -> Result<std::path::PathBuf, String> {
    projeto_sub("scenes")
}

fn checar_cena(cena: &serde_json::Value) -> Vec<ErroValidacao> {
    let mut erros: Vec<ErroValidacao> = Vec::new();
    if !cena.is_object() {
        return vec![erro("Cena", "field-name", "Cena vazia. Clique em Criar nova para começar.")];
    }
    match cena.get("schema_version") {
        Some(serde_json::Value::Number(n)) if n.as_i64() == Some(1) => {}
        _ => erros.push(erro("Versão", "field-id", "Versão precisa ser 1. Não mexa neste campo (ele é automático).")),
    }
    match cena.get("id").and_then(|v| v.as_str()) {
        Some(id) if eh_id_snake(id) => {}
        _ => erros.push(erro("ID", "field-id", "Falta um ID válido. Clique no campo ID e use só letra minúscula, número e underline — exemplo: scene_encontro_rival.")),
    }
    match cena.get("name").and_then(|v| v.as_str()) {
        Some(n) if !n.trim().is_empty() => {}
        _ => erros.push(erro("Nome", "field-name", "Falta o Nome. Clique no campo Nome e digite como a cena aparece na lista.")),
    }
    match cena.get("lines") {
        Some(serde_json::Value::Array(lista)) if !lista.is_empty() => {
            for (i, l) in lista.iter().enumerate() {
                let onde = format!("Fala {}", i + 1);
                match l.get("character").and_then(|v| v.as_str()) {
                    Some(c) if !c.trim().is_empty() => {}
                    _ => erros.push(erro(&onde, "field-lines", &format!("{onde} sem personagem. Clique em Personagem e digite quem fala."))),
                }
                match l.get("text").and_then(|v| v.as_str()) {
                    Some(t) if !t.trim().is_empty() => {}
                    _ => erros.push(erro(&onde, "field-lines", &format!("{onde} sem texto. Clique em Texto e digite a fala."))),
                }
            }
        }
        _ => erros.push(erro("Falas", "field-lines", "A cena precisa de pelo menos 1 fala. Clique em ＋ fala e escreva personagem + texto.")),
    }
    erros
}

#[tauri::command]
fn listar_cenas() -> Result<Vec<DuelistaArquivo>, String> {
    let pasta = pasta_cenas()?;
    if !pasta.is_dir() {
        return Ok(Vec::new());
    }
    listar_arquivos(&pasta, "cena")
}

#[tauri::command]
fn salvar_cena(cena: serde_json::Value) -> Result<ResultadoOk, String> {
    let id = cena.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    if !eh_id_snake(&id) {
        return Err("ID inválido: use só letra minúscula, número e underline — exemplo: scene_encontro_rival.".to_string());
    }
    let erros = checar_cena(&cena);
    let bloqueios = so_erros(&erros);
    if !bloqueios.is_empty() {
        return Err(mensagem_bloqueio(&bloqueios));
    }
    let pasta = pasta_cenas()?;
    std::fs::create_dir_all(&pasta).map_err(|e| format!("Não consegui criar projects/default/scenes/: {e}"))?;
    let destino = pasta.join(format!("{id}.json"));
    escrever_json_valor(&destino, &cena, &format!("cena {id}"))?;
    Ok(ResultadoOk {
        ok: true,
        file: format!("{id}.json"),
        mensagem: format!("Salva em projects/default/scenes/{id}.json (dado simples; grafo/timeline vêm depois)."),
    })
}

#[tauri::command]
fn validar_cena(cena: serde_json::Value) -> Vec<ErroValidacao> {
    checar_cena(&cena)
}

// ---- EXPORTAR (bloco 7) ----
// Tela com plataforma + Aberto/Protegido + checklist "testou?". O botão
// Exportar, POR ORA, só valida o projeto inteiro e avisa que o
// empacotamento (.astralis + zip, doc 12) vem depois — sem fingir empacotar.
#[derive(Debug, serde::Serialize)]
struct ItemProjeto {
    area: String,
    ok: bool,
    detalhe: String,
}

#[derive(Debug, serde::Serialize)]
struct ResultadoProjeto {
    erros: usize,
    avisos: usize,
    itens: Vec<ItemProjeto>,
    mensagem: String,
}

#[tauri::command]
fn validar_projeto() -> Result<ResultadoProjeto, String> {
    let proj = pasta_projeto()?;
    let mut itens: Vec<ItemProjeto> = Vec::new();
    let mut erros: usize = 0;
    let mut avisos: usize = 0;

    // Cartas: valida cada uma.
    let mut n_cartas = 0;
    let mut err_cartas = 0;
    let mut avisos_cartas = 0;
    let mut ids_cartas: std::collections::HashSet<String> = std::collections::HashSet::new();
    let pasta_c = proj.join("cards");
    if let Ok(entries) = std::fs::read_dir(&pasta_c) {
        let catalogo = catalogo_efeitos();
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("json") {
                continue;
            }
            n_cartas += 1;
            match std::fs::read_to_string(&p).ok().and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok()) {
                Some(v) => {
                    if let Some(id) = v.get("id").and_then(|x| x.as_str()) {
                        ids_cartas.insert(id.to_string());
                    }
                    let revisao = checar_carta(&v, &catalogo);
                    err_cartas += so_erros(&revisao).len();
                    avisos_cartas += so_avisos(&revisao).len();
                }
                None => err_cartas += 1,
            }
        }
    }
    erros += err_cartas;
    avisos += avisos_cartas;
    itens.push(ItemProjeto {
        area: "Cartas".to_string(),
        ok: n_cartas > 0 && err_cartas == 0,
        detalhe: if n_cartas == 0 {
            "nenhuma carta no projeto".to_string()
        } else {
            format!("{n_cartas} cartas, {err_cartas} erros{}", if avisos_cartas > 0 { format!(", {avisos_cartas} avisos") } else { String::new() })
        },
    });

    // Decks + duelistas (refs cruzadas).
    let mut ids_decks: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut err_decks = 0;
    let mut avisos_decks = 0;
    let mut n_decks = 0;
    let mut fora_do_alvo = 0;
    if let Ok(entries) = std::fs::read_dir(proj.join("decks")) {
        let catalogo_cartas = Catalogo::de_set(&ids_cartas);
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("json") {
                continue;
            }
            n_decks += 1;
            match std::fs::read_to_string(&p).ok().and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok()) {
                Some(v) => {
                    if let Some(id) = v.get("id").and_then(|x| x.as_str()) {
                        ids_decks.insert(id.to_string());
                    }
                    // Só ERRO conta como erro aqui: aviso (projeto sem a carta
                    // citada) não pode virar "projeto com erro" no relatório.
                    let revisao = checar_deck(&v, &catalogo_cartas);
                    err_decks += so_erros(&revisao).len();
                    avisos_decks += so_avisos(&revisao).len();
                    if let Some(serde_json::Value::Array(l)) = v.get("cards") {
                        if l.len() != 40 {
                            fora_do_alvo += 1;
                        }
                    }
                }
                None => err_decks += 1,
            }
        }
    }
    erros += err_decks;
    avisos += fora_do_alvo + avisos_decks;
    itens.push(ItemProjeto {
        area: "Decks".to_string(),
        ok: n_decks > 0 && err_decks == 0,
        detalhe: if n_decks == 0 { "nenhum deck no projeto".to_string() } else { format!("{n_decks} decks, {err_decks} erros, {fora_do_alvo} fora do alvo 40") },
    });

    let mut ids_duelistas: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut err_duel = 0;
    let mut avisos_duel = 0;
    let mut n_duel = 0;
    if let Ok(entries) = std::fs::read_dir(proj.join("duelists")) {
        let catalogo_decks = Catalogo::de_set(&ids_decks);
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("json") {
                continue;
            }
            n_duel += 1;
            match std::fs::read_to_string(&p).ok().and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok()) {
                Some(v) => {
                    if let Some(id) = v.get("id").and_then(|x| x.as_str()) {
                        ids_duelistas.insert(id.to_string());
                    }
                    let revisao = checar_duelista(&v, &catalogo_decks);
                    err_duel += so_erros(&revisao).len();
                    avisos_duel += so_avisos(&revisao).len();
                }
                None => err_duel += 1,
            }
        }
    }
    erros += err_duel;
    avisos += avisos_duel;
    itens.push(ItemProjeto {
        area: "Duelistas".to_string(),
        ok: n_duel > 0 && err_duel == 0,
        detalhe: if n_duel == 0 { "nenhum duelista no projeto".to_string() } else { format!("{n_duel} duelistas, {err_duel} erros") },
    });

    // Fusões.
    match std::fs::read_to_string(proj.join("fusions.json")).ok().and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok()) {
        Some(v) => {
            let revisao = checar_fusoes(&v, &Catalogo::de_set(&ids_cartas));
            let n = so_erros(&revisao).len();
            avisos += so_avisos(&revisao).len();
            erros += n;
            let nrec = v.get("recipes").and_then(|x| x.as_array()).map(|a| a.len()).unwrap_or(0);
            let nrul = v.get("rules").and_then(|x| x.as_array()).map(|a| a.len()).unwrap_or(0);
            itens.push(ItemProjeto { area: "Fusões".to_string(), ok: n == 0, detalhe: format!("{nrec} receitas + {nrul} regras, {n} erros") });
        }
        None => {
            erros += 1;
            itens.push(ItemProjeto { area: "Fusões".to_string(), ok: false, detalhe: "fusions.json quebrado ou sumido".to_string() });
        }
    }

    // Efeitos.
    match std::fs::read_to_string(proj.join("effects.json")).ok().and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok()) {
        Some(v) => {
            let n = checar_efeitos(&v).len();
            erros += n;
            let nef = v.get("effects").and_then(|x| x.as_array()).map(|a| a.len()).unwrap_or(0);
            itens.push(ItemProjeto { area: "Efeitos".to_string(), ok: n == 0, detalhe: format!("{nef} modelos, {n} erros de dado (execução vem depois)") });
        }
        None => {
            erros += 1;
            itens.push(ItemProjeto { area: "Efeitos".to_string(), ok: false, detalhe: "effects.json quebrado ou sumido".to_string() });
        }
    }

    // duel_setup: opcional no projeto do editor (o Duelo rápido monta o setup
    // na hora e passa --setup por cima). Ausente = neutro; presente com refs
    // quebradas = erro de dado.
    match std::fs::read_to_string(proj.join("duel_setup.json")).ok().and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok()) {
        Some(v) => {
            let mut n = 0;
            for lado in ["duelist1", "duelist2"] {
                let dud = v.get(lado).and_then(|x| x.get("duelist_id")).and_then(|x| x.as_str()).unwrap_or("");
                let deck = v.get(lado).and_then(|x| x.get("deck_id")).and_then(|x| x.as_str()).unwrap_or("");
                if !ids_duelistas.contains(dud) {
                    n += 1;
                }
                if !ids_decks.contains(deck) {
                    n += 1;
                }
            }
            if v.get("starting_lp").and_then(|x| x.as_i64()).map(|lp| lp <= 0).unwrap_or(true) {
                n += 1;
            }
            // Campo de Testes (contrato systems test_state V1): espelho do schema.
            // Ausente = neutro; presente com mão/campo/ordem quebrados = erro de dado.
            let rev_teste = checar_test_state(&v, &Catalogo::de_set(&ids_cartas));
            n += so_erros(&rev_teste).len();
            avisos += so_avisos(&rev_teste).len();
            erros += n;
            itens.push(ItemProjeto { area: "Duelo".to_string(), ok: n == 0, detalhe: if n == 0 { "setup aponta para duelistas/decks que existem".to_string() } else { format!("{n} problemas no duel_setup.json") } });
        }
        None => {
            itens.push(ItemProjeto { area: "Duelo".to_string(), ok: true, detalhe: "sem setup salvo (o Duelo rápido monta na hora)".to_string() });
        }
    }

    // Cenas (não travam nada no jogo ainda, mas contam como erro de dado).
    let pasta_s = proj.join("scenes");
    let mut n_cenas = 0;
    let mut err_cenas = 0;
    if let Ok(entries) = std::fs::read_dir(&pasta_s) {
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("json") {
                continue;
            }
            n_cenas += 1;
            match std::fs::read_to_string(&p).ok().and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok()) {
                Some(v) => err_cenas += checar_cena(&v).len(),
                None => err_cenas += 1,
            }
        }
    }
    erros += err_cenas;
    itens.push(ItemProjeto { area: "Cenas".to_string(), ok: err_cenas == 0, detalhe: if n_cenas == 0 { "nenhuma cena (ok — opcional)".to_string() } else { format!("{n_cenas} cenas, {err_cenas} erros") } });

    let mensagem = if erros == 0 {
        if avisos == 0 {
            "Projeto válido de ponta a ponta. Empacotamento (.astralis + zip) vem depois — por ora nada foi empacotado.".to_string()
        } else {
            format!("Projeto válido com {avisos} aviso(s) (ex.: decks fora do alvo 40, ou item que cita algo que o projeto ainda não tem). Empacotamento (.astralis + zip) vem depois — por ora nada foi empacotado.")
        }
    } else {
        format!("Projeto com {erros} erro(s) — arrume nas abas (clique em Validar em cada uma) e volte aqui. Nada foi empacotado.")
    };
    Ok(ResultadoProjeto { erros, avisos, itens, mensagem })
}

// ---- IMPORTAR PACK (botão Importar, ao lado do Exportar) ----
// Lê um .json pack (file picker no frontend, conteúdo via invoke), valida TUDO
// antes de mexer em nada (pack inválido = erro e o projeto continua intacto)
// e SUBSTITUI o conteúdo do projeto pelo conteúdo do pack: cartas/duelistas/
// decks viram arquivos em projects/default/... (o que não está no pack é
// apagado) e fusions.json é trocado inteiro pelo do pack. Antes de substituir,
// copia o conteúdo atual para projects/default/backups/pack_<data>_<hora>/.
// Só dado, nada de jogo (R1/R4). Resumo em PT-BR com contagens + "backup em".
// Formato aceito: chaves PT (cartas/duelistas/decks/fusoes, ex. FM Original
// Pack) ou EN (cards/duelists/decks/fusions). `equips` não tem schema V1
// (schemas/README gap 4): é contado e ignorado com aviso, o jogo ignora.
// SEM campo `erros` de propósito: qualquer erro recusa o pack INTEIRO e volta
// por `Err` (é o que o frontend mostra em âmbar, no catch do aoEscolherPack).
// No caminho `Ok` não existe lista de erros — o campo era `Vec::new()` fixo e o
// frontend tratava isso como "não tem erro", com um `{#each resumo.erros}` que
// nunca renderizava nada (código morto nas duas pontas).
#[derive(Debug, serde::Serialize)]
struct ResultadoImportacao {
    cartas: usize,
    duelistas: usize,
    decks: usize,
    fusoes_novas: usize,
    fusoes_puladas: usize,
    /// Fusão com a MESMA carta nos dois lados (A+A), pulada porque nunca
    /// dispara no jogo. Contado à parte de `fusoes_puladas` porque NÃO é
    /// repetição: a mensagem antiga somava os dois e dizia "repetido do
    /// próprio pack", mandando o usuário caçar um problema que não existe.
    fusoes_mesma: usize,
    regras_novas: usize,
    regras_puladas: usize,
    equips_ignorados: usize,
    backups: Vec<String>,
    avisos: Vec<String>,
    mensagem: String,
}

// Teto de AVISOS na resposta do import. Aviso é uma linha inteira na tela e
// existe um por carta/duelista/deck (o pack FM são 722 cartas): sem teto a
// lista vira centenas de linhas. Mesma política dos erros (30 linhas) e mesmo
// texto "…e mais N" — o corte é honesto, não esconde que sobrou.
const TOPO_AVISOS: usize = 30;

/// Empurra um aviso por item (carta/duelista/deck) respeitando o teto e conta
/// o que não coube, para a mensagem final dizer o que sobrou.
fn empurra_aviso(avisos: &mut Vec<String>, omitidos: &mut usize, texto: String) {
    if avisos.len() < TOPO_AVISOS {
        avisos.push(texto);
    } else {
        *omitidos += 1;
    }
}

// Frases de contagem com singular/plural acertados, usadas NO MESMO texto tanto
// na lista de avisos quanto na mensagem final (eles não podem discordar — foi
// o que fez o usuário ler "50 repetido(s) do próprio pack" num pack sem
// repetida nenhuma). Sem o "N item(ns)": "1 fusões ... foram" é português
// torto e a mensagem é lida por gente.
fn frase_fusao_mesma(n: usize) -> String {
    if n == 1 {
        "1 fusão com a mesma carta nos dois lados foi ignorada — ela nunca dispara no jogo (fusão precisa de duas cartas diferentes).".to_string()
    } else {
        format!("{n} fusões com a mesma carta nos dois lados foram ignoradas — elas nunca disparam no jogo (fusão precisa de duas cartas diferentes).")
    }
}

fn frase_fusao_repetida(n: usize) -> String {
    if n == 1 {
        "1 fusão repetida dentro do próprio pack foi pulada (mesmo par + resultado).".to_string()
    } else {
        format!("{n} fusões repetidas dentro do próprio pack foram puladas (mesmo par + resultado).")
    }
}

fn pack_lista<'a>(pack: &'a serde_json::Value, pt: &str, en: &str) -> Vec<&'a serde_json::Value> {
    for chave in [pt, en] {
        if let Some(serde_json::Value::Array(lista)) = pack.get(chave) {
            return lista.iter().collect();
        }
    }
    Vec::new()
}

fn pack_fusoes(pack: &serde_json::Value) -> Option<&serde_json::Value> {
    pack.get("fusoes").or_else(|| pack.get("fusions"))
}

// Chave de receita normalizada (A/B em qualquer ordem + resultado): receitas
// com a mesma fusão não entram duas vezes, mesmo com id diferente.
fn chave_receita(a: &str, b: &str, res: &str) -> String {
    let (x, y) = if a <= b { (a, b) } else { (b, a) };
    format!("{x}+{y}={res}")
}

fn pack_tem_lista(pack: &serde_json::Value, pt: &str, en: &str) -> bool {
    pack.get(pt).or_else(|| pack.get(en)).map(|v| v.is_array()).unwrap_or(false)
}

// Carimbo UTC AAAAMMDD_HHMMSS para a pasta de backup (sem crate externa:
// converte segundos Unix em data civil — algoritmo de Howard Hinnant).
fn carimbo_data_hora() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let dias = (secs / 86400) as i64;
    let resto = (secs % 86400) as i64;
    let z = dias + 719468;
    let era = z / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let ano = if m <= 2 { y + 1 } else { y };
    format!("{:04}{:02}{:02}_{:02}{:02}{:02}", ano, m, d, resto / 3600, (resto % 3600) / 60, resto % 60)
}

// Rótulo curto para mostrar ao usuário: "projects/default/backups/pack_..."
// quando der, senão o caminho completo.
fn rotulo_backup(dir: &std::path::Path) -> String {
    let s = dir.to_string_lossy().replace('\\', "/");
    if let Some(pos) = s.find("projects/default/backups") {
        return s[pos..].to_string();
    }
    if let Some(pos) = s.find("astralis-studio/projects/default/backups") {
        return s[pos..].to_string();
    }
    if let Some(pos) = s.find("backups/pack_") {
        return s[pos..].to_string();
    }
    s.to_string()
}

// Copia os *.json de uma pasta para o destino (cria o destino). Devolve
// quantos arquivos copiou. Só dado, sem executar nada (R1).
fn backup_pasta_json(origem: &std::path::Path, destino: &std::path::Path) -> usize {
    let mut n = 0;
    let _ = std::fs::create_dir_all(destino);
    if let Ok(entries) = std::fs::read_dir(origem) {
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("json") {
                continue;
            }
            if let Some(nome) = p.file_name() {
                if std::fs::copy(&p, destino.join(nome)).is_ok() {
                    n += 1;
                }
            }
        }
    }
    n
}

// Copia TODOS os arquivos de uma pasta (recursivo, vale subpasta) para o
// destino. Devolve quantos copiou. Usado só pelo backup de assets/ do
// importar (as artes têm subpastas: cards/portraits/backgrounds/fm/...).
fn backup_pasta_rec(origem: &std::path::Path, destino: &std::path::Path) -> usize {
    let mut n = 0;
    let entries = match std::fs::read_dir(origem) {
        Ok(e) => e,
        Err(_) => return 0,
    };
    for e in entries.flatten() {
        let p = e.path();
        if p.is_dir() {
            if let Some(nome) = p.file_name() {
                n += backup_pasta_rec(&p, &destino.join(nome));
            }
        } else if p.is_file() {
            if std::fs::create_dir_all(destino).is_ok() {
                if let Some(nome) = p.file_name() {
                    if std::fs::copy(&p, destino.join(nome)).is_ok() {
                        n += 1;
                    }
                }
            }
        }
    }
    n
}

// Copia o conteúdo atual (cartas/duelistas/decks/fusions.json + assets/) para
// <projects/default>/backups/pack_<data>_<hora>/. Devolve (pasta, rótulo).
// Não apaga nem altera nada do projeto — só copia.
fn backup_conteudo_atual(
    pasta_cartas: &std::path::Path,
    pasta_duelistas: &std::path::Path,
    pasta_decks: &std::path::Path,
    caminho_fusoes: &std::path::Path,
    pasta_assets: &std::path::Path,
) -> Result<(std::path::PathBuf, String), String> {
    let projeto = pasta_cartas.parent().ok_or_else(|| "Não achei a pasta projects/default a partir daqui.".to_string())?;
    let raiz_backups = projeto.join("backups");
    std::fs::create_dir_all(&raiz_backups)
        .map_err(|e| format!("Não consegui criar a pasta de backup em {}: {e}", raiz_backups.display()))?;
    let carimbo = carimbo_data_hora();
    let mut dir = raiz_backups.join(format!("pack_{carimbo}"));
    let mut i = 2;
    while dir.exists() {
        dir = raiz_backups.join(format!("pack_{carimbo}_{i}"));
        i += 1;
    }
    backup_pasta_json(pasta_cartas, &dir.join("cards"));
    backup_pasta_json(pasta_duelistas, &dir.join("duelists"));
    backup_pasta_json(pasta_decks, &dir.join("decks"));
    if caminho_fusoes.is_file() {
        let _ = std::fs::create_dir_all(&dir);
        std::fs::copy(caminho_fusoes, dir.join("fusions.json"))
            .map_err(|e| format!("Não consegui copiar fusions.json para o backup: {e}"))?;
    }
    // Artes atuais (o importar .apack SUBSTITUI imagens de mesmo nome: sem
    // este backup elas se perdiam sem volta).
    backup_pasta_rec(pasta_assets, &dir.join("assets"));
    let rotulo = rotulo_backup(&dir);
    Ok((dir, rotulo))
}

// Apaga da pasta os *.json cujo nome (sem extensão) não está no pack.
// Devolve quantos apagou. É assim que o IMPORTAR substitui em vez de somar.
fn apagar_extras(pasta: &std::path::Path, ids_do_pack: &std::collections::HashSet<String>) -> usize {
    let mut n = 0;
    if let Ok(entries) = std::fs::read_dir(pasta) {
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) != Some("json") {
                continue;
            }
            let stem = p.file_stem().and_then(|x| x.to_str()).unwrap_or("").to_string();
            if !ids_do_pack.contains(&stem) && std::fs::remove_file(&p).is_ok() {
                n += 1;
            }
        }
    }
    n
}

fn importar_pack_valor(pack: &serde_json::Value, nome: &str) -> Result<ResultadoImportacao, String> {
    if !pack.is_object() {
        return Err(format!("\"{nome}\" não é um pack válido: o arquivo precisa começar com {{ e ter as listas do pack."));
    }
    match pack.get("schema_version") {
        Some(serde_json::Value::Number(n)) if n.as_i64() == Some(1) => {}
        _ => return Err(format!("\"{nome}\" não é um pack V1: falta \"schema_version\": 1 no começo do arquivo.")),
    }
    let proj = pasta_projeto()?;
    let pasta_cartas = proj.join("cards");
    let pasta_duelistas = proj.join("duelists");
    let pasta_decks = proj.join("decks");
    let caminho_fusoes = proj.join("fusions.json");
    for (p, rotulo) in [(&pasta_cartas, "cartas"), (&pasta_duelistas, "duelistas"), (&pasta_decks, "decks")] {
        if !p.is_dir() {
            return Err(format!("Não achei a pasta projects/default/{rotulo} a partir daqui. Rode o app de dentro do projeto Astralis."));
        }
    }

    let catalogo = catalogo_efeitos();
    importar_pack_para(
        pack,
        &pasta_cartas,
        &pasta_duelistas,
        &pasta_decks,
        &caminho_fusoes,
        &catalogo,
    )
}

fn importar_pack_para(
    pack: &serde_json::Value,
    pasta_cartas: &std::path::Path,
    pasta_duelistas: &std::path::Path,
    pasta_decks: &std::path::Path,
    caminho_fusoes: &std::path::Path,
    catalogo: &Catalogo,
) -> Result<ResultadoImportacao, String> {
    let tem_cartas = pack_tem_lista(pack, "cartas", "cards");
    let tem_duelistas = pack_tem_lista(pack, "duelistas", "duelists");
    let tem_decks = pack_tem_lista(pack, "decks", "decks");
    let tem_fusoes = pack_fusoes(pack).is_some();
    if !tem_cartas && !tem_duelistas && !tem_decks && !tem_fusoes {
        return Err("Pack vazio: não achei listas de cartas, duelistas, decks nem fusões. Confira se o arquivo é um pack Astralis V1 (com \"schema_version\": 1).".to_string());
    }

    let lista_cartas = pack_lista(pack, "cartas", "cards");
    let lista_duelistas = pack_lista(pack, "duelistas", "duelists");
    let lista_decks = pack_lista(pack, "decks", "decks");

    // Universo de refs é SÓ o pack: o conteúdo atual será substituído, então
    // referenciar carta/deck de fora do pack deixaria o projeto quebrado.
    let mut todas_cartas: std::collections::HashSet<String> = std::collections::HashSet::new();
    for c in &lista_cartas {
        if let Some(id) = c.get("id").and_then(|v| v.as_str()) {
            if eh_id_snake(id) {
                todas_cartas.insert(id.to_string());
            }
        }
    }
    let mut todos_decks: std::collections::HashSet<String> = std::collections::HashSet::new();
    for d in &lista_decks {
        if let Some(id) = d.get("id").and_then(|v| v.as_str()) {
            if eh_id_snake(id) {
                todos_decks.insert(id.to_string());
            }
        }
    }

    let mut erros: Vec<String> = Vec::new();
    // Avisos POR ITEM vão para cá e são cortados no fim (teto 30). Os de
    // RESUMO (A+A, repetidas, equips) são montados depois e entram na frente.
    let mut avisos_item: Vec<String> = Vec::new();
    let mut avisos_omitidos: usize = 0;

    // ID repetido dentro do próprio pack = pack inválido (nada é importado).
    for (lista, rotulo) in [(&lista_cartas, "Carta"), (&lista_duelistas, "Duelista"), (&lista_decks, "Deck")] {
        let mut vistos: std::collections::HashSet<String> = std::collections::HashSet::new();
        for item in lista.iter() {
            if let Some(id) = item.get("id").and_then(|v| v.as_str()) {
                if eh_id_snake(id) && !vistos.insert(id.to_string()) {
                    erros.push(format!("{rotulo} \"{id}\": ID repetido dentro do pack — cada item precisa de um ID único."));
                }
            }
        }
    }
    if let Some(fusoes_pack) = pack_fusoes(pack) {
        let mut vistos: std::collections::HashSet<String> = std::collections::HashSet::new();
        for chave in ["recipes", "rules"] {
            if let Some(serde_json::Value::Array(lista)) = fusoes_pack.get(chave) {
                for r in lista {
                    if let Some(id) = r.get("id").and_then(|v| v.as_str()) {
                        if eh_id_snake(id) && !vistos.insert(id.to_string()) {
                            erros.push(format!("Fusão \"{id}\": ID repetido dentro do pack — cada receita/regra precisa de um ID único."));
                        }
                    }
                }
            }
        }
    }

    // Valida TUDO antes de mexer em nada: inválido = erro e projeto intacto.
    let mut cartas_ok: Vec<(&serde_json::Value, String)> = Vec::new();
    let mut duelistas_ok: Vec<(&serde_json::Value, String)> = Vec::new();
    let mut decks_ok: Vec<(&serde_json::Value, String)> = Vec::new();

    for c in &lista_cartas {
        let id = c.get("id").and_then(|v| v.as_str()).unwrap_or("?").to_string();
        let revisao = checar_carta(c, catalogo);
        // Aviso não barra o import (ex.: carta citando efeito que o projeto
        // ainda não tem) — erro barra tudo, sem mexer em nada.
        for a in so_avisos(&revisao) {
            empurra_aviso(&mut avisos_item, &mut avisos_omitidos, format!("Carta \"{id}\": {}", a.mensagem));
        }
        let errs = so_erros(&revisao);
        if errs.is_empty() {
            cartas_ok.push((c, id));
        } else if erros.len() < 30 {
            for e in errs {
                erros.push(format!("Carta \"{id}\": {}", e.mensagem));
            }
        } else {
            erros.push(format!("Carta \"{id}\": {} erro(s) — confira o item no pack.", errs.len()));
        }
    }
    for d in &lista_duelistas {
        let id = d.get("id").and_then(|v| v.as_str()).unwrap_or("?").to_string();
        let revisao = checar_duelista(d, &Catalogo::de_set(&todos_decks));
        // Mesmo tratamento das cartas: aviso (pack sem o deck citado) viaja
        // na lista de avisos; só ERRO recusa o pack inteiro.
        for a in so_avisos(&revisao) {
            empurra_aviso(&mut avisos_item, &mut avisos_omitidos, format!("Duelista \"{id}\": {}", a.mensagem));
        }
        let errs = so_erros(&revisao);
        if errs.is_empty() {
            duelistas_ok.push((d, id));
        } else if erros.len() < 30 {
            for e in errs {
                erros.push(format!("Duelista \"{id}\": {}", e.mensagem));
            }
        } else {
            erros.push(format!("Duelista \"{id}\": {} erro(s) — confira o item no pack.", errs.len()));
        }
    }
    for d in &lista_decks {
        let id = d.get("id").and_then(|v| v.as_str()).unwrap_or("?").to_string();
        let revisao = checar_deck(d, &Catalogo::de_set(&todas_cartas));
        for a in so_avisos(&revisao) {
            empurra_aviso(&mut avisos_item, &mut avisos_omitidos, format!("Deck \"{id}\": {}", a.mensagem));
        }
        let errs = so_erros(&revisao);
        if errs.is_empty() {
            decks_ok.push((d, id));
        } else if erros.len() < 30 {
            for e in errs {
                erros.push(format!("Deck \"{id}\": {}", e.mensagem));
            }
        } else {
            erros.push(format!("Deck \"{id}\": {} erro(s) — confira o item no pack.", errs.len()));
        }
    }

    // Fusões do pack: valida contra as cartas DO PACK e separa as novas.
    // Par repetido dentro do pack é pulado com aviso; A+A (dado morto que
    // nunca dispara) é pulado com aviso; o resto inválido barra o pack todo.
    let mut receitas_novas: Vec<serde_json::Value> = Vec::new();
    let mut regras_novas_lista: Vec<serde_json::Value> = Vec::new();
    let mut fusoes_novas = 0;
    let mut fusoes_puladas = 0;
    let mut fusoes_mesma = 0;
    let mut fusoes_repetidas = 0;
    let mut regras_novas = 0;
    let regras_puladas = 0;
    let mut pares_vistos: std::collections::HashSet<String> = std::collections::HashSet::new();
    if let Some(fusoes_pack) = pack_fusoes(pack) {
        if let Some(serde_json::Value::Array(lista)) = fusoes_pack.get("recipes") {
            for r in lista {
                let id = r.get("id").and_then(|v| v.as_str()).unwrap_or("?").to_string();
                let a = r.get("input").and_then(|x| x.get("card_a")).and_then(|v| v.as_str()).unwrap_or("");
                let b = r.get("input").and_then(|x| x.get("card_b")).and_then(|v| v.as_str()).unwrap_or("");
                let res = r.get("result").and_then(|v| v.as_str()).unwrap_or("");
                if a == b && eh_id_snake(&id) && eh_id_snake(a) && eh_id_snake(res) {
                    // Dado morto do pack (A+A nunca dispara — fusão pede duas
                    // cartas diferentes): pula sem erro para o Exportar
                    // continuar verde depois da importação.
                    fusoes_mesma += 1;
                    fusoes_puladas += 1;
                    continue;
                }
                let mut problema: Option<String> = None;
                if !eh_id_snake(&id) {
                    problema = Some("ID inválido (use só letra minúscula, número e underline).".to_string());
                } else if !eh_id_snake(a) || !eh_id_snake(b) {
                    problema = Some("carta A ou B inválida.".to_string());
                } else if a == b {
                    problema = Some(format!("carta A e B são a mesma ({a}). Fusão precisa de duas cartas diferentes."));
                } else if !eh_id_snake(res) {
                    problema = Some("sem resultado válido.".to_string());
                } else if !todas_cartas.contains(a) {
                    problema = Some(format!("carta \"{a}\" não existe no pack (vale só o que vem no pack, o conteúdo atual será substituído)."));
                } else if !todas_cartas.contains(b) {
                    problema = Some(format!("carta \"{b}\" não existe no pack (vale só o que vem no pack, o conteúdo atual será substituído)."));
                } else if !todas_cartas.contains(res) {
                    problema = Some(format!("resultado \"{res}\" não existe no pack (vale só o que vem no pack, o conteúdo atual será substituído)."));
                }
                if let Some(m) = problema {
                    if erros.len() < 30 {
                        erros.push(format!("Fusão \"{id}\": {m}"));
                    }
                    continue;
                }
                if pares_vistos.contains(&chave_receita(a, b, res)) {
                    fusoes_repetidas += 1;
                    fusoes_puladas += 1;
                    continue;
                }
                pares_vistos.insert(chave_receita(a, b, res));
                receitas_novas.push(r.clone());
                fusoes_novas += 1;
            }
        }
        if let Some(serde_json::Value::Array(lista)) = fusoes_pack.get("rules") {
            for r in lista {
                let id = r.get("id").and_then(|v| v.as_str()).unwrap_or("?").to_string();
                let mut problema: Option<String> = None;
                if !eh_id_snake(&id) {
                    problema = Some("ID inválido (use só letra minúscula, número e underline).".to_string());
                } else if !r.get("when").map(|w| w.is_object() && w.as_object().map(|o| !o.is_empty()).unwrap_or(false)).unwrap_or(false) {
                    problema = Some("sem condição (escolha pelo menos tipo ou atributo).".to_string());
                } else {
                    let res = r.get("result").and_then(|v| v.as_str()).unwrap_or("");
                    if !eh_id_snake(res) {
                        problema = Some("sem resultado válido.".to_string());
                    } else if !todas_cartas.contains(res) {
                        problema = Some(format!("resultado \"{res}\" não existe no pack (vale só o que vem no pack, o conteúdo atual será substituído)."));
                    } else if r.get("priority").and_then(|v| v.as_i64()).map(|n| n < 0).unwrap_or(true) {
                        problema = Some("prioridade precisa ser 0 ou mais.".to_string());
                    }
                }
                if let Some(m) = problema {
                    if erros.len() < 30 {
                        erros.push(format!("Regra \"{id}\": {m}"));
                    }
                    continue;
                }
                regras_novas_lista.push(r.clone());
                regras_novas += 1;
            }
        }
    }

    if !erros.is_empty() {
        if erros.len() >= 30 {
            erros.truncate(30);
            erros.push("…e mais erros (confira o pack e importe de novo).".to_string());
        }
        return Err(format!("Pack inválido — não mexi em nada. Arruma e importa de novo:\n{}", erros.join("\n")));
    }

    // Pack válido: backup do conteúdo atual e SUBSTITUIÇÃO por área presente.
    // Área ausente no pack não é tocada (não apagamos o que o pack nem cita).
    // (Aqui só chegam as pastas, sem o `proj`: assets é irmã de cards/.)
    let pasta_assets = pasta_cartas.parent().map(|p| p.join("assets")).unwrap_or_else(|| PathBuf::from("assets"));
    let (_dir_backup, rotulo) = backup_conteudo_atual(pasta_cartas, pasta_duelistas, pasta_decks, caminho_fusoes, &pasta_assets)?;

    let mut n_cartas = 0;
    let mut n_duelistas = 0;
    let mut n_decks = 0;
    let mut removidos = 0;
    let ajuda_backup = format!("(seu conteúdo antigo está no backup em {rotulo})");
    if tem_cartas {
        let ids: std::collections::HashSet<String> = todas_cartas.clone();
        removidos += apagar_extras(pasta_cartas, &ids);
        for (c, id) in cartas_ok {
            escrever_json_valor(&pasta_cartas.join(format!("{id}.json")), c, &format!("carta {id}"))
                .map_err(|m| format!("{m} {ajuda_backup}"))?;
            n_cartas += 1;
        }
    }
    if tem_duelistas {
        let ids: std::collections::HashSet<String> = duelistas_ok.iter().map(|(_, id)| id.clone()).collect();
        removidos += apagar_extras(pasta_duelistas, &ids);
        for (d, id) in duelistas_ok {
            escrever_json_valor(&pasta_duelistas.join(format!("{id}.json")), d, &format!("duelista {id}"))
                .map_err(|m| format!("{m} {ajuda_backup}"))?;
            n_duelistas += 1;
        }
    }
    if tem_decks {
        let ids: std::collections::HashSet<String> = decks_ok.iter().map(|(_, id)| id.clone()).collect();
        removidos += apagar_extras(pasta_decks, &ids);
        for (d, id) in decks_ok {
            escrever_json_valor(&pasta_decks.join(format!("{id}.json")), d, &format!("deck {id}"))
                .map_err(|m| format!("{m} {ajuda_backup}"))?;
            n_decks += 1;
        }
    }
    if tem_fusoes {
        let base = serde_json::json!({"schema_version": 1, "recipes": receitas_novas, "rules": regras_novas_lista});
        escrever_json_valor(caminho_fusoes, &base, "fusions.json")
            .map_err(|m| format!("{m} {ajuda_backup}"))?;
    }

    // Avisos de RESUMO: o que o pack tinha e foi ignorado DE PROPÓSITO. São no
    // máximo 3 linhas e entram PRIMEIROS na lista (o corte de 30 é dos avisos
    // por item) — são as coisas que o usuário precisa ler depois de importar.
    let mut avisos: Vec<String> = Vec::new();
    if fusoes_mesma > 0 {
        avisos.push(frase_fusao_mesma(fusoes_mesma));
    }
    if fusoes_repetidas > 0 {
        avisos.push(frase_fusao_repetida(fusoes_repetidas));
    }
    let equips_ignorados = match pack.get("equips") {
        Some(serde_json::Value::Array(lista)) => lista.len(),
        _ => 0,
    };
    if equips_ignorados > 0 {
        avisos.push(format!(
            "{equips_ignorados} pares equip→monstro ignorados (sem schema V1 — o jogo ignora; viram schema formal depois)."
        ));
    }

    // Completa com os avisos por item até o teto e diz o que sobrou (mesmo
    // texto "…e mais N" dos erros): 722 cartas x 1 aviso = 722 linhas, não
    // cabe numa tela e o que importa está no resumo acima.
    let total_item = avisos_item.len();
    let cabem = total_item.min(TOPO_AVISOS.saturating_sub(avisos.len()));
    avisos.extend(avisos_item.into_iter().take(cabem));
    let restantes = avisos_omitidos + (total_item - cabem);
    if restantes > 0 {
        avisos.push(format!(
            "…e mais {restantes} aviso(s) não mostrados aqui (o resumo está na mensagem acima)."
        ));
    }

    let mut partes: Vec<String> = Vec::new();
    if tem_cartas {
        partes.push(format!("{n_cartas} cartas"));
    }
    if tem_duelistas {
        partes.push(format!("{n_duelistas} duelistas"));
    }
    if tem_decks {
        partes.push(format!("{n_decks} decks"));
    }
    if tem_fusoes {
        partes.push(format!("{fusoes_novas} fusões"));
    }
    let mut mensagem = format!("Pack substituído: {}.", partes.join(", "));
    if regras_novas > 0 {
        mensagem.push_str(&format!(" (+ {regras_novas} regras)"));
    }
    if removidos > 0 {
        mensagem.push_str(&format!(" {removidos} item(ns) antigo(s) removido(s)."));
    }
    // Os dois contadores são SEPARADOS de propósito: "A+A" (mesma carta dos dois
    // lados, dado que nunca dispara) não é repetição. Antes os dois iam somados
    // num "N repetido(s) do próprio pack pulado(s)" que mandava o usuário
    // procurar no pack uma repetição que não existia.
    if fusoes_mesma > 0 {
        mensagem.push(' ');
        mensagem.push_str(&frase_fusao_mesma(fusoes_mesma));
    }
    if fusoes_repetidas > 0 {
        mensagem.push(' ');
        mensagem.push_str(&frase_fusao_repetida(fusoes_repetidas));
    }
    if regras_puladas > 0 {
        mensagem.push_str(&format!(" {regras_puladas} regras repetidas dentro do próprio pack foram puladas."));
    }
    mensagem.push_str(&format!(" backup em {rotulo}."));

    Ok(ResultadoImportacao {
        cartas: n_cartas,
        duelistas: n_duelistas,
        decks: n_decks,
        fusoes_novas,
        fusoes_puladas,
        fusoes_mesma,
        regras_novas,
        regras_puladas,
        equips_ignorados,
        backups: vec![rotulo],
        avisos,
        mensagem,
    })
}

#[tauri::command]
fn importar_pack(conteudo: String, nome: String) -> Result<ResultadoImportacao, String> {
    let nome_limpo = if nome.trim().is_empty() { "pack.json".to_string() } else { nome.trim().to_string() };
    let pack: serde_json::Value = serde_json::from_str(&conteudo)
        .map_err(|e| format!("\"{nome_limpo}\" tem JSON quebrado: {e}. Confira vírgulas e chaves e tente de novo."))?;
    importar_pack_valor(&pack, &nome_limpo)
}

// ---- APACK V1 (passos 3+4+5 do §12.7) ----
// O frontend manda o .apack como base64 (binário não viaja como texto).
// Passo 1+2 (abrir o zip, validar magic/manifest/hashes/limites/ZipSlip) é o
// apack::ler_apack; o passo 3 REUSA o importar_pack_valor atual (mesmo backup,
// mesmas chaves PT/EN, mesmo filtro A+A); o passo 4 copia os assets; o passo 5
// (faltando = aviso) entra na mensagem + avisos abaixo — nunca silêncio.
#[tauri::command]
fn importar_apack(dados_base64: String, nome: String) -> Result<ResultadoImportacao, String> {
    let nome_limpo = if nome.trim().is_empty() { "pack.apack".to_string() } else { nome.trim().to_string() };
    let bytes = decodificar_base64(&dados_base64)
        .map_err(|_| format!("\"{nome_limpo}\" não chegou direito (arquivo ilegível). Escolha o .apack de novo e confirme o arquivo."))?;
    if bytes.is_empty() {
        return Err(format!("\"{nome_limpo}\" chegou vazio. Escolha o .apack de novo e confirme o arquivo."));
    }
    let lido = apack::ler_apack(&bytes, &nome_limpo)?;
    let mut r = importar_pack_valor(&lido.pack, &nome_limpo)?;

    // Passo 4: assets/* para projects/default/<mesmo path>.
    let proj = pasta_projeto()?;
    let (n_img, falhas) = apack::copiar_assets(&proj, &lido.assets);
    let bytes_img: u64 = lido.assets.iter().map(|(_, b)| b.len() as u64).sum();
    if lido.assets.is_empty() && lido.faltando.is_empty() {
        r.mensagem.push_str(" Nenhuma imagem no pack (só-textos, igual ao .json antigo).");
    } else {
        r.mensagem.push_str(&format!(" {n_img} imagem(ns) copiada(s) para projects/default/assets/ ({bytes_img} bytes)."));
    }
    if let Some((capa, _)) = &lido.preview {
        r.mensagem.push_str(&format!(" Capa \"{capa}\" incluída no pack (só desenho — não entra no projeto)."));
    }
    // Passo 5: faltando = aviso (a carta mostra um cinza no lugar).
    let mostra = lido.faltando.iter().take(apack::AVISOS_TETO);
    for f in mostra {
        r.avisos.push(format!("Sem imagem: \"{f}\" não vem no pack (a carta mostra um cinza no lugar)."));
    }
    if lido.faltando.len() > apack::AVISOS_TETO {
        r.avisos.push(format!("…e mais {} imagem(ns) sem arquivo no pack.", lido.faltando.len() - apack::AVISOS_TETO));
    }
    for f in falhas {
        r.avisos.push(format!("{f}"));
    }
    Ok(r)
}

#[derive(Debug, serde::Serialize)]
struct ResultadoApack {
    nome: String,
    dados_base64: String,
    mensagem: String,
    avisos: Vec<String>,
}

// Resposta do exportar COM destino: o caminho final (para a tela mostrar onde
// caiu) + a mesma mensagem de contagens + avisos + tamanho em bytes.
#[derive(Debug, serde::Serialize)]
struct ResultadoApackSalvo {
    caminho: String,
    mensagem: String,
    avisos: Vec<String>,
    bytes: u64,
}

// Lê os *.json de uma pasta do projeto em ordem (para o .apack sair
// determinístico). JSON quebrado = erro com o nome do arquivo (nunca pula em
// silêncio).
fn ler_jsons_da_pasta(pasta: &std::path::Path, o_que: &str) -> Result<Vec<serde_json::Value>, String> {
    let mut nomes: Vec<String> = Vec::new();
    let entries = std::fs::read_dir(pasta)
        .map_err(|e| format!("Não consegui abrir {}: {e}", pasta.display()))?;
    for e in entries.flatten() {
        let p = e.path();
        if p.extension().and_then(|x| x.to_str()) == Some("json") {
            if let Some(n) = p.file_name().and_then(|x| x.to_str()) {
                nomes.push(n.to_string());
            }
        }
    }
    nomes.sort();
    let mut itens = Vec::new();
    for nome in nomes {
        let texto = std::fs::read_to_string(pasta.join(&nome))
            .map_err(|e| format!("Não consegui ler {nome}: {e}"))?;
        let v: serde_json::Value = serde_json::from_str(&texto)
            .map_err(|e| format!("{nome} tem JSON quebrado ({o_que}): {e}. Arruma na aba e exporta de novo."))?;
        itens.push(v);
    }
    Ok(itens)
}

// Núcleo do exportar: monta os bytes do .apack V1 + mensagem PT-BR com as
// contagens + avisos. Usado pelos DOIS comandos abaixo (download via base64 e
// gravação direta no caminho que o usuário escolheu no diálogo salvar).
struct ApackMontado {
    bytes: Vec<u8>,
    mensagem: String,
    avisos: Vec<String>,
}

fn montar_apack_bytes() -> Result<ApackMontado, String> {
    let proj = pasta_projeto()?;
    let cartas = ler_jsons_da_pasta(&proj.join("cards"), "carta")?;
    let duelistas = ler_jsons_da_pasta(&proj.join("duelists"), "duelista")?;
    let decks = ler_jsons_da_pasta(&proj.join("decks"), "deck")?;
    let fusoes: serde_json::Value = match std::fs::read_to_string(proj.join("fusions.json")) {
        Ok(t) => serde_json::from_str(&t)
            .map_err(|e| format!("fusions.json tem JSON quebrado: {e}. Arruma na aba Fusões e exporta de novo."))?,
        Err(_) => serde_json::json!({"schema_version": 1, "recipes": [], "rules": []}),
    };
    let n_recipes = fusoes.get("recipes").and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0);
    let n_rules = fusoes.get("rules").and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0);
    if cartas.is_empty() && duelistas.is_empty() && decks.is_empty() && n_recipes == 0 && n_rules == 0 {
        return Err("Projeto vazio — nada para empacotar. Importe um pack (.apack ou .json) antes de exportar.".to_string());
    }

    let pack = apack::construir_pack_json("studio_pack", "Pack do Studio", cartas, duelistas, decks, fusoes);
    let pack_raw = (serde_json::to_string_pretty(&pack).map_err(|e| format!("Não consegui montar o pack.json: {e}"))? + "\n").into_bytes();

    // Resolve as refs assets/... no disco (só abaixo de assets/, sem `..`).
    let refs = apack::refs_do_pack(&pack);
    let mut achados: std::collections::BTreeMap<String, Vec<u8>> = std::collections::BTreeMap::new();
    for r in &refs {
        if !r.starts_with("assets/") || !apack::zip_seguro(r) {
            return Err(format!("Referência fora de assets/: \"{r}\" — não empacotei. Use 'assets/...'."));
        }
        if !apack::extensao_permitida(r) {
            return Err(format!("Extensão proibida em \"{r}\" (V1 aceita: png, webp, jpg, jpeg, ogg) — não empacotei."));
        }
        match std::fs::read(proj.join(r)) {
            Ok(b) => {
                achados.insert(r.clone(), b);
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {} // faltando = aviso (montar_apack lista)
            Err(e) => return Err(format!("Não consegui ler \"{r}\" do projeto: {e} — não empacotei.")),
        }
    }

    let pronto = apack::montar_apack(&pack, &pack_raw, &achados, None, "studio", "1")?;
    let c = &pronto.manifest.counts;
    let mut mensagem = format!(
        "Pack exportado: {} cartas, {} duelistas, {} decks, {} fusões ({} regras) + {} imagem(ns) ({} bytes).",
        c.cartas, c.duelistas, c.decks, c.fusoes_recipes, c.fusoes_rules, c.assets, c.assets_bytes
    );
    if pronto.repetidas > 0 {
        mensagem.push_str(&format!(" {} repetida(s) gravada(s) 1x.", pronto.repetidas));
    }
    let mut avisos: Vec<String> = Vec::new();
    let mostra = pronto.faltando.iter().take(apack::AVISOS_TETO);
    for f in mostra {
        avisos.push(format!("Sem imagem no projeto: \"{f}\" não tem arquivo em projects/default/ (o pack abre como \"sem imagens\" nesse ponto)."));
    }
    if pronto.faltando.len() > apack::AVISOS_TETO {
        avisos.push(format!("…e mais {} referência(s) sem arquivo no projeto.", pronto.faltando.len() - apack::AVISOS_TETO));
    }
    if !pronto.faltando.is_empty() {
        mensagem.push_str(&format!(" {} referência(s) sem imagem (aviso, não erro).", pronto.faltando.len()));
    }
    Ok(ApackMontado { bytes: pronto.bytes, mensagem, avisos })
}

// Empacota o projeto atual num .apack V1 (data/pack.json + assets/ com dedup +
// manifest + contagens). O pack.json é montado das pastas do projeto nas
// mesmas chaves PT que o importar entende (exportar → importar = roundtrip).
// Projeto vazio = erro (nada para empacotar). Asset citado sem arquivo no
// disco = aviso (igual ao Python). Sem capa V1 (o Studio não tem slot de capa).
#[tauri::command]
fn exportar_apack() -> Result<ResultadoApack, String> {
    let m = montar_apack_bytes()?;
    let nome = format!("studio_pack_{}.apack", carimbo_data_hora());
    Ok(ResultadoApack { nome, dados_base64: apack::codificar_base64(&m.bytes), mensagem: m.mensagem, avisos: m.avisos })
}

// Garante o `.apack` no fim do caminho: o diálogo salvar do Windows nem sempre
// completa a extensão sozinho, e sem ela o arquivo saía sem extensão (o botão
// Importar nem listava). Maiúscula também vale (`.APACK`).
fn garantir_extensao_apack(caminho: &str) -> String {
    if caminho.to_lowercase().ends_with(".apack") {
        caminho.to_string()
    } else {
        format!("{caminho}.apack")
    }
}

// Exportar COM destino escolhido: o frontend abre o diálogo salvar nativo e
// manda o caminho para cá; o Rust grava os bytes direto nele (sem base64,
// sem download do navegador). Devolve o caminho final para a tela mostrar
// onde o pack caiu. Caminho vazio = erro (o cancelar do diálogo o frontend
// trata antes, com "Exportação cancelada.").
#[tauri::command]
fn exportar_apack_para(caminho: String) -> Result<ResultadoApackSalvo, String> {
    let destino = garantir_extensao_apack(caminho.trim());
    if destino.trim().is_empty() || destino == ".apack" {
        return Err("Sem destino: escolha onde salvar no diálogo e confirme.".to_string());
    }
    let m = montar_apack_bytes()?;
    std::fs::write(&destino, &m.bytes)
        .map_err(|e| format!("Não consegui salvar em {destino}: {e}"))?;
    Ok(ResultadoApackSalvo {
        caminho: destino,
        mensagem: m.mensagem,
        avisos: m.avisos,
        bytes: m.bytes.len() as u64,
    })
}

// ---- ASSETS (blocos 1 e 8) ----
// Arrastar PNG para carta/duelista/cena: valida, copia para
// projects/default/assets/<cards|portraits|backgrounds>/ e devolve o caminho
// para referenciar no dado (relativo à pasta do projeto, que o jogo lê via
// --project). Sem arte, a tela mostra placeholder cinza (frontend).
#[derive(Debug, serde::Deserialize)]
struct PedidoAsset {
    #[serde(default)]
    nome: String,
    #[serde(default)]
    tipo: String,
    #[serde(default)]
    dados_base64: String,
}

fn decodificar_base64(s: &str) -> Result<Vec<u8>, String> {
    let tabela = |c: u8| -> Option<u8> {
        match c {
            b'A'..=b'Z' => Some(c - b'A'),
            b'a'..=b'z' => Some(c - b'a' + 26),
            b'0'..=b'9' => Some(c - b'0' + 52),
            b'+' => Some(62),
            b'/' => Some(63),
            _ => None,
        }
    };
    let limpo: Vec<u8> = s.bytes().filter(|b| !b.is_ascii_whitespace()).collect();
    if limpo.len() % 4 != 0 {
        return Err("Arquivo ilegível. Tente arrastar o PNG de novo.".to_string());
    }
    let mut fora = Vec::with_capacity(limpo.len() * 3 / 4);
    let mut i = 0;
    while i < limpo.len() {
        let mut n: u32 = 0;
        let mut pad = 0;
        for k in 0..4 {
            let c = limpo[i + k];
            if c == b'=' {
                pad += 1;
                n <<= 6;
            } else {
                match tabela(c) {
                    Some(v) => n = (n << 6) | v as u32,
                    None => return Err("Arquivo ilegível. Tente arrastar o PNG de novo.".to_string()),
                }
            }
        }
        fora.push(((n >> 16) & 0xFF) as u8);
        if pad < 2 {
            fora.push(((n >> 8) & 0xFF) as u8);
        }
        if pad < 1 {
            fora.push((n & 0xFF) as u8);
        }
        i += 4;
    }
    Ok(fora)
}

#[tauri::command]
fn importar_asset(pedido: PedidoAsset) -> Result<ResultadoOk, String> {
    let subpasta = match pedido.tipo.as_str() {
        "carta" => "cards",
        "duelista" => "portraits",
        "cena" => "backgrounds",
        _ => return Err("Tipo de arte desconhecido. Arraste a imagem para cima de uma carta, duelista ou cena.".to_string()),
    };
    let bytes = decodificar_base64(&pedido.dados_base64)?;
    if bytes.len() < 8 || bytes[0..8] != [137, 80, 78, 71, 13, 10, 26, 10] {
        return Err("Só vale PNG. Converta a imagem para .png e arraste de novo.".to_string());
    }
    if bytes.len() > 5 * 1024 * 1024 {
        return Err("PNG muito grande (limite 5 MB). Comprima a imagem e tente de novo.".to_string());
    }
    let base = pedido.nome.trim().to_lowercase().replace(' ', "_");
    let mut limpo: String = base.chars().filter(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || *c == '_').collect();
    if limpo.is_empty() || !limpo.chars().next().map(|c| c.is_ascii_lowercase()).unwrap_or(false) {
        limpo = format!("arte_{subpasta}");
    }
    if limpo.len() > 60 {
        limpo.truncate(60);
    }
    let proj = pasta_projeto()?;
    let pasta = proj.join("assets").join(subpasta);
    std::fs::create_dir_all(&pasta)
        .map_err(|e| format!("Não consegui criar a pasta de artes: {e}"))?;
    let destino = pasta.join(format!("{limpo}.png"));
    std::fs::write(&destino, &bytes)
        .map_err(|e| format!("Não consegui copiar a imagem: {e}"))?;
    let relativo = format!("assets/{subpasta}/{limpo}.png");
    Ok(ResultadoOk {
        ok: true,
        file: relativo.clone(),
        mensagem: format!("Imagem salva em projects/default/{relativo} e ligada aqui. Se apagar a arte, a tela mostra um cinza no lugar."),
    })
}

// ---- BOOT VAZIO (ordem do usuário, D29) ----
// Toda vez que o editor abre, ele abre VAZIO: APAGA todo o conteúdo de
// projects/default/ e recria o esqueleto vazio — SEM backup, sem pasta
// sessao_*, sem nada guardado (ordem literal do usuário). O frontend chama
// `preparar_boot` no onMount ANTES da primeira listagem. Projeto já vazio =
// não faz nada. Só dado, nada de jogo (R1/R4).
#[derive(Debug, serde::Serialize)]
struct ResultadoBoot {
    limpou: bool,
    mensagem: String,
}

fn pasta_tem_json(pasta: &std::path::Path) -> bool {
    if let Ok(entries) = std::fs::read_dir(pasta) {
        for e in entries.flatten() {
            let p = e.path();
            if p.is_file() && p.extension().and_then(|x| x.to_str()) == Some("json") {
                return true;
            }
        }
    }
    false
}

// True se o arquivo tem a lista com item — ou se existe mas está quebrado
// (quebrado também vai para o backup e o esqueleto válido é recriado: o
// boot nunca abre com JSON quebrado). Arquivo ausente = sem conteúdo.
fn json_tem_lista(caminho: &std::path::Path, chave: &str) -> bool {
    match std::fs::read_to_string(caminho)
        .ok()
        .and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok())
    {
        Some(v) => v
            .get(chave)
            .and_then(|x| x.as_array())
            .map(|a| !a.is_empty())
            .unwrap_or(true),
        None => caminho.is_file(),
    }
}

fn projeto_tem_conteudo(proj: &std::path::Path) -> bool {
    for sub in ["cards", "duelists", "decks", "arenas", "scenes", "layouts"] {
        if pasta_tem_json(&proj.join(sub)) {
            return true;
        }
    }
    if json_tem_lista(&proj.join("fusions.json"), "recipes") {
        return true;
    }
    if json_tem_lista(&proj.join("fusions.json"), "rules") {
        return true;
    }
    if json_tem_lista(&proj.join("effects.json"), "effects") {
        return true;
    }
    if proj.join("duel_setup.json").is_file() {
        return true;
    }
    false
}

// Apaga os *.json de uma pasta. Devolve quantos apagou.
fn apagar_json_da_pasta(pasta: &std::path::Path) -> usize {
    let mut n = 0;
    if let Ok(entries) = std::fs::read_dir(pasta) {
        for e in entries.flatten() {
            let p = e.path();
            if p.is_file() && p.extension().and_then(|x| x.to_str()) == Some("json") {
                if std::fs::remove_file(&p).is_ok() {
                    n += 1;
                }
            }
        }
    }
    n
}

// Apaga TODOS os arquivos de uma pasta (artes). Devolve quantos apagou.
fn apagar_tudo_da_pasta(pasta: &std::path::Path) -> usize {
    let mut n = 0;
    if let Ok(entries) = std::fs::read_dir(pasta) {
        for e in entries.flatten() {
            let p = e.path();
            if p.is_file() && std::fs::remove_file(&p).is_ok() {
                n += 1;
            }
        }
    }
    n
}

fn preparar_boot_para(proj: &std::path::Path) -> Result<ResultadoBoot, String> {
    garantir_projeto(proj)?;
    // Nada guardado: nem sessão antiga nem backup órfão ficam de pé.
    if !projeto_tem_conteudo(proj) && !proj.join("backups").exists() {
        return Ok(ResultadoBoot {
            limpou: false,
            mensagem: "Projeto já vazio — nada a apagar. Importe um pack para começar.".to_string(),
        });
    }
    let mut apagados = 0;
    for sub in ["cards", "duelists", "decks", "arenas", "scenes", "layouts"] {
        apagados += apagar_json_da_pasta(&proj.join(sub));
    }
    for sub in ["assets/cards", "assets/portraits", "assets/backgrounds"] {
        apagados += apagar_tudo_da_pasta(&proj.join(sub));
    }
    for nome in ["fusions.json", "effects.json", "duel_setup.json"] {
        let p = proj.join(nome);
        if p.is_file() && std::fs::remove_file(&p).is_ok() {
            apagados += 1;
        }
    }
    if proj.join("backups").exists() {
        let _ = std::fs::remove_dir_all(proj.join("backups"));
    }
    // Recria o esqueleto vazio e COMPLETO: pastas + .gitkeep (para as pastas
    // continuarem rastreáveis no git) + fusions/effects vazios válidos.
    garantir_projeto(proj)?;
    Ok(ResultadoBoot {
        limpou: true,
        mensagem: format!("Projeto zerado ({apagados} arquivo(s) apagado(s), sem backup). Importe um pack para começar."),
    })
}

// ---- BOOT 1x POR PROCESSO (regra do usuário, sem reabrir D29) ----
// Abrir o app (processo novo) = SEMPRE zera (D29, via preparar_boot_para).
// Reload da página no dev (HMR / F5: o processo Tauri continua vivo, só o
// JS recarrega e o onMount do +page.svelte chama preparar_boot DE NOVO) =
// NÃO zera: só garante o esqueleto e mantém o que está no disco. Sem esta
// flag, cada reload pós-import apagava as 722 cartas + 25k fusões e a tela
// "abria zerada". Processo novo = flag nasce false = zera de novo (prod
// intacto: fechar e abrir zera).
static BOOT_JA_FEITO: AtomicBool = AtomicBool::new(false);

fn contar_arquivos_projeto(proj: &std::path::Path) -> usize {
    let mut n = 0;
    for sub in ["cards", "duelists", "decks", "arenas", "scenes", "layouts"] {
        if let Ok(entries) = std::fs::read_dir(proj.join(sub)) {
            n += entries
                .flatten()
                .filter(|e| {
                    let p = e.path();
                    p.is_file() && p.extension().and_then(|x| x.to_str()) == Some("json")
                })
                .count();
        }
    }
    for nome in ["fusions.json", "effects.json", "duel_setup.json"] {
        if proj.join(nome).is_file() {
            n += 1;
        }
    }
    n
}

// Núcleo testável do boot 1x: a 1ª chamada do processo delega ao
// preparar_boot_para (que zera de verdade, D29); as seguintes só garantem o
// esqueleto sem apagar nada. `ja_feito` é o BOOT_JA_FEITO no app e uma flag
// fresca nos testes.
fn preparar_boot_uma_vez(
    proj: &std::path::Path,
    ja_feito: &AtomicBool,
) -> Result<ResultadoBoot, String> {
    if ja_feito.swap(true, Ordering::SeqCst) {
        garantir_projeto(proj)?;
        let n = contar_arquivos_projeto(proj);
        return Ok(ResultadoBoot {
            limpou: false,
            mensagem: format!(
                "Sessão já aberta — {n} arquivo(s) mantido(s) (reload não apaga; fechar e abrir zera)."
            ),
        });
    }
    preparar_boot_para(proj)
}

#[tauri::command]
fn preparar_boot() -> Result<ResultadoBoot, String> {
    let proj = pasta_projeto()?;
    preparar_boot_uma_vez(&proj, &BOOT_JA_FEITO)
}

// ---- DIAGNÓSTICO DE IPC (o frontend manda lote a cada 2s) ----
// ipc.ts chamava "debug_push_batch", comando que NÃO existia no Rust: a falha
// era engolida (.then(ok, falho)), então todo o diagnóstico se perdia e ainda
// sobrava 1 IPC morto a cada 2s. Agora o lote é registrado num estado do Tauri
// com teto de DIAG_MAX_LINHAS linhas (o buffer não cresce para sempre).
const DIAG_MAX_LINHAS: usize = 500;

#[derive(Debug, serde::Deserialize, Clone)]
struct EventoIpc {
    #[serde(default)]
    origin: String,
    #[serde(default)]
    level: String,
    #[serde(default)]
    area: String,
    #[serde(default)]
    msg: String,
}

#[derive(Debug, Default)]
struct DiagnosticoIpc {
    linhas: std::sync::Mutex<Vec<String>>,
}

fn trancar(estado: &DiagnosticoIpc) -> std::sync::MutexGuard<'_, Vec<String>> {
    estado.linhas.lock().unwrap_or_else(|e| e.into_inner())
}

fn linha_de_diag(agora: u64, e: &EventoIpc) -> String {
    format!("{agora} [{}] {}/{} — {}", e.level, e.origin, e.area, e.msg)
}

// Registra o lote e corta o excesso (guarda as últimas DIAG_MAX_LINHAS).
// Devolve quantas linhas estão guardadas depois do lote.
fn registrar_diagnostico(estado: &DiagnosticoIpc, agora: u64, eventos: &[EventoIpc]) -> usize {
    let mut linhas = trancar(estado);
    for e in eventos {
        linhas.push(linha_de_diag(agora, e));
    }
    if linhas.len() > DIAG_MAX_LINHAS {
        let excesso = linhas.len() - DIAG_MAX_LINHAS;
        linhas.drain(0..excesso);
    }
    linhas.len()
}

// Só os testes leem o buffer (o comando só grava e devolve o total).
#[cfg(test)]
fn ler_diagnostico(estado: &DiagnosticoIpc) -> Vec<String> {
    trancar(estado).clone()
}

#[derive(Debug, serde::Serialize)]
struct ResumoDiagnostico {
    recebidos: usize,
    total: usize,
    teto: usize,
}

#[tauri::command]
fn debug_push_batch(
    estado: tauri::State<'_, DiagnosticoIpc>,
    events: Vec<EventoIpc>,
) -> Result<ResumoDiagnostico, String> {
    let total = registrar_diagnostico(&estado, agora_em_segundos(), &events);
    Ok(ResumoDiagnostico { recebidos: events.len(), total, teto: DIAG_MAX_LINHAS })
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .manage(DiagnosticoIpc::default())
        .invoke_handler(tauri::generate_handler![
            listar_cartas,
            salvar_carta,
            validar_carta,
            jogar_carta,
            listar_duelistas,
            ler_deck,
            salvar_duelista,
            validar_duelista,
            listar_decks,
            salvar_deck,
            validar_deck,
            importar_asset,
            ler_fusoes,
            salvar_fusoes,
            testar_fusao,
            ler_efeitos,
            salvar_efeitos,
            validar_efeito,
            listar_arenas,
            jogar_duelo,
            validar_test_state,
            listar_cenas,
            salvar_cena,
            validar_cena,
            ler_card_layout,
            validar_molde,
            salvar_card_layout,
            validar_projeto,
            importar_pack,
            importar_apack,
            exportar_apack,
            exportar_apack_para,
            preparar_boot,
            debug_push_batch
        ])
        .run(tauri::generate_context!())
        .expect("Astralis Studio não abriu");
}

// Regressão mínima: validação PT-BR espelha o card.schema.json (R4).
#[cfg(test)]
mod testes {
    use super::*;

    // Catálogo sem nenhum item (projeto novo/zerado — D29).
    fn sem_efeitos() -> Catalogo {
        catalogo(&[])
    }

    // Catálogo com itens (o projeto já tem o que foi citado).
    fn com_efeitos(ids: &[&str]) -> Catalogo {
        catalogo(ids)
    }

    // Catálogo de QUALQUER pasta do projeto (cartas/decks/arenas/efeitos):
    // vazio = projeto zerado (D29), com ids = projeto com conteúdo.
    fn catalogo(ids: &[&str]) -> Catalogo {
        Catalogo::de_ids(ids.iter().map(|s| s.to_string()))
    }

    #[test]
    fn id_snake() {
        assert!(eh_id_snake("card_meu_dragao"));
        assert!(eh_id_snake("a1"));
        assert!(!eh_id_snake("Card_X"));
        assert!(!eh_id_snake("1abc"));
        assert!(!eh_id_snake("com espaco"));
        assert!(!eh_id_snake(""));
    }

    #[test]
    fn destino_apack_garante_extensao() {
        assert_eq!(garantir_extensao_apack("C:\\packs\\meu_pack"), "C:\\packs\\meu_pack.apack");
        assert_eq!(garantir_extensao_apack("C:\\packs\\meu_pack.apack"), "C:\\packs\\meu_pack.apack");
        assert_eq!(garantir_extensao_apack("C:\\packs\\MEU.APACK"), "C:\\packs\\MEU.APACK");
    }

    #[test]
    fn carta_vazia_reclama_obrigatorios() {
        let erros = checar_carta(&serde_json::json!({}), &sem_efeitos());
        let campos: Vec<&str> = so_erros(&erros).iter().map(|e| e.campo.as_str()).collect();
        for c in ["Versão", "ID", "Nome", "Tipo", "Efeitos"] {
            assert!(campos.contains(&c), "faltou erro de {c}");
        }
    }

    #[test]
    fn monstro_valido_passa() {
        let carta = serde_json::json!({
            "schema_version": 1,
            "id": "card_teste",
            "name": "Teste",
            "description": "",
            "artwork": "",
            "card_type": "monster",
            "monster_type": "warrior",
            "attribute": "earth",
            "level": 4,
            "attack": 1500,
            "defense": 1200,
            "effects": [],
            "tags": []
        });
        assert!(checar_carta(&carta, &sem_efeitos()).is_empty());
    }

    #[test]
    fn efeito_desconhecido_barra_r4() {
        let carta = serde_json::json!({
            "schema_version": 1, "id": "card_teste", "name": "Teste",
            "card_type": "spell", "effects": ["efeito_que_nao_existe"], "tags": []
        });
        let erros = checar_carta(&carta, &com_efeitos(&["ganho_lp"]));
        assert!(so_erros(&erros).iter().any(|e| e.mensagem.contains("não existe neste projeto")));
    }

    // ---- Gate de efeitos: os 3 estados do R4 (aciei o bug do fail-open) ----

    fn carta_com_efeito(id_efeito: &str) -> serde_json::Value {
        serde_json::json!({
            "schema_version": 1, "id": "card_teste", "name": "Teste",
            "card_type": "spell", "effects": [id_efeito], "tags": []
        })
    }

    #[test]
    fn efeito_em_projeto_sem_efeitos_avisa_e_nao_passa_em_silencio() {
        // Projeto novo/vazio (effects.json ausente ou "effects": []) — a carta
        // NÃO pode citar efeito, mas é AVISO (não erro): some da lista de
        // bloqueio e aparece com o texto dizendo onde cadastrar o modelo.
        let revisao = checar_carta(&carta_com_efeito("effect_inventado"), &sem_efeitos());
        assert!(so_erros(&revisao).is_empty(), "sem catálogo não pode virar erro: {revisao:?}");
        let avisos = so_avisos(&revisao);
        assert_eq!(avisos.len(), 1, "o efeito citado tem que gerar aviso");
        let m = &avisos[0].mensagem;
        assert!(m.contains("effect_inventado"), "aviso tem que citar o efeito: {m}");
        assert!(m.contains("não tem nenhum efeito cadastrado"), "aviso tem que avisar: {m}");
        assert!(m.contains("aba Efeitos"), "aviso tem que dizer onde corrigir: {m}");
    }

    #[test]
    fn efeito_cadastrado_no_projeto_passa() {
        let revisao = checar_carta(&carta_com_efeito("effect_ganho_lp"), &com_efeitos(&["effect_ganho_lp"]));
        assert!(revisao.is_empty(), "efeito cadastrado tem que passar: {revisao:?}");
    }

    #[test]
    fn efeito_fora_da_lista_do_projeto_e_erro_com_o_nome() {
        let revisao = checar_carta(&carta_com_efeito("effect_inventado"), &com_efeitos(&["effect_ganho_lp"]));
        let erros = so_erros(&revisao);
        assert_eq!(erros.len(), 1, "fora da lista tem que ser ERRO: {revisao:?}");
        assert!(erros[0].mensagem.contains("effect_inventado"), "erro tem que citar o efeito");
        assert!(erros[0].mensagem.contains("aba Efeitos"), "erro tem que dizer onde corrigir");
    }

    #[test]
    fn gate_efeito_unico_os_tres_estados() {
        assert!(checar_efeito_da_carta(&com_efeitos(&["a"]), "a").is_none());
        let e = checar_efeito_da_carta(&com_efeitos(&["a"]), "b").expect("fora da lista = erro");
        assert!(eh_erro(&e));
        let a = checar_efeito_da_carta(&sem_efeitos(), "b").expect("sem catálogo = aviso");
        assert!(!eh_erro(&a));
    }

    #[test]
    fn catalogo_le_effects_json_da_pasta() {
        // Projeto temporário: effects.json com 1 efeito -> Listado.
        let dir = projeto_boot_teste("catalogo-listado");
        let mut ef = efeito_base();
        ef["id"] = serde_json::json!("effect_ganho_lp");
        escrever_json_valor(
            &dir.join("effects.json"),
            &serde_json::json!({"schema_version": 1, "effects": [ef]}),
            "efeitos",
        )
        .unwrap();
        assert_eq!(catalogo_efeitos_de(&dir), com_efeitos(&["effect_ganho_lp"]));
        // effects.json com lista vazia -> Vazio (o caso do projeto novo).
        escrever_json_valor(
            &dir.join("effects.json"),
            &serde_json::json!({"schema_version": 1, "effects": []}),
            "efeitos",
        )
        .unwrap();
        assert_eq!(catalogo_efeitos_de(&dir), catalogo(&[]));
        // Sem o arquivo -> Vazio.
        std::fs::remove_file(dir.join("effects.json")).unwrap();
        assert_eq!(catalogo_efeitos_de(&dir), catalogo(&[]));
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn salvar_carta_valida_antes_de_gravar() {
        // Os dois lados: carta boa grava, carta ruim NÃO grava e volta a lista.
        let dir = projeto_boot_teste("salvar-carta");
        let pasta_cartas = dir.join("cards");
        let boa = carta_pack_valida("card_boa", "Boa");
        let gravada = salvar_carta_para(&pasta_cartas, &boa);
        assert!(gravada.is_ok(), "carta válida tem que gravar: {:?}", gravada.err());
        assert!(pasta_cartas.join("card_boa.json").is_file());

        // Carta com efeito fora do catálogo de um projeto que TEM efeitos: erro.
        let mut ruim = carta_pack_valida("card_ruim", "Ruim");
        ruim["effects"] = serde_json::json!(["effect_inventado"]);
        let revisao = checar_carta(&ruim, &com_efeitos(&["effect_ganho_lp"]));
        let erros = so_erros(&revisao);
        assert!(!erros.is_empty());
        let msg = mensagem_bloqueio(&erros);
        assert!(msg.starts_with("Arruma antes de salvar:"), "mesma frase dos outros salvar_*: {msg}");
        assert!(!pasta_cartas.join("card_ruim.json").exists(), "carta inválida não pode ir pro disco");

        // Sem catálogo: aviso, não erro — a carta pode gravar, o aviso vai junto.
        let revisao = checar_carta(&ruim, &sem_efeitos());
        assert!(so_erros(&revisao).is_empty());
        assert_eq!(so_avisos(&revisao).len(), 1);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn salvar_carta_invalida_real_nao_grava() {
        // O comando de verdade (com o projeto do editor): carta sem nome não
        // pode criar arquivo nenhum.
        let carta = serde_json::json!({"schema_version": 1, "id": "card_sem_nome", "card_type": "spell", "effects": [], "tags": []});
        let r = salvar_carta(carta);
        assert!(r.is_err(), "carta sem nome tem que barrar");
        let e = r.unwrap_err();
        assert!(e.starts_with("Arruma antes de salvar:"), "mesma frase padrão: {e}");
        assert!(e.contains("Nome"), "tem que dizer o que falta: {e}");
    }

    #[test]
    fn deck_id_invalido_barra() {
        assert!(ler_deck("Deck_X".to_string()).is_err());
        assert!(ler_deck("".to_string()).is_err());
    }

    #[test]
    fn duelista_vazio_reclama_obrigatorios() {
        let erros = checar_duelista(&serde_json::json!({}), &catalogo(&[]));
        let campos: Vec<&str> = erros.iter().map(|e| e.campo.as_str()).collect();
        for c in ["Versão", "ID", "Nome", "Deck", "Estilo de jogo"] {
            assert!(campos.contains(&c), "faltou erro de {c}");
        }
    }

    #[test]
    fn duelista_valido_passa() {
        let decks = catalogo(&["deck_starter_hero"]);
        let d = serde_json::json!({
            "schema_version": 1, "id": "duelist_teste", "name": "Teste",
            "deck_id": "deck_starter_hero", "starting_lp": 4000,
            "ai_preset": { "dificuldade": "normal", "agressividade": 50, "uso_fusao": 50, "protecao_lp": 50 }
        });
        assert!(checar_duelista(&d, &decks).is_empty());
    }

    #[test]
    fn duelista_deck_fantasma_barra() {
        let decks = catalogo(&["deck_outro"]);
        let d = serde_json::json!({
            "schema_version": 1, "id": "duelist_teste", "name": "Teste",
            "deck_id": "deck_fantasma",
            "ai_preset": { "dificuldade": "facil", "agressividade": 30, "uso_fusao": 20, "protecao_lp": 60 }
        });
        let erros = checar_duelista(&d, &decks);
        assert!(so_erros(&erros).iter().any(|e| e.campo == "Deck"));
    }

    #[test]
    fn deck_curto_barra() {
        let d = serde_json::json!({
            "schema_version": 1, "id": "deck_teste", "name": "Teste",
            "cards": ["card_a", "card_fantasma"]
        });
        let erros = checar_deck(&d, &catalogo(&["card_a"]));
        assert!(erros.iter().any(|e| e.mensagem.contains("20 a 60")));
        assert!(so_erros(&erros).iter().any(|e| e.mensagem.contains("card_fantasma")));
    }

    #[test]
    fn base64_png_minimo_decodifica() {
        // PNG 1x1 válido (assinatura + IHDR/IEND mínimos).
        let b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
        let bytes = decodificar_base64(b64).unwrap();
        assert_eq!(&bytes[0..8], &[137, 80, 78, 71, 13, 10, 26, 10]);
        assert!(decodificar_base64("%%%").is_err());
    }

    #[test]
    fn fusao_vazia_reclama_listas() {
        let erros = checar_fusoes(&serde_json::json!({}), &catalogo(&[]));
        assert!(erros.iter().any(|e| e.campo == "Receitas" || e.mensagem.contains("Receitas")));
    }

    #[test]
    fn fusao_receita_igual_barra() {
        let cartas = catalogo(&["card_a"]);
        let dado = serde_json::json!({
            "schema_version": 1,
            "recipes": [{ "id": "fusion_x", "input": { "card_a": "card_a", "card_b": "card_a" }, "result": "card_a" }],
            "rules": []
        });
        let erros = checar_fusoes(&dado, &cartas);
        assert!(erros.iter().any(|e| e.mensagem.contains("mesma")));
    }

    #[test]
    fn fusao_regra_sem_condicao_barra() {
        let dado = serde_json::json!({
            "schema_version": 1, "recipes": [],
            "rules": [{ "id": "fusion_r", "when": {}, "result": "card_a", "priority": 1 }]
        });
        let erros = checar_fusoes(&dado, &catalogo(&[]));
        assert!(erros.iter().any(|e| e.mensagem.contains("sem condição")));
    }

    #[test]
    fn regra_casa_tipo_atributo() {
        let mut cartas = std::collections::HashMap::new();
        cartas.insert("card_a".to_string(), serde_json::json!({"monster_type": "dragon", "attribute": "light", "attack": 1500}));
        cartas.insert("card_b".to_string(), serde_json::json!({"monster_type": "warrior", "attribute": "dark", "attack": 1200}));
        let when = serde_json::json!({"type_a": "dragon", "attribute_b": "dark"});
        assert!(regra_casa(&when, "card_a", "card_b", &cartas));
        assert!(!regra_casa(&when, "card_b", "card_a", &cartas));
        let when_min = serde_json::json!({"min_atk": 2000});
        assert!(!regra_casa(&when_min, "card_a", "card_b", &cartas));
        let when_min2 = serde_json::json!({"min_atk": 1500});
        assert!(regra_casa(&when_min2, "card_a", "card_b", &cartas));
    }

    fn efeito_base() -> serde_json::Value {
        serde_json::json!({
            "id": "effect_teste", "name": "Teste",
            "trigger": "card_summoned", "conditions": [],
            "target": "opponent",
            "actions": [{ "action": "damage", "amount": 500 }],
            "flow": { "mode": "sequence" }
        })
    }

    #[test]
    fn efeito_valido_passa() {
        assert!(checar_um_efeito(&efeito_base(), "Efeito").is_empty());
    }

    #[test]
    fn efeito_gatilho_fantasma_barra() {
        let mut ef = efeito_base();
        ef["trigger"] = serde_json::json!("quando_quiser");
        let erros = checar_um_efeito(&ef, "Efeito");
        assert!(erros.iter().any(|e| e.mensagem.contains("gatilho")));
    }

    #[test]
    fn efeito_draw_alvo_errado_barra() {
        let mut ef = efeito_base();
        ef["target"] = serde_json::json!("enemy_monster");
        ef["actions"] = serde_json::json!([{ "action": "draw", "amount": 1 }]);
        let erros = checar_um_efeito(&ef, "Efeito");
        assert!(erros.iter().any(|e| e.mensagem.contains("não combina")));
    }

    #[test]
    fn efeito_modify_sem_duracao_barra() {
        let mut ef = efeito_base();
        ef["target"] = serde_json::json!("enemy_monster");
        ef["actions"] = serde_json::json!([{ "action": "modify_attack", "amount": -500 }]);
        let erros = checar_um_efeito(&ef, "Efeito");
        assert!(erros.iter().any(|e| e.mensagem.contains("duração")));
    }

    // ---- Gate de catálogo: os 3 estados, ponto por ponto (o fail-open) ----
    // Mesmo formato do gate de efeitos: projeto VAZIO = aviso (D29 abre
    // vazio, barra-error quebraria o fluxo), projeto COM itens = erro quando
    // o id não está na lista, id na lista = passa.

    fn deck_de_20(carta: &str) -> serde_json::Value {
        let cartas: Vec<serde_json::Value> = (0..20).map(|_| serde_json::json!(carta)).collect();
        serde_json::json!({"schema_version": 1, "id": "deck_teste", "name": "Teste", "cards": cartas})
    }

    fn duelista_com_deck(deck: &str) -> serde_json::Value {
        serde_json::json!({
            "schema_version": 1, "id": "duelist_teste", "name": "Teste",
            "deck_id": deck,
            "ai_preset": { "dificuldade": "facil", "agressividade": 30, "uso_fusao": 20, "protecao_lp": 60 }
        })
    }

    // Ponto 1: duelista -> deck (era `!decks.is_empty() && !decks.contains`).
    #[test]
    fn gate_deck_do_duelista() {
        let vazio = checar_duelista(&duelista_com_deck("deck_x"), &catalogo(&[]));
        assert!(so_erros(&vazio).is_empty(), "projeto sem deck não pode virar erro: {vazio:?}");
        let avisos = so_avisos(&vazio);
        assert_eq!(avisos.len(), 1, "tem que avisar: {vazio:?}");
        assert!(avisos[0].mensagem.contains("deck_x"), "o aviso cita o id: {}", avisos[0].mensagem);
        assert!(avisos[0].mensagem.contains("não tem nenhum deck cadastrado"), "{}", avisos[0].mensagem);
        assert!(avisos[0].mensagem.contains("aba Decks"), "{}", avisos[0].mensagem);

        let fora = checar_duelista(&duelista_com_deck("deck_x"), &catalogo(&["deck_outro"]));
        let erros = so_erros(&fora);
        assert_eq!(erros.len(), 1, "fora da lista tem que ser ERRO: {fora:?}");
        assert!(erros[0].mensagem.contains("deck_x"), "{}", erros[0].mensagem);
        assert!(erros[0].mensagem.contains("aba Decks"), "{}", erros[0].mensagem);

        assert!(checar_duelista(&duelista_com_deck("deck_x"), &catalogo(&["deck_x"])).is_empty());
    }

    // Ponto 2: deck -> cartas (era `!cartas.is_empty() && !cartas.contains`).
    #[test]
    fn gate_carta_do_deck() {
        let vazio = checar_deck(&deck_de_20("card_x"), &catalogo(&[]));
        assert!(so_erros(&vazio).is_empty(), "projeto sem carta não pode virar erro: {vazio:?}");
        let avisos = so_avisos(&vazio);
        assert_eq!(avisos.len(), 20, "uma linha por carta citada: {vazio:?}");
        assert!(avisos[0].mensagem.contains("card_x"), "{}", avisos[0].mensagem);
        assert!(avisos[0].mensagem.contains("não tem nenhuma carta cadastrada"), "{}", avisos[0].mensagem);
        assert!(avisos[0].mensagem.contains("aba Cartas"), "{}", avisos[0].mensagem);

        let fora = checar_deck(&deck_de_20("card_x"), &catalogo(&["card_outra"]));
        let erros = so_erros(&fora);
        assert_eq!(erros.len(), 20, "fora da lista tem que ser ERRO: {fora:?}");
        assert!(erros[0].mensagem.contains("card_x"), "{}", erros[0].mensagem);
        assert!(erros[0].mensagem.contains("aba Cartas"), "{}", erros[0].mensagem);

        assert!(checar_deck(&deck_de_20("card_x"), &catalogo(&["card_x"])).is_empty());
    }

    // Ponto 3: fusão -> carta A/B da receita (o `else if` da receita).
    #[test]
    fn gate_cartas_da_receita() {
        let receita = |a: &str, b: &str, res: &str| serde_json::json!({
            "schema_version": 1,
            "recipes": [{ "id": "fusion_x", "input": { "card_a": a, "card_b": b }, "result": res }],
            "rules": []
        });

        let vazio = checar_fusoes(&receita("card_x", "card_y", "card_x"), &catalogo(&[]));
        assert!(so_erros(&vazio).is_empty(), "projeto sem carta não pode virar erro: {vazio:?}");
        let avisos = so_avisos(&vazio);
        assert_eq!(avisos.len(), 3, "A, B e resultado: {vazio:?}");
        assert!(avisos.iter().all(|a| a.mensagem.contains("Receita 1")), "{avisos:?}");
        assert!(avisos.iter().all(|a| a.mensagem.contains("não tem nenhuma carta cadastrada")), "{avisos:?}");

        let fora = checar_fusoes(&receita("card_x", "card_y", "card_x"), &catalogo(&["card_outra"]));
        let erros = so_erros(&fora);
        assert_eq!(erros.len(), 3, "fora da lista tem que ser ERRO: {fora:?}");
        assert!(erros[0].mensagem.contains("card_x"), "{}", erros[0].mensagem);
        assert!(erros[2].mensagem.contains("card_x"), "{}", erros[2].mensagem);

        assert!(checar_fusoes(&receita("card_x", "card_y", "card_x"), &catalogo(&["card_x", "card_y"])).is_empty());
    }

    // Ponto 4: fusão -> resultado da receita (só o resultado fora da lista).
    #[test]
    fn gate_resultado_da_receita() {
        let receita = serde_json::json!({
            "schema_version": 1,
            "recipes": [{ "id": "fusion_x", "input": { "card_a": "card_a", "card_b": "card_b" }, "result": "card_fantasma" }],
            "rules": []
        });

        let vazio = checar_fusoes(&receita, &catalogo(&[]));
        assert!(so_erros(&vazio).is_empty(), "projeto sem carta não pode virar erro: {vazio:?}");
        let avisos = so_avisos(&vazio);
        assert_eq!(avisos.len(), 3, "A, B e resultado: {vazio:?}");
        assert!(avisos[2].mensagem.contains("resultado"), "o aviso do resultado: {}", avisos[2].mensagem);
        assert!(avisos[2].mensagem.contains("não tem nenhuma carta cadastrada"), "{}", avisos[2].mensagem);

        let fora = checar_fusoes(&receita, &catalogo(&["card_a", "card_b"]));
        let erros = so_erros(&fora);
        assert_eq!(erros.len(), 1, "só o resultado está fora: {fora:?}");
        assert!(erros[0].mensagem.contains("card_fantasma"), "{}", erros[0].mensagem);
        assert!(erros[0].mensagem.contains("aba Cartas"), "{}", erros[0].mensagem);

        assert!(checar_fusoes(&receita, &catalogo(&["card_a", "card_b", "card_fantasma"])).is_empty());
    }

    // Ponto 5: fusão -> resultado da regra genérica.
    #[test]
    fn gate_resultado_da_regra() {
        let regra = serde_json::json!({
            "schema_version": 1, "recipes": [],
            "rules": [{ "id": "fusion_r", "when": { "type_a": "dragon" }, "result": "card_fantasma", "priority": 1 }]
        });

        let vazio = checar_fusoes(&regra, &catalogo(&[]));
        assert!(so_erros(&vazio).is_empty(), "projeto sem carta não pode virar erro: {vazio:?}");
        let avisos = so_avisos(&vazio);
        assert_eq!(avisos.len(), 1, "só o resultado da regra: {vazio:?}");
        assert!(avisos[0].mensagem.contains("resultado"), "{}", avisos[0].mensagem);
        assert!(avisos[0].campo == "Regra 1", "{}", avisos[0].campo);

        let fora = checar_fusoes(&regra, &catalogo(&["card_a"]));
        let erros = so_erros(&fora);
        assert_eq!(erros.len(), 1, "só o resultado está fora: {fora:?}");
        assert!(erros[0].mensagem.contains("card_fantasma"), "{}", erros[0].mensagem);
        assert!(erros[0].campo == "Regra 1", "{}", erros[0].campo);

        assert!(checar_fusoes(&regra, &catalogo(&["card_fantasma"])).is_empty());
    }

    // Ponto 6: arena do duelo rápido (o gate que NÃO pode virar erro sozinho:
    // o projeto nunca traz arena e a lista oferece arena_starter).
    #[test]
    fn gate_arena_do_duelo() {
        let vazio = checar_arena_do_duelo(&catalogo(&[]), "arena_starter").expect("sem arena = aviso");
        assert!(!eh_erro(&vazio), "projeto sem arena não pode travar o duelo: {vazio:?}");
        assert!(vazio.mensagem.contains("arena_starter"), "{}", vazio.mensagem);
        assert!(vazio.mensagem.contains("projects/default/arenas/"), "{}", vazio.mensagem);

        let fora = checar_arena_do_duelo(&catalogo(&["arena_x"]), "arena_y").expect("fora da lista = erro");
        assert!(eh_erro(&fora), "projeto COM arenas e id errado tem que barrar: {fora:?}");
        assert!(fora.mensagem.contains("arena_y"), "{}", fora.mensagem);
        assert!(fora.mensagem.contains("Avançado"), "{}", fora.mensagem);

        assert!(checar_arena_do_duelo(&catalogo(&["arena_x"]), "arena_x").is_none());
    }

    #[test]
    fn duelo_mesmo_duelista_barra() {
        let p = PedidoDuelo { duelista1: "duelist_hero".to_string(), duelista2: "duelist_hero".to_string(), vida: 4000, seed: None, arena: "".to_string(), ordem: "".to_string(), test_state: None };
        assert!(jogar_duelo(p).is_err());
    }

    #[test]
    fn duelo_vida_zero_barra() {
        let p = PedidoDuelo { duelista1: "duelist_hero".to_string(), duelista2: "duelist_rival".to_string(), vida: 0, seed: None, arena: "".to_string(), ordem: "".to_string(), test_state: None };
        let r = jogar_duelo(p);
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("Vida"));
    }

    // Campo de Testes (contrato systems test_state V1): ausente = válido;
    // presente e bem formado = válido; quebrado = erro em PT-BR.
    fn setup_base_com_teste(teste: serde_json::Value) -> serde_json::Value {
        let mut s = serde_json::json!({
            "schema_version": 1, "duel_id": "duel_teste",
            "duelist1": { "duelist_id": "duelist_hero", "deck_id": "deck_a" },
            "duelist2": { "duelist_id": "duelist_rival", "deck_id": "deck_b" },
            "starting_lp": 4000, "turn_order": "first_p1", "seed": 42,
            "arena_id": "arena_starter",
            "win": { "on_lp_zero": true, "on_deckout": true }
        });
        s["test_state"] = teste;
        s
    }

    #[test]
    fn teste_ausente_e_valido() {
        let s = serde_json::json!({
            "schema_version": 1, "duel_id": "duel_fm_abertura",
            "duelist1": { "duelist_id": "fm_duelist_01", "deck_id": "fm_deck_01" },
            "duelist2": { "duelist_id": "fm_duelist_03", "deck_id": "fm_deck_03" },
            "starting_lp": 8000, "turn_order": "first_p1", "seed": 42,
            "arena_id": "arena_starter",
            "win": { "on_lp_zero": true, "on_deckout": true }
        });
        assert!(checar_test_state(&s, &catalogo(&["fm_0001"])).is_empty());
    }

    #[test]
    fn teste_minimo_valido_passa() {
        let s = setup_base_com_teste(serde_json::json!({
            "my_hand": ["card_a", "card_b"],
            "p0_monster": [{"card_id": "card_a"}, null, null, null, null],
            "p0_spell": [null, null, null, null, null],
            "p1_monster": [null, null, null, null, null],
            "p1_spell": [null, null, null, null, null]
        }));
        assert!(checar_test_state(&s, &catalogo(&["card_a", "card_b"])).is_empty());
    }

    #[test]
    fn teste_mao_com_6_barra() {
        let s = setup_base_com_teste(serde_json::json!({
            "my_hand": ["card_a", "card_a", "card_a", "card_a", "card_a", "card_a"]
        }));
        let rev = checar_test_state(&s, &catalogo(&["card_a"]));
        let erros = so_erros(&rev);
        assert_eq!(erros.len(), 1, "{erros:?}");
        assert!(erros[0].mensagem.contains("0 a 5"), "{}", erros[0].mensagem);
    }

    #[test]
    fn teste_zona_com_4_barra() {
        let s = setup_base_com_teste(serde_json::json!({
            "p0_monster": [null, null, null, null]
        }));
        let rev = checar_test_state(&s, &catalogo(&["card_a"]));
        let erros = so_erros(&rev);
        assert_eq!(erros.len(), 1, "{erros:?}");
        assert!(erros[0].mensagem.contains("exatos 5"), "{}", erros[0].mensagem);
    }

    #[test]
    fn teste_ordem_errada_barra() {
        let mut s = setup_base_com_teste(serde_json::json!({ "my_hand": [] }));
        s["turn_order"] = serde_json::json!("random");
        let rev = checar_test_state(&s, &catalogo(&[]));
        let erros = so_erros(&rev);
        assert!(erros.iter().any(|e| e.campo == "Ordem do teste"), "{erros:?}");
    }

    #[test]
    fn teste_carta_fora_da_lista_barra() {
        let s = setup_base_com_teste(serde_json::json!({ "my_hand": ["card_fantasma"] }));
        let rev = checar_test_state(&s, &catalogo(&["card_a"]));
        let erros = so_erros(&rev);
        assert_eq!(erros.len(), 1, "{erros:?}");
        assert!(erros[0].mensagem.contains("card_fantasma"), "{}", erros[0].mensagem);
    }

    // PedidoDuelo com test_state (ligação da aba Testes): vazio = duelo
    // normal; preenchido = first_p1 forçado + test_state dentro do setup.
    #[test]
    fn teste_vazio_cobre_ausente_null_e_so_nulo() {
        assert!(test_state_vazio(None));
        assert!(test_state_vazio(Some(&serde_json::json!(null))));
        assert!(test_state_vazio(Some(&serde_json::json!({}))));
        assert!(test_state_vazio(Some(&serde_json::json!({
            "my_hand": [],
            "p0_monster": [null, null, null, null, null],
            "p0_spell": [null, null, null, null, null],
            "p1_monster": [null, null, null, null, null],
            "p1_spell": [null, null, null, null, null]
        }))));
        assert!(test_state_vazio(Some(&serde_json::json!({ "my_hand": [] }))));
    }

    #[test]
    fn teste_preenchido_nao_e_vazio() {
        assert!(!test_state_vazio(Some(&serde_json::json!({ "my_hand": ["card_a"] }))));
        assert!(!test_state_vazio(Some(&serde_json::json!({
            "p1_monster": [null, {"card_id": "card_a"}, null, null, null]
        }))));
        // Formato quebrado não é "vazio": tem que cair no gate e barrar.
        assert!(!test_state_vazio(Some(&serde_json::json!("lixo"))));
        assert!(!test_state_vazio(Some(&serde_json::json!({ "my_hand": "lixo" }))));
    }

    #[test]
    fn setup_do_teste_forca_first_p1_e_carrega_teste() {
        let ts = serde_json::json!({
            "my_hand": ["card_a"],
            "p0_monster": [{"card_id": "card_a"}, null, null, null, null],
            "p0_spell": [null, null, null, null, null],
            "p1_monster": [null, null, null, null, null],
            "p1_spell": [null, null, null, null, null]
        });
        let s = montar_setup_duelo("duelist_a", "deck_a", "duelist_b", "deck_b", 4000, "random", 42, "arena_starter", Some(&ts));
        assert_eq!(s["turn_order"], serde_json::json!("first_p1"));
        assert_eq!(s["test_state"], ts);
        assert_eq!(s["duel_id"], serde_json::json!("duel_studio_rapido"));
    }

    #[test]
    fn setup_sem_teste_mantem_ordem_e_sem_chave() {
        let s = montar_setup_duelo("duelist_a", "deck_a", "duelist_b", "deck_b", 4000, "random", 42, "arena_starter", None);
        assert_eq!(s["turn_order"], serde_json::json!("random"));
        assert!(s.get("test_state").is_none());
        let vazio = serde_json::json!({ "my_hand": [] });
        let s2 = montar_setup_duelo("duelist_a", "deck_a", "duelist_b", "deck_b", 4000, "random", 42, "arena_starter", Some(&vazio));
        assert_eq!(s2["turn_order"], serde_json::json!("random"));
        assert!(s2.get("test_state").is_none());
    }

    #[test]
    fn duelo_com_teste_quebrado_barra_antes_do_disco() {
        // Mão com 6 cartas + ordem first_p2 no pedido: erro estrutural (não
        // depende do catálogo em disco) e a ordem é forçada p/ first_p1, então
        // a mensagem fala da mão e NUNCA reclama de ordem.
        let p = PedidoDuelo {
            duelista1: "duelist_a".to_string(), duelista2: "duelist_b".to_string(),
            vida: 4000, seed: None, arena: "".to_string(), ordem: "first_p2".to_string(),
            test_state: Some(serde_json::json!({ "my_hand": ["card_a", "card_a", "card_a", "card_a", "card_a", "card_a"] })),
        };
        let r = jogar_duelo(p);
        assert!(r.is_err());
        let msg = r.unwrap_err();
        assert!(msg.contains("0 a 5"), "{msg}");
        assert!(!msg.contains("fase da mão"), "ordem foi forçada p/ first_p1, não pode reclamar de ordem: {msg}");
    }

    #[test]
    fn duelo_com_teste_fora_de_formato_barra() {
        let p = PedidoDuelo {
            duelista1: "duelist_a".to_string(), duelista2: "duelist_b".to_string(),
            vida: 4000, seed: None, arena: "".to_string(), ordem: "first_p2".to_string(),
            test_state: Some(serde_json::json!("lixo")),
        };
        assert!(jogar_duelo(p).is_err());
    }

    #[test]
    fn validar_test_state_vazio_passa() {
        let sonda = serde_json::json!({ "turn_order": "first_p1", "test_state": {} });
        assert!(validar_test_state(sonda).is_empty());
    }

    #[test]
    fn validar_test_state_barra_zona_curta() {
        let sonda = serde_json::json!({ "turn_order": "first_p1", "test_state": { "p0_monster": [null, null] } });
        let rev = validar_test_state(sonda);
        let erros = so_erros(&rev);
        assert_eq!(erros.len(), 1, "{erros:?}");
        assert!(erros[0].mensagem.contains("exatos 5"), "{}", erros[0].mensagem);
    }

    fn molde_minimo() -> serde_json::Value {
        serde_json::json!({ "schema_version": 1, "id": "layout_teste", "name": "Teste" })
    }

    fn peca_nome() -> serde_json::Value {
        serde_json::json!({ "id": "p_name", "kind": "name",
            "rect": { "x": 35, "y": 35, "w": 930, "h": 65 },
            "style": { "font_size": 37, "bold": true, "color": "#2a1c08", "align": "left", "z": 5 } })
    }

    #[test]
    fn molde_minimo_sem_pecas_passa() {
        assert!(checar_card_layout(&molde_minimo()).is_empty());
    }

    #[test]
    fn molde_default_oficial_passa_com_9_pecas() {
        let caminho = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../schemas/examples/layouts/card_layout_monster_default.json");
        let texto = std::fs::read_to_string(&caminho).expect("molde default oficial sumiu");
        let molde: serde_json::Value = serde_json::from_str(&texto).unwrap();
        assert!(checar_card_layout(&molde).is_empty());
        let pecas = molde["pieces"].as_array().unwrap();
        assert_eq!(pecas.len(), 9);
        let mut kinds: Vec<&str> = pecas.iter().filter_map(|p| p["kind"].as_str()).collect();
        kinds.sort_unstable();
        let mut esperados = ["name", "attribute_orb", "level_stars", "art_window", "type_line",
            "text_box", "atkdef_bar", "footer", "frame"];
        esperados.sort_unstable();
        assert_eq!(kinds, esperados);
    }

    #[test]
    fn molde_kind_fora_barra() {
        let mut m = molde_minimo();
        let mut p = peca_nome();
        p["kind"] = serde_json::json!("sombra");
        m["pieces"] = serde_json::json!([p]);
        let erros = checar_card_layout(&m);
        assert!(erros.iter().any(|e| e.campo == "Peças do molde"), "{erros:?}");
    }

    #[test]
    fn molde_rect_fora_do_canvas_barra() {
        let mut m = molde_minimo();
        let mut p = peca_nome();
        p["rect"] = serde_json::json!({ "x": 900, "y": 0, "w": 200, "h": 10 });
        m["pieces"] = serde_json::json!([p]);
        let erros = checar_card_layout(&m);
        assert!(erros.iter().any(|e| e.campo == "Posição da peça"), "{erros:?}");
    }

    #[test]
    fn molde_kind_repetido_barra() {
        let mut m = molde_minimo();
        let mut p2 = peca_nome();
        p2["id"] = serde_json::json!("p2");
        m["pieces"] = serde_json::json!([peca_nome(), p2]);
        let erros = checar_card_layout(&m);
        assert!(erros.iter().any(|e| e.mensagem.contains("repetida")), "{erros:?}");
    }

    #[test]
    fn molde_cor_e_vis_barra() {
        let mut m = molde_minimo();
        let mut p = peca_nome();
        p["style"] = serde_json::json!({ "color": "marrom" });
        m["pieces"] = serde_json::json!([p]);
        let erros = checar_card_layout(&m);
        assert!(erros.iter().any(|e| e.campo == "Visual da peça"), "{erros:?}");
        let mut m2 = molde_minimo();
        let mut p2 = peca_nome();
        p2["visible_when"] = serde_json::json!("so_efeito");
        m2["pieces"] = serde_json::json!([p2]);
        let erros2 = checar_card_layout(&m2);
        assert!(erros2.iter().any(|e| e.mensagem.contains("visible_when")), "{erros2:?}");
    }

    #[test]
    fn molde_versao_e_canvas_barra() {
        let mut m = molde_minimo();
        m["schema_version"] = serde_json::json!(2);
        m["canvas"] = serde_json::json!({ "w": 60, "h": 86, "unit": "per_mil" });
        let erros = checar_card_layout(&m);
        assert!(erros.iter().any(|e| e.campo == "Versão do molde"), "{erros:?}");
        assert!(erros.iter().any(|e| e.campo == "Tamanho do molde"), "{erros:?}");
    }

    #[test]
    fn molde_id_longo_71_recusa_64_aceita() {
        // Espelha o jogo (card_layout.gd _eh_id máx 64): 71 chars barra nos
        // dois ids (molde + peça), 64 chars passa.
        let longo71 = format!("a{}", "x".repeat(70));
        assert_eq!(longo71.chars().count(), 71);
        let mut m = molde_minimo();
        m["id"] = serde_json::json!(longo71);
        let erros = checar_card_layout(&m);
        assert!(erros.iter().any(|e| e.mensagem.contains("no máximo 64")), "{erros:?}");
        let mut m2 = molde_minimo();
        let mut p = peca_nome();
        p["id"] = serde_json::json!(format!("p{}", "y".repeat(70)));
        m2["pieces"] = serde_json::json!([p]);
        let erros2 = checar_card_layout(&m2);
        assert!(erros2.iter().any(|e| e.mensagem.contains("no máximo 64")), "{erros2:?}");
        let ok64 = format!("a{}", "x".repeat(63));
        assert_eq!(ok64.chars().count(), 64);
        let mut m3 = molde_minimo();
        m3["id"] = serde_json::json!(ok64);
        let mut p3 = peca_nome();
        p3["id"] = serde_json::json!(ok64);
        m3["pieces"] = serde_json::json!([p3]);
        assert!(checar_card_layout(&m3).is_empty(), "64 chars devia passar");
    }

    fn molde_para_teste(nome: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("astralis-studio-test-molde-{nome}"));
        let _ = std::fs::remove_dir_all(&dir);
        garantir_projeto(&dir).unwrap();
        dir
    }

    #[test]
    fn molde_ler_sem_arquivo_devolve_padrao_oficial() {
        // Projeto vazio (D29) ou legado: sem layouts/*.json o ler devolve o
        // oficial (o mesmo que o jogo usa como fallback) — a tela sempre tem
        // o que editar, sem inventar número.
        let base = molde_para_teste("ler");
        assert!(base.join("layouts").is_dir(), "esqueleto devia ter layouts/");
        let molde = ler_molde_de(&base).expect("ler sem arquivo devia devolver o padrão");
        assert_eq!(molde.get("id").and_then(|v| v.as_str()), Some("card_layout_monster_default"));
        assert!(checar_card_layout(&molde).is_empty(), "padrão oficial devia passar no gate");
        assert_eq!(molde.get("pieces").and_then(|v| v.as_array()).map(|a| a.len()), Some(9));
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn molde_salvar_valido_grava_e_ler_devolve_igual() {
        let base = molde_para_teste("salvar");
        let mut molde = molde_padrao_oficial().expect("oficial devia ler no teste");
        // Muda 1 peça (nome 10 por-mil p/ direita): o resto segue idêntico.
        molde["pieces"].as_array_mut().unwrap()[0]["rect"]["x"] = serde_json::json!(45);
        let r = salvar_molde_para(&base, &molde).expect("molde válido devia salvar");
        assert!(r.mensagem.contains("layouts/card_layout_monster_default.json"), "{}", r.mensagem);
        let de_volta = ler_molde_de(&base).expect("ler depois de salvar");
        assert_eq!(de_volta, molde, "o que volta do disco devia ser igual ao que salvou");
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn molde_salvar_invalido_nao_grava() {
        // INVÁLIDO NÃO GRAVA: o arquivo em disco continua intacto e o erro
        // diz onde clicar (mensagem de bloqueio PT-BR).
        let base = molde_para_teste("invalido");
        let oficial = molde_padrao_oficial().expect("oficial devia ler no teste");
        salvar_molde_para(&base, &oficial).unwrap();
        let mut ruim = oficial.clone();
        let mut p2 = peca_nome();
        p2["id"] = serde_json::json!("p2");
        ruim["pieces"] = serde_json::json!([peca_nome(), p2]);
        let err = salvar_molde_para(&base, &ruim).expect_err("molde inválido não podia salvar");
        assert!(err.contains("Arruma antes de salvar"), "{err}");
        let intacto = ler_molde_de(&base).unwrap();
        assert_eq!(intacto, oficial, "arquivo inválido não podia ter sobrescrito o disco");
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn molde_json_quebrado_no_ler_avisa_onde() {
        let base = molde_para_teste("quebrado");
        std::fs::write(base.join("layouts").join(MOLDE_ARQUIVO), "{quebrado").unwrap();
        let err = ler_molde_de(&base).expect_err("JSON quebrado devia falhar com onde arrumar");
        assert!(err.contains("molde da carta"), "{err}");
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn molde_boot_apaga_e_ler_volta_ao_padrao() {
        // D29 vale p/ o molde: boot com molde customizado apaga o arquivo e
        // o ler volta a devolver o oficial (sem molde velho sobrevivendo).
        let base = projeto_boot_teste("molde");
        let mut molde = molde_padrao_oficial().expect("oficial devia ler no teste");
        molde["pieces"].as_array_mut().unwrap()[0]["rect"]["x"] = serde_json::json!(45);
        salvar_molde_para(&base, &molde).unwrap();
        escrever_json_valor(&base.join("cards").join("card_x.json"), &carta_pack_valida("card_x", "X"), "base").unwrap();
        let r = preparar_boot_para(&base).unwrap();
        assert!(r.limpou, "projeto cheio devia limpar");
        assert!(!base.join("layouts").join(MOLDE_ARQUIVO).exists(), "molde customizado devia ter sido apagado");
        assert!(base.join("layouts").is_dir(), "pasta layouts/ devia continuar de pé");
        let de_volta = ler_molde_de(&base).expect("ler pós-boot");
        assert_eq!(de_volta["pieces"].as_array().unwrap()[0]["rect"]["x"], serde_json::json!(35), "pós-boot o ler devia voltar ao oficial");
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn cena_vazia_reclama_falas() {
        let erros = checar_cena(&serde_json::json!({}));
        let campos: Vec<&str> = erros.iter().map(|e| e.campo.as_str()).collect();
        for c in ["Versão", "ID", "Nome", "Falas"] {
            assert!(campos.contains(&c), "faltou erro de {c}");
        }
    }

    #[test]
    fn cena_valida_passa() {
        let c = serde_json::json!({
            "schema_version": 1, "id": "scene_teste", "name": "Teste",
            "background": "assets/backgrounds/campo.png",
            "lines": [{ "character": "Rival", "text": "Vamos duelar!" }]
        });
        assert!(checar_cena(&c).is_empty());
    }

    #[test]
    fn cena_fala_muda_barra() {
        let c = serde_json::json!({
            "schema_version": 1, "id": "scene_teste", "name": "Teste",
            "lines": [{ "character": "", "text": "" }]
        });
        let erros = checar_cena(&c);
        assert_eq!(erros.len(), 2);
    }

    #[test]
    fn listar_recusa_item_sem_id() {
        let dir = std::env::temp_dir().join("astralis-studio-test-sem-id");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("ruim.json"), "{\"name\":\"sem id\"}").unwrap();
        let r = listar_arquivos(&dir, "duelista");
        assert!(r.is_err());
        let _ = std::fs::remove_dir_all(&dir);
    }

    fn carta_fm_base() -> serde_json::Value {
        serde_json::json!({
            "schema_version": 1, "id": "card_fm", "name": "FM",
            "description": "", "artwork": "assets/fm/card_0001.png",
            "card_type": "monster", "monster_type": "fish",
            "attribute": "water", "level": 3, "attack": 800, "defense": 600,
            "guardian_star_1": "moon", "guardian_star_2": "mars",
            "password": "12345678", "starchip_cost": 50,
            "effects": [], "tags": ["fm_original"]
        })
    }

    #[test]
    fn carta_fm_completa_passa() {
        assert!(checar_carta(&carta_fm_base(), &sem_efeitos()).is_empty());
    }

    #[test]
    fn carta_tipos_fm_novos_passam() {
        for mt in ["beast-warrior", "winged-beast", "dinosaur", "reptile", "sea-serpent", "fish"] {
            let mut c = carta_fm_base();
            c["monster_type"] = serde_json::json!(mt);
            assert!(checar_carta(&c, &sem_efeitos()).is_empty(), "tipo {mt} deveria passar");
        }
        for ct in ["equip", "ritual"] {
            let c = serde_json::json!({
                "schema_version": 1, "id": "card_fm_x", "name": "X",
                "card_type": ct, "effects": [], "tags": []
            });
            assert!(checar_carta(&c, &sem_efeitos()).is_empty(), "tipo {ct} deveria passar sem status");
        }
    }

    #[test]
    fn carta_magic_barra_fm() {
        let mut c = carta_fm_base();
        c["card_type"] = serde_json::json!("magic");
        let erros = checar_carta(&c, &sem_efeitos());
        assert!(erros.iter().any(|e| e.campo == "Tipo"));
    }

    #[test]
    fn carta_fm_opcionais_invalidos_barram() {
        let mut c = carta_fm_base();
        c["password"] = serde_json::json!("123");
        assert!(checar_carta(&c, &sem_efeitos()).iter().any(|e| e.campo == "Senha"));
        let mut c = carta_fm_base();
        c["guardian_star_1"] = serde_json::json!("terra");
        assert!(checar_carta(&c, &sem_efeitos()).iter().any(|e| e.campo == "Estrela guardiã"));
        let mut c = carta_fm_base();
        c["starchip_cost"] = serde_json::json!(-5);
        assert!(checar_carta(&c, &sem_efeitos()).iter().any(|e| e.campo == "Starchips"));
        // Ausentes = N/A: continuam válidas.
        let mut c = carta_fm_base();
        for k in ["guardian_star_1", "guardian_star_2", "password", "starchip_cost"] {
            c.as_object_mut().unwrap().remove(k);
        }
        assert!(checar_carta(&c, &sem_efeitos()).is_empty());
    }

    fn pasta_teste_import(nome: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("astralis-studio-test-{nome}"));
        let _ = std::fs::remove_dir_all(&dir);
        for sub in ["cards", "duelists", "decks"] {
            std::fs::create_dir_all(dir.join(sub)).unwrap();
        }
        dir
    }

    fn carta_pack_valida(id: &str, nome: &str) -> serde_json::Value {
        serde_json::json!({
            "schema_version": 1, "id": id, "name": nome,
            "card_type": "monster", "monster_type": "warrior", "attribute": "earth",
            "level": 4, "attack": 1500, "defense": 1200, "effects": [], "tags": []
        })
    }

    fn duelista_pack_valido(id: &str, deck: &str) -> serde_json::Value {
        serde_json::json!({
            "schema_version": 1, "id": id, "name": "Duelista Pack",
            "deck_id": deck,
            "ai_preset": {"dificuldade": "facil", "agressividade": 30, "uso_fusao": 20, "protecao_lp": 60}
        })
    }

    fn pack_teste() -> serde_json::Value {
        // Pack 100% válido: refs apontam SÓ para dentro do pack (o conteúdo
        // atual é substituído, então nada de fora vale).
        let mut cartas_deck: Vec<serde_json::Value> = Vec::new();
        for _ in 0..10 {
            cartas_deck.push(serde_json::json!("card_pack_nova"));
        }
        for _ in 0..10 {
            cartas_deck.push(serde_json::json!("card_pack_outra"));
        }
        serde_json::json!({
            "schema_version": 1, "pack_id": "pack_teste", "name": "Pack Teste",
            "cartas": [
                carta_pack_valida("card_pack_nova", "Nova"),
                carta_pack_valida("card_pack_outra", "Outra")
            ],
            "duelistas": [duelista_pack_valido("duelist_pack", "deck_pack")],
            "decks": [
                {"schema_version": 1, "id": "deck_pack", "name": "Deck Pack", "cards": cartas_deck}
            ],
            "fusoes": {
                "schema_version": 1,
                "recipes": [
                    {"id": "fusion_pack_nova",
                     "input": {"card_a": "card_pack_nova", "card_b": "card_pack_outra"},
                     "result": "card_pack_nova"},
                    {"id": "fusion_par_repetido",
                     "input": {"card_a": "card_pack_outra", "card_b": "card_pack_nova"},
                     "result": "card_pack_nova"}
                ],
                "rules": []
            },
            "equips": [
                {"equip": "card_pack_nova", "monster": "card_pack_outra"}
            ]
        })
    }

    #[test]
    fn importar_pack_substitui_com_backup() {
        let dir = pasta_teste_import("substituir");
        // Conteúdo atual: um extra fora do pack + um com mesmo id e texto velho.
        escrever_json_valor(&dir.join("cards").join("card_velha.json"), &carta_pack_valida("card_velha", "Velha"), "base").unwrap();
        let mut nova_velha = carta_pack_valida("card_pack_nova", "Nova");
        nova_velha["name"] = serde_json::json!("Nome Antigo");
        escrever_json_valor(&dir.join("cards").join("card_pack_nova.json"), &nova_velha, "base").unwrap();
        escrever_json_valor(&dir.join("duelists").join("duelist_velho.json"), &duelista_pack_valido("duelist_velho", "deck_velho"), "base").unwrap();
        let velhas: Vec<serde_json::Value> = (0..20).map(|_| serde_json::json!("card_velha")).collect();
        escrever_json_valor(&dir.join("decks").join("deck_velho.json"), &serde_json::json!({"schema_version": 1, "id": "deck_velho", "name": "Velho", "cards": velhas}), "base").unwrap();
        let caminho_fusoes = dir.join("fusions.json");
        escrever_json_valor(&caminho_fusoes, &serde_json::json!({
            "schema_version": 1,
            "recipes": [{"id": "fusion_base",
                "input": {"card_a": "card_velha", "card_b": "card_pack_nova"},
                "result": "card_velha"}],
            "rules": []
        }), "fusoes").unwrap();

        let pack = pack_teste();
        let r = importar_pack_para(
            &pack,
            &dir.join("cards"),
            &dir.join("duelists"),
            &dir.join("decks"),
            &caminho_fusoes,
            &sem_efeitos(),
        )
        .unwrap();
        assert_eq!(r.cartas, 2);
        assert_eq!(r.duelistas, 1);
        assert_eq!(r.decks, 1);
        assert_eq!(r.fusoes_novas, 1);
        assert_eq!(r.fusoes_puladas, 1);
        // A única fusão pulada é o MESMO par de novo (não é A+A): a mensagem
        // tem que falar de repetida e não inventar "repetido do próprio pack"
        // para o A+A (que é o que o texto antigo fazia).
        assert_eq!(r.fusoes_mesma, 0);
        assert!(r.mensagem.contains("repetida dentro do próprio pack"), "{}", r.mensagem);
        assert!(!r.mensagem.contains("repetido(s) do próprio pack"), "texto antigo voltou: {}", r.mensagem);
        assert!(!r.mensagem.contains("nunca disparam"), "não tem A+A neste pack: {}", r.mensagem);
        assert_eq!(r.equips_ignorados, 1);
        assert_eq!(r.backups.len(), 1);
        assert!(r.mensagem.contains("backup em"));
        assert!(r.mensagem.contains("substituído"));
        // Substituiu em vez de somar: extra sumiu, id repetido foi trocado,
        // fusões trocadas inteiras (sem merge com a base).
        assert!(!dir.join("cards").join("card_velha.json").exists());
        let nova: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(dir.join("cards").join("card_pack_nova.json")).unwrap()).unwrap();
        assert_eq!(nova.get("name").and_then(|v| v.as_str()), Some("Nova"));
        assert!(dir.join("cards").join("card_pack_outra.json").is_file());
        assert!(!dir.join("duelists").join("duelist_velho.json").exists());
        assert!(dir.join("duelists").join("duelist_pack.json").is_file());
        assert!(!dir.join("decks").join("deck_velho.json").exists());
        assert!(dir.join("decks").join("deck_pack.json").is_file());
        let final_f: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&caminho_fusoes).unwrap()).unwrap();
        let recipes = final_f.get("recipes").and_then(|v| v.as_array()).unwrap();
        assert_eq!(recipes.len(), 1);
        assert_eq!(recipes[0].get("id").and_then(|v| v.as_str()), Some("fusion_pack_nova"));
        // Backup com data/hora guarda o conteúdo antigo.
        let backup = dir.join(&r.backups[0]);
        assert!(backup.join("cards").join("card_velha.json").is_file());
        assert!(backup.join("duelists").join("duelist_velho.json").is_file());
        assert!(backup.join("decks").join("deck_velho.json").is_file());
        assert!(backup.join("fusions.json").is_file());
        let _ = std::fs::remove_dir_all(&dir);
    }

    // A+A (mesma carta nos dois lados) NÃO é repetição: é dado que nunca
    // dispara no jogo. A mensagem antiga somava as duas coisas e dizia
    // "N repetido(s) do próprio pack pulado(s)" — o usuário ia procurar no
    // pack uma repetição que não existia (no pack FM: 0 repetidas, 50 A+A).
    #[test]
    fn importar_pack_separa_a_mais_a_de_repetida() {
        let dir = pasta_teste_import("a-mais-a");
        let caminho_fusoes = dir.join("fusions.json");
        escrever_json_valor(&caminho_fusoes, &serde_json::json!({"schema_version": 1, "recipes": [], "rules": []}), "fusoes").unwrap();

        let mut pack = pack_teste();
        pack["fusoes"]["recipes"].as_array_mut().unwrap().push(serde_json::json!({
            "id": "fusion_aa",
            "input": {"card_a": "card_pack_nova", "card_b": "card_pack_nova"},
            "result": "card_pack_nova"
        }));
        let r = importar_pack_para(
            &pack,
            &dir.join("cards"),
            &dir.join("duelists"),
            &dir.join("decks"),
            &caminho_fusoes,
            &sem_efeitos(),
        )
        .unwrap();
        // 1 repetida (mesmo par) + 1 A+A = 2 puladas, contadas à parte.
        assert_eq!(r.fusoes_novas, 1);
        assert_eq!(r.fusoes_puladas, 2);
        assert_eq!(r.fusoes_mesma, 1);
        assert!(r.mensagem.contains("1 fusão com a mesma carta nos dois lados foi ignorada"), "{}", r.mensagem);
        assert!(r.mensagem.contains("nunca dispara no jogo"), "{}", r.mensagem);
        assert!(r.mensagem.contains("1 fusão repetida dentro do próprio pack foi pulada"), "{}", r.mensagem);
        assert!(!r.mensagem.contains("repetido(s) do próprio pack"), "texto antigo voltou: {}", r.mensagem);
        // O resumo (A+A) é a PRIMEIRA linha dos avisos, e é aviso de novo.
        assert!(r.avisos[0].contains("nunca dispara no jogo"), "{:?}", r.avisos);
        assert!(r.avisos[1].contains("repetida dentro do próprio pack"), "{:?}", r.avisos);
        let _ = std::fs::remove_dir_all(&dir);
    }

    // Aviso é uma linha inteira na tela e existe um por carta: pack grande
    // (o FM são 722 cartas) gerava centenas. Teto de 30 + linha "…e mais N",
    // igual ao teto de erros.
    #[test]
    fn importar_pack_corta_aviso_no_teto() {
        let dir = pasta_teste_import("teto-aviso");
        let caminho_fusoes = dir.join("fusions.json");
        escrever_json_valor(&caminho_fusoes, &serde_json::json!({"schema_version": 1, "recipes": [], "rules": []}), "fusoes").unwrap();

        // 40 cartas, cada uma citando 1 efeito que o projeto não tem
        // (projeto vazio = aviso, não erro — o pack entra inteiro).
        let mut cartas: Vec<serde_json::Value> = Vec::new();
        for i in 0..40 {
            let mut c = carta_pack_valida(&format!("card_aviso_{i}"), "Aviso");
            c["effects"] = serde_json::json!(["fx_que_nao_existe"]);
            cartas.push(c);
        }
        let pack = serde_json::json!({"schema_version": 1, "cartas": cartas});
        let r = importar_pack_para(
            &pack,
            &dir.join("cards"),
            &dir.join("duelists"),
            &dir.join("decks"),
            &caminho_fusoes,
            &sem_efeitos(),
        )
        .unwrap();
        assert_eq!(r.cartas, 40, "aviso não pode barrar o import");
        assert_eq!(r.avisos.len(), 31, "30 avisos + a linha do que sobrou: {:?}", r.avisos);
        assert!(!r.avisos[0].contains("mais"), "a linha do excesso tem que vir por último");
        let ultima = r.avisos.last().unwrap();
        assert!(ultima.contains("…e mais 10 aviso(s)"), "{ultima}");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn importar_pack_invalido_nao_mexe_em_nada() {
        let dir = pasta_teste_import("invalido");
        let base = carta_pack_valida("card_base", "Base");
        escrever_json_valor(&dir.join("cards").join("card_base.json"), &base, "base").unwrap();
        let caminho_fusoes = dir.join("fusions.json");
        escrever_json_valor(&caminho_fusoes, &serde_json::json!({"schema_version": 1, "recipes": [], "rules": []}), "fusoes").unwrap();

        let mut pack = pack_teste();
        pack["cartas"][0]["password"] = serde_json::json!("123");
        let antes = std::fs::read_to_string(dir.join("cards").join("card_base.json")).unwrap();
        let r = importar_pack_para(
            &pack,
            &dir.join("cards"),
            &dir.join("duelists"),
            &dir.join("decks"),
            &caminho_fusoes,
            &sem_efeitos(),
        );
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("não mexi em nada"));
        // Nada mudou e nenhum backup foi criado.
        assert_eq!(std::fs::read_to_string(dir.join("cards").join("card_base.json")).unwrap(), antes);
        assert!(!dir.join("cards").join("card_pack_nova.json").exists());
        assert!(!dir.join("backups").exists());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn projeto_mora_em_projects_default() {
        let p = pasta_projeto().unwrap();
        assert!(p.ends_with("projects/default"), "projeto fora do lugar: {}", p.display());
        for sub in ["cards", "duelists", "decks", "arenas"] {
            assert!(p.join(sub).is_dir(), "faltou projects/default/{sub}");
        }
    }

    #[test]
    fn args_jogo_levam_project() {
        assert_eq!(montar_args_jogo("P", None), vec!["--project".to_string(), "P".to_string()]);
        assert_eq!(
            montar_args_jogo("P", Some("S")),
            vec!["--project".to_string(), "P".to_string(), "--setup".to_string(), "S".to_string()]
        );
    }

    #[test]
    fn fusoes_vazias_passam() {
        let dado = serde_json::json!({"schema_version": 1, "recipes": [], "rules": []});
        assert!(checar_fusoes(&dado, &catalogo(&[])).is_empty());
    }

    #[test]
    fn importar_pack_ref_de_fora_barra_tudo() {
        // Deck do pack citando carta que só existe no projeto: como o IMPORTAR
        // substitui, essa ref quebraria — então o pack inteiro é recusado.
        let dir = pasta_teste_import("ref-fora");
        escrever_json_valor(&dir.join("cards").join("card_base.json"), &carta_pack_valida("card_base", "Base"), "base").unwrap();
        let mut pack = pack_teste();
        pack["decks"][0]["cards"][0] = serde_json::json!("card_base");
        let r = importar_pack_para(
            &pack,
            &dir.join("cards"),
            &dir.join("duelists"),
            &dir.join("decks"),
            &dir.join("fusions.json"),
            &sem_efeitos(),
        );
        assert!(r.is_err());
        assert!(!dir.join("cards").join("card_pack_nova.json").exists());
        assert!(!dir.join("backups").exists());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn boot_vazio_ler_nao_cria_nada() {
        // Projeto VAZIO (igual ao commitado vazio): ler não escreve.
        // Trava R1/R4 no boot: listar_cartas/duelistas/decks voltam vazios e o
        // disco continua vazio — nenhum fm_*.json, nenhum pack_* criado.
        // Só importar_pack (file picker) e salvar_* escrevem; todo o resto
        // (listar_*, ler_*, validar_*, testar_fusao, jogar_duelo no projeto)
        // é só leitura (+ garantir_projeto só cria o esqueleto vazio).
        // Usa pasta temporária (nunca encosta em projects/default/).
        let base = std::env::temp_dir().join("astralis-studio-test-boot-vazio");
        let _ = std::fs::remove_dir_all(&base);
        garantir_projeto(&base).unwrap();
        let conta_json = |p: &std::path::Path| -> usize {
            std::fs::read_dir(p)
                .map(|e| {
                    e.flatten()
                        .filter(|x| x.path().extension().and_then(|x| x.to_str()) == Some("json"))
                        .count()
                })
                .unwrap_or(0)
        };
        let tem_fm = |p: &std::path::Path| -> bool {
            std::fs::read_dir(p)
                .map(|e| {
                    e.flatten().any(|x| {
                        x.file_name().to_str().map(|n| n.starts_with("fm_")).unwrap_or(false)
                    })
                })
                .unwrap_or(false)
        };
        // Antes: esqueleto vazio (0 itens, 0 fm_*, fusions/effects vazios).
        assert_eq!(conta_json(&base.join("cards")), 0);
        assert_eq!(conta_json(&base.join("duelists")), 0);
        assert_eq!(conta_json(&base.join("decks")), 0);
        // Leitura pelos mesmos helpers dos comandos (só leitura, sem escrever).
        let cartas = listar_arquivos(&base.join("cards"), "carta").unwrap();
        let duelistas = listar_arquivos(&base.join("duelists"), "duelista").unwrap();
        let decks = listar_arquivos(&base.join("decks"), "deck").unwrap();
        assert!(cartas.is_empty(), "projeto vazio: cartas deviam voltar vazias");
        assert!(duelistas.is_empty(), "projeto vazio: duelistas deviam voltar vazios");
        assert!(decks.is_empty(), "projeto vazio: decks deviam voltar vazios");
        // Depois: disco continua vazio — a leitura não criou nada.
        assert_eq!(conta_json(&base.join("cards")), 0);
        assert_eq!(conta_json(&base.join("duelists")), 0);
        assert_eq!(conta_json(&base.join("decks")), 0);
        assert!(!tem_fm(&base.join("cards")));
        assert!(!tem_fm(&base.join("duelists")));
        assert!(!tem_fm(&base.join("decks")));
        // Nenhum backup pack_* nasceu sozinho (só o Importar cria).
        let tem_pack = std::fs::read_dir(base.join("backups"))
            .map(|e| {
                e.flatten().any(|x| {
                    x.file_name().to_str().map(|n| n.starts_with("pack_")).unwrap_or(false)
                })
            })
            .unwrap_or(false);
        assert!(!tem_pack, "leitura não devia criar backup pack_*");
        // fusions/effects seguem vazios válidos (esqueleto, não conteúdo).
        let f: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(base.join("fusions.json")).unwrap(),
        )
        .unwrap();
        assert_eq!(f.get("recipes").and_then(|v| v.as_array()).map(|a| a.len()), Some(0));
        let _ = std::fs::remove_dir_all(&base);
    }

    fn projeto_boot_teste(nome: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("astralis-studio-test-boot-{nome}"));
        let _ = std::fs::remove_dir_all(&dir);
        garantir_projeto(&dir).unwrap();
        dir
    }

    #[test]
    fn boot_cheio_apaga_tudo_sem_backup_e_vazio_nao_muda() {
        // Projeto cheio (carta + duelista + deck + arena + cena + fusão com
        // receita + efeito + backup órfão antigo): preparar_boot APAGA tudo,
        // sem backup, e recria o esqueleto vazio. Segunda chamada (já vazio)
        // = não faz nada.
        let base = projeto_boot_teste("cheio");
        escrever_json_valor(&base.join("cards").join("card_x.json"), &carta_pack_valida("card_x", "X"), "base").unwrap();
        escrever_json_valor(&base.join("duelists").join("duelist_x.json"), &duelista_pack_valido("duelist_x", "deck_x"), "base").unwrap();
        let velhas: Vec<serde_json::Value> = (0..20).map(|_| serde_json::json!("card_x")).collect();
        escrever_json_valor(&base.join("decks").join("deck_x.json"), &serde_json::json!({"schema_version": 1, "id": "deck_x", "name": "X", "cards": velhas}), "base").unwrap();
        escrever_json_valor(&base.join("arenas").join("arena_x.json"), &serde_json::json!({"schema_version": 1, "id": "arena_x", "name": "X"}), "base").unwrap();
        escrever_json_valor(&base.join("scenes").join("scene_x.json"), &serde_json::json!({"schema_version": 1, "id": "scene_x", "name": "X", "lines": [{"character": "A", "text": "Oi"}]}), "base").unwrap();
        escrever_json_valor(&base.join("fusions.json"), &serde_json::json!({"schema_version": 1, "recipes": [{"id": "fusion_x", "input": {"card_a": "card_x", "card_b": "card_y"}, "result": "card_x"}], "rules": []}), "base").unwrap();
        let mut ef = efeito_base();
        ef["id"] = serde_json::json!("effect_x");
        escrever_json_valor(&base.join("effects.json"), &serde_json::json!({"schema_version": 1, "effects": [ef]}), "base").unwrap();
        // Backup órfão antigo (de versão anterior): também é apagado, nada guardado.
        std::fs::create_dir_all(base.join("backups").join("sessao_antiga")).unwrap();
        std::fs::write(base.join("backups").join("sessao_antiga").join("card_x.json"), "{}").unwrap();

        let r = preparar_boot_para(&base).unwrap();
        assert!(r.limpou, "projeto cheio devia limpar");
        assert!(r.mensagem.contains("zerado"), "mensagem devia dizer que zerou: {}", r.mensagem);
        assert!(r.mensagem.contains("sem backup"), "mensagem devia dizer sem backup: {}", r.mensagem);
        // Esqueleto vazio recriado (pastas sem json + fusions/effects válidos).
        for sub in ["cards", "duelists", "decks", "arenas", "scenes"] {
            assert!(!pasta_tem_json(&base.join(sub)), "{sub} devia voltar vazio");
        }
        let f: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(base.join("fusions.json")).unwrap()).unwrap();
        assert_eq!(f.get("recipes").and_then(|v| v.as_array()).map(|a| a.len()), Some(0));
        assert_eq!(f.get("rules").and_then(|v| v.as_array()).map(|a| a.len()), Some(0));
        let e: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(base.join("effects.json")).unwrap()).unwrap();
        assert_eq!(e.get("effects").and_then(|v| v.as_array()).map(|a| a.len()), Some(0));
        // SEM backup: nada guardado, nenhuma pasta sessao_* de pé.
        assert!(!base.join("backups").exists(), "boot não devia deixar backups/ de pé");
        assert!(!base.join("cards").join("card_x.json").exists(), "carta devia ter sido apagada, não guardada");

        // Segunda chamada: projeto já vazio = não faz nada.
        let r2 = preparar_boot_para(&base).unwrap();
        assert!(!r2.limpou, "projeto vazio não devia limpar");
        assert!(!base.join("backups").exists(), "projeto vazio não devia criar backups/");
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn boot_vazio_nao_cria_backup() {
        let base = projeto_boot_teste("vazio2");
        let r = preparar_boot_para(&base).unwrap();
        assert!(!r.limpou);
        assert!(!base.join("backups").exists(), "boot vazio não devia criar backups/");
        // Esqueleto válido segue de pé.
        let f: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(base.join("fusions.json")).unwrap()).unwrap();
        assert_eq!(f.get("recipes").and_then(|v| v.as_array()).map(|a| a.len()), Some(0));
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn boot_uma_vez_segunda_chamada_mesmo_processo_nao_apaga() {
        // Reload no dev (HMR/F5: mesmo processo Tauri vivo, onMount do
        // +page.svelte chama preparar_boot de novo) NÃO pode apagar o que foi
        // importado. 1ª chamada zera (D29); 2ª com conteúdo mantém tudo.
        let base = projeto_boot_teste("uma-vez");
        escrever_json_valor(&base.join("cards").join("card_x.json"), &carta_pack_valida("card_x", "X"), "base").unwrap();
        let flag = AtomicBool::new(false);
        let r1 = preparar_boot_uma_vez(&base, &flag).unwrap();
        assert!(r1.limpou, "1ª chamada do processo devia zerar (D29)");
        // Simula o import: conteúdo entra DEPOIS do boot.
        escrever_json_valor(&base.join("cards").join("card_y.json"), &carta_pack_valida("card_y", "Y"), "base").unwrap();
        // Simula o reload: mesma flag (mesmo processo) chama de novo.
        let r2 = preparar_boot_uma_vez(&base, &flag).unwrap();
        assert!(!r2.limpou, "reload no mesmo processo não devia limpar");
        assert!(r2.mensagem.contains("mantido"), "mensagem devia dizer que manteve: {}", r2.mensagem);
        assert!(base.join("cards").join("card_y.json").is_file(), "reload apagou o importado!");
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn boot_uma_vez_processo_novo_zera_de_novo() {
        // Fechar e abrir = processo novo = flag fresca = D29 zera de novo.
        let base = projeto_boot_teste("processo-novo");
        escrever_json_valor(&base.join("cards").join("card_x.json"), &carta_pack_valida("card_x", "X"), "base").unwrap();
        let r = preparar_boot_uma_vez(&base, &AtomicBool::new(false)).unwrap();
        assert!(r.limpou, "processo novo devia zerar (D29)");
        assert!(!base.join("cards").join("card_x.json").exists());
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn boot_devolve_os_gitkeep_do_esqueleto() {
        // Bug do "abrir o app suja o git": o boot (D29) apaga o conteúdo E o
        // .gitkeep das pastas de arte (`apagar_tudo_da_pasta` não faz ideia do
        // que é marcador), e o esqueleto voltava só com as pastas. Pasta sem
        // .gitkeep some do git, então todo `git status` mostrava os .gitkeep
        // como DELETADOS só de abrir o Studio.
        //
        // A lista abaixo é a que `git ls-files astralis-studio/projects/default/`
        // devolve — de propósito NÃO é a constante PASTAS_ESQUELETO: se alguém
        // tirar uma pasta de lá, este teste quebra. É o contrato com o repo.
        let com_gitkeep = [
            "arenas", "assets/backgrounds", "assets/cards", "assets/portraits",
            "cards", "decks", "duelists", "scenes",
        ];
        let base = projeto_boot_teste("gitkeep");
        // Conteúdo de verdade, para o boot ter o que apagar (D29).
        escrever_json_valor(&base.join("cards").join("card_x.json"), &carta_pack_valida("card_x", "X"), "base").unwrap();
        std::fs::write(base.join("assets").join("cards").join("arte_x.png"), b"png").unwrap();
        // O esqueleto já nasce rastreável.
        for sub in com_gitkeep {
            assert!(base.join(sub).join(".gitkeep").is_file(), "{sub} devia nascer com .gitkeep");
        }
        // Cenário do bug: o boot come o .gitkeep de assets/cards, e alguém mexeu
        // no de cards/ na mão. Depois do boot TODOS têm que estar de volta.
        std::fs::remove_file(base.join("assets").join("cards").join(".gitkeep")).unwrap();
        std::fs::remove_file(base.join("cards").join(".gitkeep")).unwrap();

        let r = preparar_boot_para(&base).unwrap();
        assert!(r.limpou, "projeto cheio devia limpar");
        for sub in com_gitkeep {
            let marca = base.join(sub).join(".gitkeep");
            assert!(base.join(sub).is_dir(), "{sub} devia existir depois do boot");
            assert!(marca.is_file(), "{sub}/.gitkeep devia VOLTAR depois do boot (senão a pasta some do git)");
            assert_eq!(marca.metadata().unwrap().len(), 0, "{sub}/.gitkeep devia ser o marcador vazio");
        }
        // D29 intacto: o conteúdo foi mesmo, e nada ficou guardado.
        assert!(!base.join("cards").join("card_x.json").exists(), "a carta devia ter sido apagada");
        assert!(!base.join("assets").join("cards").join("arte_x.png").exists(), "a arte devia ter sido apagada");
        assert!(!base.join("backups").exists(), "boot não devia deixar backups/ de pé");
        // Regra da creación: .gitkeep que JÁ existe não é sobrescrito.
        std::fs::write(base.join("decks").join(".gitkeep"), b"intacto").unwrap();
        garantir_projeto(&base).unwrap();
        assert_eq!(std::fs::read(base.join("decks").join(".gitkeep")).unwrap(), b"intacto");
        let _ = std::fs::remove_dir_all(&base);
    }

    // ---- Duelo rápido: --setup temporário com nome único + limpeza ----

    #[test]
    fn setup_temporario_tem_nome_unico_por_chamada() {
        // Duas chamadas seguidas = dois arquivos diferentes (o nome fixo
        // duel_studio_rapido.json fazia o 2º sobrescrever o setup do 1º
        // antes do Godot ler).
        let a = novo_setup_temporario(1_000);
        let b = novo_setup_temporario(1_000);
        assert_ne!(a, b, "duas chamadas não podem gerar o mesmo arquivo");
        let c = novo_setup_temporario(1_001);
        assert_ne!(b, c);
        for p in [&a, &b, &c] {
            let nome = p.file_name().unwrap().to_string_lossy().to_string();
            assert!(nome.starts_with(PREFIXO_SETUP), "prefixo: {nome}");
            assert!(nome.ends_with(".json"), "extensão: {nome}");
        }
    }

    #[test]
    fn setup_temporario_apaga_so_o_que_esta_velho() {
        // Limpeza: a varredura do próximo duelo apaga o setup ancient e
        // preserva o recente (o jogo em curso ainda pode estar lendo).
        let agora = 10_000_000u64;
        let velho = std::env::temp_dir().join(format!("{PREFIXO_SETUP}99999_{}_0.json", agora - 7200));
        let recente = std::env::temp_dir().join(format!("{PREFIXO_SETUP}99999_{}_0.json", agora - 10));
        let meu_setup = novo_setup_temporario(agora);
        std::fs::write(&velho, "{}").unwrap();
        std::fs::write(&recente, "{}").unwrap();
        std::fs::write(&meu_setup, "{}").unwrap();

        assert_eq!(idade_setup(&velho, agora), Some(7200));
        assert_eq!(idade_setup(&recente, agora), Some(10));
        // Arquivo que não é nosso (ou nome sem tempo) nunca é tocado.
        let outro = std::env::temp_dir().join("duel_studio_rapido.json");
        assert!(idade_setup(&outro, agora).is_none());
        let sem_seg = std::env::temp_dir().join(format!("{PREFIXO_SETUP}sem_tempo.json"));
        assert!(idade_setup(&sem_seg, agora).is_none());

        let apagados = limpar_setups_antigos(agora, SETUP_MAX_IDADE_SEGS);
        assert!(!velho.exists(), "setup de 2h tem que ser apagado");
        assert!(recente.exists(), "setup de 10s tem que continuar (duelo em curso)");
        assert!(meu_setup.exists(), "o setup que acabou de nascer nunca é apagado");
        assert_eq!(apagados, 1, "só o velho devia entrar na conta");
        // Limpeza do teste (nada de lixo no temp — R8).
        let _ = std::fs::remove_file(&recente);
        let _ = std::fs::remove_file(&meu_setup);
    }

    // ---- Achar o Godot (o nome do exe estava repetido 4x, sem fallback) ----

    #[test]
    fn achar_godot_usa_o_exe_oficial_e_depois_o_mais_novo() {
        let base = projeto_boot_teste("godot");
        let dir_godot = base.join("Godot");
        std::fs::create_dir_all(&dir_godot).unwrap();
        // 1) nome oficial (D14) ganha mesmo com outras versões na pasta.
        for nome in ["Godot_v4.4.0-stable_win64.exe", "Godot_v4.7.2-stable_win64.exe"] {
            std::fs::write(dir_godot.join(nome), "x").unwrap();
        }
        assert!(achar_godot(&base).unwrap().ends_with("Godot_v4.7.2-stable_win64.exe"));
        // 2) sem o oficial: qualquer Godot_v*_win64*.exe, versão mais nova 1º.
        std::fs::remove_file(dir_godot.join("Godot_v4.7.2-stable_win64.exe")).unwrap();
        assert!(achar_godot(&base).unwrap().ends_with("Godot_v4.4.0-stable_win64.exe"));
        std::fs::write(dir_godot.join("Godot_v4.10.1-stable_win64.exe"), "x").unwrap();
        assert!(achar_godot(&base).unwrap().ends_with("Godot_v4.10.1-stable_win64.exe"));
        // 3) sem nenhum exe (e nem linux/mac valem): erro em PT-BR dizendo
        //    onde procurar e como resolver.
        for nome in ["Godot_v4.4.0-stable_win64.exe", "Godot_v4.10.1-stable_win64.exe"] {
            std::fs::remove_file(dir_godot.join(nome)).unwrap();
        }
        let r = achar_godot(&base).unwrap_err();
        assert!(r.contains("Não achei o Godot"), "{r}");
        assert!(r.contains("GODOT_PATH"), "{r}");
        assert!(r.contains("Godot"), "{r}");
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn versao_godot_ordena() {
        assert_eq!(versao_godot("Godot_v4.7.2-stable_win64.exe"), (4, 7, 2));
        assert_eq!(versao_godot("Godot_v4.10.1-stable_win64.exe"), (4, 10, 1));
        assert_eq!(versao_godot("Godot_v3.5-stable_win64.exe"), (3, 5, 0));
        assert_eq!(versao_godot("outro.exe"), (0, 0, 0));
        assert!(versao_godot("Godot_v4.10.1-stable_win64.exe") > versao_godot("Godot_v4.7.2-stable_win64.exe"));
    }

    // ---- Diagnóstico de IPC (o comando que faltava) ----

    #[test]
    fn diagnostico_ipc_guarda_lote_e_respeita_o_teto() {
        let estado = DiagnosticoIpc::default();
        let lote: Vec<EventoIpc> = (0..3)
            .map(|i| EventoIpc {
                origin: "ui".to_string(),
                level: "info".to_string(),
                area: "ipc".to_string(),
                msg: format!("listar_cartas ok {i}ms"),
            })
            .collect();
        assert_eq!(registrar_diagnostico(&estado, 100, &lote), 3);
        assert_eq!(registrar_diagnostico(&estado, 101, &[]), 3, "lote vazio não muda nada");
        let guardado = ler_diagnostico(&estado);
        assert_eq!(guardado.len(), 3);
        assert!(guardado[0].contains("listar_cartas ok 0ms"), "linha: {}", guardado[0]);
        assert!(guardado[0].contains("[info]"), "nível tem que aparecer: {}", guardado[0]);

        // Estourando o teto: fica com as ÚLTIMAS 500 (o buffer não cresce).
        let cheio: Vec<EventoIpc> = (0..600)
            .map(|i| EventoIpc {
                origin: "ui".to_string(),
                level: "info".to_string(),
                area: "ipc".to_string(),
                msg: format!("evento {i}"),
            })
            .collect();
        assert_eq!(registrar_diagnostico(&estado, 102, &cheio), DIAG_MAX_LINHAS);
        let guardado = ler_diagnostico(&estado);
        assert_eq!(guardado.len(), DIAG_MAX_LINHAS);
        // Sobrou a cauda: as 3 do primeiro lote caíram fora e o começo do lote
        // de 600 também (o que é velho some, o que é novo fica).
        assert_eq!(guardado[0].contains("evento 100"), true, "primeira linha guardada: {}", guardado[0]);
        assert!(guardado[DIAG_MAX_LINHAS - 1].contains("evento 599"), "última linha guardada: {}", guardado[DIAG_MAX_LINHAS - 1]);
    }
}
