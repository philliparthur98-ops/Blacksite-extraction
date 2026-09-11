#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BlacksiteExtractionZone.generated.h"

class ABlacksitePlayerCharacter;
class UBoxComponent;
class UPointLightComponent;
class USceneComponent;
class UStaticMeshComponent;

UCLASS()
class BLACKSITERUNTIME_API ABlacksiteExtractionZone : public AActor
{
    GENERATED_BODY()

public:
    ABlacksiteExtractionZone();
    virtual void Tick(float DeltaSeconds) override;

    bool IsPlayerInside(const ABlacksitePlayerCharacter* Player) const;
    float GetRequiredHoldTime() const { return 4.0f; }

private:
    UPROPERTY(VisibleAnywhere)
    TObjectPtr<USceneComponent> Root;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UBoxComponent> ExtractionVolume;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Floor;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> LeftPost;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> RightPost;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> HeaderBeam;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UPointLightComponent> StatusLight;
};
