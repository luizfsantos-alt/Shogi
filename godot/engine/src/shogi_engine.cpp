// Shogi engine for Godot: Fairy-Stockfish (variant "shogi") exposed as a GDExtension class.
// Copyright (C) 2026 the Shogi project contributors. GPL-3.0-or-later (see LICENSE).

// Fairy-Stockfish first: its headers define short macros that must not leak into Godot's.
#include "fairy.h"

#include "shogi_engine.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cctype>
#include <cstring>
#include <deque>
#include <mutex>
#include <sstream>

using namespace godot;
namespace SF = Stockfish;

// ---------------------------------------------------------------- engine globals

namespace {

std::mutex g_init_mutex;
bool g_initialized = false;
// Thread object handed to the game positions (Position::do_move counts nodes on it). It is not
// part of the search pool, so resizing the pool never leaves a position with a dangling pointer.
SF::Thread *g_board_thread = nullptr;
const SF::Variant *g_variant = nullptr;
// Fairy-Stockfish has one global search: only one ShogiEngine may search at a time.
std::atomic<bool> g_search_busy{ false };

constexpr int DEFAULT_THREADS = 2;
constexpr int DEFAULT_HASH_MB = 16;

void ensure_initialized() {
	std::lock_guard<std::mutex> lock(g_init_mutex);
	if (g_initialized)
		return;
	// The engine reports through std::cout ("info ...", "bestmove ..."): silence it.
	std::cout.setstate(std::ios_base::badbit);
	SF::pieceMap.init();
	SF::variants.init();
	SF::UCI::init(SF::Options);
	SF::Tune::init();
	SF::PSQT::init(SF::variants.find("chess")->second);
	SF::Bitboards::init();
	SF::Position::init();
	SF::Bitbases::init();
	SF::Endgames::init();
	SF::Options["Threads"] = std::to_string(DEFAULT_THREADS); // creates the pool
	SF::Options["Hash"] = std::to_string(DEFAULT_HASH_MB);
	SF::Options["UCI_Variant"] = std::string("shogi"); // piece tables + PSQT for shogi
	SF::Search::clear();
	g_variant = SF::variants.find("shogi")->second;
	g_board_thread = new SF::Thread(0);
	g_initialized = true;
}

// ---------------------------------------------------------------- USI <-> Fairy-Stockfish

// Fairy-Stockfish file A is USI file 9 and its rank 1 is USI rank "i" (see src/core/notation.ts).
std::string usi_square(const SF::Position &pos, SF::Square s) {
	return std::string{ char('1' + pos.max_file() - SF::file_of(s)), char('a' + pos.max_rank() - SF::rank_of(s)) };
}

std::string move_to_usi(const SF::Position &pos, SF::Move m) {
	if (m == SF::MOVE_NONE || m == SF::MOVE_NULL)
		return "";
	if (SF::type_of(m) == SF::DROP) {
		char piece = char(std::toupper(pos.piece_to_char()[SF::in_hand_piece_type(m)]));
		return std::string{ piece, '*' } + usi_square(pos, SF::to_sq(m));
	}
	std::string text = usi_square(pos, SF::from_sq(m)) + usi_square(pos, SF::to_sq(m));
	if (SF::type_of(m) == SF::PIECE_PROMOTION || SF::type_of(m) == SF::PROMOTION)
		text += '+';
	return text;
}

SF::Move usi_to_move(const SF::Position &pos, const std::string &usi) {
	for (const auto &m : SF::MoveList<SF::LEGAL>(pos))
		if (move_to_usi(pos, m) == usi)
			return m;
	return SF::MOVE_NONE;
}

std::string to_std(const String &s) {
	CharString utf8 = s.utf8();
	return std::string(utf8.get_data(), utf8.length());
}

// ---------------------------------------------------------------- SFEN

const char *HAND_ORDER = "RBGSNLP";

struct ParsedSfen {
	std::string board;
	bool black_to_move = true;
	int hand[2][7] = {}; // [0] = black (Sente), [1] = white (Gote), in HAND_ORDER
	int move_number = 1;
};

// Light syntax check plus conversion into the bracketed-pocket FEN Fairy-Stockfish reads
// (same as toFairyFen in src/core/position.ts). Returns false on malformed input.
bool parse_sfen(const std::string &text, ParsedSfen &out) {
	std::istringstream ss(text);
	std::string board, side, hand, number;
	if (!(ss >> board >> side >> hand))
		return false;
	if (!(ss >> number))
		number = "1";
	int ranks = 1, files = 0, kings[2] = { 0, 0 };
	bool plus = false;
	for (char c : board) {
		if (c == '/') {
			if (files != 9 || plus)
				return false;
			ranks++, files = 0;
		} else if (std::isdigit((unsigned char)c)) {
			if (plus)
				return false;
			files += c - '0';
		} else if (c == '+') {
			plus = true;
		} else {
			char up = char(std::toupper((unsigned char)c));
			if (!std::strchr("KRBGSNLP", up))
				return false;
			if (plus && (up == 'K' || up == 'G'))
				return false;
			if (up == 'K')
				kings[std::isupper((unsigned char)c) ? 0 : 1]++;
			plus = false;
			files++;
		}
		if (files > 9)
			return false;
	}
	if (ranks != 9 || files != 9 || kings[0] != 1 || kings[1] != 1)
		return false;
	if (side != "b" && side != "w")
		return false;
	if (hand != "-") {
		int count = 0;
		for (char c : hand) {
			if (std::isdigit((unsigned char)c)) {
				count = count * 10 + (c - '0');
				if (count > 18)
					return false;
				continue;
			}
			const char *p = std::strchr(HAND_ORDER, std::toupper((unsigned char)c));
			if (!p || !*p)
				return false;
			out.hand[std::isupper((unsigned char)c) ? 0 : 1][p - HAND_ORDER] += count ? count : 1;
			count = 0;
		}
		if (count)
			return false;
	}
	for (char c : number)
		if (!std::isdigit((unsigned char)c))
			return false;
	out.board = board;
	out.black_to_move = side == "b";
	out.move_number = std::max(1, std::atoi(number.c_str()));
	return true;
}

std::string fairy_fen(const ParsedSfen &p, bool black_to_move) {
	std::string pocket;
	for (int c = 0; c < 2; c++)
		for (int i = 0; i < 7; i++)
			pocket.append(p.hand[c][i], c == 0 ? HAND_ORDER[i] : char(std::tolower(HAND_ORDER[i])));
	// Fairy-Stockfish calls the first player (Sente) "white".
	return p.board + "[" + pocket + "] " + (black_to_move ? "w" : "b") + " - - 0 " + std::to_string((p.move_number + 1) / 2);
}

} // namespace

// ---------------------------------------------------------------- game state

struct ShogiEngine::Game {
	std::string start_fen;   // Fairy-Stockfish FEN of the start position
	std::string start_sfen;  // normalized SFEN of the start position
	int start_move_number = 1;
	SF::StateListPtr states;
	SF::Position pos;
	std::vector<SF::Move> moves;
	std::vector<std::string> usi_moves;

	void reset(const std::string &fen) {
		start_fen = fen;
		states = SF::StateListPtr(new std::deque<SF::StateInfo>(1));
		pos.set(g_variant, fen, false, &states->back(), g_board_thread);
		moves.clear();
		usi_moves.clear();
	}

	void push(SF::Move m) {
		usi_moves.push_back(move_to_usi(pos, m));
		states->emplace_back();
		pos.do_move(m, states->back());
		moves.push_back(m);
	}

	void pop() {
		pos.undo_move(moves.back());
		moves.pop_back();
		usi_moves.pop_back();
		states->pop_back();
	}

	std::string sfen() const {
		// Fairy-Stockfish writes the board in SFEN already; hands follow the usual R B G S N L P order.
		std::istringstream ss(pos.fen(true));
		std::string board, side;
		ss >> board >> side;
		int hand[2][7] = {};
		for (int c = 0; c < 2; c++)
			for (int i = 0; i < 7; i++) {
				// piece_to_char() is indexed by Piece; Sente's (uppercase) pieces equal their PieceType.
				SF::PieceType pt = SF::PieceType(std::string(pos.piece_to_char()).find(HAND_ORDER[i]));
				hand[c][i] = pos.count_in_hand(c == 0 ? SF::WHITE : SF::BLACK, pt);
			}
		std::string hands;
		for (int c = 0; c < 2; c++)
			for (int i = 0; i < 7; i++)
				if (hand[c][i] > 0) {
					if (hand[c][i] > 1)
						hands += std::to_string(hand[c][i]);
					hands += c == 0 ? HAND_ORDER[i] : char(std::tolower(HAND_ORDER[i]));
				}
		if (hands.empty())
			hands = "-";
		return board + " " + side + " " + hands + " " + std::to_string(start_move_number + int(moves.size()));
	}
};

// ---------------------------------------------------------------- ShogiEngine

ShogiEngine::ShogiEngine() {
	ensure_initialized();
	game = std::make_unique<Game>();
	set_position("", PackedStringArray());
}

ShogiEngine::~ShogiEngine() {
	if (searching.load())
		SF::Threads.stop = true;
	join_waiter();
}

void ShogiEngine::join_waiter() {
	if (waiter.joinable())
		waiter.join();
}

bool ShogiEngine::configure(int threads, int hash_mb) {
	if (g_search_busy.load())
		return false;
	SF::Options["Threads"] = std::to_string(std::clamp(threads, 1, 4));
	SF::Options["Hash"] = std::to_string(std::clamp(hash_mb, 1, 256));
	return true;
}

String ShogiEngine::engine_info() {
	ensure_initialized();
	return String::utf8(SF::engine_info().c_str());
}

bool ShogiEngine::set_position(const String &sfen, const PackedStringArray &moves) {
	std::string text = to_std(sfen);
	if (text.empty() || text == "startpos")
		text = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1";
	ParsedSfen parsed;
	if (!parse_sfen(text, parsed))
		return false;

	// The side that just moved must not be in check (as FairyBackend.load checks).
	{
		SF::StateInfo st;
		SF::Position probe;
		probe.set(g_variant, fairy_fen(parsed, !parsed.black_to_move), false, &st, g_board_thread);
		if (probe.checkers())
			return false;
	}

	auto next = std::make_unique<Game>();
	next->start_move_number = parsed.move_number;
	next->reset(fairy_fen(parsed, parsed.black_to_move));
	next->start_sfen = next->sfen();
	for (int i = 0; i < moves.size(); i++) {
		SF::Move m = usi_to_move(next->pos, to_std(moves[i]));
		if (m == SF::MOVE_NONE)
			return false;
		next->push(m);
	}
	game = std::move(next);
	return true;
}

String ShogiEngine::get_sfen() const {
	return String::utf8(game->sfen().c_str());
}

String ShogiEngine::get_start_sfen() const {
	return String::utf8(game->start_sfen.c_str());
}

PackedStringArray ShogiEngine::history() const {
	PackedStringArray out;
	for (const auto &m : game->usi_moves)
		out.push_back(String::utf8(m.c_str()));
	return out;
}

String ShogiEngine::side_to_move() const {
	return game->pos.side_to_move() == SF::WHITE ? "black" : "white";
}

PackedStringArray ShogiEngine::legal_moves() const {
	PackedStringArray out;
	for (const auto &m : SF::MoveList<SF::LEGAL>(game->pos))
		out.push_back(String::utf8(move_to_usi(game->pos, m).c_str()));
	return out;
}

int ShogiEngine::legal_move_count() const {
	return int(SF::MoveList<SF::LEGAL>(game->pos).size());
}

bool ShogiEngine::is_legal(const String &move) const {
	return usi_to_move(game->pos, to_std(move)) != SF::MOVE_NONE;
}

bool ShogiEngine::play(const String &move) {
	SF::Move m = usi_to_move(game->pos, to_std(move));
	if (m == SF::MOVE_NONE)
		return false;
	game->push(m);
	return true;
}

String ShogiEngine::undo() {
	if (game->moves.empty())
		return "";
	String last = String::utf8(game->usi_moves.back().c_str());
	game->pop();
	return last;
}

bool ShogiEngine::is_check() const {
	return bool(game->pos.checkers());
}

bool ShogiEngine::gives_check(const String &move) const {
	SF::Move m = usi_to_move(game->pos, to_std(move));
	return m != SF::MOVE_NONE && game->pos.gives_check(m);
}

static int64_t perft_rec(SF::Position &pos, int depth) {
	if (depth == 1)
		return int64_t(SF::MoveList<SF::LEGAL>(pos).size());
	int64_t nodes = 0;
	SF::StateInfo st;
	for (const auto &m : SF::MoveList<SF::LEGAL>(pos)) {
		pos.do_move(m, st);
		nodes += perft_rec(pos, depth - 1);
		pos.undo_move(m);
	}
	return nodes;
}

int64_t ShogiEngine::perft(int depth) {
	return depth <= 0 ? 1 : perft_rec(game->pos, depth);
}

Dictionary ShogiEngine::game_result() const {
	// Same reading as ffish's Board.result(true) + FairyBackend.result().
	const SF::Position &pos = game->pos;
	SF::Value result;
	size_t legal = SF::MoveList<SF::LEGAL>(pos).size();
	bool over = pos.is_immediate_game_end(result);
	if (!over && legal == 0) {
		over = true;
		result = pos.checkers() ? pos.checkmate_value() : pos.stalemate_value();
	}
	if (!over)
		over = pos.is_optional_game_end(result);

	Dictionary d;
	d["over"] = over;
	if (!over)
		return d;
	if (pos.side_to_move() == SF::BLACK)
		result = -result;
	String winner = result == SF::VALUE_DRAW ? "draw" : result > 0 ? "black" : "white";
	String reason;
	if (legal == 0)
		reason = pos.checkers() ? "checkmate" : "no-legal-moves";
	else
		reason = winner == "draw" ? "repetition" : "perpetual-check";
	d["winner"] = winner;
	d["reason"] = reason;
	return d;
}

bool ShogiEngine::start_search(int depth, int movetime_ms, int skill) {
	if (g_search_busy.exchange(true))
		return false;
	join_waiter();
	searching = true;

	SF::Options["Skill Level"] = std::to_string(std::clamp(skill, -20, 20));
	SF::Search::LimitsType limits;
	limits.startTime = SF::now();
	limits.depth = depth > 0 ? depth : 0;
	limits.movetime = movetime_ms > 0 ? movetime_ms : 0;
	if (!limits.depth && !limits.movetime)
		limits.depth = 10; // same default as the PWA ("go depth 10")

	// Fresh copy of the game (with its history, for repetitions) for the search threads.
	SF::StateListPtr states(new std::deque<SF::StateInfo>(1));
	SF::Position root;
	root.set(g_variant, game->start_fen, false, &states->back(), SF::Threads.main());
	for (SF::Move m : game->moves) {
		states->emplace_back();
		root.do_move(m, states->back());
	}
	SF::Threads.start_thinking(root, states, limits);

	uint64_t self = get_instance_id();
	waiter = std::thread([this, self]() {
		SF::MainThread *main = SF::Threads.main();
		main->wait_for_search_finished();
		SF::Thread *best = main->bestThread ? main->bestThread : main;
		SF::Move m = best->rootMoves.empty() ? SF::MOVE_NONE : best->rootMoves[0].pv[0];
		String usi = String::utf8(move_to_usi(best->rootPos, m).c_str());
		searching = false;
		g_search_busy = false;
		if (Object *obj = ObjectDB::get_instance(self))
			obj->call_deferred("emit_signal", "best_move", usi);
	});
	return true;
}

void ShogiEngine::stop() {
	if (searching.load())
		SF::Threads.stop = true;
}

bool ShogiEngine::is_searching() const {
	return searching.load();
}

void ShogiEngine::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "threads", "hash_mb"), &ShogiEngine::configure);
	ClassDB::bind_static_method("ShogiEngine", D_METHOD("engine_info"), &ShogiEngine::engine_info);
	ClassDB::bind_method(D_METHOD("set_position", "sfen", "moves"), &ShogiEngine::set_position, DEFVAL(PackedStringArray()));
	ClassDB::bind_method(D_METHOD("get_sfen"), &ShogiEngine::get_sfen);
	ClassDB::bind_method(D_METHOD("get_start_sfen"), &ShogiEngine::get_start_sfen);
	ClassDB::bind_method(D_METHOD("history"), &ShogiEngine::history);
	ClassDB::bind_method(D_METHOD("side_to_move"), &ShogiEngine::side_to_move);
	ClassDB::bind_method(D_METHOD("legal_moves"), &ShogiEngine::legal_moves);
	ClassDB::bind_method(D_METHOD("legal_move_count"), &ShogiEngine::legal_move_count);
	ClassDB::bind_method(D_METHOD("is_legal", "move"), &ShogiEngine::is_legal);
	ClassDB::bind_method(D_METHOD("play", "move"), &ShogiEngine::play);
	ClassDB::bind_method(D_METHOD("undo"), &ShogiEngine::undo);
	ClassDB::bind_method(D_METHOD("is_check"), &ShogiEngine::is_check);
	ClassDB::bind_method(D_METHOD("gives_check", "move"), &ShogiEngine::gives_check);
	ClassDB::bind_method(D_METHOD("perft", "depth"), &ShogiEngine::perft);
	ClassDB::bind_method(D_METHOD("game_result"), &ShogiEngine::game_result);
	ClassDB::bind_method(D_METHOD("start_search", "depth", "movetime_ms", "skill"), &ShogiEngine::start_search, DEFVAL(0), DEFVAL(0), DEFVAL(20));
	ClassDB::bind_method(D_METHOD("stop"), &ShogiEngine::stop);
	ClassDB::bind_method(D_METHOD("is_searching"), &ShogiEngine::is_searching);
	ADD_SIGNAL(MethodInfo("best_move", PropertyInfo(Variant::STRING, "move")));
}

// ---------------------------------------------------------------- module shutdown

void shogi_engine_shutdown() {
	std::lock_guard<std::mutex> lock(g_init_mutex);
	if (!g_initialized)
		return;
	SF::Threads.stop = true;
	SF::Threads.set(0);
	delete g_board_thread;
	g_board_thread = nullptr;
	g_initialized = false;
}
