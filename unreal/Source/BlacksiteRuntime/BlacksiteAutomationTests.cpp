#if WITH_DEV_AUTOMATION_TESTS

#include "Misc/AutomationTest.h"
#include "BlacksiteEnemyCharacter.h"
#include "BlacksiteExtractionZone.h"
#include "BlacksiteGameMode.h"
#include "BlacksiteObjective.h"
#include "BlacksitePlayerCharacter.h"

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FBlacksiteRuntimeClassContractTest,
    "Blacksite.Runtime.ClassContract",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBlacksiteRuntimeClassContractTest::RunTest(const FString& Parameters)
{
    TestNotNull(TEXT("Player class must be registered"), ABlacksitePlayerCharacter::StaticClass());
    TestNotNull(TEXT("Enemy class must be registered"), ABlacksiteEnemyCharacter::StaticClass());
    TestNotNull(TEXT("GameMode class must be registered"), ABlacksiteGameMode::StaticClass());
    TestNotNull(TEXT("Objective class must be registered"), ABlacksiteObjective::StaticClass());
    TestNotNull(TEXT("Extraction zone class must be registered"), ABlacksiteExtractionZone::StaticClass());

    TestTrue(
        TEXT("BlacksiteRuntime player must derive from Character"),
        ABlacksitePlayerCharacter::StaticClass()->IsChildOf(ACharacter::StaticClass()));

    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FBlacksiteRuntimeOwnershipTest,
    "Blacksite.Runtime.ModuleOwnership",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBlacksiteRuntimeOwnershipTest::RunTest(const FString& Parameters)
{
    const FString PlayerModule = ABlacksitePlayerCharacter::StaticClass()->GetOuterUPackage()->GetName();
    const FString GameModeModule = ABlacksiteGameMode::StaticClass()->GetOuterUPackage()->GetName();

    TestEqual(TEXT("Player remains owned by active runtime module"), PlayerModule, FString(TEXT("/Script/BlacksiteRuntime")));
    TestEqual(TEXT("GameMode remains owned by active runtime module"), GameModeModule, FString(TEXT("/Script/BlacksiteRuntime")));
    return true;
}

#endif
