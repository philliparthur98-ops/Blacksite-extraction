#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameFramework/Character.h"
#include "GameFramework/GameModeBase.h"
#include "GameFramework/HUD.h"
#include "BlacksitePrototype.generated.h"

class UBoxComponent;
class UCameraComponent;
class UPointLightComponent;
class USceneComponent;
class UStaticMeshComponent;
class ABlacksiteExtractionZone;
class ABlacksiteObjective;
class ABlacksiteEnemyCharacter;

UENUM()
enum class EBlacksiteWeaponState : uint8
{
    Ready,
    Reloading
};

UENUM()
enum class EBlacksiteEnemyState : uint8
{
    Patrol,
    Investigate,
    Combat,
    Dead
};

UCLASS()
class BLACKSITEEXTRACTION_API ABlacksitePlayerCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ABlacksitePlayerCharacter();

    virtual void Tick(float DeltaSeconds) override;
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
    virtual float TakeDamage(float DamageAmount, struct FDamageEvent const& DamageEvent,
        class AController* EventInstigator, AActor* DamageCauser) override;

    int32 GetAmmo() const { return Ammo; }
    int32 GetReserve() const { return ReserveAmmo; }
    float GetHealth() const { return Health; }
    float GetMaxHealth() const { return MaxHealth; }
    float GetInteractionProgress() const { return InteractionProgress; }
    bool IsAiming() const { return bAimHeld; }
    bool IsDead() const { return bDead; }

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY()
    TObjectPtr<UCameraComponent> Camera;

    UPROPERTY()
    TObjectPtr<USceneComponent> WeaponPivot;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> ReceiverMesh;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> HandguardMesh;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> BarrelMesh;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> MagazineMesh;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> StockMesh;

    UPROPERTY()
    TObjectPtr<UPointLightComponent> MuzzleFlash;

    void MoveForward(float Value);
    void MoveRight(float Value);
    void Turn(float Value);
    void LookUp(float Value);
    void SprintPressed();
    void SprintReleased();
    void JumpPressed();
    void JumpReleased();
    void ToggleCrouch();
    void FirePressed();
    void FireReleased();
    void AimPressed();
    void AimReleased();
    void ReloadPressed();
    void InteractPressed();
    void InteractReleased();
    void RestartRaid();

    void TryFire();
    void FireOnce();
    void BeginReload();
    void FinishReload();
    void UpdateWeaponPresentation(float DeltaSeconds);
    void UpdateInteraction(float DeltaSeconds);
    void UpdateFootsteps(float DeltaSeconds);
    void PlayWeaponSound(bool bDryFire = false);
    void PlayFootstepSound();
    void Die();

    float Health = 100.0f;
    float MaxHealth = 100.0f;
    int32 Ammo = 30;
    int32 ReserveAmmo = 120;
    int32 MagazineSize = 30;
    float FireInterval = 60.0f / 650.0f;
    float LastFireTime = -100.0f;
    float ReloadElapsed = 0.0f;
    float ReloadDuration = 1.75f;
    float InteractionProgress = 0.0f;
    float InteractionRequired = 0.65f;
    float FootstepTimer = 0.0f;
    float RecoilKick = 0.0f;
    float MuzzleIntensity = 0.0f;

    bool bFireHeld = false;
    bool bAimHeld = false;
    bool bSprintHeld = false;
    bool bInteractHeld = false;
    bool bDead = false;

    EBlacksiteWeaponState WeaponState = EBlacksiteWeaponState::Ready;

    FVector WeaponHipLocation = FVector(34.0f, 21.0f, -22.0f);
    FVector WeaponADSLocation = FVector(29.0f, 0.0f, -16.0f);
    FVector WeaponSprintLocation = FVector(22.0f, 27.0f, -34.0f);
    FRotator WeaponHipRotation = FRotator(0.0f, 0.0f, 0.0f);
};

UCLASS()
class BLACKSITEEXTRACTION_API ABlacksiteEnemyCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ABlacksiteEnemyCharacter();

    virtual void Tick(float DeltaSeconds) override;
    virtual float TakeDamage(float DamageAmount, struct FDamageEvent const& DamageEvent,
        class AController* EventInstigator, AActor* DamageCauser) override;

    void SetArchetype(int32 InArchetype);
    void Alert(const FVector& SourceLocation);
    bool IsHeadComponent(const UPrimitiveComponent* Component) const;

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> TorsoMesh;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> HeadMesh;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> WeaponMesh;

    UPROPERTY()
    TObjectPtr<UPointLightComponent> MuzzleFlash;

    bool CanSeePlayer(FVector& OutPlayerLocation) const;
    void UpdateMovement(float DeltaSeconds, const FVector& PlayerLocation, bool bHasLOS);
    void FireAtPlayer(const FVector& PlayerLocation);
    void Die();

    float Health = 100.0f;
    float FireCooldown = 0.0f;
    float StateTime = 0.0f;
    float MuzzleIntensity = 0.0f;
    int32 Archetype = 0;
    bool bDead = false;

    FVector HomeLocation = FVector::ZeroVector;
    FVector LastSeenLocation = FVector::ZeroVector;
    FVector PatrolOffset = FVector::ZeroVector;
    FVector TacticalDestination = FVector::ZeroVector;
    EBlacksiteEnemyState State = EBlacksiteEnemyState::Patrol;
};

UCLASS()
class BLACKSITEEXTRACTION_API ABlacksiteObjective : public AActor
{
    GENERATED_BODY()

public:
    ABlacksiteObjective();
    void Interact(ABlacksitePlayerCharacter* Player);

private:
    UPROPERTY()
    TObjectPtr<USceneComponent> Root;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> CaseMesh;

    UPROPERTY()
    TObjectPtr<UPointLightComponent> MarkerLight;

    bool bSecured = false;
};

UCLASS()
class BLACKSITEEXTRACTION_API ABlacksiteExtractionZone : public AActor
{
    GENERATED_BODY()

public:
    ABlacksiteExtractionZone();

    virtual void Tick(float DeltaSeconds) override;
    bool IsPlayerInside(const ABlacksitePlayerCharacter* Player) const;
    float GetRequiredHoldTime() const { return 4.0f; }

private:
    UPROPERTY()
    TObjectPtr<USceneComponent> Root;

    UPROPERTY()
    TObjectPtr<UBoxComponent> Zone;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> FloorMesh;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> LeftPost;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> RightPost;

    UPROPERTY()
    TObjectPtr<UStaticMeshComponent> HeaderBeam;

    UPROPERTY()
    TObjectPtr<UPointLightComponent> StatusLight;
};

UCLASS()
class BLACKSITEEXTRACTION_API ABlacksiteHUD : public AHUD
{
    GENERATED_BODY()

public:
    virtual void DrawHUD() override;

private:
    void DrawBar(float X, float Y, float Width, float Height, float Fraction,
        const FLinearColor& FillColor, const FLinearColor& BackColor);
};

UCLASS()
class BLACKSITEEXTRACTION_API ABlacksiteGameMode : public AGameModeBase
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
    void BuildHarbor();
    void BuildLighting();
    void SpawnCombatants();
    void SpawnObjectiveAndExtraction();
    void EnsurePlayer();
    void CreateNavigationBounds();

    AActor* SpawnBox(const FVector& Location, const FVector& Scale, const FRotator& Rotation = FRotator::ZeroRotator);
    AActor* SpawnCylinder(const FVector& Location, const FVector& Scale, const FRotator& Rotation = FRotator::ZeroRotator);

    bool bObjectiveSecured = false;
    bool bRaidComplete = false;
    bool bExtracted = false;
    int32 Kills = 0;
    int32 EnemiesRemaining = 0;

    UPROPERTY()
    TObjectPtr<ABlacksiteObjective> Objective;

    UPROPERTY()
    TObjectPtr<ABlacksiteExtractionZone> ExtractionZone;

    TArray<TWeakObjectPtr<ABlacksiteEnemyCharacter>> Enemies;
};
