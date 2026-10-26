#!/usr/bin/env bash
# Fetches the sources the GDExtension is built from into godot/engine/thirdparty/ (git-ignored):
#   - Fairy-Stockfish (GPL-3.0), pinned commit;
#   - godot-cpp, branch compatible with Godot 4.5+ (works with 4.7).
set -euo pipefail
cd "$(dirname "$0")"

FS_COMMIT=9f778da667f6e07dae1e85d3e2ea204fc6dee94d
GODOT_CPP_REF=godot-4.5-stable

mkdir -p thirdparty build
# Keep Godot from importing the dependency trees (godot-cpp ships its own test project).
touch thirdparty/.gdignore build/.gdignore
if [ ! -d thirdparty/Fairy-Stockfish/.git ]; then
  git init -q thirdparty/Fairy-Stockfish
  git -C thirdparty/Fairy-Stockfish remote add origin https://github.com/fairy-stockfish/Fairy-Stockfish.git
fi
if [ "$(git -C thirdparty/Fairy-Stockfish rev-parse -q --verify HEAD || true)" != "$FS_COMMIT" ]; then
  git -C thirdparty/Fairy-Stockfish fetch -q --depth 1 origin "$FS_COMMIT"
  git -C thirdparty/Fairy-Stockfish checkout -q FETCH_HEAD
fi
if [ ! -d thirdparty/godot-cpp/.git ]; then
  git clone -q --depth 1 --branch "$GODOT_CPP_REF" --recursive https://github.com/godotengine/godot-cpp.git thirdparty/godot-cpp
fi
echo "Fairy-Stockfish $(git -C thirdparty/Fairy-Stockfish rev-parse --short HEAD), godot-cpp $GODOT_CPP_REF"
