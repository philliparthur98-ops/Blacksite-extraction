#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "BlacksiteHUD.generated.h"

UCLASS()
class BLACKSITERUNTIME_API ABlacksiteHUD : public AHUD
{
    GENERATED_BODY()

public:
    virtual void DrawHUD() override;

private:
    void DrawBar(float X, float Y, float Width, float Height, float Fraction,
        const FLinearColor& FillColor, const FLinearColor& BackColor);
};
