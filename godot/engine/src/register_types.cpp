// GDExtension entry point for the shogi engine.
// Copyright (C) 2026 the Shogi project contributors. GPL-3.0-or-later (see LICENSE).

#include "shogi_engine.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void shogi_engine_shutdown();

static void initialize_shogi_engine(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE)
		return;
	GDREGISTER_CLASS(ShogiEngine);
}

static void uninitialize_shogi_engine(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE)
		return;
	shogi_engine_shutdown();
}

extern "C" {
GDExtensionBool GDE_EXPORT shogi_engine_library_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		const GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);
	init_obj.register_initializer(initialize_shogi_engine);
	init_obj.register_terminator(uninitialize_shogi_engine);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
