import type { GameSettings, SavedGame } from "./session";

/**
 * localStorage persistence. Every access is guarded: storage may be unavailable
 * (private mode, blocked site data) and the game must keep working without it.
 */

const CURRENT_KEY = "shogi.current.v1";
const SAVES_KEY = "shogi.saves.v1";
const PREFS_KEY = "shogi.prefs.v1";
const MAX_SAVES = 30;

export interface Preferences {
  /** Bumped when defaults change in a way that should reach existing players. */
  version: number;
  /** Reading mode: pieces show how they move and their name instead of kanji. */
  reading: boolean;
  /** Language of the piece names in reading mode. */
  labels: "pt" | "en";
  /** Shade the squares the opponent attacks. */
  showAttacks: boolean;
  sound: boolean;
  lastSettings?: GameSettings;
}

export interface SaveSlot extends SavedGame {
  id: string;
  name: string;
}

function read<T>(key: string): T | null {
  try {
    const text = localStorage.getItem(key);
    return text ? (JSON.parse(text) as T) : null;
  } catch {
    return null;
  }
}

function write(key: string, value: unknown): boolean {
  try {
    localStorage.setItem(key, JSON.stringify(value));
    return true;
  } catch {
    return false;
  }
}

export function loadCurrentGame(): SavedGame | null {
  return read<SavedGame>(CURRENT_KEY);
}

export function saveCurrentGame(game: SavedGame): void {
  write(CURRENT_KEY, game);
}

export function listSaves(): SaveSlot[] {
  return read<SaveSlot[]>(SAVES_KEY) ?? [];
}

export function addSave(game: SavedGame, name: string): boolean {
  const slot: SaveSlot = { ...game, id: `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`, name };
  return write(SAVES_KEY, [slot, ...listSaves()].slice(0, MAX_SAVES));
}

export function deleteSave(id: string): void {
  write(SAVES_KEY, listSaves().filter((slot) => slot.id !== id));
}

const PREFERENCES_VERSION = 3;

/** Preferences as stored by older versions, which had piece styles instead of reading mode. */
type StoredPreferences = Partial<Preferences> & { pieceStyle?: string; showMarks?: boolean };

/** Fills in defaults and upgrades preferences saved by older versions. */
export function migratePreferences(stored: StoredPreferences): Preferences {
  const { pieceStyle, showMarks, ...rest } = stored;
  const preferences: Preferences = { reading: false, labels: "pt", showAttacks: false, sound: true, ...rest, version: PREFERENCES_VERSION };
  // Version 3 replaced the piece styles (kanji, Portuguese or English names, optional movement
  // marks) with kanji plus a reading mode. Whoever chose names or marks gets reading mode.
  if ((stored.version ?? 1) < 3) {
    preferences.reading = (stored.version ?? 1) >= 2 && (pieceStyle === "pt" || pieceStyle === "en" || showMarks === true);
    preferences.labels = pieceStyle === "en" ? "en" : "pt";
  }
  return preferences;
}

export function loadPreferences(): Preferences {
  return migratePreferences(read<StoredPreferences>(PREFS_KEY) ?? {});
}

export function savePreferences(preferences: Preferences): void {
  write(PREFS_KEY, preferences);
}
