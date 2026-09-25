// apack.rs — Pack de criação `.apack` V1 (dono: Editor Engineer).
//
// Espelho Rust de tools/apack.py + docs/12 §12.7 + docs/04 §4.7. O `.apack` é
// um ZIP comum (deflate) com manifest.json + data/pack.json + assets/ +
// preview opcional. Formato de CRIAÇÃO (aberto, editável) — nunca a fita final
// `.astralis` (binária trancada, R6).
//
// Os 5 passos do §12.7, onde cada um mora:
// 1. Abrir o zip e validar magic/format .... `ler_apack` (usa crate `zip`)
// 2. Conferir SHA256 de cada files[] ..... `ler_apack` (usa crate `sha2`)
// 3. Passar data/pack.json ao importar ..... main.rs `importar_apack` chama o
//    `importar_pack_valor` atual (NÃO muda: mesmas chaves PT/EN, filtro A+A,
//    backup — agora com backup de assets/ também)
// 4. Copiar assets/ p/ o projeto .......... `copiar_assets` (só abaixo de
//    `assets/`, repetida vira cópia em cada path)
// 5. Faltando = aviso ..................... `faltando` no `ApackLido` (nunca
//    erro; "sem imagens" quando assets == 0)
//
// Exportar (`exportar_apack` no main.rs): monta o pack.json do projeto atual
// (via `construir_pack_json`), resolve as refs `assets/...` no disco e chama
// `montar_apack` (dedup por SHA256 igual ao Python: repetida grava 1x).

use std::collections::{BTreeMap, BTreeSet};
use std::io::{Read, Write};
use std::path::Path;

pub const MAGIC: &str = "APACK";
pub const FORMAT_VERSION: i64 = 1;
pub const SCHEMA_VERSION: i64 = 1;

pub const MAX_ASSET_BYTES: u64 = 5_000_000; // 5 MB por arquivo
pub const MAX_ASSETS_TOTAL: u64 = 200_000_000; // 200 MB somados
pub const MAX_APACK_TOTAL: u64 = 250_000_000; // 250 MB o arquivo final
pub const MAX_ASSET_FILES: usize = 5000;
pub const PREVIEW_MAX: u64 = 2_000_000; // 2 MB
pub const AVISOS_TETO: usize = 10; // quantas faltantes listar (resto vira "+N")

const EXT_OK: [&str; 5] = [".png", ".webp", ".jpg", ".jpeg", ".ogg"];
const PREVIEW_NOMES: [&str; 4] = ["preview.png", "preview.jpg", "preview.jpeg", "preview.webp"];

// ---- base ----

pub fn sha256_hex(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    h.update(bytes);
    format!("{:x}", h.finalize())
}

// Base64 padrão (mesmo alfabeto do decodificar_base64 do main.rs). Manual de
// propósito: codificar é tabela de 64 chars, sem crate nova.
pub fn codificar_base64(bytes: &[u8]) -> String {
    const TAB: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut fora = String::with_capacity(bytes.len().div_ceil(3) * 4);
    let mut i = 0;
    while i < bytes.len() {
        let b0 = bytes[i] as u32;
        let b1 = if i + 1 < bytes.len() { bytes[i + 1] as u32 } else { 0 };
        let b2 = if i + 2 < bytes.len() { bytes[i + 2] as u32 } else { 0 };
        let n = (b0 << 16) | (b1 << 8) | b2;
        fora.push(TAB[((n >> 18) & 63) as usize] as char);
        fora.push(TAB[((n >> 12) & 63) as usize] as char);
        fora.push(if i + 1 < bytes.len() { TAB[((n >> 6) & 63) as usize] as char } else { '=' });
        fora.push(if i + 2 < bytes.len() { TAB[(n & 63) as usize] as char } else { '=' });
        i += 3;
    }
    fora
}

// Carimbo UTC "AAAA-MM-DDTHH:MM:SSZ" (mesmo algoritmo de Howard Hinnant do
// carimbo_data_hora do main.rs; formato ISO porque o manifest do Python usa).
pub fn utc_iso_agora() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let dias = (secs / 86400) as i64;
    let resto = (secs % 86400) as i64;
    let z = dias + 719468;
    let era = z.div_euclid(146097);
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let ano = if m <= 2 { y + 1 } else { y };
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", ano, m, d, resto / 3600, (resto % 3600) / 60, resto % 60)
}

// ---- regras V1 (iguais ao apack.py) ----

// Trava ZipSlip: só paths relativos dentro do zip, sem `..` nem letra de
// unidade. Vale pros nomes do zip E pros paths do manifest E pras refs do pack.
pub fn zip_seguro(nome: &str) -> bool {
    if nome.is_empty() {
        return false;
    }
    let n = nome.replace('\\', "/");
    if n.starts_with('/') {
        return false;
    }
    if n.len() >= 2 && n.as_bytes()[1] == b':' {
        return false;
    }
    for p in n.split('/') {
        if p == ".." {
            return false;
        }
    }
    true
}

// Extensão V1 (minúscula): png/webp/jpg/jpeg/ogg. Sem ponto = proibida.
pub fn extensao_permitida(path: &str) -> bool {
    match path.rfind('.') {
        Some(i) => EXT_OK.contains(&path[i..].to_lowercase().as_str()),
        None => false,
    }
}

// Toda string `assets/...` no pack é referência de asset (hoje artwork,
// amanhã portraits/backgrounds — genérico de propósito, igual ao Python).
pub fn coletar_refs(valor: &serde_json::Value, refs: &mut BTreeSet<String>) {
    match valor {
        serde_json::Value::Object(o) => {
            for v in o.values() {
                coletar_refs(v, refs);
            }
        }
        serde_json::Value::Array(l) => {
            for v in l {
                coletar_refs(v, refs);
            }
        }
        serde_json::Value::String(s) => {
            if s.starts_with("assets/") {
                refs.insert(s.clone());
            }
        }
        _ => {}
    }
}

pub fn refs_do_pack(pack: &serde_json::Value) -> BTreeSet<String> {
    let mut refs = BTreeSet::new();
    coletar_refs(pack, &mut refs);
    refs
}

// ---- manifest.json (schema exato do §12.7: campo a mais ou a menos = inválido) ----

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Contagens {
    pub cartas: usize,
    pub duelistas: usize,
    pub decks: usize,
    pub fusoes_recipes: usize,
    pub fusoes_rules: usize,
    pub equips: usize,
    pub assets: usize,
    pub assets_bytes: u64,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ArquivoManifest {
    pub path: String,
    pub sha256: String,
    pub size: u64,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub stored_as: Option<String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub magic: String,
    pub format_version: i64,
    pub schema_version: i64,
    pub runtime_version: String,
    pub author_id: String,
    pub mode: String,
    pub pack_id: String,
    pub name: String,
    pub counts: Contagens,
    pub files: Vec<ArquivoManifest>,
    pub pack_sha256: String,
    pub created_utc: String,
    pub tool: String,
}

// ---- LER (passos 1+2+5) ----

#[derive(Debug)]
pub struct ApackLido {
    pub pack_bytes: Vec<u8>, // bytes EXATOS de data/pack.json (roundtrip = mesmo hash)
    pub pack: serde_json::Value,
    pub manifest: Manifest,
    // Um por path lógico (repetida gravada 1x vira cópia em cada path aqui).
    pub assets: Vec<(String, Vec<u8>)>,
    pub preview: Option<(String, Vec<u8>)>,
    // Refs `assets/...` sem arquivo no zip = AVISO, nunca erro ("sem imagens").
    pub faltando: Vec<String>,
}

fn nomes_do_zip(arq: &mut zip::ZipArchive<std::io::Cursor<&[u8]>>) -> Result<Vec<String>, String> {
    let mut nomes = Vec::with_capacity(arq.len());
    for i in 0..arq.len() {
        match arq.name_for_index(i) {
            Some(n) => nomes.push(n.to_string()),
            None => return Err("Não consegui ler a lista de arquivos do .apack (zip com nome quebrado).".to_string()),
        }
    }
    Ok(nomes)
}

fn ler_entrada(arq: &mut zip::ZipArchive<std::io::Cursor<&[u8]>>, nome: &str) -> Result<Vec<u8>, String> {
    let mut f = arq
        .by_name(nome)
        .map_err(|_| format!("\"{nome}\" listado no manifest mas fora do zip (arquivo adulterado?)."))?;
    let mut buf = Vec::with_capacity(f.size().min(50_000_000) as usize);
    f.read_to_end(&mut buf)
        .map_err(|e| format!("Não consegui ler \"{nome}\" de dentro do .apack: {e}"))?;
    Ok(buf)
}

pub fn ler_apack(bytes: &[u8], nome: &str) -> Result<ApackLido, String> {
    if bytes.len() as u64 > MAX_APACK_TOTAL {
        return Err(format!("\"{nome}\" passa de 250 MB (teto V1) — não abri."));
    }
    let mut arq = zip::ZipArchive::new(std::io::Cursor::new(bytes))
        .map_err(|_| format!("\"{nome}\" não é um .apack válido: não é um zip (todo .apack é um zip)."))?;
    let nomes = nomes_do_zip(&mut arq)?;
    if !nomes.contains(&"manifest.json".to_string()) || !nomes.contains(&"data/pack.json".to_string()) {
        return Err(format!("\"{nome}\" não é um .apack V1: faltam manifest.json e/ou data/pack.json."));
    }
    for n in &nomes {
        if !zip_seguro(n) {
            return Err(format!("\"{nome}\" tem entrada fora do zip (ZipSlip barrado): \"{n}\"."));
        }
    }

    let cru = ler_entrada(&mut arq, "manifest.json")?;
    let manifest: Manifest = serde_json::from_slice(&cru).map_err(|e| {
        format!("\"{nome}\" tem manifest.json quebrado: {e}. O arquivo pode estar adulterado.")
    })?;
    if manifest.magic != MAGIC {
        return Err(format!("\"{nome}\" não é um .apack: magic={:?} (esperava \"APACK\").", manifest.magic));
    }
    if manifest.format_version != FORMAT_VERSION {
        return Err(format!("\"{nome}\" não é V1: format_version={} (só aceito 1).", manifest.format_version));
    }
    if manifest.schema_version != SCHEMA_VERSION {
        return Err(format!("\"{nome}\" não é V1: schema_version={} (o contrato V1 é 1, sem migração).", manifest.schema_version));
    }
    if manifest.mode != "aberto" {
        return Err(format!("\"{nome}\" tem mode={:?} (V1 .apack é sempre \"aberto\"; trancado é .astralis).", manifest.mode));
    }
    if manifest.runtime_version.trim().is_empty() {
        return Err(format!("\"{nome}\" sem runtime_version no manifest (info obrigatória)."));
    }
    if manifest.author_id.trim().is_empty() {
        return Err(format!("\"{nome}\" sem author_id no manifest (info obrigatória)."));
    }

    // Confere hash de tudo (stored_as: hash dos bytes guardados 1x).
    let mut guardados: BTreeMap<String, Vec<u8>> = BTreeMap::new(); // entrada no zip -> bytes
    let mut pack_bytes: Option<Vec<u8>> = None;
    let mut logicos: Vec<(String, String)> = Vec::new(); // (path lógico, entrada no zip)
    let mut preview_nome: Option<String> = None;
    for f in &manifest.files {
        if !zip_seguro(&f.path) {
            return Err(format!("\"{nome}\" tem path fora do zip no manifest (ZipSlip barrado): \"{}\".", f.path));
        }
        let entrada = f.stored_as.as_deref().unwrap_or(&f.path);
        if !zip_seguro(entrada) {
            return Err(format!("\"{nome}\" tem stored_as fora do zip no manifest (ZipSlip barrado): \"{entrada}\"."));
        }
        if f.path == "data/pack.json" {
            let b = ler_entrada(&mut arq, entrada)?;
            if sha256_hex(&b) != f.sha256 {
                return Err(format!("\"{nome}\": hash não bate em data/pack.json (arquivo adulterado?)."));
            }
            pack_bytes = Some(b);
        } else if f.path.starts_with("assets/") {
            if !extensao_permitida(&f.path) {
                return Err(format!("\"{nome}\": extensão proibida em \"{}\" (V1 aceita: png, webp, jpg, jpeg, ogg).", f.path));
            }
            if f.size > MAX_ASSET_BYTES {
                return Err(format!("\"{nome}\": \"{}\" passa de 5 MB (teto V1 por arquivo).", f.path));
            }
            if !guardados.contains_key(entrada) {
                let b = ler_entrada(&mut arq, entrada)?;
                if sha256_hex(&b) != f.sha256 {
                    return Err(format!("\"{nome}\": hash não bate em \"{}\" (arquivo adulterado?).", f.path));
                }
                guardados.insert(entrada.to_string(), b);
            } else if sha256_hex(&guardados[entrada]) != f.sha256 {
                return Err(format!("\"{nome}\": hash não bate em \"{}\" (arquivo adulterado?).", f.path));
            }
            logicos.push((f.path.clone(), entrada.to_string()));
        } else if PREVIEW_NOMES.contains(&f.path.as_str()) {
            if f.size > PREVIEW_MAX {
                return Err(format!("\"{nome}\": capa \"{}\" passa de 2 MB.", f.path));
            }
            let b = ler_entrada(&mut arq, entrada)?;
            if sha256_hex(&b) != f.sha256 {
                return Err(format!("\"{nome}\": hash não bate na capa \"{}\" (arquivo adulterado?).", f.path));
            }
            preview_nome = Some(f.path.clone());
            guardados.insert(format!("preview:{0}", f.path), b);
        } else {
            return Err(format!("\"{nome}\": entrada desconhecida no manifest: \"{}\" (V1 só aceita data/pack.json, assets/* e preview).", f.path));
        }
    }
    if logicos.len() > MAX_ASSET_FILES {
        return Err(format!("\"{nome}\" tem {} assets (teto V1: 5000).", logicos.len()));
    }
    let total_assets: u64 = logicos
        .iter()
        .map(|(p, _)| manifest.files.iter().find(|f| &f.path == p).map(|f| f.size).unwrap_or(0))
        .sum();
    if total_assets > MAX_ASSETS_TOTAL {
        return Err(format!("\"{nome}\": assets passam de 200 MB (teto V1)."));
    }

    let pack_bytes = pack_bytes.ok_or_else(|| format!("\"{nome}\": manifest sem data/pack.json."))?;
    if sha256_hex(&pack_bytes) != manifest.pack_sha256 {
        return Err(format!("\"{nome}\": pack_sha256 não bate (manifest adulterado?)."));
    }
    let pack: serde_json::Value = serde_json::from_slice(&pack_bytes)
        .map_err(|e| format!("\"{nome}\": data/pack.json tem JSON quebrado: {e}"))?;
    if pack.get("schema_version").and_then(|v| v.as_i64()) != Some(1) {
        return Err(format!("\"{nome}\" não é um pack V1: falta \"schema_version\": 1 no data/pack.json."));
    }

    // Materializa (repetida gravada 1x volta como cópia em cada path lógico).
    let mut assets: Vec<(String, Vec<u8>)> = Vec::with_capacity(logicos.len());
    for (logico, entrada) in logicos {
        let b = guardados.get(&entrada).cloned().unwrap_or_default();
        assets.push((logico, b));
    }
    assets.sort_by(|a, b| a.0.cmp(&b.0));
    let preview = preview_nome.map(|n| {
        let b = guardados.get(&format!("preview:{n}")).cloned().unwrap_or_default();
        (n, b)
    });

    // Refs sem arquivo = AVISO (pack abre como legado "sem imagens").
    let no_zip: BTreeSet<String> = manifest.files.iter().map(|f| f.path.clone()).collect();
    let faltando: Vec<String> = refs_do_pack(&pack).into_iter().filter(|r| !no_zip.contains(r)).collect();

    Ok(ApackLido { pack_bytes, pack, manifest, assets, preview, faltando })
}

// ---- MONTAR (exportar) ----

#[derive(Debug)]
pub struct ApackPronto {
    pub bytes: Vec<u8>, // o .apack pronto (zip)
    pub manifest: Manifest,
    pub faltando: Vec<String>, // refs sem arquivo no projeto (aviso)
    pub repetidas: usize,      // quantas refs reaproveitaram bytes já gravados
}

// Monta o pack.json V1 a partir do projeto atual (mesmas chaves PT do
// fm_original_pack.json, que o importar_pack_valor já entende).
pub fn construir_pack_json(
    pack_id: &str,
    nome: &str,
    cartas: Vec<serde_json::Value>,
    duelistas: Vec<serde_json::Value>,
    decks: Vec<serde_json::Value>,
    fusoes: serde_json::Value,
) -> serde_json::Value {
    serde_json::json!({
        "schema_version": 1,
        "pack_id": pack_id,
        "name": nome,
        "source": { "tool": "astralis-studio V1" },
        "cartas": cartas,
        "duelistas": duelistas,
        "decks": decks,
        "fusoes": fusoes,
        "equips": []
    })
}

fn tamanho_lista(pack: &serde_json::Value, pt: &str, en: &str) -> usize {
    for chave in [pt, en] {
        if let Some(l) = pack.get(chave).and_then(|v| v.as_array()) {
            return l.len();
        }
    }
    0
}

// `achados`: path lógico -> bytes (só os que existem no disco; o resto vira
// `faltando`). Preview: o Studio não tem capa (None) — o parâmetro existe para
// o formato continuar aceitando a capa opcional V1.
pub fn montar_apack(
    pack: &serde_json::Value,
    pack_raw: &[u8],
    achados: &BTreeMap<String, Vec<u8>>,
    preview: Option<(String, Vec<u8>)>,
    author_id: &str,
    runtime_version: &str,
) -> Result<ApackPronto, String> {
    if pack.get("schema_version").and_then(|v| v.as_i64()) != Some(1) {
        return Err("Projeto não é V1 (falta \"schema_version\": 1) — não empacotei.".to_string());
    }
    let refs = refs_do_pack(pack);
    for r in &refs {
        if !zip_seguro(r) {
            return Err(format!("Referência fora do zip: \"{r}\" (use 'assets/...') — não empacotei."));
        }
        if !extensao_permitida(r) {
            return Err(format!("Extensão proibida em \"{r}\" (V1 aceita: png, webp, jpg, jpeg, ogg) — não empacotei."));
        }
    }
    for (p, b) in achados {
        if b.len() as u64 > MAX_ASSET_BYTES {
            return Err(format!("\"{p}\" tem {} bytes (teto V1: 5 MB por arquivo) — não empacotei.", b.len()));
        }
    }
    if achados.len() > MAX_ASSET_FILES {
        return Err(format!("{} assets (teto V1: 5000) — não empacotei.", achados.len()));
    }
    let total: u64 = achados.values().map(|b| b.len() as u64).sum();
    if total > MAX_ASSETS_TOTAL {
        return Err("Assets passam de 200 MB (teto V1) — não empacotei.".to_string());
    }
    let faltando: Vec<String> = refs.into_iter().filter(|r| !achados.contains_key(r)).collect();

    // Dedup content-addressed: mesmo SHA256 grava 1x no zip.
    let mut por_hash: BTreeMap<String, String> = BTreeMap::new(); // sha -> path guardado
    let mut stored_as: BTreeMap<String, String> = BTreeMap::new(); // path lógico -> entrada no zip
    for (path, bytes) in achados {
        let h = sha256_hex(bytes);
        por_hash.entry(h).or_insert_with(|| path.clone());
        stored_as.insert(path.clone(), por_hash[&sha256_hex(bytes)].clone());
    }
    let repetidas = achados.len() - por_hash.len();

    let fusoes = pack.get("fusoes").or_else(|| pack.get("fusions"));
    let contagens = Contagens {
        cartas: tamanho_lista(pack, "cartas", "cards"),
        duelistas: tamanho_lista(pack, "duelistas", "duelists"),
        decks: tamanho_lista(pack, "decks", "decks"),
        fusoes_recipes: fusoes.and_then(|f| f.get("recipes")).and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0),
        fusoes_rules: fusoes.and_then(|f| f.get("rules")).and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0),
        equips: tamanho_lista(pack, "equips", "equips"),
        assets: achados.len(),
        assets_bytes: total,
    };
    let mut files: Vec<ArquivoManifest> = vec![ArquivoManifest {
        path: "data/pack.json".to_string(),
        sha256: sha256_hex(pack_raw),
        size: pack_raw.len() as u64,
        stored_as: None,
    }];
    for (path, bytes) in achados {
        files.push(ArquivoManifest {
            path: path.clone(),
            sha256: sha256_hex(bytes),
            size: bytes.len() as u64,
            stored_as: Some(stored_as[path].clone()),
        });
    }
    if let Some((nome_prev, bytes_prev)) = &preview {
        if !PREVIEW_NOMES.contains(&nome_prev.as_str()) {
            return Err("Capa precisa se chamar preview.png|jpg|webp — não empacotei.".to_string());
        }
        if bytes_prev.len() as u64 > PREVIEW_MAX {
            return Err("Capa passa de 2 MB — não empacotei.".to_string());
        }
        files.push(ArquivoManifest {
            path: nome_prev.clone(),
            sha256: sha256_hex(bytes_prev),
            size: bytes_prev.len() as u64,
            stored_as: None,
        });
    }
    let manifest = Manifest {
        magic: MAGIC.to_string(),
        format_version: FORMAT_VERSION,
        schema_version: SCHEMA_VERSION,
        runtime_version: runtime_version.to_string(),
        author_id: author_id.to_string(),
        mode: "aberto".to_string(),
        pack_id: pack.get("pack_id").and_then(|v| v.as_str()).unwrap_or("studio_pack").to_string(),
        name: pack.get("name").and_then(|v| v.as_str()).unwrap_or("Pack do Studio").to_string(),
        counts: contagens,
        files,
        pack_sha256: sha256_hex(pack_raw),
        created_utc: utc_iso_agora(),
        tool: "astralis-studio V1".to_string(),
    };

    let mut w = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
    let opcoes = zip::write::SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);
    let gravar = |w: &mut zip::ZipWriter<std::io::Cursor<Vec<u8>>>, nome: &str, bytes: &[u8]| -> Result<(), String> {
        w.start_file(nome, opcoes)
            .map_err(|e| format!("Não consegui empacotar \"{nome}\": {e}"))?;
        w.write_all(bytes).map_err(|e| format!("Não consegui empacotar \"{nome}\": {e}"))?;
        Ok(())
    };
    let manifest_raw = serde_json::to_string_pretty(&manifest).map_err(|e| format!("Não consegui montar o manifest: {e}"))? + "\n";
    gravar(&mut w, "manifest.json", manifest_raw.as_bytes())?;
    gravar(&mut w, "data/pack.json", pack_raw)?;
    let mut gravadas: BTreeSet<String> = BTreeSet::new();
    for (path, bytes) in achados {
        let entrada = &stored_as[path];
        if gravadas.contains(entrada) {
            continue; // repetida: já gravada 1x (content-addressed)
        }
        gravar(&mut w, entrada, bytes)?;
        gravadas.insert(entrada.clone());
    }
    if let Some((nome_prev, bytes_prev)) = &preview {
        gravar(&mut w, nome_prev, bytes_prev)?;
    }
    let bytes = w.finish().map_err(|e| format!("Não consegui fechar o .apack: {e}"))?.into_inner();
    if bytes.len() as u64 > MAX_APACK_TOTAL {
        return Err(".apack passa de 250 MB (teto V1) — não empacotei.".to_string());
    }
    Ok(ApackPronto { bytes, manifest, faltando, repetidas })
}

// ---- PASSO 4: copiar assets/* p/ projects/default/<mesmo path> ----

// Escreve cada asset abaixo de `proj` (cria as pastas). Devolve (quantas
// entraram, falhas em PT-BR). Path fora de `assets/` ou com `..` é barrado
// (nunca escreve fora do projeto).
pub fn copiar_assets(proj: &Path, assets: &[(String, Vec<u8>)]) -> (usize, Vec<String>) {
    let mut ok = 0;
    let mut falhas: Vec<String> = Vec::new();
    for (logico, bytes) in assets {
        if !logico.starts_with("assets/") || !zip_seguro(logico) {
            falhas.push(format!("\"{logico}\" fora de assets/ (barrado por segurança) — imagem não copiada."));
            continue;
        }
        let destino = proj.join(logico);
        if let Some(pai) = destino.parent() {
            if std::fs::create_dir_all(pai).is_err() {
                falhas.push(format!("Não consegui criar a pasta de \"{logico}\" — imagem não copiada."));
                continue;
            }
        }
        match std::fs::write(&destino, bytes) {
            Ok(_) => ok += 1,
            Err(_) => falhas.push(format!("Não consegui salvar \"{logico}\" — imagem não copiada.")),
        }
    }
    (ok, falhas)
}

#[cfg(test)]
mod testes_apack {
    use super::*;

    // Monta um zip bruto na mão (para testar o leitor contra manifests
    // inválidos sem passar pelo montador, que só gera válido).
    fn zip_bruto(entradas: &[(&str, &[u8])]) -> Vec<u8> {
        let mut w = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
        let op = zip::write::SimpleFileOptions::default().compression_method(zip::CompressionMethod::Stored);
        for (nome, bytes) in entradas {
            w.start_file(nome, op).unwrap();
            w.write_all(bytes).unwrap();
        }
        w.finish().unwrap().into_inner()
    }

    fn manifest_valido_com(pack_raw: &[u8], extra: serde_json::Value) -> Vec<u8> {
        // Manifest completo e válido, mesclado com `extra` (para adulterar 1 campo).
        let mut m = serde_json::json!({
            "magic": "APACK", "format_version": 1, "schema_version": 1,
            "runtime_version": "1", "author_id": "a", "mode": "aberto",
            "pack_id": "p", "name": "P",
            "counts": {"cartas": 0, "duelistas": 0, "decks": 0, "fusoes_recipes": 0,
                       "fusoes_rules": 0, "equips": 0, "assets": 0, "assets_bytes": 0},
            "files": [{"path": "data/pack.json", "sha256": sha256_hex(pack_raw), "size": pack_raw.len() as u64}],
            "pack_sha256": sha256_hex(pack_raw),
            "created_utc": "2026-09-25T00:00:00Z", "tool": "t"
        });
        for (k, v) in extra.as_object().unwrap() {
            m[k] = v.clone();
        }
        serde_json::to_string(&m).unwrap().into_bytes()
    }

    fn pack_minimo(refs: &[serde_json::Value]) -> (serde_json::Value, Vec<u8>) {
        let mut cartas = vec![serde_json::json!({
            "schema_version": 1, "id": "card_a", "name": "A",
            "card_type": "monster", "monster_type": "warrior", "attribute": "earth",
            "level": 4, "attack": 1500, "defense": 1200, "effects": [], "tags": []
        })];
        for (i, r) in refs.iter().enumerate() {
            let mut c = cartas[0].clone();
            c["id"] = serde_json::json!(format!("card_ref_{i}"));
            c["artwork"] = r.clone();
            cartas.push(c);
        }
        let pack = construir_pack_json("pack_teste", "Pack Teste", cartas, vec![], vec![],
            serde_json::json!({"schema_version": 1, "recipes": [], "rules": []}));
        let raw = (serde_json::to_string_pretty(&pack).unwrap() + "\n").into_bytes();
        (pack, raw)
    }

    #[test]
    fn sha256_vetor_conhecido() {
        assert_eq!(
            sha256_hex(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn base64_vetor_e_roundtrip_com_o_decodificador() {
        assert_eq!(codificar_base64(b"hello"), "aGVsbG8=");
        assert_eq!(codificar_base64(b""), "");
        assert_eq!(codificar_base64(b"a"), "YQ==");
        // O decodificador que o importar_apack usa (main.rs) entende o que geramos.
        let bytes = b"bytes \x00\xff bin\xc3\xa1rios do .apack".to_vec();
        assert_eq!(super::super::decodificar_base64(&codificar_base64(&bytes)).unwrap(), bytes);
    }

    #[test]
    fn zip_seguro_barra_fuga_e_absoluto() {
        assert!(!zip_seguro(""));
        assert!(!zip_seguro("../fora.png"));
        assert!(!zip_seguro("assets/../../fora.png"));
        assert!(!zip_seguro("/absoluto.png"));
        assert!(!zip_seguro("C:/win.png"));
        assert!(!zip_seguro("assets\\..\\fora.png"));
        assert!(zip_seguro("manifest.json"));
        assert!(zip_seguro("data/pack.json"));
        assert!(zip_seguro("assets/cards/x.png"));
    }

    #[test]
    fn refs_acha_strings_assets_aninhadas() {
        let v = serde_json::json!({
            "cartas": [{"artwork": "assets/cards/a.png"}],
            "cenas": {"fundo": "assets/backgrounds/f.png"},
            "nome": "assets_nao_e_ref_sozinha",
            "outra": "assets/"
        });
        let refs = refs_do_pack(&v);
        assert!(refs.contains("assets/cards/a.png"));
        assert!(refs.contains("assets/backgrounds/f.png"));
        assert!(refs.contains("assets/"));
        assert_eq!(refs.len(), 3);
    }

    #[test]
    fn extensao_v1() {
        assert!(extensao_permitida("assets/a.PNG"));
        assert!(extensao_permitida("assets/a.ogg"));
        assert!(!extensao_permitida("assets/a.gif"));
        assert!(!extensao_permitida("assets/a.svg"));
        assert!(!extensao_permitida("assets/sem_ext"));
    }

    #[test]
    fn roundtrip_monta_le_e_dedupica_repetida() {
        let (pack, raw) = pack_minimo(&[
            serde_json::json!("assets/cards/hero.png"),
            serde_json::json!("assets/cards/hero_copia.png"),
            serde_json::json!("assets/cards/faltando.png"),
        ]);
        let png = vec![137, 80, 78, 71, 1, 2, 3];
        let mut achados = BTreeMap::new();
        achados.insert("assets/cards/hero.png".to_string(), png.clone());
        // Mesmos bytes em outro path: grava 1x no zip, volta como 2 cópias.
        achados.insert("assets/cards/hero_copia.png".to_string(), png.clone());
        let pronto = montar_apack(&pack, &raw, &achados, None, "studio", "1").unwrap();
        assert_eq!(pronto.repetidas, 1);
        assert_eq!(pronto.faltando, vec!["assets/cards/faltando.png".to_string()]);
        assert_eq!(pronto.manifest.counts.assets, 2);
        assert_eq!(pronto.manifest.files.iter().filter(|f| f.path.starts_with("assets/")).count(), 2);

        let lido = ler_apack(&pronto.bytes, "teste.apack").unwrap();
        assert_eq!(lido.pack_bytes, raw, "roundtrip tem que preservar o pack byte-idêntico");
        assert_eq!(sha256_hex(&lido.pack_bytes), pronto.manifest.pack_sha256);
        assert_eq!(lido.assets.len(), 2);
        assert_eq!(lido.assets[0].1, png);
        assert_eq!(lido.assets[1].1, png, "repetida volta como cópia em cada path");
        assert_eq!(lido.faltando, vec!["assets/cards/faltando.png".to_string()]);
        assert!(lido.preview.is_none());
    }

    #[test]
    fn ler_recusa_manifest_com_magic_errada() {
        let (_pack, raw) = pack_minimo(&[]);
        let manifest = manifest_valido_com(&raw, serde_json::json!({"magic": "XXXX"}));
        let z = zip_bruto(&[
            ("manifest.json", &manifest),
            ("data/pack.json", &raw),
        ]);
        let r = ler_apack(&z, "x.apack");
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("APACK"));
    }

    #[test]
    fn ler_recusa_hash_quebrado() {
        // Mesmo manifest, bytes adulterados: o hash acusa.
        let (_pack, raw) = pack_minimo(&[serde_json::json!("assets/cards/a.png")]);
        let png = b"conteudo-verdadeiro";
        let mut files = vec![serde_json::json!({"path": "data/pack.json", "sha256": sha256_hex(&raw), "size": raw.len() as u64})];
        files.push(serde_json::json!({"path": "assets/cards/a.png", "sha256": sha256_hex(png), "size": png.len() as u64, "stored_as": "assets/cards/a.png"}));
        let manifest = manifest_valido_com(&raw, serde_json::json!({"files": files}));
        let z = zip_bruto(&[
            ("manifest.json", &manifest),
            ("data/pack.json", &raw),
            ("assets/cards/a.png", b"conteudo-ADULTERADO"),
        ]);
        let r = ler_apack(&z, "x.apack");
        assert!(r.is_err(), "hash quebrado tem que barrar");
        assert!(r.unwrap_err().contains("hash não bate"));
    }

    #[test]
    fn ler_recusa_zipslip_no_nome_do_zip() {
        let (_pack, raw) = pack_minimo(&[]);
        let manifest = manifest_valido_com(&raw, serde_json::json!({}));
        let z = zip_bruto(&[
            ("manifest.json", &manifest),
            ("data/pack.json", &raw),
            ("../fuga.txt", b"x"),
        ]);
        let r = ler_apack(&z, "x.apack");
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("ZipSlip"));
    }

    #[test]
    fn montar_recusa_extensao_proibida_e_asset_grande() {
        let (pack, raw) = pack_minimo(&[serde_json::json!("assets/cards/a.gif")]);
        let mut achados = BTreeMap::new();
        achados.insert("assets/cards/a.gif".to_string(), b"gif".to_vec());
        let r = montar_apack(&pack, &raw, &achados, None, "studio", "1");
        assert!(r.is_err());
        assert!(r.unwrap_err().contains("Extensão proibida"));

        let (pack2, raw2) = pack_minimo(&[serde_json::json!("assets/cards/g.png")]);
        let mut grandes = BTreeMap::new();
        grandes.insert("assets/cards/g.png".to_string(), vec![0u8; MAX_ASSET_BYTES as usize + 1]);
        let r2 = montar_apack(&pack2, &raw2, &grandes, None, "studio", "1");
        assert!(r2.is_err());
        assert!(r2.unwrap_err().contains("5 MB"));
    }

    #[test]
    fn construir_pack_json_tem_chaves_pt() {
        let p = construir_pack_json("id1", "Nome",
            vec![serde_json::json!({"id": "c"})], vec![], vec![],
            serde_json::json!({"schema_version": 1, "recipes": [], "rules": []}));
        assert_eq!(p["schema_version"], serde_json::json!(1));
        assert_eq!(p["cartas"].as_array().unwrap().len(), 1);
        assert!(p.get("duelistas").and_then(|v| v.as_array()).is_some());
        assert!(p.get("decks").and_then(|v| v.as_array()).is_some());
        assert!(p.get("fusoes").and_then(|v| v.as_object()).is_some());
        assert_eq!(p["equips"], serde_json::json!([]));
    }

    #[test]
    fn copiar_assets_escreve_e_barra_fuga() {
        let base = std::env::temp_dir().join("astralis-studio-test-apack-copy");
        let _ = std::fs::remove_dir_all(&base);
        std::fs::create_dir_all(&base).unwrap();
        let (ok, falhas) = copiar_assets(&base, &[
            ("assets/cards/x.png".to_string(), b"png".to_vec()),
            ("../fora.png".to_string(), b"mal".to_vec()),
        ]);
        assert_eq!(ok, 1);
        assert_eq!(falhas.len(), 1);
        assert!(base.join("assets/cards/x.png").is_file());
        assert!(!base.join("fora.png").exists());
        assert!(!base.parent().unwrap().join("fora.png").exists());
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn utc_iso_tem_formato() {
        let s = utc_iso_agora();
        assert_eq!(s.len(), 20, "{s}");
        assert!(s.ends_with('Z'), "{s}");
        assert_eq!(&s[10..11], "T", "{s}");
    }
}
