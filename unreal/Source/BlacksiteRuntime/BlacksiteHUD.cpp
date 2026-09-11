#include "BlacksiteHUD.h"

#include "BlacksiteGameMode.h"
#include "BlacksitePlayerCharacter.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "GameFramework/PlayerController.h"

void ABlacksiteHUD::DrawBar(
    float X,
    float Y,
    float Width,
    float Height,
    float Fraction,
    const FLinearColor& FillColor,
    const FLinearColor& BackColor)
{
    DrawRect(BackColor, X, Y, Width, Height);
    DrawRect(FillColor, X, Y, Width * FMath::Clamp(Fraction, 0.0f, 1.0f), Height);
}

void ABlacksiteHUD::DrawHUD()
{
    Super::DrawHUD();

    if (!Canvas || !GEngine || !PlayerOwner)
    {
        return;
    }

    ABlacksitePlayerCharacter* Player = Cast<ABlacksitePlayerCharacter>(PlayerOwner->GetPawn());
    ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>();
    if (!Player || !GM)
    {
        return;
    }

    const float W = Canvas->ClipX;
    const float H = Canvas->ClipY;
    UFont* Small = GEngine->GetSmallFont();
    UFont* Medium = GEngine->GetMediumFont();

    const FLinearColor White(0.88f, 0.93f, 0.94f, 1.0f);
    const FLinearColor Cyan(0.20f, 0.86f, 0.94f, 1.0f);
    const FLinearColor Red(0.95f, 0.18f, 0.12f, 1.0f);
    const FLinearColor Green(0.20f, 0.90f, 0.38f, 1.0f);
    const FLinearColor Dark(0.01f, 0.02f, 0.025f, 0.78f);

    DrawRect(Dark, 24.0f, H - 128.0f, 310.0f, 92.0f);
    DrawText(
        FString::Printf(TEXT("VXR-11   %02d / %03d"), Player->GetAmmo(), Player->GetReserveAmmo()),
        White,
        42.0f,
        H - 108.0f,
        Medium,
        1.0f,
        false);

    DrawText(TEXT("VITALS"), White, 42.0f, H - 76.0f, Small, 0.9f, false);
    DrawBar(
        104.0f,
        H - 70.0f,
        194.0f,
        9.0f,
        Player->GetHealth() / FMath::Max(Player->GetMaxHealth(), 1.0f),
        Green,
        FLinearColor(0.12f, 0.12f, 0.12f, 0.95f));

    DrawRect(Dark, W - 430.0f, 24.0f, 406.0f, 82.0f);
    DrawText(
        GM->GetObjectiveText(),
        GM->IsObjectiveSecured() ? Green : Cyan,
        W - 412.0f,
        42.0f,
        Small,
        0.95f,
        false);
    DrawText(
        FString::Printf(TEXT("HOSTILES %02d   KILLS %02d"), GM->GetEnemiesRemaining(), GM->GetKills()),
        White,
        W - 412.0f,
        70.0f,
        Small,
        0.85f,
        false);

    if (!Player->IsAiming())
    {
        const float CX = W * 0.5f;
        const float CY = H * 0.5f;
        DrawRect(White, CX - 10.0f, CY - 1.0f, 7.0f, 2.0f);
        DrawRect(White, CX + 3.0f, CY - 1.0f, 7.0f, 2.0f);
        DrawRect(White, CX - 1.0f, CY - 10.0f, 2.0f, 7.0f);
        DrawRect(White, CX - 1.0f, CY + 3.0f, 2.0f, 7.0f);
    }

    if (Player->GetInteractionProgress() > 0.0f)
    {
        DrawRect(Dark, W * 0.5f - 170.0f, H * 0.72f, 340.0f, 48.0f);
        DrawBar(
            W * 0.5f - 145.0f,
            H * 0.72f + 28.0f,
            290.0f,
            8.0f,
            Player->GetInteractionProgress(),
            GM->IsObjectiveSecured() ? Green : Cyan,
            FLinearColor(0.12f, 0.12f, 0.12f, 1.0f));
        DrawText(
            GM->IsObjectiveSecured() ? TEXT("HOLD F // EXTRACTING") : TEXT("HOLD F // SECURING DRIVE"),
            White,
            W * 0.5f - 112.0f,
            H * 0.72f + 6.0f,
            Small,
            0.85f,
            false);
    }

    DrawText(
        TEXT("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   RMB ADS   R RELOAD   F INTERACT   F5 RESTART"),
        FLinearColor(0.58f, 0.64f, 0.66f, 1.0f),
        28.0f,
        24.0f,
        Small,
        0.72f,
        false);

    if (GM->IsRaidComplete())
    {
        DrawRect(FLinearColor(0.0f, 0.0f, 0.0f, 0.76f), 0.0f, H * 0.36f, W, 150.0f);
        DrawText(
            GM->WasExtracted() ? TEXT("EXTRACTION COMPLETE") : TEXT("OPERATOR KIA"),
            GM->WasExtracted() ? Green : Red,
            W * 0.5f - 160.0f,
            H * 0.40f,
            Medium,
            1.35f,
            false);
        DrawText(TEXT("F5 // RUN HARBOR AGAIN"), White, W * 0.5f - 92.0f, H * 0.46f, Small, 0.9f, false);
    }
}
