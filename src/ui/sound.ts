/**
 * Small synthesized sounds (Web Audio, no audio files): a wooden "clack" for moves,
 * a heavier one for captures, a double tone for check and a short phrase at the end.
 */

export type SoundEvent = "move" | "capture" | "check" | "end";

let context: AudioContext | null = null;

function audio(): AudioContext | null {
  try {
    context ??= new AudioContext();
    if (context.state === "suspended") void context.resume();
    return context;
  } catch {
    return null;
  }
}

function clack(ctx: AudioContext, at: number, pitch: number, volume: number): void {
  // Short filtered noise burst: sounds like a piece hitting a wooden board.
  const length = Math.floor(ctx.sampleRate * 0.05);
  const buffer = ctx.createBuffer(1, length, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < length; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / length) ** 3;
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  const filter = ctx.createBiquadFilter();
  filter.type = "bandpass";
  filter.frequency.value = pitch;
  filter.Q.value = 4;
  const gain = ctx.createGain();
  gain.gain.value = volume;
  source.connect(filter).connect(gain).connect(ctx.destination);
  source.start(at);
}

function tone(ctx: AudioContext, at: number, frequency: number, duration: number, volume: number): void {
  const oscillator = ctx.createOscillator();
  oscillator.type = "sine";
  oscillator.frequency.value = frequency;
  const gain = ctx.createGain();
  gain.gain.setValueAtTime(volume, at);
  gain.gain.exponentialRampToValueAtTime(0.0001, at + duration);
  oscillator.connect(gain).connect(ctx.destination);
  oscillator.start(at);
  oscillator.stop(at + duration);
}

export function playSound(event: SoundEvent): void {
  const ctx = audio();
  if (!ctx) return;
  const now = ctx.currentTime + 0.01;
  switch (event) {
    case "move":
      clack(ctx, now, 1800, 1.6);
      break;
    case "capture":
      clack(ctx, now, 1200, 2.2);
      clack(ctx, now + 0.06, 900, 1.2);
      break;
    case "check":
      clack(ctx, now, 1800, 1.6);
      tone(ctx, now + 0.05, 880, 0.18, 0.12);
      tone(ctx, now + 0.2, 660, 0.25, 0.12);
      break;
    case "end":
      tone(ctx, now, 523, 0.25, 0.12);
      tone(ctx, now + 0.2, 659, 0.25, 0.12);
      tone(ctx, now + 0.4, 784, 0.45, 0.12);
      break;
  }
}
