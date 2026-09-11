from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
UNREAL = ROOT / "unreal"
SRC = UNREAL / "Source" / "BlacksiteRuntime"

failures: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def text(path: Path) -> str:
    require(path.exists(), f"missing:{path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8") if path.exists() else ""

uproject = json.loads(text(UNREAL / "BlacksiteExtraction.uproject") or "{}")
modules = [m.get("Name") for m in uproject.get("Modules", [])]
require(modules == ["BlacksiteRuntime"], f"active_modules:{modules}")
require(uproject.get("EngineAssociation") == "5.8", "engine_not_5_8")

engine = text(UNREAL / "Config" / "DefaultEngine.ini")
require("GlobalDefaultGameMode=/Script/BlacksiteRuntime.BlacksiteGameMode" in engine, "wrong_game_mode_route")
require("r.DynamicGlobalIlluminationMethod=1" in engine, "lumen_gi_disabled")
require("r.ReflectionMethod=1" in engine, "lumen_reflections_disabled")
require("r.Shadow.Virtual.Enable=1" in engine, "virtual_shadows_disabled")
require("r.AntiAliasingMethod=4" in engine, "tsr_disabled")
require("RuntimeGeneration=Dynamic" in engine, "dynamic_navigation_disabled")

required_files = [
    "BlacksiteRuntime.Build.cs",
    "BlacksiteRuntime.cpp",
    "BlacksitePlayerCharacter.h",
    "BlacksitePlayerCharacter.cpp",
    "BlacksiteEnemyCharacter.h",
    "BlacksiteEnemyCharacter.cpp",
    "BlacksiteObjective.h",
    "BlacksiteObjective.cpp",
    "BlacksiteExtractionZone.h",
    "BlacksiteExtractionZone.cpp",
    "BlacksiteHUD.h",
    "BlacksiteHUD.cpp",
    "BlacksiteGameMode.h",
    "BlacksiteGameMode.cpp",
    "BlacksiteAudio.h",
    "BlacksiteAudio.cpp",
    "BlacksiteAutomationTests.cpp",
]
for name in required_files:
    require((SRC / name).exists(), f"missing_runtime_file:{name}")

audio = text(SRC / "BlacksiteAudio.cpp")
player = text(SRC / "BlacksitePlayerCharacter.cpp")
enemy = text(SRC / "BlacksiteEnemyCharacter.cpp")
extraction_h = text(SRC / "BlacksiteExtractionZone.h")
world = text(SRC / "BlacksiteGameMode.cpp")
automation = text(SRC / "BlacksiteAutomationTests.cpp")
build_proof = text(ROOT / ".github" / "workflows" / "unreal-ue58-build.yml")

require("SetSampleRate(SampleRate, false)" in audio, "ue58_sample_rate_signature_regressed")
require("QueueAudio(" in audio, "procedural_audio_queue_missing")
require("LineTraceSingleByChannel" in player, "player_physical_fire_missing")
require("LineTraceSingleByChannel" in enemy, "enemy_physical_fire_missing")
require("MoveToLocation(" in enemy, "enemy_pathing_missing")
require("EBlacksiteAIState::Investigate" in enemy, "enemy_investigate_state_missing")
require("GM->BroadcastGunshot" in player, "player_gunshot_alert_missing")
require("GetRequiredHoldTime() const { return 4.0f; }" in extraction_h, "extraction_not_four_seconds")
require("InteractionProgress = 0.0f" in player, "interaction_cancel_reset_missing")
require("BuildHarbor();" in world, "harbor_build_missing")
require("SpawnCombatants();" in world, "enemy_spawn_missing")
require("SetFogDensity" in world and "APostProcessVolume" in world, "visual_atmosphere_missing")

# The source-sanity job is not compile proof. Require a separate UE-native gate whose
# commands can only succeed on a machine with a licensed UE 5.8 installation.
require("runs-on: [self-hosted, Windows, X64, unreal-5.8]" in build_proof, "ue58_runner_gate_missing")
require("Build.bat" in build_proof and "BlacksiteExtractionEditor Win64 Development" in build_proof,
        "ubt_compile_gate_missing")
require("Automation RunTests Blacksite.Runtime" in build_proof, "ue_automation_gate_missing")
require("RunUAT.bat" in build_proof and "BuildCookRun" in build_proof, "package_gate_missing")
require("Packaged executable launch smoke" in build_proof, "packaged_launch_gate_missing")
require("IMPLEMENT_SIMPLE_AUTOMATION_TEST" in automation, "runtime_automation_tests_missing")
require("Blacksite.Runtime.ClassContract" in automation, "runtime_class_contract_test_missing")
require("Blacksite.Runtime.ModuleOwnership" in automation, "runtime_module_ownership_test_missing")

# Active runtime must use the UE light-component signature with explicit color-space bool.
for source_path in SRC.glob("*.cpp"):
    source = source_path.read_text(encoding="utf-8")
    for line_no, line in enumerate(source.splitlines(), start=1):
        if "SetLightColor(" in line and "FLinearColor::LerpUsingHSV" not in line:
            # Calls may wrap, so only reject a clearly complete one-line call with no explicit bool.
            if line.count("SetLightColor(") and line.rstrip().endswith(");") and ", false" not in line:
                failures.append(f"light_color_signature:{source_path.name}:{line_no}")

# Crude but useful truncation guard for generated source files.
for source_path in SRC.glob("*.cpp"):
    source = source_path.read_text(encoding="utf-8")
    require(source.count("{") == source.count("}"), f"brace_balance:{source_path.name}")

if failures:
    print("BLACKSITE_UNREAL_SOURCE_CONTRACT_FAILED")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print("BLACKSITE_UNREAL_SOURCE_CONTRACT_OK")
print("engine=5.8 module=BlacksiteRuntime physical_fire=PASS pathing=PASS extraction_hold=PASS visuals=PASS ue_build_gate=DEFINED")
