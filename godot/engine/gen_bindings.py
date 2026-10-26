# Generates the godot-cpp C++ bindings (thirdparty/godot-cpp/gen/) from the Godot API JSON.
import sys
from pathlib import Path

root = Path(__file__).resolve().parent / "thirdparty" / "godot-cpp"
sys.path.insert(0, str(root))
import binding_generator  # noqa: E402

binding_generator.generate_bindings(str(root / "gdextension" / "extension_api.json"), False, "64", "single", str(root))
