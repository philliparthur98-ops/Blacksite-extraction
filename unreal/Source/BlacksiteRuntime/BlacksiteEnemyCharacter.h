#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "BlacksiteEnemyCharacter.generated.h"

class UPointLightComponent;
class UStaticMeshComponent;

UENUM()
enum class EBlacksiteAIState : uint8
{
    Patrol,
    Investigate,
    Combat,
    Dead
};

UCLASS()
class BLACKSITERUNTIME_API ABlacksiteEnemyCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ABlacksiteEnemyCharacter();

    virtual void Tick(float DeltaSeconds) override;
    virtual float TakeDamage(float DamageAmount, const FDamageEvent& DamageEvent,
        AController* EventInstigator, AActor* DamageCauser) override;

    void SetArchetype(int32 InArchetype);
    void Alert(const FVector& SourceLocation);
    bool IsHeadComponent(const UPrimitiveComponent* Component) const;

protected:
    virtual void BeginPlay() override;

private:
    bool CanSeePlayer(FVector& OutLocation) const;
    void UpdateTactics(const FVector& PlayerLocation, bool bHasLOS);
    void MoveToward(const FVector& Destination);
    void FireAtPlayer(const FVector& PlayerLocation);
    void Die();

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Torso;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Head;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Weapon;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UPointLightComponent> MuzzleFlash;

    float Health = 100.0f;
    float FireCooldown = 0.0f;
    float StateTimer = 0.0f;
    float MuzzleEnergy = 0.0f;
    int32 Archetype = 0;
    bool bDead = false;

    FVector HomeLocation = FVector::ZeroVector;
    FVector LastSeenLocation = FVector::ZeroVector;
    FVector TacticalDestination = FVector::ZeroVector;
    EBlacksiteAIState State = EBlacksiteAIState::Patrol;
};
