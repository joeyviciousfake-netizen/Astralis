// Sincroniza o dado do repo para o snapshot usado pelo build estático.
// Lê (somente leitura): schemas/examples/cards/*.json, effects.json,
// duelists/, decks/ e fusions.json (só contagem).
// Escreve (gerado, ignorado no git): astralis-studio/src/generated/cards-snapshot.json
// Roda sozinho via `predev` / `prebuild` (npm install + npm run dev/build).
//
// ENXUTO (pós-pack FM, 762 cartas + 25 mil fusões): o snapshot NÃO inclui as
// receitas de fusão (só recipe_count/rule_count) e sai em JSON compacto sem
// strings vazias repetidas (description/artwork/password vazios são omitidos
// — o frontend trata ausente como ""). Antes: 4.7MB pretty; agora: ~300KB.
const fs = require('node:fs');
const path = require('node:path');

const STUDIO = path.resolve(__dirname, '..');
const CARDS_DIR = path.resolve(STUDIO, '..', 'schemas', 'examples', 'cards');
const DUELISTS_DIR = path.resolve(STUDIO, '..', 'schemas', 'examples', 'duelists');
const DECKS_DIR = path.resolve(STUDIO, '..', 'schemas', 'examples', 'decks');
const EFFECTS_FILE = path.resolve(STUDIO, '..', 'schemas', 'examples', 'effects.json');
const FUSIONS_FILE = path.resolve(STUDIO, '..', 'schemas', 'examples', 'fusions.json');
const OUT_DIR = path.resolve(STUDIO, 'src', 'generated');
const OUT_FILE = path.resolve(OUT_DIR, 'cards-snapshot.json');

// Campos vazios que só incham o snapshot: ausente = "" no frontend (?? "").
function enxugarCarta(data) {
  const o = { ...data };
  for (const k of ['description', 'artwork', 'password']) {
    if (o[k] === '') delete o[k];
  }
  if (Array.isArray(o.effects) && o.effects.length === 0) delete o.effects;
  if (Array.isArray(o.tags) && o.tags.length === 0) delete o.tags;
  return o;
}

const cards = fs
  .readdirSync(CARDS_DIR)
  .filter((f) => f.endsWith('.json'))
  .sort()
  .map((file) => ({ file, data: enxugarCarta(JSON.parse(fs.readFileSync(path.join(CARDS_DIR, file), 'utf8'))) }));

let effects = [];
try {
  const raw = JSON.parse(fs.readFileSync(EFFECTS_FILE, 'utf8'));
  effects = Array.isArray(raw.effects) ? raw.effects : [];
} catch {
  effects = [];
}

// Duelistas: somente leitura (nomes para a aba "Duelistas"). Sem editar por aqui (R1/R4).
let duelists = [];
try {
  duelists = fs
    .readdirSync(DUELISTS_DIR)
    .filter((f) => f.endsWith('.json'))
    .sort()
    .map((file) => ({ file, data: JSON.parse(fs.readFileSync(path.join(DUELISTS_DIR, file), 'utf8')) }));
} catch {
  duelists = [];
}

// Decks: somente leitura (aba "Duelistas" mostra o deck de cada um). Sem editar (R1/R4).
let decks = [];
try {
  decks = fs
    .readdirSync(DECKS_DIR)
    .filter((f) => f.endsWith('.json'))
    .sort()
    .map((file) => ({ file, data: JSON.parse(fs.readFileSync(path.join(DECKS_DIR, file), 'utf8')) }));
} catch {
  decks = [];
}

// Fusões: SÓ CONTAGEM no snapshot. As 25 mil receitas ficam fora do bundle:
// no app elas chegam via comando Tauri `ler_fusoes` (só quando a aba Fusões
// abre); no navegador a aba Fusões avisa para abrir via app.bat.
let fusions = { schema_version: 1, recipe_count: 0, rule_count: 0 };
try {
  const raw = JSON.parse(fs.readFileSync(FUSIONS_FILE, 'utf8'));
  fusions = {
    schema_version: 1,
    recipe_count: Array.isArray(raw.recipes) ? raw.recipes.length : 0,
    rule_count: Array.isArray(raw.rules) ? raw.rules.length : 0,
  };
} catch {
  fusions = { schema_version: 1, recipe_count: 0, rule_count: 0 };
}

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.writeFileSync(
  OUT_FILE,
  JSON.stringify({ syncedAt: new Date().toISOString(), cards, effects, duelists, decks, fusions }) + '\n',
  'utf8'
);
const bytes = fs.statSync(OUT_FILE).size;
console.log(`[sync-cards] ${cards.length} cartas + ${effects.length} efeitos + ${duelists.length} duelistas + ${decks.length} decks + ${fusions.recipe_count} receitas (só contagem) -> src/generated/cards-snapshot.json (${(bytes / 1024).toFixed(0)} KB enxuto)`);
