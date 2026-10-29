// Authoring compiler: turns the terse specs in scripts/content/authoring/*.txt
// into content/exams/{level}/*.json, content/diagrams/*.json, content/photos.json,
// content/photos/LISTA_DE_FOTOS.md and the matching entries of content/index.json.
// Idempotent: regenerates every exam whose id looks like {level}-eNN-*, and keeps
// the real audioMs of steps whose text did not change (tts/generate.py writes it).
//
// deno run --allow-read --allow-write scripts/content/author.ts
//
// Spec format (one block per exam, blank lines ignored, text must not contain "||" or ";"):
//   === B2 | Topic title | short theme used by the Part 4 intro
//   P1: question                       (alternates A, B, A, B...)
//   P2: photo ; photo || task || partner follow-up       (B2: 2 photos, C1: 3 photos)
//   P2: photo || what the photo shows                    (B1: 1 photo)
//   P3: lead-in (B2/C1) or full reader text (B1) || central question || p1 ; p2 ; p3 ; p4 ; p5 || decision question
//   P4: both|A|B: question
//   (two P2 lines: the first for candidate A, the second for candidate B)
import { CONTENT_DIR } from "./lib.ts";
import {
  audioPath,
  ContentIndex,
  estimateAudioMs,
  type Level,
} from "../../apps/backend/supabase/functions/_shared/exam/schema.ts";

const AUTHORING = new URL("./authoring/", import.meta.url);
const PHOTOS_PER_TURN: Record<Level, number> = { B1: 1, B2: 2, C1: 3 };

type P2 = { photos: string[]; task: string; follow?: string };
type P3 = { text: string; central: string; prompts: string[]; decision: string };
type Spec = {
  level: Level;
  n: number;
  title: string;
  theme: string;
  p1: string[];
  p2: P2[];
  p3: P3;
  p4: { who: "both" | "A" | "B"; q: string }[];
};

const slugify = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
const nn = (n: number) => String(n).padStart(2, "0");
const examId = (s: Spec) => `${s.level.toLowerCase()}-e${nn(s.n)}-${slugify(s.title)}`.slice(0, 62).replace(/-+$/, "");
export const photoId = (level: Level, n: number, cand: "a" | "b", k: number) =>
  `${level.toLowerCase()}-e${nn(n)}-${cand}${k}`;

function parse(text: string, file: string): Spec[] {
  const specs: Spec[] = [];
  let cur: Spec | null = null;
  text.split(/\r?\n/).forEach((raw, i) => {
    const line = raw.trim();
    if (!line || line.startsWith("#")) return;
    const where = `${file}:${i + 1}`;
    if (line.startsWith("===")) {
      const [head, title, theme] = line.slice(3).split("|").map((s) => s.trim());
      const [level, n] = head.split(/\s+/);
      if (!["B1", "B2", "C1"].includes(level) || !Number(n) || !title || !theme) throw new Error(`${where}: bad header`);
      cur = { level: level as Level, n: Number(n), title, theme, p1: [], p2: [], p3: null as unknown as P3, p4: [] };
      specs.push(cur);
      return;
    }
    if (!cur) throw new Error(`${where}: line before any header`);
    const m = line.match(/^(P[1-4]):\s*(.*)$/);
    if (!m) throw new Error(`${where}: unknown line`);
    const body = m[2];
    const cols = body.split("||").map((s) => s.trim());
    if (m[1] === "P1") cur.p1.push(body);
    else if (m[1] === "P2") {
      const photos = cols[0].split(";").map((s) => s.trim());
      if (photos.length !== PHOTOS_PER_TURN[cur.level]) throw new Error(`${where}: ${cur.level} needs ${PHOTOS_PER_TURN[cur.level]} photos`);
      if (cur.level === "B1" ? cols.length !== 2 : cols.length !== 3) throw new Error(`${where}: wrong P2 columns`);
      cur.p2.push({ photos, task: cols[1], follow: cols[2] });
    } else if (m[1] === "P3") {
      const prompts = cols[2]?.split(";").map((s) => s.trim());
      if (cols.length !== 4 || prompts.length !== 5) throw new Error(`${where}: P3 needs 4 columns and 5 prompts`);
      cur.p3 = { text: cols[0], central: cols[1], prompts, decision: cols[3] };
    } else {
      const q = body.match(/^(both|A|B):\s*(.+)$/);
      if (!q) throw new Error(`${where}: P4 needs both|A|B: question`);
      cur.p4.push({ who: q[1] as "both" | "A" | "B", q: q[2] });
    }
  });
  for (const s of specs) {
    const id = `${s.level} ${s.n}`;
    if (s.p2.length !== 2) throw new Error(`${id}: needs 2 P2 lines`);
    if (!s.p3) throw new Error(`${id}: missing P3`);
    if (s.p1.length < 4 || s.p4.length < 4) throw new Error(`${id}: too few P1/P4 lines`);
  }
  return specs;
}

const greeting = (n: number) => ["Good morning.", "Good afternoon.", "Good evening."][n % 3];
const lcFirst = (s: string) => s.charAt(0).toLowerCase() + s.slice(1);

type Step = Record<string, unknown> & { id: string; text: string };

function build(s: Spec): { exam: unknown; diagram: unknown; photos: Record<string, string>; assetsA: string[]; assetsB: string[] } {
  const id = examId(s);
  const step = (partial: Record<string, unknown> & { id: string; text: string }): Step => ({
    ...partial,
    audio: audioPath(s.level, id, partial.id),
    audioMs: 0,
  });
  const photos: Record<string, string> = {};
  const assetsFor = (cand: "a" | "b", descs: string[]) =>
    descs.map((d, i) => {
      const pid = photoId(s.level, s.n, cand, i + 1);
      photos[pid] = d;
      return pid;
    });
  const assetsA = assetsFor("a", s.p2[0].photos);
  const assetsB = assetsFor("b", s.p2[1].photos);

  // Part 1
  const intro1 = {
    B1: `${greeting(s.n)} In this test, I'm going to ask you some questions about yourselves. Let's begin.`,
    B2: `${greeting(s.n)} First of all, we'd like to know something about you.`,
    C1: `${greeting(s.n)} First of all, we'd like to know a little about you.`,
  }[s.level];
  const part1 = [step({ id: "p1-intro", kind: "narration", text: intro1 })];
  s.p1.forEach((q, i) => {
    const target = i % 2 === 0 ? "A" : "B";
    const dur = s.level === "B1" ? 25 : i < 2 ? 25 : 30;
    part1.push(step({ id: `p1-q${i + 1}`, kind: "turn", target, text: `Candidate ${target}, ${q}`, durationSec: dur }));
  });

  // Part 2
  const intro2 = {
    B1: "Now I'm going to give each of you a photograph. I'd like you to talk about it on your own for about one minute.",
    B2: "In this part of the test, I'm going to give each of you two photographs. I'd like you to talk about them on your own for about a minute, and also to answer a question about your partner's photographs.",
    C1: "In this part of the test, I'm going to give each of you three pictures. I'd like you to talk about two of them on your own for about a minute, and also to answer a question briefly about your partner's pictures.",
  }[s.level];
  const part2 = [step({ id: "p2-intro", kind: "narration", text: intro2 })];
  const cands: ["A" | "B", "a" | "b", string[], P2][] = [["A", "a", assetsA, s.p2[0]], ["B", "b", assetsB, s.p2[1]]];
  for (const [c, lower, assets, p2] of cands) {
    const other = c === "A" ? "B" : "A";
    if (s.level === "B1") {
      part2.push(step({
        id: `p2-${lower}`, kind: "turn", target: c, durationSec: 60, assets,
        text: `Candidate ${c}, here is your photograph. It shows ${p2.task}. Please tell us what you can see.`,
      }));
    } else {
      part2.push(step({ id: `p2-${lower}`, kind: "turn", target: c, durationSec: 60, assets, text: `Candidate ${c}, ${p2.task}` }));
      part2.push(step({ id: `p2-${lower}-follow`, kind: "turn", target: other, durationSec: 30, text: `Candidate ${other}, ${p2.follow}` }));
    }
  }

  // Part 3
  const diagramId = id;
  const diagram = {
    id: diagramId,
    centralQuestion: s.p3.central,
    prompts: s.p3.prompts,
    decisionQuestion: s.p3.decision,
  };
  const part3 = s.level === "B1"
    ? [
      step({ id: "p3-intro", kind: "narration", text: "Now, in this part of the test, you're going to talk about something together for about two or three minutes." }),
      step({ id: "p3-discuss", kind: "open", target: "both", durationSec: 150, diagram: diagramId, text: s.p3.text }),
    ]
    : [
      step({ id: "p3-intro", kind: "narration", text: `Now I'd like you to talk about something together for about two minutes. ${s.p3.text}` }),
      step({ id: "p3-discuss", kind: "open", target: "both", durationSec: 120, diagram: diagramId, text: `Talk to each other about this question: ${s.p3.central}` }),
      step({ id: "p3-decide", kind: "open", target: "both", durationSec: 60, diagram: diagramId, text: `Now you have about a minute to decide together. ${s.p3.decision}` }),
    ];

  // Part 4
  const part4 = [step({ id: "p4-intro", kind: "narration", text: `Now I'd like to ask you some more questions about ${s.theme}.` })];
  s.p4.forEach((p, i) => {
    const single = p.who !== "both";
    const dur = s.level === "B1" ? (single ? 40 : 45) : single ? 45 : 50;
    part4.push(step({
      id: `p4-q${i + 1}`, kind: "open", target: p.who, durationSec: dur,
      text: single ? `Candidate ${p.who}, ${lcFirst(p.q)}` : p.q,
    }));
  });

  const exam = {
    id, level: s.level, version: 1, topic: s.title,
    parts: [
      { index: 1, title: "Interview", steps: part1 },
      { index: 2, title: s.level === "B1" ? "Photograph" : "Long turn", steps: part2 },
      { index: 3, title: "Collaborative task", steps: part3 },
      { index: 4, title: "Discussion", steps: part4 },
    ],
  };
  return { exam, diagram, photos, assetsA, assetsB };
}

async function readJsonIfExists(url: URL): Promise<any | null> {
  try {
    return JSON.parse(await Deno.readTextFile(url));
  } catch {
    return null;
  }
}

const GENERATED = /^(b1|b2|c1)-e\d\d-/;

if (import.meta.main) {
  const specs: Spec[] = [];
  for await (const f of Deno.readDir(AUTHORING)) {
    if (f.name.endsWith(".txt")) specs.push(...parse(await Deno.readTextFile(new URL(f.name, AUTHORING)), f.name));
  }
  specs.sort((a, b) => a.level.localeCompare(b.level) || a.n - b.n);
  const seen = new Set<string>();
  for (const s of specs) {
    const k = `${s.level}${s.n}`;
    if (seen.has(k)) throw new Error(`duplicate spec ${s.level} ${s.n}`);
    seen.add(k);
  }

  const indexUrl = new URL("index.json", CONTENT_DIR);
  const index = ContentIndex.parse(JSON.parse(await Deno.readTextFile(indexUrl)));
  index.exams = index.exams.filter((e) => !GENERATED.test(e.id));
  index.diagrams = index.diagrams.filter((d) => !GENERATED.test(d));

  // Drop the files of previously generated exams that no longer have a spec.
  for (const level of ["B1", "B2", "C1"]) {
    for await (const f of Deno.readDir(new URL(`exams/${level}/`, CONTENT_DIR))) {
      if (GENERATED.test(f.name) && !specs.some((s) => `${examId(s)}.json` === f.name)) {
        await Deno.remove(new URL(`exams/${level}/${f.name}`, CONTENT_DIR));
      }
    }
  }
  for await (const f of Deno.readDir(new URL("diagrams/", CONTENT_DIR))) {
    const id = f.name.replace(/\.json$/, "");
    if (GENERATED.test(id) && !specs.some((s) => examId(s) === id)) await Deno.remove(new URL(`diagrams/${f.name}`, CONTENT_DIR));
  }

  const photosUrl = new URL("photos.json", CONTENT_DIR);
  const photosPrev: Record<string, string> = (await readJsonIfExists(photosUrl)) ?? {};
  const photos: Record<string, string> = {};
  for (const [k, v] of Object.entries(photosPrev)) if (!GENERATED.test(k)) photos[k] = v;

  const listing: Record<Level, string[]> = { B1: [], B2: [], C1: [] };
  for (const s of specs) {
    const b = build(s);
    const exam = b.exam as { id: string; parts: { steps: Step[] }[] };
    const url = new URL(`exams/${s.level}/${exam.id}.json`, CONTENT_DIR);
    const prev = await readJsonIfExists(url);
    const prevSteps = new Map<string, { text: string; audioMs: number }>();
    for (const p of prev?.parts ?? []) for (const st of p.steps) prevSteps.set(st.id, st);
    for (const p of exam.parts) {
      for (const st of p.steps) {
        const old = prevSteps.get(st.id);
        st.audioMs = old && old.text === st.text && old.audioMs ? old.audioMs : estimateAudioMs(st.text);
      }
    }
    await Deno.writeTextFile(url, JSON.stringify(exam, null, 2) + "\n");
    await Deno.writeTextFile(new URL(`diagrams/${exam.id}.json`, CONTENT_DIR), JSON.stringify(b.diagram, null, 2) + "\n");
    index.exams.push({ id: exam.id, level: s.level, version: 1, topic: s.title });
    index.diagrams.push(exam.id);
    Object.assign(photos, b.photos);

    const rows = [...b.assetsA.map((a) => ["A", a] as const), ...b.assetsB.map((a) => ["B", a] as const)];
    listing[s.level].push(
      `### ${s.level} · Examen ${nn(s.n)} — ${s.title}\n\n| Candidato | Archivo (sin extensión) | Qué debe mostrar la foto |\n|---|---|---|\n` +
        rows.map(([c, a]) => `| ${c} | \`${a}\` | ${b.photos[a]} |`).join("\n") + "\n",
    );
  }
  index.exams.sort((a, b) => a.level.localeCompare(b.level) || a.id.localeCompare(b.id));
  index.diagrams.sort();
  await Deno.writeTextFile(indexUrl, JSON.stringify(index, null, 2) + "\n");
  await Deno.writeTextFile(photosUrl, JSON.stringify(Object.fromEntries(Object.entries(photos).sort(([a], [b]) => a.localeCompare(b))), null, 2) + "\n");

  const total = Object.values(listing).reduce((n, l) => n + l.length, 0);
  const md = [
    "# Lista de fotos de la Parte 2",
    "",
    `Total de exámenes con fotos: ${total}. Cada fila es una imagen vacía en la app hasta que exista el archivo.`,
    "",
    "## Cómo usarla",
    "",
    "1. Busca o genera la imagen según la columna *Qué debe mostrar la foto*.",
    "2. Guárdala con **exactamente** el nombre de la columna *Archivo* + su extensión (`.jpg`, `.jpeg`, `.png` o `.webp`), por ejemplo `b1-e01-a1.jpg`.",
    "3. Pégala en `content/photos/` (esta carpeta).",
    "4. Ejecuta `python scripts/content/build-photos.py` (las comprime a WebP de 1024 px, sin metadatos) y luego `scripts/content/upload-r2.sh img`. La app las descarga de R2 en el lobby; no van en el bundle.",
    "",
    "Convención del nombre: `{nivel}-e{número de examen}-{candidato}{n}`. `a`/`b` es el candidato que recibe la foto y `n` el orden",
    "dentro de su turno (B1: 1 foto por candidato; B2: 2; C1: 3). Formato recomendado: horizontal 4:3. El tamaño da igual: el script las reduce y comprime.",
    "",
    "> Consejo: en B2 las dos fotos de un mismo candidato se comparan y en C1 se eligen 2 de 3, así que deben contrastar entre sí (lugar, edad, actividad, ambiente).",
    "",
    ...(["B1", "B2", "C1"] as Level[]).flatMap((l) => [`## Nivel ${l}`, "", ...listing[l]]),
    "## Exámenes originales (los 3 primeros)",
    "",
    "| Archivo (sin extensión) | Qué debe mostrar la foto |",
    "|---|---|",
    ...Object.entries(photos).filter(([k]) => !GENERATED.test(k)).map(([k, v]) => `| \`${k}\` | ${v} |`),
    "",
  ].join("\n");
  await Deno.mkdir(new URL("photos/", CONTENT_DIR), { recursive: true });
  await Deno.writeTextFile(new URL("photos/LISTA_DE_FOTOS.md", CONTENT_DIR), md);
  console.log(`generated ${specs.length} exams, ${Object.keys(photos).length} photo slots`);
}
