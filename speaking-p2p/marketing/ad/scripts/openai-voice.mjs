// Voice-over with OpenAI (D-056): gpt-4o-mini-tts for a warm, human voice, and
// whisper-1 word timestamps so the subtitles can light up the word being said.
// The key is read from speaking-p2p/.env (never printed); every call is logged
// with its estimated cost in .openai-spend.json (gitignored).
//
//   node scripts/openai-voice.mjs samples            -> out/samples/<voice>.wav
//   node scripts/openai-voice.mjs render <voice>     -> public/vo/line<n>.wav + src/timing.json
//   node scripts/openai-voice.mjs retime             -> word times again from the same WAVs
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LINES, INSTRUCTIONS } from './script.mjs';

const HERE = join(dirname(fileURLToPath(import.meta.url)), '..');
const ENV = join(HERE, '..', '..', '.env');
const LEDGER = join(HERE, '.openai-spend.json');
const CAP_USD = 0.5; // this script never spends more than this in total

// Estimates from OpenAI's price list: speech ~ $0.015 per minute of audio,
// whisper-1 $0.006 per minute.
const TTS_PER_MIN = 0.015;
const STT_PER_MIN = 0.006;

function key() {
  const line = readFileSync(ENV, 'utf8').split(/\r?\n/).find((l) => l.startsWith('OPENAI_API_KEY='));
  if (!line) throw new Error('OPENAI_API_KEY not found in speaking-p2p/.env');
  return line.slice('OPENAI_API_KEY='.length).trim();
}

function ledger() {
  return existsSync(LEDGER) ? JSON.parse(readFileSync(LEDGER, 'utf8')) : { totalUsd: 0, calls: [] };
}

function spend(what, usd) {
  const l = ledger();
  l.totalUsd = +(l.totalUsd + usd).toFixed(5);
  l.calls.push({ at: new Date().toISOString(), what, usd: +usd.toFixed(5) });
  writeFileSync(LEDGER, JSON.stringify(l, null, 2));
}

function guard() {
  if (ledger().totalUsd >= CAP_USD) throw new Error(`Spending cap of $${CAP_USD} reached (see .openai-spend.json)`);
}

/// Length of a 16-bit PCM WAV in seconds (OpenAI returns 24 kHz mono).
function wavSeconds(buf) {
  const rate = buf.readUInt32LE(24);
  const channels = buf.readUInt16LE(22);
  const bits = buf.readUInt16LE(34);
  let off = 12;
  while (off < buf.length - 8) {
    const id = buf.toString('ascii', off, off + 4);
    const size = buf.readUInt32LE(off + 4);
    if (id === 'data') {
      // Streams may leave the size at 0xFFFFFFFF: use what is actually there.
      const bytes = Math.min(size, buf.length - off - 8);
      return bytes / (rate * channels * (bits / 8));
    }
    off += 8 + size;
  }
  throw new Error('no data chunk');
}

async function speak(text, voice) {
  guard();
  const r = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key()}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-4o-mini-tts', voice, input: text, instructions: INSTRUCTIONS, response_format: 'wav' }),
  });
  if (!r.ok) throw new Error(`speech ${r.status}: ${(await r.text()).slice(0, 300)}`);
  const buf = Buffer.from(await r.arrayBuffer());
  const secs = wavSeconds(buf);
  spend(`tts ${voice} ${secs.toFixed(1)}s`, (secs / 60) * TTS_PER_MIN);
  return { buf, secs };
}

async function words(buf, secs, prompt) {
  guard();
  const form = new FormData();
  form.append('file', new Blob([buf], { type: 'audio/wav' }), 'line.wav');
  form.append('model', 'whisper-1');
  form.append('language', 'es');
  form.append('prompt', prompt);
  form.append('response_format', 'verbose_json');
  form.append('timestamp_granularities[]', 'word');
  const r = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key()}` },
    body: form,
  });
  if (!r.ok) throw new Error(`transcription ${r.status}: ${(await r.text()).slice(0, 300)}`);
  spend(`whisper ${secs.toFixed(1)}s`, (Math.max(secs, 1) / 60) * STT_PER_MIN);
  return (await r.json()).words ?? [];
}

const norm = (w) => w.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9ñ]/g, '');

/// Times for the words of the SCRIPT (its spelling and punctuation), taken from
/// whisper's words in order; a word whisper heard differently gets its time by
/// interpolation between its neighbours.
function align(text, heard, secs) {
  const shown = text.split(/\s+/).filter(Boolean);
  const out = shown.map((w) => ({ w, start: null, end: null }));
  let j = 0;
  for (const o of out) {
    const target = norm(o.w);
    for (let k = j; k < Math.min(j + 4, heard.length); k++) {
      if (norm(heard[k].word) === target) {
        o.start = heard[k].start;
        o.end = heard[k].end;
        j = k + 1;
        break;
      }
      // "MirloTalk" may be heard as "Mirlo" + "Talk".
      if (k + 1 < heard.length && norm(heard[k].word + heard[k + 1].word) === target) {
        o.start = heard[k].start;
        o.end = heard[k + 1].end;
        j = k + 2;
        break;
      }
    }
  }
  // A word cannot start before the unheard words in front of it were said
  // (~50 ms per letter): whisper sometimes drops a word and puts the next at 0.
  let since = 0;
  let pending = 0;
  for (const o of out) {
    if (o.start === null) {
      pending += o.w.length;
      continue;
    }
    if (o.start - since < 0.05 * pending) {
      o.start = o.end = null;
      pending += o.w.length;
      continue;
    }
    since = o.end;
    pending = 0;
  }
  // Fill the gaps proportionally to word length.
  for (let i = 0; i < out.length; i++) {
    if (out[i].start !== null) continue;
    let a = i - 1;
    while (a >= 0 && out[a].start === null) a--;
    let b = i;
    while (b < out.length && out[b].start === null) b++;
    const from = a >= 0 ? out[a].end : 0;
    const to = b < out.length ? out[b].start : secs;
    const span = out.slice(a + 1, b);
    const total = span.reduce((n, s) => n + s.w.length, 0);
    let t = from;
    for (const s of span) {
      const d = ((to - from) * s.w.length) / total;
      s.start = t;
      s.end = t + d;
      t += d;
    }
  }
  return out.map((o) => ({ w: o.w, start: +o.start.toFixed(3), end: +o.end.toFixed(3) }));
}

const [, , cmd, voiceArg] = process.argv;
if (cmd === 'samples') {
  const dir = join(HERE, 'out', 'samples');
  mkdirSync(dir, { recursive: true });
  const text = `${LINES[0]} ${LINES[1]}`;
  for (const voice of ['marin', 'cedar', 'coral']) {
    const { buf, secs } = await speak(text, voice);
    writeFileSync(join(dir, `${voice}.wav`), buf);
    console.log(voice, secs.toFixed(1), 's');
  }
} else if (cmd === 'render') {
  const voice = voiceArg ?? 'marin';
  mkdirSync(join(HERE, 'public', 'vo'), { recursive: true });
  const lines = [];
  for (const [i, text] of LINES.entries()) {
    const { buf, secs } = await speak(text, voice);
    const file = `vo/line${i + 1}.wav`;
    writeFileSync(join(HERE, 'public', file), buf);
    const heard = await words(buf, secs, text);
    lines.push({ text, file, seconds: +secs.toFixed(3), words: align(text, heard, secs), heard });
    console.log(`${i + 1}: ${secs.toFixed(1)} s  ${text}`);
  }
  writeFileSync(join(HERE, 'src', 'timing.json'), JSON.stringify({ voice, lines }, null, 2));
} else if (cmd === 'retime') {
  // Re-transcribes the WAVs already in public/vo (no new speech is paid for).
  const t = JSON.parse(readFileSync(join(HERE, 'src', 'timing.json'), 'utf8'));
  for (const l of t.lines) {
    const buf = readFileSync(join(HERE, 'public', l.file));
    l.heard = await words(buf, l.seconds, l.text);
    l.words = align(l.text, l.heard, l.seconds);
  }
  writeFileSync(join(HERE, 'src', 'timing.json'), JSON.stringify(t, null, 2));
} else {
  console.log('usage: node scripts/openai-voice.mjs samples | render <voice> | retime');
}
console.log(`OpenAI spent by this script so far: $${ledger().totalUsd.toFixed(4)}`);
