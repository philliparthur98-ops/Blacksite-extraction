#include "BlacksitePlayerCharacter.h"

#include "BlacksiteAudio.h"
#include "BlacksiteEnemyCharacter.h"
#include "BlacksiteExtractionZone.h"
#include "BlacksiteGameMode.h"
#include "BlacksiteObjective.h"
#include "Camera/CameraComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"

namespace
{
    UStaticMesh* CubeMesh()
    {
        static UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube"));
        return Mesh;
    }

    UStaticMesh* CylinderMesh()
    {
        static UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
        return Mesh;
    }
}

ABlacksitePlayerCharacter::ABlacksitePlayerCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    GetCapsuleComponent()->InitCapsuleSize(42.0f, 92.0f);
    GetCapsuleComponent()->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);

    bUseControllerRotationYaw = true;
    GetCharacterMovement()->bOrientRotationToMovement = false;
    GetCharacterMovement()->MaxWalkSpeed = 420.0f;
    GetCharacterMovement()->MaxWalkSpeedCrouched = 220.0f;
    GetCharacterMovement()->GroundFriction = 7.5f;
    GetCharacterMovement()->BrakingDecelerationWalking = 1800.0f;
    GetCharacterMovement()->AirControl = 0.18f;
    GetCharacterMovement()->GetNavAgentPropertiesRef().bCanCrouch = true;

    Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("FirstPersonCamera"));
    Camera->SetupAttachment(GetCapsuleComponent());
    Camera->SetRelativeLocation(FVector(-6.0f, 0.0f, 64.0f));
    Camera->bUsePawnControlRotation = true;
    Camera->FieldOfView = 80.0f;

    WeaponPivot = CreateDefaultSubobject<USceneComponent>(TEXT("WeaponPivot"));
    WeaponPivot->SetupAttachment(Camera);
    WeaponPivot->SetRelativeLocation(HipLocation);

    Receiver = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Receiver"));
    Receiver->SetupAttachment(WeaponPivot);
    Receiver->SetStaticMesh(CubeMesh());
    Receiver->SetRelativeScale3D(FVector(0.42f, 0.085f, 0.11f));
    Receiver->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    Handguard = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Handguard"));
    Handguard->SetupAttachment(WeaponPivot);
    Handguard->SetStaticMesh(CubeMesh());
    Handguard->SetRelativeLocation(FVector(43.0f, 0.0f, 0.0f));
    Handguard->SetRelativeScale3D(FVector(0.42f, 0.07f, 0.085f));
    Handguard->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    Barrel = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Barrel"));
    Barrel->SetupAttachment(WeaponPivot);
    Barrel->SetStaticMesh(CylinderMesh());
    Barrel->SetRelativeLocation(FVector(86.0f, 0.0f, 0.0f));
    Barrel->SetRelativeRotation(FRotator(0.0f, 90.0f, 0.0f));
    Barrel->SetRelativeScale3D(FVector(0.028f, 0.028f, 0.46f));
    Barrel->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    Magazine = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Magazine"));
    Magazine->SetupAttachment(WeaponPivot);
    Magazine->SetStaticMesh(CubeMesh());
    Magazine->SetRelativeLocation(FVector(5.0f, 0.0f, -16.0f));
    Magazine->SetRelativeRotation(FRotator(0.0f, 0.0f, -7.0f));
    Magazine->SetRelativeScale3D(FVector(0.12f, 0.06f, 0.24f));
    Magazine->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    Stock = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Stock"));
    Stock->SetupAttachment(WeaponPivot);
    Stock->SetStaticMesh(CubeMesh());
    Stock->SetRelativeLocation(FVector(-37.0f, 0.0f, -1.0f));
    Stock->SetRelativeScale3D(FVector(0.34f, 0.07f, 0.09f));
    Stock->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    MuzzleFlash = CreateDefaultSubobject<UPointLightComponent>(TEXT("MuzzleFlash"));
    MuzzleFlash->SetupAttachment(WeaponPivot);
    MuzzleFlash->SetRelativeLocation(FVector(132.0f, 0.0f, 0.0f));
    MuzzleFlash->SetLightColor(FLinearColor(1.0f, 0.36f, 0.08f), false);
    MuzzleFlash->SetAttenuationRadius(480.0f);
    MuzzleFlash->SetIntensity(0.0f);
}

void ABlacksitePlayerCharacter::BeginPlay()
{
    Super::BeginPlay();

    if (APlayerController* PC = Cast<APlayerController>(GetController()))
    {
        PC->SetShowMouseCursor(false);
        PC->SetInputMode(FInputModeGameOnly());
    }
}

void ABlacksitePlayerCharacter::SetupPlayerInputComponent(UInputComponent* Input)
{
    Super::SetupPlayerInputComponent(Input);

    Input->BindAxis(TEXT("MoveForward"), this, &ABlacksitePlayerCharacter::MoveForward);
    Input->BindAxis(TEXT("MoveRight"), this, &ABlacksitePlayerCharacter::MoveRight);
    Input->BindAxis(TEXT("Turn"), this, &ABlacksitePlayerCharacter::Turn);
    Input->BindAxis(TEXT("LookUp"), this, &ABlacksitePlayerCharacter::LookUp);

    Input->BindAction(TEXT("Jump"), IE_Pressed, this, &ABlacksitePlayerCharacter::JumpPressed);
    Input->BindAction(TEXT("Jump"), IE_Released, this, &ABlacksitePlayerCharacter::JumpReleased);
    Input->BindAction(TEXT("Sprint"), IE_Pressed, this, &ABlacksitePlayerCharacter::SprintPressed);
    Input->BindAction(TEXT("Sprint"), IE_Released, this, &ABlacksitePlayerCharacter::SprintReleased);
    Input->BindAction(TEXT("CrouchToggle"), IE_Pressed, this, &ABlacksitePlayerCharacter::CrouchPressed);
    Input->BindAction(TEXT("Fire"), IE_Pressed, this, &ABlacksitePlayerCharacter::FirePressed);
    Input->BindAction(TEXT("Fire"), IE_Released, this, &ABlacksitePlayerCharacter::FireReleased);
    Input->BindAction(TEXT("Aim"), IE_Pressed, this, &ABlacksitePlayerCharacter::AimPressed);
    Input->BindAction(TEXT("Aim"), IE_Released, this, &ABlacksitePlayerCharacter::AimReleased);
    Input->BindAction(TEXT("Reload"), IE_Pressed, this, &ABlacksitePlayerCharacter::ReloadPressed);
    Input->BindAction(TEXT("Interact"), IE_Pressed, this, &ABlacksitePlayerCharacter::InteractPressed);
    Input->BindAction(TEXT("Interact"), IE_Released, this, &ABlacksitePlayerCharacter::InteractReleased);
    Input->BindAction(TEXT("RestartRaid"), IE_Pressed, this, &ABlacksitePlayerCharacter::RestartRaid);
}

void ABlacksitePlayerCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (bDead)
    {
        return;
    }

    MuzzleEnergy = FMath::FInterpTo(MuzzleEnergy, 0.0f, DeltaSeconds, 34.0f);
    MuzzleFlash->SetIntensity(MuzzleEnergy);

    if (bReloading)
    {
        ReloadTimer += DeltaSeconds;
        if (ReloadTimer >= ReloadDuration)
        {
            FinishReload();
        }
    }

    if (bFireHeld)
    {
        TryFire();
    }

    UpdateWeapon(DeltaSeconds);
    UpdateInteraction(DeltaSeconds);
    UpdateFootsteps(DeltaSeconds);
}

void ABlacksitePlayerCharacter::MoveForward(float Value)
{
    if (!bDead && FMath::Abs(Value) > KINDA_SMALL_NUMBER)
    {
        AddMovementInput(GetActorForwardVector(), Value);
    }
}

void ABlacksitePlayerCharacter::MoveRight(float Value)
{
    if (!bDead && FMath::Abs(Value) > KINDA_SMALL_NUMBER)
    {
        AddMovementInput(GetActorRightVector(), Value);
    }
}

void ABlacksitePlayerCharacter::Turn(float Value)
{
    if (!bDead)
    {
        AddControllerYawInput(Value);
    }
}

void ABlacksitePlayerCharacter::LookUp(float Value)
{
    if (!bDead)
    {
        AddControllerPitchInput(Value);
    }
}

void ABlacksitePlayerCharacter::JumpPressed()
{
    if (!bDead)
    {
        Jump();
    }
}

void ABlacksitePlayerCharacter::JumpReleased()
{
    StopJumping();
}

void ABlacksitePlayerCharacter::SprintPressed()
{
    bSprintHeld = true;
}

void ABlacksitePlayerCharacter::SprintReleased()
{
    bSprintHeld = false;
}

void ABlacksitePlayerCharacter::CrouchPressed()
{
    if (bDead)
    {
        return;
    }

    bIsCrouched ? UnCrouch() : Crouch();
}

void ABlacksitePlayerCharacter::FirePressed()
{
    bFireHeld = true;
    TryFire();
}

void ABlacksitePlayerCharacter::FireReleased()
{
    bFireHeld = false;
}

void ABlacksitePlayerCharacter::AimPressed()
{
    bAimHeld = true;
}

void ABlacksitePlayerCharacter::AimReleased()
{
    bAimHeld = false;
}

void ABlacksitePlayerCharacter::ReloadPressed()
{
    BeginReload();
}

void ABlacksitePlayerCharacter::InteractPressed()
{
    bInteractHeld = true;
    InteractionProgress = 0.0f;
}

void ABlacksitePlayerCharacter::InteractReleased()
{
    bInteractHeld = false;
    InteractionProgress = 0.0f;
}

void ABlacksitePlayerCharacter::RestartRaid()
{
    if (UWorld* World = GetWorld())
    {
        UGameplayStatics::OpenLevel(this, FName(*World->GetName()));
    }
}

void ABlacksitePlayerCharacter::TryFire()
{
    if (bDead || bReloading || bSprintHeld)
    {
        return;
    }

    const float Now = GetWorld()->GetTimeSeconds();
    if (Now - LastFireTime < FireInterval)
    {
        return;
    }

    if (Ammo <= 0)
    {
        LastFireTime = Now;
        PlayShot(true);
        return;
    }

    FireRound();
}

void ABlacksitePlayerCharacter::FireRound()
{
    --Ammo;
    LastFireTime = GetWorld()->GetTimeSeconds();
    RecoilKick = FMath::Min(RecoilKick + (bAimHeld ? 0.55f : 0.92f), 2.8f);
    MuzzleEnergy = 9500.0f;

    const FVector Start = Camera->GetComponentLocation();
    FVector Direction = Camera->GetForwardVector();
    const float SpreadDegrees = bAimHeld ? 0.18f : 0.72f;
    Direction = FMath::VRandCone(Direction, FMath::DegreesToRadians(SpreadDegrees));

    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlacksitePlayerFire), true, this);
    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, Start + Direction * 20000.0f, ECC_Visibility, Params))
    {
        if (ABlacksiteEnemyCharacter* Enemy = Cast<ABlacksiteEnemyCharacter>(Hit.GetActor()))
        {
            const bool bHeadshot = Enemy->IsHeadComponent(Hit.GetComponent());
            UGameplayStatics::ApplyPointDamage(
                Enemy,
                bHeadshot ? 92.0f : 34.0f,
                Direction,
                Hit,
                GetController(),
                this,
                nullptr);
        }
    }

    if (APlayerController* PC = Cast<APlayerController>(GetController()))
    {
        FRotator Rotation = PC->GetControlRotation();
        Rotation.Pitch -= bAimHeld ? 0.48f : 0.78f;
        Rotation.Yaw += FMath::FRandRange(-0.24f, 0.24f);
        PC->SetControlRotation(Rotation);
    }

    PlayShot(false);

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->BroadcastGunshot(GetActorLocation());
    }
}

void ABlacksitePlayerCharacter::BeginReload()
{
    if (bDead || bReloading || Ammo >= MagazineSize || ReserveAmmo <= 0)
    {
        return;
    }

    bReloading = true;
    bFireHeld = false;
    ReloadTimer = 0.0f;
    BlacksiteAudio::PlayTransient(this, GetActorLocation(), 155.0f, 0.08f, 0.25f, 0.78f);
}

void ABlacksitePlayerCharacter::FinishReload()
{
    const int32 Needed = MagazineSize - Ammo;
    const int32 Taken = FMath::Min(Needed, ReserveAmmo);
    Ammo += Taken;
    ReserveAmmo -= Taken;
    ReloadTimer = 0.0f;
    bReloading = false;
    Magazine->SetVisibility(true, true);
    BlacksiteAudio::PlayTransient(this, GetActorLocation(), 390.0f, 0.05f, 0.20f, 0.16f);
}

void ABlacksitePlayerCharacter::UpdateWeapon(float DeltaSeconds)
{
    const bool bActuallySprinting = bSprintHeld && !bAimHeld && !bReloading && GetVelocity().SizeSquared2D() > 500.0f;
    GetCharacterMovement()->MaxWalkSpeed = bActuallySprinting ? 650.0f : (bAimHeld ? 320.0f : 420.0f);

    FVector TargetLocation = HipLocation;
    FRotator TargetRotation = FRotator::ZeroRotator;

    if (bReloading)
    {
        const float P = FMath::Clamp(ReloadTimer / ReloadDuration, 0.0f, 1.0f);
        const float Arc = FMath::Sin(P * PI);
        TargetLocation += FVector(-4.0f, 11.0f, -26.0f * Arc);
        TargetRotation = FRotator(18.0f * Arc, -14.0f * Arc, 28.0f * Arc);
        Magazine->SetVisibility(!(P > 0.25f && P < 0.60f), true);

        if (P > 0.78f)
        {
            TargetLocation.X -= 5.0f;
            TargetRotation.Pitch -= 4.0f;
        }
    }
    else if (bActuallySprinting)
    {
        TargetLocation = SprintLocation;
        TargetRotation = FRotator(-18.0f, 15.0f, 42.0f);
    }
    else if (bAimHeld)
    {
        TargetLocation = AimLocation;
    }
    else
    {
        const float SpeedAlpha = FMath::Clamp(GetVelocity().Size2D() / 420.0f, 0.0f, 1.0f);
        const float T = GetWorld()->GetTimeSeconds();
        TargetLocation.Z += FMath::Sin(T * 8.0f) * 0.65f * SpeedAlpha;
        TargetLocation.Y += FMath::Sin(T * 4.0f) * 0.28f;
        TargetRotation.Roll += FMath::Sin(T * 6.0f) * 0.45f * SpeedAlpha;
    }

    RecoilKick = FMath::FInterpTo(RecoilKick, 0.0f, DeltaSeconds, 16.0f);
    TargetLocation.X -= RecoilKick * 3.2f;
    TargetRotation.Pitch += RecoilKick * 2.2f;

    WeaponPivot->SetRelativeLocation(FMath::VInterpTo(WeaponPivot->GetRelativeLocation(), TargetLocation, DeltaSeconds, 14.0f));
    WeaponPivot->SetRelativeRotation(FMath::RInterpTo(WeaponPivot->GetRelativeRotation(), TargetRotation, DeltaSeconds, 16.0f));
    Camera->SetFieldOfView(FMath::FInterpTo(Camera->FieldOfView, bAimHeld ? 58.0f : 80.0f, DeltaSeconds, 12.0f));
}

void ABlacksitePlayerCharacter::UpdateInteraction(float DeltaSeconds)
{
    if (!bInteractHeld || bDead)
    {
        InteractionProgress = 0.0f;
        return;
    }

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        if (ABlacksiteExtractionZone* Zone = GM->GetExtractionZone())
        {
            if (GM->IsObjectiveSecured() && Zone->IsPlayerInside(this))
            {
                InteractionProgress += DeltaSeconds / Zone->GetRequiredHoldTime();
                if (InteractionProgress >= 1.0f)
                {
                    InteractionProgress = 0.0f;
                    bInteractHeld = false;
                    GM->CompleteExtraction();
                }
                return;
            }
        }
    }

    const FVector Start = Camera->GetComponentLocation();
    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlacksiteInteract), false, this);
    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, Start + Camera->GetForwardVector() * 260.0f, ECC_Visibility, Params))
    {
        if (ABlacksiteObjective* Objective = Cast<ABlacksiteObjective>(Hit.GetActor()))
        {
            InteractionProgress += DeltaSeconds / 0.65f;
            if (InteractionProgress >= 1.0f)
            {
                InteractionProgress = 0.0f;
                bInteractHeld = false;
                Objective->Interact(this);
            }
            return;
        }
    }

    InteractionProgress = 0.0f;
}

void ABlacksitePlayerCharacter::UpdateFootsteps(float DeltaSeconds)
{
    if (!GetCharacterMovement()->IsMovingOnGround() || GetVelocity().SizeSquared2D() < 40000.0f)
    {
        FootstepTimer = 0.0f;
        return;
    }

    FootstepTimer -= DeltaSeconds;
    if (FootstepTimer <= 0.0f)
    {
        const bool bFast = GetCharacterMovement()->MaxWalkSpeed > 500.0f;
        const float Volume = bIsCrouched ? 0.07f : (bFast ? 0.17f : 0.12f);
        BlacksiteAudio::PlayTransient(this, GetActorLocation(), bIsCrouched ? 92.0f : 72.0f, 0.055f, Volume, 0.88f);
        FootstepTimer = bFast ? 0.31f : 0.48f;
    }
}

void ABlacksitePlayerCharacter::PlayShot(bool bDryFire)
{
    if (bDryFire)
    {
        BlacksiteAudio::PlayTransient(this, GetActorLocation(), 1150.0f, 0.025f, 0.13f, 0.08f);
        return;
    }

    BlacksiteAudio::PlayTransient(this, GetActorLocation(), 92.0f, 0.18f, 0.90f, 0.80f);
    BlacksiteAudio::PlayTransient(this, GetActorLocation(), 720.0f, 0.07f, 0.32f, 0.18f);
}

float ABlacksitePlayerCharacter::TakeDamage(
    float DamageAmount,
    const FDamageEvent& DamageEvent,
    AController* EventInstigator,
    AActor* DamageCauser)
{
    if (bDead)
    {
        return 0.0f;
    }

    const float Applied = FMath::Max(0.0f, DamageAmount);
    Health = FMath::Clamp(Health - Applied, 0.0f, MaxHealth);
    if (Health <= 0.0f)
    {
        Die();
    }
    return Applied;
}

void ABlacksitePlayerCharacter::Die()
{
    if (bDead)
    {
        return;
    }

    bDead = true;
    bFireHeld = false;
    GetCharacterMovement()->DisableMovement();

    if (APlayerController* PC = Cast<APlayerController>(GetController()))
    {
        DisableInput(PC);
    }

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->FailRaid();
    }
}
