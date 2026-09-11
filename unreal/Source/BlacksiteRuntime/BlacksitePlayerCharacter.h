#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "BlacksitePlayerCharacter.generated.h"

class UCameraComponent;
class UPointLightComponent;
class USceneComponent;
class UStaticMeshComponent;

UCLASS()
class BLACKSITERUNTIME_API ABlacksitePlayerCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ABlacksitePlayerCharacter();

    virtual void Tick(float DeltaSeconds) override;
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
    virtual float TakeDamage(float DamageAmount, const FDamageEvent& DamageEvent,
        AController* EventInstigator, AActor* DamageCauser) override;

    int32 GetAmmo() const { return Ammo; }
    int32 GetReserveAmmo() const { return ReserveAmmo; }
    float GetHealth() const { return Health; }
    float GetMaxHealth() const { return MaxHealth; }
    float GetInteractionProgress() const { return InteractionProgress; }
    bool IsAiming() const { return bAimHeld; }
    bool IsDead() const { return bDead; }

protected:
    virtual void BeginPlay() override;

private:
    void MoveForward(float Value);
    void MoveRight(float Value);
    void Turn(float Value);
    void LookUp(float Value);
    void JumpPressed();
    void JumpReleased();
    void SprintPressed();
    void SprintReleased();
    void CrouchPressed();
    void FirePressed();
    void FireReleased();
    void AimPressed();
    void AimReleased();
    void ReloadPressed();
    void InteractPressed();
    void InteractReleased();
    void RestartRaid();

    void TryFire();
    void FireRound();
    void BeginReload();
    void FinishReload();
    void UpdateWeapon(float DeltaSeconds);
    void UpdateInteraction(float DeltaSeconds);
    void UpdateFootsteps(float DeltaSeconds);
    void PlayShot(bool bDryFire);
    void Die();

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UCameraComponent> Camera;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<USceneComponent> WeaponPivot;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Receiver;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Handguard;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Barrel;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Magazine;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Stock;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UPointLightComponent> MuzzleFlash;

    float Health = 100.0f;
    float MaxHealth = 100.0f;
    int32 Ammo = 30;
    int32 ReserveAmmo = 120;
    int32 MagazineSize = 30;

    float FireInterval = 60.0f / 650.0f;
    float LastFireTime = -100.0f;
    float ReloadTimer = 0.0f;
    float ReloadDuration = 1.75f;
    float InteractionProgress = 0.0f;
    float FootstepTimer = 0.0f;
    float RecoilKick = 0.0f;
    float MuzzleEnergy = 0.0f;

    bool bFireHeld = false;
    bool bAimHeld = false;
    bool bSprintHeld = false;
    bool bInteractHeld = false;
    bool bReloading = false;
    bool bDead = false;

    FVector HipLocation = FVector(34.0f, 21.0f, -22.0f);
    FVector AimLocation = FVector(29.0f, 0.0f, -16.0f);
    FVector SprintLocation = FVector(22.0f, 27.0f, -34.0f);
};
