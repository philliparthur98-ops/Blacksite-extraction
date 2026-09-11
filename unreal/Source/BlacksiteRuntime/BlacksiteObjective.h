#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BlacksiteObjective.generated.h"

class ABlacksitePlayerCharacter;
class UPointLightComponent;
class USceneComponent;
class UStaticMeshComponent;

UCLASS()
class BLACKSITERUNTIME_API ABlacksiteObjective : public AActor
{
    GENERATED_BODY()

public:
    ABlacksiteObjective();
    void Interact(ABlacksitePlayerCharacter* Player);
    bool IsSecured() const { return bSecured; }

private:
    UPROPERTY(VisibleAnywhere)
    TObjectPtr<USceneComponent> Root;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> DriveCase;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UPointLightComponent> MarkerLight;

    bool bSecured = false;
};
