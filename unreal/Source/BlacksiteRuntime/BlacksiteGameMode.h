#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "BlacksiteGameMode.generated.h"

class ABlacksiteEnemyCharacter;
class ABlacksiteExtractionZone;
class ABlacksiteObjective;
class UMaterialInterface;

UCLASS()
class BLACKSITERUNTIME_API ABlacksiteGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    ABlacksiteGameMode();
    virtual void StartPlay() override;

    void SecureObjective();
    void CompleteExtraction();
    void FailRaid();
    void OnEnemyKilled();
    void BroadcastGunshot(const FVector& Location);

    bool IsObjectiveSecured() const { return bObjectiveSecured; }
    bool IsRaidComplete() const { return bRaidComplete; }
    bool WasExtracted() const { return bExtracted; }
    int32 GetKills() const { return Kills; }
    int32 GetEnemiesRemaining() const { return EnemiesRemaining; }
    FString GetObjectiveText() const;
    ABlacksiteExtractionZone* GetExtractionZone() const { return ExtractionZone; }

private:
    void BuildLighting();
    void BuildHarbor();
    void CreateNavigationBounds();
    void EnsurePlayer();
    void SpawnObjectiveAndExtraction();
    void SpawnCombatants();

    AActor* SpawnBox(
        const FVector& Location,
        const FVector& Scale,
        const FRotator& Rotation,
        const FLinearColor& Color);

    AActor* SpawnCylinder(
        const FVector& Location,
        const FVector& Scale,
        const FRotator& Rotation,
        const FLinearColor& Color);

    void ApplyColor(class UStaticMeshComponent* Mesh, const FLinearColor& Color);

    bool bObjectiveSecured = false;
    bool bRaidComplete = false;
    bool bExtracted = false;
    int32 Kills = 0;
    int32 EnemiesRemaining = 0;

    UPROPERTY()
    TObjectPtr<ABlacksiteObjective> Objective;

    UPROPERTY()
    TObjectPtr<ABlacksiteExtractionZone> ExtractionZone;

    UPROPERTY()
    TObjectPtr<UMaterialInterface> BasicMaterial;

    TArray<TWeakObjectPtr<ABlacksiteEnemyCharacter>> Enemies;
};
