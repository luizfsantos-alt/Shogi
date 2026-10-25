import type { GameSettings, SavedGame } from "./session";
import type { PieceStyle } from "./pieceView";

/**
 * localStorage persistence. Every access is guarded: storage may be unavailable
 * (private mode, blocked site data) and the game must keep working without it.
 */

const CURRENT_KEY = "shogi.current.v1";
const SAVES_KEY = "shogi.saves.v1";
const PREFS_KEY = "shogi.prefs.v1";
const MAX_SAVES = 30;

export interface Preferences {
  pieceStyle: PieceStyle;
  /** Shade the squares the opponent attacks. */
  showAttacks: boolean;
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

export function loadPreferences(): Preferences {
  return { pieceStyle: "pt", showAttacks: false, ...read<Partial<Preferences>>(PREFS_KEY) };
}

export function savePreferences(preferences: Preferences): void {
  write(PREFS_KEY, preferences);
}
