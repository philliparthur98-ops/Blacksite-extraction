using UnrealBuildTool;

public class BlacksiteExtraction : ModuleRules
{
    public BlacksiteExtraction(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new string[]
        {
            "Core",
            "CoreUObject",
            "Engine",
            "InputCore",
            "AIModule",
            "NavigationSystem",
            "GameplayTasks"
        });
    }
}
