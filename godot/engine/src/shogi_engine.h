// Shogi engine for Godot: Fairy-Stockfish (variant "shogi") exposed as a GDExtension class.
// Copyright (C) 2026 the Shogi project contributors. GPL-3.0-or-later (see LICENSE).

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <atomic>
#include <memory>
#include <string>
#include <thread>
#include <vector>

namespace godot {

/**
 * One shogi game (position + move history) plus access to the engine search.
 *
 * Everything is in USI notation (7g7f, P*5e, 8h2b+) and SFEN. The rules come from
 * Fairy-Stockfish as-is: legal_moves() still contains uchifuzume (checkmate by a dropped
 * pawn), which the GDScript layer filters out, as FairyBackend.ts does in the PWA.
 *
 * Fairy-Stockfish keeps its search state in globals, so all instances share one search
 * thread pool: only one search runs at a time (start_search() fails while another runs).
 */
class ShogiEngine : public RefCounted {
	GDCLASS(ShogiEngine, RefCounted)

public:
	ShogiEngine();
	~ShogiEngine() override;

	// Engine settings (Threads clamped to 1..4, Hash in MB). Ignored while searching.
	bool configure(int threads, int hash_mb);
	static String engine_info();

	// Position
	bool set_position(const String &sfen, const PackedStringArray &moves);
	String get_sfen() const;
	String get_start_sfen() const;
	PackedStringArray history() const;
	String side_to_move() const;

	// Moves
	PackedStringArray legal_moves() const;
	int legal_move_count() const;
	bool is_legal(const String &move) const;
	bool play(const String &move);
	String undo();
	bool is_check() const;
	bool gives_check(const String &move) const;
	int64_t perft(int depth);

	// {over: bool, winner: "black"|"white"|"draw", reason: "checkmate"|"no-legal-moves"|
	//  "repetition"|"perpetual-check"}; reads Fairy-Stockfish like FairyBackend.ts (result(true)).
	Dictionary game_result() const;

	// Search (async): emits best_move(move) on the main thread; "" when there is no move.
	bool start_search(int depth, int movetime_ms, int skill);
	void stop();
	bool is_searching() const;

	struct Game;

protected:
	static void _bind_methods();

private:
	std::unique_ptr<Game> game;
	std::thread waiter;
	std::atomic<bool> searching{ false };

	void join_waiter();
};

} // namespace godot
