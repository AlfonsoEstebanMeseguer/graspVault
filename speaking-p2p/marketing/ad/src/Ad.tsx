// MirloTalk ad, in Spanish (D-056). The app's own colours and fonts (Design
// 2.0). Three fixed bands, all centred with the same margin on both sides:
// headline (top), visual (middle) and subtitles (bottom, always on screen,
// the word being said glows). Every scene lasts as long as its line of the
// voice-over, and word times come from whisper (src/timing.json).
import React, { useEffect, useState } from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  Img,
  Sequence,
  continueRender,
  delayRender,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import timing from './timing.json';

export const FPS = 30;
const LEAD = 0.4; // silence before the first line
const GAP = 0.35; // breath between lines
const HOLD = 2.2; // logo on screen after the last line

const W = 1080;
const SIDE = 80; // same margin on both sides, everywhere
const HEAD_TOP = 170; // headline band
const VISUAL_TOP = 460; // visual band: 460 .. 1400
const VISUAL_H = 940;
const SUBS_TOP = 1470; // subtitle band: from here down, never over the visual

const C = {
  ink: '#0B0E14',
  raised: '#1B2030',
  text: '#F2F4F8',
  muted: '#A9B1C3',
  faint: '#7D8598',
  cobalt: '#3F62F5',
  link: '#9DB0FF',
  a: '#7C8CFF',
  b: '#FF9B5E',
  onRole: '#0B0E14',
  b1: '#3CC8A4',
  b2: '#5BB8FF',
  c1: '#E07BC0',
};
const SANS = 'Instrument Sans';
const MONO = 'Plex Mono';

type Word = { w: string; start: number; end: number };
type Line = { text: string; file: string; seconds: number; words: Word[] };
const LINES = timing.lines as Line[];

/// Start frame and length of each scene, from the real voice-over lengths.
/// [audioAt] is where the line starts inside its scene.
export function scenePlan() {
  const lead = Math.round(LEAD * FPS);
  let at = 0;
  const scenes = LINES.map((l, i) => {
    const last = i === LINES.length - 1;
    const pre = i === 0 ? lead : 0;
    const frames = pre + Math.ceil((l.seconds + (last ? HOLD : GAP)) * FPS);
    const s = { from: at, frames, audioAt: pre, line: l };
    at += frames;
    return s;
  });
  return { scenes, total: at };
}

// ------------------------------------------------------------------ helpers
function useFonts() {
  const [handle] = useState(() => delayRender('fonts'));
  useEffect(() => {
    const faces = [
      new FontFace(SANS, `url(${staticFile('fonts/InstrumentSans-600.ttf')})`, { weight: '600' }),
      new FontFace(SANS, `url(${staticFile('fonts/InstrumentSans-700.ttf')})`, { weight: '700' }),
      new FontFace(MONO, `url(${staticFile('fonts/IBMPlexMono-600.ttf')})`, { weight: '600' }),
    ];
    const fonts = document.fonts as unknown as { add: (f: FontFace) => void };
    Promise.all(faces.map((f) => f.load().then((l) => fonts.add(l)))).then(() => continueRender(handle));
  }, [handle]);
}

/// 0 -> 1 with a soft spring, starting at [delay] frames.
function useIn(delay = 0, damping = 18) {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return spring({ frame: frame - delay, fps, config: { damping, stiffness: 140, mass: 0.9 } });
}

const Fade: React.FC<{ frames: number; children: React.ReactNode }> = ({ frames, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 6, frames - 7, frames], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

/// A band of the screen: full width minus the same margin on both sides, centred.
const Band: React.FC<{ top: number; height?: number; children: React.ReactNode }> = ({ top, height, children }) => (
  <div
    style={{
      position: 'absolute',
      top,
      left: SIDE,
      width: W - 2 * SIDE,
      height,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      textAlign: 'center',
    }}
  >
    {children}
  </div>
);

const Headline: React.FC<{ text: string; kicker?: string; size?: number }> = ({ text, kicker, size = 84 }) => {
  const p = useIn(2);
  return (
    <Band top={HEAD_TOP} height={260}>
      {kicker && (
        <div style={{ fontFamily: SANS, fontWeight: 600, fontSize: 30, letterSpacing: 4, color: C.link, marginBottom: 18, opacity: p }}>
          {kicker.toUpperCase()}
        </div>
      )}
      <div
        style={{
          fontFamily: SANS,
          fontWeight: 700,
          fontSize: size,
          lineHeight: 1.05,
          letterSpacing: -2,
          color: C.text,
          opacity: p,
          transform: `translateY(${(1 - p) * 30}px)`,
        }}
      >
        {text}
      </div>
    </Band>
  );
};

/// A phone with a real screenshot of the app, centred in the visual band.
const Phone: React.FC<{ src: string; delay?: number; tilt?: number }> = ({ src, delay = 0, tilt = 0 }) => {
  const p = useIn(delay, 20);
  const h = VISUAL_H - 20;
  const w = h * (786 / 1702) + 24;
  return (
    <div
      style={{
        position: 'absolute',
        top: VISUAL_TOP + 10 + (1 - p) * 200,
        left: (W - w) / 2,
        width: w,
        height: h + 24,
        borderRadius: 60,
        padding: 12,
        background: '#05070B',
        border: `2px solid ${C.raised}`,
        boxShadow: '0 40px 90px rgba(0,0,0,0.6)',
        opacity: p,
        transform: `rotate(${tilt * p}deg)`,
      }}
    >
      <Img src={staticFile(`screens/${src}.png`)} style={{ width: '100%', height: '100%', borderRadius: 48, objectFit: 'cover', objectPosition: 'top' }} />
    </div>
  );
};

const Chip: React.FC<{ label: string; color: string; delay: number; fill?: boolean; size?: number }> = ({ label, color, delay, fill, size = 40 }) => {
  const p = useIn(delay, 12);
  return (
    <div
      style={{
        fontFamily: SANS,
        fontWeight: 700,
        fontSize: size,
        padding: '16px 32px',
        borderRadius: 999,
        color: fill ? C.onRole : color,
        background: fill ? color : `${color}22`,
        border: `2px solid ${color}66`,
        transform: `scale(${0.6 + 0.4 * p})`,
        opacity: p,
      }}
    >
      {label}
    </div>
  );
};

const Row: React.FC<{ children: React.ReactNode; gap?: number }> = ({ children, gap = 24 }) => (
  <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap, flexWrap: 'wrap' }}>{children}</div>
);

const People: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 64 64" fill="#fff">
    <circle cx="21" cy="20" r="9" />
    <path d="M5 50c0-9 7-15 16-15s16 6 16 15v2H5z" />
    <circle cx="44" cy="22" r="8" opacity="0.8" />
    <path d="M33 52c0-8 5-14 11-14s15 5 15 13v1z" opacity="0.8" />
  </svg>
);

/// Home's "Buscar pareja": cobalt circle with mandarin rings (D-043).
const Pulse: React.FC<{ size: number }> = ({ size }) => {
  const frame = useCurrentFrame();
  const p = useIn(0, 14);
  const t = (frame / (2.4 * FPS)) % 1;
  const hex = (a: number) => Math.round(a).toString(16).padStart(2, '0');
  return (
    <div style={{ position: 'relative', width: size * 1.7, height: size * 1.7, transform: `scale(${p})` }}>
      {[0, 1, 2].map((i) => {
        const v = (t + i / 3) % 1;
        const r = size * (0.5 + 0.35 * v);
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: '50%',
              top: '50%',
              width: r * 2,
              height: r * 2,
              marginLeft: -r,
              marginTop: -r,
              borderRadius: '50%',
              background: `${C.b}${hex(0x33 * (1 - v))}`,
              border: `3px solid ${C.b}${hex(0x80 * (1 - v))}`,
            }}
          />
        );
      })}
      <div
        style={{
          position: 'absolute',
          left: '50%',
          top: '50%',
          width: size,
          height: size,
          marginLeft: -size / 2,
          marginTop: -size / 2,
          borderRadius: '50%',
          background: `linear-gradient(135deg, #6680F7, ${C.cobalt}, #3350C9)`,
          boxShadow: `0 24px 60px ${C.cobalt}66`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 8,
        }}
      >
        <People size={size * 0.3} />
        <div style={{ fontFamily: SANS, fontWeight: 700, fontSize: size * 0.12, color: '#fff' }}>Buscar pareja</div>
      </div>
    </div>
  );
};

/// Two speech bubbles, A indigo and B mandarin (Design 2.0 §6.1).
const Logo: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size * 0.8} viewBox="0 0 100 80">
    <path d="M8 8h48a8 8 0 0 1 8 8v26a8 8 0 0 1-8 8H26l-12 10v-10H8a8 8 0 0 1-8-8V16a8 8 0 0 1 8-8z" fill={C.a} />
    <path d="M44 24h48a8 8 0 0 1 8 8v26a8 8 0 0 1-8 8h-6v10l-12-10H44a8 8 0 0 1-8-8V32a8 8 0 0 1 8-8z" fill={C.b} opacity="0.92" />
    <path d="M48 41c4-6 8 6 12 0s8 6 12 0" stroke={C.onRole} strokeWidth="4" fill="none" strokeLinecap="round" />
  </svg>
);

const RoleCircle: React.FC<{ label: string; color: string; on: boolean; empty?: boolean; size?: number }> = ({ label, color, on, empty, size = 170 }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: '50%',
      background: empty ? 'transparent' : color,
      border: empty ? `4px dashed ${C.faint}` : 'none',
      color: empty ? C.faint : C.onRole,
      fontFamily: SANS,
      fontWeight: 700,
      fontSize: size * 0.44,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      boxShadow: on ? `0 0 0 12px ${color}33, 0 0 0 26px ${color}14` : 'none',
    }}
  >
    {label}
  </div>
);

// ------------------------------------------------------------------ subtitles
/// The whole line, centred; the word being said glows, the ones already said
/// stay lit and the ones still to come are dimmed.
const Subtitles: React.FC<{ line: Line; audioAt: number }> = ({ line, audioAt }) => {
  const frame = useCurrentFrame();
  const t = (frame - audioAt) / FPS;
  const p = useIn(0, 20);
  return (
    <div style={{ position: 'absolute', top: SUBS_TOP, left: SIDE, width: W - 2 * SIDE, display: 'flex', justifyContent: 'center' }}>
      <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', columnGap: 14, rowGap: 4, opacity: p }}>
        {line.words.map((w, i) => {
          const next = line.words[i + 1]?.start ?? line.seconds;
          const now = t >= w.start && t < Math.max(w.end, next);
          const said = t >= w.start;
          const glow = now ? interpolate(t, [w.start, w.start + 0.08], [0, 1], { extrapolateRight: 'clamp' }) : 0;
          return (
            <span
              key={i}
              style={{
                fontFamily: SANS,
                fontWeight: 700,
                fontSize: 54,
                lineHeight: 1.2,
                color: now ? '#FFFFFF' : said ? C.text : C.faint,
                opacity: said ? 1 : 0.55,
                textShadow: glow
                  ? `0 0 ${18 * glow}px rgba(157,176,255,${0.95 * glow}), 0 0 ${42 * glow}px rgba(63,98,245,${0.8 * glow})`
                  : '0 2px 12px rgba(0,0,0,0.6)',
                transform: `scale(${1 + 0.06 * glow})`,
                display: 'inline-block',
              }}
            >
              {w.w}
            </span>
          );
        })}
      </div>
    </div>
  );
};

// ------------------------------------------------------------------ scenes
const Alone: React.FC = () => {
  const frame = useCurrentFrame();
  const days = Math.max(13, 14 - Math.floor(frame / (2.2 * FPS)));
  return (
    <>
      <Headline text="¿Con quién practico?" kicker="Speaking B2" />
      <Band top={VISUAL_TOP} height={VISUAL_H}>
        <div style={{ fontFamily: MONO, fontWeight: 600, fontSize: 240, lineHeight: 1, color: C.text, opacity: useIn(4) }}>{days}</div>
        <div style={{ fontFamily: SANS, fontWeight: 600, fontSize: 40, letterSpacing: 6, color: C.muted, marginTop: 8, opacity: useIn(8) }}>
          DÍAS PARA EL EXAMEN
        </div>
        <div style={{ marginTop: 90, opacity: useIn(16) }}>
          <Row gap={70}>
            <RoleCircle label="A" color={C.a} on />
            <RoleCircle label="?" color={C.b} on={false} empty />
          </Row>
        </div>
      </Band>
    </>
  );
};

const Reveal: React.FC = () => {
  const p = useIn(0, 13);
  return (
    <Band top={VISUAL_TOP - 150} height={VISUAL_H}>
      <div style={{ transform: `scale(${0.6 + 0.4 * p})`, opacity: p }}>
        <Logo size={340} />
      </div>
      <div style={{ fontFamily: SANS, fontWeight: 700, fontSize: 150, letterSpacing: -4, color: C.text, marginTop: 40, opacity: useIn(6) }}>MirloTalk</div>
    </Band>
  );
};

const Match: React.FC = () => (
  <>
    <Headline text="Emparejamiento en vivo" kicker="Mismo nivel" />
    <Band top={VISUAL_TOP} height={VISUAL_H}>
      <Pulse size={360} />
      <div style={{ marginTop: 40 }}>
        <Row>
          <Chip label="Tú · A" color={C.a} delay={20} fill />
          <Chip label="B2" color={C.b2} delay={26} />
          <Chip label="Compañero · B" color={C.b} delay={32} fill />
        </Row>
      </div>
    </Band>
  </>
);

const Agenda: React.FC = () => (
  <>
    <Headline text="Propón un horario" kicker="Agenda" />
    <Phone src="agenda" delay={2} />
  </>
);

const Exam: React.FC<{ frames: number }> = ({ frames }) => {
  const frame = useCurrentFrame();
  const swap = Math.round(frames * 0.52);
  const second = interpolate(frame, [swap, swap + 12], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic) });
  return (
    <>
      <Headline text="Como el examen real" kicker="4 partes · turnos · tiempo" />
      <AbsoluteFill style={{ opacity: 1 - second }}>
        <Phone src="part1" delay={2} />
      </AbsoluteFill>
      <AbsoluteFill style={{ opacity: second }}>
        <Phone src="part3" />
      </AbsoluteFill>
    </>
  );
};

/// Frame (inside its scene) at which [word] of line [line] is said.
function wordFrame(line: number, word: string) {
  const w = LINES[line].words.find((x) => x.w.replace(/[^\p{L}\p{N}]/gu, '') === word);
  return w ? Math.round(w.start * FPS) : 0;
}

/// "51" counts up while "cincuenta y un" is said; each level pops when it is named.
const Count: React.FC<{ level: string; color: string; delay: number }> = ({ level, color, delay }) => {
  const frame = useCurrentFrame();
  const from = wordFrame(5, 'cincuenta');
  const n = Math.round(interpolate(frame, [from, from + 36], [0, 51], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic) }));
  const p = useIn(from - 4, 14);
  return (
    <div style={{ width: 280, display: 'flex', flexDirection: 'column', alignItems: 'center', opacity: p, transform: `translateY(${(1 - p) * 40}px)` }}>
      <div style={{ fontFamily: MONO, fontWeight: 600, fontSize: 150, lineHeight: 1, color: C.text }}>{n}</div>
      <div style={{ fontFamily: SANS, fontWeight: 600, fontSize: 32, color: C.muted, margin: '10px 0 22px' }}>exámenes</div>
      <Chip label={level} color={color} delay={delay} size={44} />
    </div>
  );
};

const Bank: React.FC = () => (
  <>
    <Headline text="153 exámenes originales" kicker="Contenido" />
    <Band top={VISUAL_TOP} height={VISUAL_H}>
      <Row gap={0}>
        <Count level="B1" color={C.b1} delay={wordFrame(5, 'B1') - 4} />
        <Count level="B2" color={C.b2} delay={wordFrame(5, 'B2') - 4} />
        <Count level="C1" color={C.c1} delay={wordFrame(5, 'C1') - 4} />
      </Row>
    </Band>
  </>
);

const Feedback: React.FC = () => (
  <>
    <Headline text="Feedback entre los dos" kicker="Al terminar" />
    <Phone src="feedback" delay={2} />
  </>
);

const Cta: React.FC = () => {
  const p = useIn(0, 14);
  const soon = useIn(30);
  return (
    <>
      <Band top={VISUAL_TOP - 250} height={VISUAL_H + 100}>
        <div style={{ transform: `scale(${0.7 + 0.3 * p})`, opacity: p }}>
          <Logo size={300} />
        </div>
        <div style={{ fontFamily: SANS, fontWeight: 700, fontSize: 140, letterSpacing: -4, color: C.text, marginTop: 30, opacity: p }}>MirloTalk</div>
        <div
          style={{
            marginTop: 70,
            fontFamily: SANS,
            fontWeight: 700,
            fontSize: 46,
            color: '#fff',
            background: C.cobalt,
            borderRadius: 999,
            padding: '26px 60px',
            boxShadow: `0 20px 50px ${C.cobalt}55`,
            opacity: soon,
            transform: `translateY(${(1 - soon) * 30}px)`,
          }}
        >
          Próximamente en iOS y Android
        </div>
      </Band>
      <Band top={1820} height={70}>
        <div style={{ fontFamily: SANS, fontWeight: 600, fontSize: 22, color: C.faint, opacity: useIn(30) }}>
          Material original. Sin relación con Cambridge University Press & Assessment.
        </div>
      </Band>
    </>
  );
};

// ------------------------------------------------------------------ the ad
export const Ad: React.FC = () => {
  useFonts();
  const { scenes } = scenePlan();
  const views = [
    <Alone key="1" />,
    <Reveal key="2" />,
    <Match key="3" />,
    <Agenda key="4" />,
    <Exam key="5" frames={scenes[4].frames} />,
    <Bank key="6" />,
    <Feedback key="7" />,
    <Cta key="8" />,
  ];
  return (
    <AbsoluteFill style={{ background: `radial-gradient(120% 70% at 50% 0%, #17203F 0%, ${C.ink} 60%)` }}>
      {scenes.map((s, i) => (
        <Sequence key={i} from={s.from} durationInFrames={s.frames}>
          <Fade frames={i === scenes.length - 1 ? s.frames + 60 : s.frames}>{views[i]}</Fade>
          <Subtitles line={s.line} audioAt={s.audioAt} />
          <Sequence from={s.audioAt}>
            <Audio src={staticFile(s.line.file)} />
          </Sequence>
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
