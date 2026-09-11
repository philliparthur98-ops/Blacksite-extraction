using UnrealBuildTool;
using System.Collections.Generic;

public class BlacksiteExtractionTarget : TargetRules
{
    public BlacksiteExtractionTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.Latest;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("BlacksiteRuntime");
    }
}
