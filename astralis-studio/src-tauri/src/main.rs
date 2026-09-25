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

#[derive(Debug, Serialize, Deserialize, Clone)]
struct CartaArquivo {
    file: String,
    data: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct ErroValidacao {
    campo: String,
    #[serde(rename = "campoId")]
    campo_id: String,
    mensagem: String,
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
    }
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
// importar aparece). Cria a estrutura se faltar (pastas + fusions/effects
// vazios válidos). Todo comando de dado lê/escreve AQUI, nunca no jogo.
fn pasta_projeto() -> Result<PathBuf, String> {
    let studio = raiz_studio().ok_or_else(|| "Não achei a pasta astralis-studio/ a partir daqui. Rode o app de dentro do projeto Astralis.".to_string())?;
    let proj = studio.join("projects").join("default");
    garantir_projeto(&proj)?;
    Ok(proj)
}

fn garantir_projeto(proj: &std::path::Path) -> Result<(), String> {
    for sub in [
        "cards", "duelists", "decks", "arenas", "scenes",
        "assets/cards", "assets/portraits", "assets/backgrounds",
    ] {
        std::fs::create_dir_all(proj.join(sub))
            .map_err(|e| format!("Não consegui criar projects/default/{sub}: {e}"))?;
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

// IDs de efeito que o Astralis sabe executar (R4): lidos de
// projects/default/effects.json. Se o arquivo faltar, volta vazio e a
// checagem de "efeito desconhecido" é pulada (sem travar o resto).
fn efeitos_conhecidos() -> Vec<String> {
    let caminho = match pasta_projeto() {
        Ok(p) => p.join("effects.json"),
        Err(_) => return Vec::new(),
    };
    let texto = match std::fs::read_to_string(&caminho) {
        Ok(t) => t,
        Err(_) => return Vec::new(),
    };
    let v: serde_json::Value = match serde_json::from_str(&texto) {
        Ok(v) => v,
        Err(_) => return Vec::new(),
    };
    match v.get("effects") {
        Some(serde_json::Value::Array(lista)) => lista
            .iter()
            .filter_map(|e| e.get("id")?.as_str().map(|s| s.to_string()))
            .collect(),
        _ => Vec::new(),
    }
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

// Lança o Astralis de verdade com um setup rápido externo (--setup <temp>)
// POR CIMA do projeto do editor (--project <projects/default>).
// O jogo já aceita os dois. Nunca toca no duel_setup do jogo (starter intacto).
fn lancar_astralis_com_setup(setup: &std::path::Path) -> Result<String, String> {
    let raiz = raiz_projeto().ok_or_else(|| "Não achei a raiz do projeto para lançar o jogo.".to_string())?;
    let godot = raiz.join("Godot").join("Godot_v4.7.2-stable_win64.exe");
    if !godot.is_file() {
        return Err("Não achei o Godot em Godot/Godot_v4.7.2-stable_win64.exe.".to_string());
    }
    let projeto = raiz.join("astralis");
    if !projeto.is_dir() {
        return Err("Não achei a pasta astralis/ do jogo.".to_string());
    }
    let pasta_ed = pasta_projeto()?;
    let extra = montar_args_jogo(&pasta_ed.to_string_lossy(), Some(&setup.to_string_lossy()));
    let status = std::process::Command::new("cmd")
        .args(["/C", "start", "", &godot.to_string_lossy(), "--path", &projeto.to_string_lossy(), "--"])
        .args(&extra)
        .spawn();
    match status {
        Ok(_) => Ok("Astralis aberto de verdade (lendo projects/default + setup do duelo). Bom jogo!".to_string()),
        Err(e) => Err(format!("O jogo não abriu: {e}")),
    }
}

// Espelha schemas/card.schema.json com mensagens em PT-BR simples dizendo
// onde clicar (mesmo texto do frontend em src/lib/validacao.js).
fn checar_carta(carta: &serde_json::Value, conhecidos: &[String]) -> Vec<ErroValidacao> {
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
                        if !conhecidos.is_empty() && !conhecidos.contains(&id.to_string()) {
                            erros.push(erro(
                                "Efeitos",
                                "field-effects",
                                &format!("Efeito \"{id}\" o jogo não conhece (só vale o que o Astralis sabe executar). Clique em Efeitos e escolha um modelo da lista."),
                            ));
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
    let canon = match destino.canonicalize() {
        Ok(c) => c,
        Err(_) => destino.clone(),
    };
    let base = match pasta.canonicalize() {
        Ok(b) => b,
        Err(_) => pasta.to_path_buf(),
    };
    if !canon.starts_with(&base) {
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
    let id = carta.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    if !eh_id_snake(&id) {
        return Err("ID inválido: use só letra minúscula, número e underline — exemplo: card_meu_dragao.".to_string());
    }
    let pasta = pasta_cartas()?;
    let file = escrever_carta(&pasta, &carta, &id)?;
    Ok(ResultadoOk {
        ok: true,
        file: file.clone(),
        mensagem: format!("Salvo em projects/default/cards/{file} (dado puro, sem mexer no jogo)."),
    })
}

#[tauri::command]
fn validar_carta(carta: serde_json::Value) -> Vec<ErroValidacao> {
    let conhecidos = efeitos_conhecidos();
    checar_carta(&carta, &conhecidos)
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
fn checar_duelista(d: &serde_json::Value, decks: &std::collections::HashSet<String>) -> Vec<ErroValidacao> {
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
            if !decks.is_empty() && !decks.contains(deck) {
                erros.push(erro("Deck", "field-deck", &format!("Deck \"{deck}\" não existe. Clique em Deck e escolha um da lista — ou crie na aba Decks.")));
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
    let canon = match destino.canonicalize() {
        Ok(c) => c,
        Err(_) => destino.clone(),
    };
    let base = match pasta.canonicalize() {
        Ok(b) => b,
        Err(_) => pasta.to_path_buf(),
    };
    if !canon.starts_with(&base) {
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
    let decks = ids_de_projeto("decks").unwrap_or_default();
    let erros = checar_duelista(&duelista, &decks);
    if !erros.is_empty() {
        let lista: Vec<String> = erros.iter().map(|e| format!("- {}", e.mensagem)).collect();
        return Err(format!("Arruma antes de salvar:\n{}", lista.join("\n")));
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
    let decks = ids_de_projeto("decks").unwrap_or_default();
    checar_duelista(&duelista, &decks)
}

// Preview unificado (doc 10), contexto mínimo V1: valida tudo, salva o dado
// e lança o Astralis de verdade. Sem seed ainda. O editor não calcula nada:
// só entrega o dado e abre o jogo.
#[tauri::command]
fn jogar_carta(carta: serde_json::Value) -> Result<ResultadoOk, String> {
    let conhecidos = efeitos_conhecidos();
    let erros = checar_carta(&carta, &conhecidos);
    if !erros.is_empty() {
        let lista: Vec<String> = erros.iter().map(|e| format!("- {}", e.mensagem)).collect();
        return Err(format!("Arruma antes de jogar:\n{}", lista.join("\n")));
    }
    let id = carta.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let pasta = pasta_cartas()?;
    let file = escrever_carta(&pasta, &carta, &id)?;

    let raiz = raiz_projeto().ok_or_else(|| "Não achei a raiz do projeto para lançar o jogo.".to_string())?;
    let godot = raiz.join("Godot").join("Godot_v4.7.2-stable_win64.exe");
    if !godot.is_file() {
        return Err("Salvei a carta, mas não achei o Godot em Godot/Godot_v4.7.2-stable_win64.exe.".to_string());
    }
    let projeto = raiz.join("astralis");
    if !projeto.is_dir() {
        return Err("Salvei a carta, mas não achei a pasta astralis/ do jogo.".to_string());
    }
    let pasta_ed = pasta_projeto()
        .map_err(|e| format!("Salvei a carta, mas {e}"))?;
    let extra = montar_args_jogo(&pasta_ed.to_string_lossy(), None);

    // Lança via shell (cmd start): janela normal, processo solto do Studio.
    // O jogo lê TUDO de projects/default/ via --project (só o que importar).
    let status = std::process::Command::new("cmd")
        .args(["/C", "start", "", &godot.to_string_lossy(), "--path", &projeto.to_string_lossy(), "--"])
        .args(&extra)
        .spawn();
    match status {
        Ok(_) => Ok(ResultadoOk {
            ok: true,
            file,
            mensagem: "Carta salva e Astralis aberto de verdade (lendo projects/default). Bom jogo!".to_string(),
        }),
        Err(e) => Err(format!("Salvei a carta, mas o jogo não abriu: {e}")),
    }
}

// ---- DECKS (bloco 2) ----
// Espelha schemas/deck.schema.json. Alvo do jogo: 40 cartas (doc 14 conta
// "contador 40"); schema aceita 20..60, então fora disso é ERRO e diferente
// de 40 é só AVISO mostrado na tela (não trava o salvar).
fn checar_deck(deck: &serde_json::Value, cartas: &std::collections::HashSet<String>) -> Vec<ErroValidacao> {
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
                        if !cartas.is_empty() && !cartas.contains(id) {
                            erros.push(erro("Cartas", "field-cards", &format!("Carta \"{id}\" não existe no projeto. Remova ela do deck (clique no ✕) ou crie a carta na aba Cartas.")));
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
    let cartas = cartas_ids().unwrap_or_default();
    let erros = checar_deck(&deck, &cartas);
    if !erros.is_empty() {
        let lista: Vec<String> = erros.iter().map(|e| format!("- {}", e.mensagem)).collect();
        return Err(format!("Arruma antes de salvar:\n{}", lista.join("\n")));
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
    let cartas = cartas_ids().unwrap_or_default();
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

fn checar_fusoes(dado: &serde_json::Value, cartas: &std::collections::HashSet<String>) -> Vec<ErroValidacao> {
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
                    } else if !cartas.is_empty() && !cartas.contains(id) {
                        erros.push(erro(&onde, "field-recipes", &format!("{onde}: carta \"{id}\" não existe no projeto. Escolha outra na lista.")));
                    }
                }
                if !a.is_empty() && a == b {
                    erros.push(erro(&onde, "field-recipes", &format!("{onde}: carta A e B são a mesma ({a}). Fusão precisa de duas cartas diferentes.")));
                }
                match r.get("result").and_then(|v| v.as_str()) {
                    Some(id) if eh_id_snake(id) => {
                        if !cartas.is_empty() && !cartas.contains(id) {
                            erros.push(erro(&onde, "field-recipes", &format!("{onde}: resultado \"{id}\" não existe no projeto. Crie a carta na aba Cartas ou escolha outra.")));
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
                        if !cartas.is_empty() && !cartas.contains(id) {
                            erros.push(erro(&onde, "field-rules", &format!("{onde}: resultado \"{id}\" não existe no projeto. Crie a carta na aba Cartas ou escolha outra.")));
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
    let cartas = cartas_ids().unwrap_or_default();
    let erros = checar_fusoes(&dado, &cartas);
    if !erros.is_empty() {
        let lista: Vec<String> = erros.iter().map(|e| format!("- {}", e.mensagem)).collect();
        return Err(format!("Arruma antes de salvar:\n{}", lista.join("\n")));
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
    if !erros.is_empty() {
        let lista: Vec<String> = erros.iter().map(|e| format!("- {}", e.mensagem)).collect();
        return Err(format!("Arruma antes de salvar:\n{}", lista.join("\n")));
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
// temporário do SO (std::env::temp_dir()/duel_studio_rapido.json) e lança o
// Godot com --project <projects/default> + --setup <temp> (o jogo já aceita
// os dois: lê o projeto e põe o setup por cima). Nunca toca no duel_setup do
// jogo (starter intacto).
// O editor nunca simula duelo (R1).
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
    let ordem = if pedido.ordem.trim().is_empty() { "first_p1".to_string() } else { pedido.ordem.trim().to_string() };
    if !["first_p1", "first_p2", "random"].contains(&ordem.as_str()) {
        return Err("Ordem de turno inválida. Escolha quem começa na lista.".to_string());
    }
    let arena = if pedido.arena.trim().is_empty() { "arena_starter".to_string() } else { pedido.arena.trim().to_string() };
    let arenas = arenas_ids();
    if !arenas.is_empty() && !arenas.contains(&arena) {
        return Err(format!("Arena \"{arena}\" não existe. Escolha uma da lista."));
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
    let setup = serde_json::json!({
        "schema_version": 1,
        "duel_id": "duel_studio_rapido",
        "duelist1": { "duelist_id": pedido.duelista1, "deck_id": deck1 },
        "duelist2": { "duelist_id": pedido.duelista2, "deck_id": deck2 },
        "starting_lp": pedido.vida,
        "turn_order": ordem,
        "seed": pedido.seed.unwrap_or(42),
        "arena_id": arena,
        "win": { "on_lp_zero": true, "on_deckout": true }
    });
    let temp = std::env::temp_dir().join("duel_studio_rapido.json");
    escrever_json_valor(&temp, &setup, "duelo rápido (temporário)")?;
    match lancar_astralis_com_setup(&temp) {
        Ok(msg) => Ok(ResultadoOk {
            ok: true,
            file: temp.to_string_lossy().to_string(),
            mensagem: format!("Duelo rápido salvo no temporário ({}) e {msg}", temp.display()),
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
    if !erros.is_empty() {
        let lista: Vec<String> = erros.iter().map(|e| format!("- {}", e.mensagem)).collect();
        return Err(format!("Arruma antes de salvar:\n{}", lista.join("\n")));
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
    let mut ids_cartas: std::collections::HashSet<String> = std::collections::HashSet::new();
    let pasta_c = proj.join("cards");
    if let Ok(entries) = std::fs::read_dir(&pasta_c) {
        let conhecidos = efeitos_conhecidos();
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
                    err_cartas += checar_carta(&v, &conhecidos).len();
                }
                None => err_cartas += 1,
            }
        }
    }
    erros += err_cartas;
    itens.push(ItemProjeto {
        area: "Cartas".to_string(),
        ok: n_cartas > 0 && err_cartas == 0,
        detalhe: if n_cartas == 0 { "nenhuma carta no projeto".to_string() } else { format!("{n_cartas} cartas, {err_cartas} erros") },
    });

    // Decks + duelistas (refs cruzadas).
    let mut ids_decks: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut err_decks = 0;
    let mut n_decks = 0;
    let mut fora_do_alvo = 0;
    if let Ok(entries) = std::fs::read_dir(proj.join("decks")) {
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
                    err_decks += checar_deck(&v, &ids_cartas).len();
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
    avisos += fora_do_alvo;
    itens.push(ItemProjeto {
        area: "Decks".to_string(),
        ok: n_decks > 0 && err_decks == 0,
        detalhe: if n_decks == 0 { "nenhum deck no projeto".to_string() } else { format!("{n_decks} decks, {err_decks} erros, {fora_do_alvo} fora do alvo 40") },
    });

    let mut ids_duelistas: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut err_duel = 0;
    let mut n_duel = 0;
    if let Ok(entries) = std::fs::read_dir(proj.join("duelists")) {
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
                    err_duel += checar_duelista(&v, &ids_decks).len();
                }
                None => err_duel += 1,
            }
        }
    }
    erros += err_duel;
    itens.push(ItemProjeto {
        area: "Duelistas".to_string(),
        ok: n_duel > 0 && err_duel == 0,
        detalhe: if n_duel == 0 { "nenhum duelista no projeto".to_string() } else { format!("{n_duel} duelistas, {err_duel} erros") },
    });

    // Fusões.
    match std::fs::read_to_string(proj.join("fusions.json")).ok().and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok()) {
        Some(v) => {
            let n = checar_fusoes(&v, &ids_cartas).len();
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
            format!("Projeto válido com {avisos} aviso(s) (decks fora do alvo 40). Empacotamento (.astralis + zip) vem depois — por ora nada foi empacotado.")
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
#[derive(Debug, serde::Serialize)]
struct ResultadoImportacao {
    cartas: usize,
    duelistas: usize,
    decks: usize,
    fusoes_novas: usize,
    fusoes_puladas: usize,
    regras_novas: usize,
    regras_puladas: usize,
    equips_ignorados: usize,
    backups: Vec<String>,
    erros: Vec<String>,
    avisos: Vec<String>,
    mensagem: String,
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

// Copia o conteúdo atual (cartas/duelistas/decks/fusions.json) para
// <projects/default>/backups/pack_<data>_<hora>/. Devolve (pasta, rótulo).
// Não apaga nem altera nada do projeto — só copia.
fn backup_conteudo_atual(
    pasta_cartas: &std::path::Path,
    pasta_duelistas: &std::path::Path,
    pasta_decks: &std::path::Path,
    caminho_fusoes: &std::path::Path,
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

    let conhecidos = efeitos_conhecidos();
    importar_pack_para(
        pack,
        &pasta_cartas,
        &pasta_duelistas,
        &pasta_decks,
        &caminho_fusoes,
        &conhecidos,
    )
}

fn importar_pack_para(
    pack: &serde_json::Value,
    pasta_cartas: &std::path::Path,
    pasta_duelistas: &std::path::Path,
    pasta_decks: &std::path::Path,
    caminho_fusoes: &std::path::Path,
    conhecidos: &[String],
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
    let mut avisos: Vec<String> = Vec::new();

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
        let errs = checar_carta(c, conhecidos);
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
        let errs = checar_duelista(d, &todos_decks);
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
        let errs = checar_deck(d, &todas_cartas);
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
    let (_dir_backup, rotulo) = backup_conteudo_atual(pasta_cartas, pasta_duelistas, pasta_decks, caminho_fusoes)?;

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

    if fusoes_mesma > 0 {
        avisos.push(format!("{fusoes_mesma} fusões com A e B iguais ignoradas (fusão precisa de duas cartas diferentes — esse dado nunca dispara)."));
    }
    if fusoes_repetidas > 0 {
        avisos.push(format!("{fusoes_repetidas} fusões repetidas dentro do próprio pack puladas (mesmo par + resultado)."));
    }
    let equips_ignorados = match pack.get("equips") {
        Some(serde_json::Value::Array(lista)) => lista.len(),
        _ => 0,
    };
    if equips_ignorados > 0 {
        avisos.push(format!("{equips_ignorados} pares equip→monstro ignorados (sem schema V1 — o jogo ignora; viram schema formal depois)."));
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
    if fusoes_puladas + regras_puladas > 0 {
        mensagem.push_str(&format!(" {} repetido(s) do próprio pack pulado(s).", fusoes_puladas + regras_puladas));
    }
    mensagem.push_str(&format!(" backup em {rotulo}."));

    Ok(ResultadoImportacao {
        cartas: n_cartas,
        duelistas: n_duelistas,
        decks: n_decks,
        fusoes_novas,
        fusoes_puladas,
        regras_novas,
        regras_puladas,
        equips_ignorados,
        backups: vec![rotulo],
        erros: Vec::new(),
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
    for sub in ["cards", "duelists", "decks", "arenas", "scenes"] {
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
    for sub in ["cards", "duelists", "decks", "arenas", "scenes"] {
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
    // Recria o esqueleto vazio (pastas + fusions/effects vazios válidos).
    garantir_projeto(proj)?;
    Ok(ResultadoBoot {
        limpou: true,
        mensagem: format!("Projeto zerado ({apagados} arquivo(s) apagado(s), sem backup). Importe um pack para começar."),
    })
}

#[tauri::command]
fn preparar_boot() -> Result<ResultadoBoot, String> {
    let proj = pasta_projeto()?;
    preparar_boot_para(&proj)
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
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
            listar_cenas,
            salvar_cena,
            validar_cena,
            validar_projeto,
            importar_pack,
            preparar_boot
        ])
        .run(tauri::generate_context!())
        .expect("Astralis Studio não abriu");
}

// Regressão mínima: validação PT-BR espelha o card.schema.json (R4).
#[cfg(test)]
mod testes {
    use super::*;

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
    fn carta_vazia_reclama_obrigatorios() {
        let erros = checar_carta(&serde_json::json!({}), &[]);
        let campos: Vec<&str> = erros.iter().map(|e| e.campo.as_str()).collect();
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
        assert!(checar_carta(&carta, &[]).is_empty());
    }

    #[test]
    fn efeito_desconhecido_barra_r4() {
        let carta = serde_json::json!({
            "schema_version": 1, "id": "card_teste", "name": "Teste",
            "card_type": "spell", "effects": ["efeito_que_nao_existe"], "tags": []
        });
        let erros = checar_carta(&carta, &["ganho_lp".to_string()]);
        assert!(erros.iter().any(|e| e.mensagem.contains("não conhece")));
    }

    #[test]
    fn deck_id_invalido_barra() {
        assert!(ler_deck("Deck_X".to_string()).is_err());
        assert!(ler_deck("".to_string()).is_err());
    }

    #[test]
    fn duelista_vazio_reclama_obrigatorios() {
        let erros = checar_duelista(&serde_json::json!({}), &std::collections::HashSet::new());
        let campos: Vec<&str> = erros.iter().map(|e| e.campo.as_str()).collect();
        for c in ["Versão", "ID", "Nome", "Deck", "Estilo de jogo"] {
            assert!(campos.contains(&c), "faltou erro de {c}");
        }
    }

    #[test]
    fn duelista_valido_passa() {
        let mut decks = std::collections::HashSet::new();
        decks.insert("deck_starter_hero".to_string());
        let d = serde_json::json!({
            "schema_version": 1, "id": "duelist_teste", "name": "Teste",
            "deck_id": "deck_starter_hero", "starting_lp": 4000,
            "ai_preset": { "dificuldade": "normal", "agressividade": 50, "uso_fusao": 50, "protecao_lp": 50 }
        });
        assert!(checar_duelista(&d, &decks).is_empty());
    }

    #[test]
    fn duelista_deck_fantasma_barra() {
        let mut decks = std::collections::HashSet::new();
        decks.insert("deck_outro".to_string());
        let d = serde_json::json!({
            "schema_version": 1, "id": "duelist_teste", "name": "Teste",
            "deck_id": "deck_fantasma",
            "ai_preset": { "dificuldade": "facil", "agressividade": 30, "uso_fusao": 20, "protecao_lp": 60 }
        });
        let erros = checar_duelista(&d, &decks);
        assert!(erros.iter().any(|e| e.campo == "Deck"));
    }

    #[test]
    fn deck_curto_barra() {
        let cartas: std::collections::HashSet<String> =
            ["card_a".to_string()].into_iter().collect();
        let d = serde_json::json!({
            "schema_version": 1, "id": "deck_teste", "name": "Teste",
            "cards": ["card_a", "card_fantasma"]
        });
        let erros = checar_deck(&d, &cartas);
        assert!(erros.iter().any(|e| e.mensagem.contains("20 a 60")));
        assert!(erros.iter().any(|e| e.mensagem.contains("card_fantasma")));
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
        let erros = checar_fusoes(&serde_json::json!({}), &std::collections::HashSet::new());
        assert!(erros.iter().any(|e| e.campo == "Receitas" || e.mensagem.contains("Receitas")));
    }

    #[test]
    fn fusao_receita_igual_barra() {
        let mut cartas = std::collections::HashSet::new();
        cartas.insert("card_a".to_string());
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
        let erros = checar_fusoes(&dado, &std::collections::HashSet::new());
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

    #[test]
    fn duelo_mesmo_duelista_barra() {
        let p = PedidoDuelo { duelista1: "duelist_hero".to_string(), duelista2: "duelist_hero".to_string(), vida: 4000, seed: None, arena: "".to_string(), ordem: "".to_string() };
        assert!(jogar_duelo(p).is_err());
    }

    #[test]
    fn duelo_vida_zero_barra() {
        let p = PedidoDuelo { duelista1: "duelist_hero".to_string(), duelista2: "duelist_rival".to_string(), vida: 0, seed: None, arena: "".to_string(), ordem: "".to_string() };
        let r = jogar_duelo(p);
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("Vida"));
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
        assert!(checar_carta(&carta_fm_base(), &[]).is_empty());
    }

    #[test]
    fn carta_tipos_fm_novos_passam() {
        for mt in ["beast-warrior", "winged-beast", "dinosaur", "reptile", "sea-serpent", "fish"] {
            let mut c = carta_fm_base();
            c["monster_type"] = serde_json::json!(mt);
            assert!(checar_carta(&c, &[]).is_empty(), "tipo {mt} deveria passar");
        }
        for ct in ["equip", "ritual"] {
            let c = serde_json::json!({
                "schema_version": 1, "id": "card_fm_x", "name": "X",
                "card_type": ct, "effects": [], "tags": []
            });
            assert!(checar_carta(&c, &[]).is_empty(), "tipo {ct} deveria passar sem status");
        }
    }

    #[test]
    fn carta_magic_barra_fm() {
        let mut c = carta_fm_base();
        c["card_type"] = serde_json::json!("magic");
        let erros = checar_carta(&c, &[]);
        assert!(erros.iter().any(|e| e.campo == "Tipo"));
    }

    #[test]
    fn carta_fm_opcionais_invalidos_barram() {
        let mut c = carta_fm_base();
        c["password"] = serde_json::json!("123");
        assert!(checar_carta(&c, &[]).iter().any(|e| e.campo == "Senha"));
        let mut c = carta_fm_base();
        c["guardian_star_1"] = serde_json::json!("terra");
        assert!(checar_carta(&c, &[]).iter().any(|e| e.campo == "Estrela guardiã"));
        let mut c = carta_fm_base();
        c["starchip_cost"] = serde_json::json!(-5);
        assert!(checar_carta(&c, &[]).iter().any(|e| e.campo == "Starchips"));
        // Ausentes = N/A: continuam válidas.
        let mut c = carta_fm_base();
        for k in ["guardian_star_1", "guardian_star_2", "password", "starchip_cost"] {
            c.as_object_mut().unwrap().remove(k);
        }
        assert!(checar_carta(&c, &[]).is_empty());
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
            &[],
        )
        .unwrap();
        assert_eq!(r.cartas, 2);
        assert_eq!(r.duelistas, 1);
        assert_eq!(r.decks, 1);
        assert_eq!(r.fusoes_novas, 1);
        assert_eq!(r.fusoes_puladas, 1);
        assert_eq!(r.equips_ignorados, 1);
        assert!(r.erros.is_empty());
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
            &[],
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
        assert!(checar_fusoes(&dado, &std::collections::HashSet::new()).is_empty());
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
            &[],
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
}
