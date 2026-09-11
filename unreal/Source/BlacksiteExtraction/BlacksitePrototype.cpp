#include "BlacksitePrototype.h"

#include "AIController.h"
#include "Camera/CameraComponent.h"
#include "Components/BoxComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/Engine.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/PointLight.h"
#include "Engine/PostProcessVolume.h"
#include "Engine/SkyAtmosphere.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMeshActor.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "NavigationSystem.h"
#include "NavMesh/NavMeshBoundsVolume.h"
#include "Sound/SoundWaveProcedural.h"

namespace BlacksitePrototype
{
    static UStaticMesh* LoadCube()
    {
        static UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube"));
        return Mesh;
    }

    static UStaticMesh* LoadCylinder()
    {
        static UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
        return Mesh;
    }

    static UStaticMesh* LoadSphere()
    {
        static UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Sphere.Sphere"));
        return Mesh;
    }

    static void PlayProceduralSound(UObject* WorldContext, const FVector& Location, float BaseFrequency,
        float Duration, float Volume, bool bNoiseHeavy)
    {
        if (!WorldContext)
        {
            return;
        }

        constexpr int32 SampleRate = 44100;
        const int32 SampleCount = FMath::Max(1, FMath::RoundToInt(Duration * static_cast<float>(SampleRate)));
        TArray<int16> PCM;
        PCM.SetNumUninitialized(SampleCount);

        float Phase = 0.0f;
        const float PhaseStep = 2.0f * PI * BaseFrequency / static_cast<float>(SampleRate);

        for (int32 Index = 0; Index < SampleCount; ++Index)
        {
            const float T = static_cast<float>(Index) / static_cast<float>(SampleCount);
            const float Envelope = FMath::Square(1.0f - T);
            const float Tone = FMath::Sin(Phase);
            const float Noise = FMath::FRandRange(-1.0f, 1.0f);
            const float Mixed = bNoiseHeavy ? (Tone * 0.22f + Noise * 0.78f) : (Tone * 0.82f + Noise * 0.18f);
            PCM[Index] = static_cast<int16>(FMath::Clamp(Mixed * Envelope * Volume, -1.0f, 1.0f) * 32767.0f);
            Phase += PhaseStep;
        }

        USoundWaveProcedural* Sound = NewObject<USoundWaveProcedural>(WorldContext);
        Sound->SetSampleRate(SampleRate);
        Sound->NumChannels = 1;
        Sound->Duration = Duration;
        Sound->bLooping = false;
        Sound->SoundGroup = SOUNDGROUP_Effects;
        Sound->QueueAudio(reinterpret_cast<const uint8*>(PCM.GetData()), PCM.Num() * sizeof(int16));
        UGameplayStatics::PlaySoundAtLocation(WorldContext, Sound, Location, 1.0f);
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
    GetCharacterMovement()->BrakingDecelerationWalking = 1800.0f;
    GetCharacterMovement()->GroundFriction = 7.5f;
    GetCharacterMovement()->AirControl = 0.18f;
    GetCharacterMovement()->GetNavAgentPropertiesRef().bCanCrouch = true;

    Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("FirstPersonCamera"));
    Camera->SetupAttachment(GetCapsuleComponent());
    Camera->SetRelativeLocation(FVector(-6.0f, 0.0f, 64.0f));
    Camera->bUsePawnControlRotation = true;
    Camera->FieldOfView = 80.0f;

    WeaponPivot = CreateDefaultSubobject<USceneComponent>(TEXT("WeaponPivot"));
    WeaponPivot->SetupAttachment(Camera);
    WeaponPivot->SetRelativeLocation(WeaponHipLocation);

    ReceiverMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Receiver"));
    ReceiverMesh->SetupAttachment(WeaponPivot);
    ReceiverMesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    ReceiverMesh->SetRelativeScale3D(FVector(0.42f, 0.085f, 0.11f));
    ReceiverMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    HandguardMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Handguard"));
    HandguardMesh->SetupAttachment(WeaponPivot);
    HandguardMesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    HandguardMesh->SetRelativeLocation(FVector(43.0f, 0.0f, 0.0f));
    HandguardMesh->SetRelativeScale3D(FVector(0.42f, 0.07f, 0.085f));
    HandguardMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    BarrelMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Barrel"));
    BarrelMesh->SetupAttachment(WeaponPivot);
    BarrelMesh->SetStaticMesh(BlacksitePrototype::LoadCylinder());
    BarrelMesh->SetRelativeLocation(FVector(86.0f, 0.0f, 0.0f));
    BarrelMesh->SetRelativeRotation(FRotator(0.0f, 90.0f, 0.0f));
    BarrelMesh->SetRelativeScale3D(FVector(0.028f, 0.028f, 0.46f));
    BarrelMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    MagazineMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Magazine"));
    MagazineMesh->SetupAttachment(WeaponPivot);
    MagazineMesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    MagazineMesh->SetRelativeLocation(FVector(5.0f, 0.0f, -16.0f));
    MagazineMesh->SetRelativeRotation(FRotator(0.0f, 0.0f, -7.0f));
    MagazineMesh->SetRelativeScale3D(FVector(0.12f, 0.06f, 0.24f));
    MagazineMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    StockMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Stock"));
    StockMesh->SetupAttachment(WeaponPivot);
    StockMesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    StockMesh->SetRelativeLocation(FVector(-37.0f, 0.0f, -1.0f));
    StockMesh->SetRelativeScale3D(FVector(0.34f, 0.07f, 0.09f));
    StockMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    MuzzleFlash = CreateDefaultSubobject<UPointLightComponent>(TEXT("MuzzleFlash"));
    MuzzleFlash->SetupAttachment(WeaponPivot);
    MuzzleFlash->SetRelativeLocation(FVector(132.0f, 0.0f, 0.0f));
    MuzzleFlash->SetLightColor(FLinearColor(1.0f, 0.36f, 0.08f));
    MuzzleFlash->SetAttenuationRadius(480.0f);
    MuzzleFlash->SetIntensity(0.0f);
    MuzzleFlash->bUseInverseSquaredFalloff = true;
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

void ABlacksitePlayerCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);

    PlayerInputComponent->BindAxis(TEXT("MoveForward"), this, &ABlacksitePlayerCharacter::MoveForward);
    PlayerInputComponent->BindAxis(TEXT("MoveRight"), this, &ABlacksitePlayerCharacter::MoveRight);
    PlayerInputComponent->BindAxis(TEXT("Turn"), this, &ABlacksitePlayerCharacter::Turn);
    PlayerInputComponent->BindAxis(TEXT("LookUp"), this, &ABlacksitePlayerCharacter::LookUp);

    PlayerInputComponent->BindAction(TEXT("Jump"), IE_Pressed, this, &ABlacksitePlayerCharacter::JumpPressed);
    PlayerInputComponent->BindAction(TEXT("Jump"), IE_Released, this, &ABlacksitePlayerCharacter::JumpReleased);
    PlayerInputComponent->BindAction(TEXT("Sprint"), IE_Pressed, this, &ABlacksitePlayerCharacter::SprintPressed);
    PlayerInputComponent->BindAction(TEXT("Sprint"), IE_Released, this, &ABlacksitePlayerCharacter::SprintReleased);
    PlayerInputComponent->BindAction(TEXT("CrouchToggle"), IE_Pressed, this, &ABlacksitePlayerCharacter::ToggleCrouch);
    PlayerInputComponent->BindAction(TEXT("Fire"), IE_Pressed, this, &ABlacksitePlayerCharacter::FirePressed);
    PlayerInputComponent->BindAction(TEXT("Fire"), IE_Released, this, &ABlacksitePlayerCharacter::FireReleased);
    PlayerInputComponent->BindAction(TEXT("Aim"), IE_Pressed, this, &ABlacksitePlayerCharacter::AimPressed);
    PlayerInputComponent->BindAction(TEXT("Aim"), IE_Released, this, &ABlacksitePlayerCharacter::AimReleased);
    PlayerInputComponent->BindAction(TEXT("Reload"), IE_Pressed, this, &ABlacksitePlayerCharacter::ReloadPressed);
    PlayerInputComponent->BindAction(TEXT("Interact"), IE_Pressed, this, &ABlacksitePlayerCharacter::InteractPressed);
    PlayerInputComponent->BindAction(TEXT("Interact"), IE_Released, this, &ABlacksitePlayerCharacter::InteractReleased);
    PlayerInputComponent->BindAction(TEXT("RestartRaid"), IE_Pressed, this, &ABlacksitePlayerCharacter::RestartRaid);
}

void ABlacksitePlayerCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (bDead)
    {
        return;
    }

    MuzzleIntensity = FMath::FInterpTo(MuzzleIntensity, 0.0f, DeltaSeconds, 34.0f);
    MuzzleFlash->SetIntensity(MuzzleIntensity);

    if (WeaponState == EBlacksiteWeaponState::Reloading)
    {
        ReloadElapsed += DeltaSeconds;
        if (ReloadElapsed >= ReloadDuration)
        {
            FinishReload();
        }
    }

    if (bFireHeld)
    {
        TryFire();
    }

    UpdateWeaponPresentation(DeltaSeconds);
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

void ABlacksitePlayerCharacter::SprintPressed()
{
    bSprintHeld = true;
}

void ABlacksitePlayerCharacter::SprintReleased()
{
    bSprintHeld = false;
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

void ABlacksitePlayerCharacter::ToggleCrouch()
{
    if (bDead)
    {
        return;
    }

    if (bIsCrouched)
    {
        UnCrouch();
    }
    else
    {
        Crouch();
    }
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
        UGameplayStatics::OpenLevel(this, FName(*World->GetName()), false);
    }
}

void ABlacksitePlayerCharacter::TryFire()
{
    if (bDead || WeaponState != EBlacksiteWeaponState::Ready || bSprintHeld)
    {
        return;
    }

    const float Now = GetWorld()->GetTimeSeconds();
    if ((Now - LastFireTime) < FireInterval)
    {
        return;
    }

    if (Ammo <= 0)
    {
        LastFireTime = Now;
        PlayWeaponSound(true);
        return;
    }

    FireOnce();
}

void ABlacksitePlayerCharacter::FireOnce()
{
    if (!Camera || Ammo <= 0)
    {
        return;
    }

    --Ammo;
    LastFireTime = GetWorld()->GetTimeSeconds();
    RecoilKick = FMath::Min(RecoilKick + (bAimHeld ? 0.55f : 0.92f), 2.8f);
    MuzzleIntensity = 9500.0f;

    FVector Start = Camera->GetComponentLocation();
    FVector Direction = Camera->GetForwardVector();

    const float SpreadDegrees = bAimHeld ? 0.18f : 0.72f;
    Direction = FMath::VRandCone(Direction, FMath::DegreesToRadians(SpreadDegrees));

    FVector End = Start + Direction * 20000.0f;
    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlacksitePlayerFire), true, this);

    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params))
    {
        if (ABlacksiteEnemyCharacter* Enemy = Cast<ABlacksiteEnemyCharacter>(Hit.GetActor()))
        {
            const bool bHeadshot = Enemy->IsHeadComponent(Hit.GetComponent());
            const float Damage = bHeadshot ? 92.0f : 34.0f;
            UGameplayStatics::ApplyPointDamage(Enemy, Damage, Direction, Hit, GetController(), this, nullptr);
        }
    }

    if (APlayerController* PC = Cast<APlayerController>(GetController()))
    {
        FRotator ViewRotation = PC->GetControlRotation();
        ViewRotation.Pitch -= bAimHeld ? 0.48f : 0.78f;
        ViewRotation.Yaw += FMath::FRandRange(-0.24f, 0.24f);
        PC->SetControlRotation(ViewRotation);
    }

    PlayWeaponSound(false);

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->BroadcastGunshot(GetActorLocation());
    }
}

void ABlacksitePlayerCharacter::BeginReload()
{
    if (bDead || WeaponState != EBlacksiteWeaponState::Ready || Ammo >= MagazineSize || ReserveAmmo <= 0)
    {
        return;
    }

    WeaponState = EBlacksiteWeaponState::Reloading;
    ReloadElapsed = 0.0f;
    bFireHeld = false;
    BlacksitePrototype::PlayProceduralSound(this, GetActorLocation(), 155.0f, 0.08f, 0.26f, true);
}

void ABlacksitePlayerCharacter::FinishReload()
{
    const int32 Needed = MagazineSize - Ammo;
    const int32 Taken = FMath::Min(Needed, ReserveAmmo);
    Ammo += Taken;
    ReserveAmmo -= Taken;
    ReloadElapsed = 0.0f;
    WeaponState = EBlacksiteWeaponState::Ready;
    MagazineMesh->SetVisibility(true, true);
    BlacksitePrototype::PlayProceduralSound(this, GetActorLocation(), 390.0f, 0.05f, 0.20f, false);
}

void ABlacksitePlayerCharacter::UpdateWeaponPresentation(float DeltaSeconds)
{
    const bool bActuallySprinting = bSprintHeld && !bAimHeld && GetVelocity().SizeSquared2D() > 500.0f &&
        WeaponState == EBlacksiteWeaponState::Ready;

    GetCharacterMovement()->MaxWalkSpeed = bActuallySprinting ? 650.0f : (bAimHeld ? 320.0f : 420.0f);

    FVector TargetLocation = WeaponHipLocation;
    FRotator TargetRotation = WeaponHipRotation;

    if (WeaponState == EBlacksiteWeaponState::Reloading)
    {
        const float P = FMath::Clamp(ReloadElapsed / ReloadDuration, 0.0f, 1.0f);
        const float Arc = FMath::Sin(P * PI);
        TargetLocation += FVector(-4.0f, 11.0f, -26.0f * Arc);
        TargetRotation += FRotator(18.0f * Arc, -14.0f * Arc, 28.0f * Arc);

        if (P > 0.25f && P < 0.60f)
        {
            MagazineMesh->SetVisibility(false, true);
        }
        else
        {
            MagazineMesh->SetVisibility(true, true);
        }

        if (P > 0.78f)
        {
            TargetLocation += FVector(-5.0f, 0.0f, 0.0f);
            TargetRotation.Pitch -= 4.0f;
        }
    }
    else if (bActuallySprinting)
    {
        TargetLocation = WeaponSprintLocation;
        TargetRotation = FRotator(-18.0f, 15.0f, 42.0f);
    }
    else if (bAimHeld)
    {
        TargetLocation = WeaponADSLocation;
        TargetRotation = FRotator::ZeroRotator;
    }
    else
    {
        const float SpeedAlpha = FMath::Clamp(GetVelocity().Size2D() / 420.0f, 0.0f, 1.0f);
        const float Time = GetWorld()->GetTimeSeconds();
        TargetLocation.Z += FMath::Sin(Time * 8.0f) * 0.65f * SpeedAlpha;
        TargetLocation.Y += FMath::Sin(Time * 4.0f) * 0.28f;
        TargetRotation.Roll += FMath::Sin(Time * 6.0f) * 0.45f * SpeedAlpha;
    }

    RecoilKick = FMath::FInterpTo(RecoilKick, 0.0f, DeltaSeconds, 16.0f);
    TargetLocation.X -= RecoilKick * 3.2f;
    TargetRotation.Pitch += RecoilKick * 2.2f;

    WeaponPivot->SetRelativeLocation(FMath::VInterpTo(WeaponPivot->GetRelativeLocation(), TargetLocation, DeltaSeconds, 14.0f));
    WeaponPivot->SetRelativeRotation(FMath::RInterpTo(WeaponPivot->GetRelativeRotation(), TargetRotation, DeltaSeconds, 16.0f));

    const float TargetFOV = bAimHeld ? 58.0f : 80.0f;
    Camera->SetFieldOfView(FMath::FInterpTo(Camera->FieldOfView, TargetFOV, DeltaSeconds, 12.0f));
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
        if (ABlacksiteExtractionZone* Extraction = GM->GetExtractionZone())
        {
            if (GM->IsObjectiveSecured() && Extraction->IsPlayerInside(this))
            {
                InteractionRequired = Extraction->GetRequiredHoldTime();
                InteractionProgress += DeltaSeconds / InteractionRequired;

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

    FVector Start = Camera->GetComponentLocation();
    FVector End = Start + Camera->GetForwardVector() * 260.0f;
    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlacksiteInteract), false, this);

    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params))
    {
        if (ABlacksiteObjective* Objective = Cast<ABlacksiteObjective>(Hit.GetActor()))
        {
            InteractionRequired = 0.65f;
            InteractionProgress += DeltaSeconds / InteractionRequired;

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
    const bool bGroundedMoving = GetCharacterMovement()->IsMovingOnGround() && GetVelocity().SizeSquared2D() > 40000.0f;
    if (!bGroundedMoving)
    {
        FootstepTimer = 0.0f;
        return;
    }

    FootstepTimer -= DeltaSeconds;
    if (FootstepTimer <= 0.0f)
    {
        PlayFootstepSound();
        const bool bSprint = GetCharacterMovement()->MaxWalkSpeed > 500.0f;
        FootstepTimer = bSprint ? 0.31f : 0.48f;
    }
}

void ABlacksitePlayerCharacter::PlayWeaponSound(bool bDryFire)
{
    if (bDryFire)
    {
        BlacksitePrototype::PlayProceduralSound(this, GetActorLocation(), 1150.0f, 0.025f, 0.13f, false);
        return;
    }

    BlacksitePrototype::PlayProceduralSound(this, GetActorLocation(), 92.0f, 0.18f, 0.90f, true);
    BlacksitePrototype::PlayProceduralSound(this, GetActorLocation(), 720.0f, 0.07f, 0.32f, false);
}

void ABlacksitePlayerCharacter::PlayFootstepSound()
{
    const float Pitch = bIsCrouched ? 90.0f : 72.0f;
    BlacksitePrototype::PlayProceduralSound(this, GetActorLocation(), Pitch, 0.055f, bIsCrouched ? 0.08f : 0.15f, true);
}

float ABlacksitePlayerCharacter::TakeDamage(float DamageAmount, FDamageEvent const& DamageEvent,
    AController* EventInstigator, AActor* DamageCauser)
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

ABlacksiteEnemyCharacter::ABlacksiteEnemyCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    AIControllerClass = AAIController::StaticClass();
    AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;
    GetCapsuleComponent()->InitCapsuleSize(42.0f, 92.0f);
    GetCapsuleComponent()->SetCollisionResponseToChannel(ECC_Visibility, ECR_Ignore);

    bUseControllerRotationYaw = false;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 420.0f, 0.0f);
    GetCharacterMovement()->MaxWalkSpeed = 300.0f;

    TorsoMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Torso"));
    TorsoMesh->SetupAttachment(GetCapsuleComponent());
    TorsoMesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    TorsoMesh->SetRelativeLocation(FVector(0.0f, 0.0f, 12.0f));
    TorsoMesh->SetRelativeScale3D(FVector(0.42f, 0.28f, 0.72f));
    TorsoMesh->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    TorsoMesh->SetCollisionResponseToAllChannels(ECR_Ignore);
    TorsoMesh->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);

    HeadMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Head"));
    HeadMesh->SetupAttachment(GetCapsuleComponent());
    HeadMesh->SetStaticMesh(BlacksitePrototype::LoadSphere());
    HeadMesh->SetRelativeLocation(FVector(0.0f, 0.0f, 76.0f));
    HeadMesh->SetRelativeScale3D(FVector(0.20f));
    HeadMesh->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    HeadMesh->SetCollisionResponseToAllChannels(ECR_Ignore);
    HeadMesh->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);

    WeaponMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("EnemyWeapon"));
    WeaponMesh->SetupAttachment(GetCapsuleComponent());
    WeaponMesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    WeaponMesh->SetRelativeLocation(FVector(28.0f, 16.0f, 42.0f));
    WeaponMesh->SetRelativeScale3D(FVector(0.48f, 0.055f, 0.055f));
    WeaponMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    MuzzleFlash = CreateDefaultSubobject<UPointLightComponent>(TEXT("EnemyMuzzleFlash"));
    MuzzleFlash->SetupAttachment(WeaponMesh);
    MuzzleFlash->SetRelativeLocation(FVector(55.0f, 0.0f, 0.0f));
    MuzzleFlash->SetLightColor(FLinearColor(1.0f, 0.24f, 0.04f));
    MuzzleFlash->SetAttenuationRadius(420.0f);
    MuzzleFlash->SetIntensity(0.0f);
}

void ABlacksiteEnemyCharacter::BeginPlay()
{
    Super::BeginPlay();
    HomeLocation = GetActorLocation();
    PatrolOffset = FVector(FMath::FRandRange(-900.0f, 900.0f), FMath::FRandRange(-900.0f, 900.0f), 0.0f);
    TacticalDestination = HomeLocation + PatrolOffset;
}

void ABlacksiteEnemyCharacter::SetArchetype(int32 InArchetype)
{
    Archetype = FMath::Clamp(InArchetype, 0, 2);

    if (Archetype == 0)
    {
        Health = 80.0f;
        GetCharacterMovement()->MaxWalkSpeed = 360.0f;
        TorsoMesh->SetRelativeScale3D(FVector(0.38f, 0.25f, 0.67f));
    }
    else if (Archetype == 1)
    {
        Health = 110.0f;
        GetCharacterMovement()->MaxWalkSpeed = 300.0f;
    }
    else
    {
        Health = 165.0f;
        GetCharacterMovement()->MaxWalkSpeed = 240.0f;
        TorsoMesh->SetRelativeScale3D(FVector(0.48f, 0.34f, 0.78f));
        HeadMesh->SetRelativeScale3D(FVector(0.23f));
    }
}

void ABlacksiteEnemyCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (bDead)
    {
        return;
    }

    FireCooldown = FMath::Max(0.0f, FireCooldown - DeltaSeconds);
    StateTime += DeltaSeconds;
    MuzzleIntensity = FMath::FInterpTo(MuzzleIntensity, 0.0f, DeltaSeconds, 32.0f);
    MuzzleFlash->SetIntensity(MuzzleIntensity);

    FVector PlayerLocation = FVector::ZeroVector;
    const bool bHasLOS = CanSeePlayer(PlayerLocation);

    if (bHasLOS)
    {
        LastSeenLocation = PlayerLocation;
        State = EBlacksiteEnemyState::Combat;
        StateTime = 0.0f;
    }
    else if (State == EBlacksiteEnemyState::Combat)
    {
        State = EBlacksiteEnemyState::Investigate;
        StateTime = 0.0f;
    }
    else if (State == EBlacksiteEnemyState::Investigate && StateTime > 6.0f)
    {
        State = EBlacksiteEnemyState::Patrol;
        StateTime = 0.0f;
        TacticalDestination = HomeLocation + FVector(FMath::FRandRange(-1000.0f, 1000.0f), FMath::FRandRange(-1000.0f, 1000.0f), 0.0f);
    }

    UpdateMovement(DeltaSeconds, PlayerLocation, bHasLOS);

    if (bHasLOS && FireCooldown <= 0.0f)
    {
        FireAtPlayer(PlayerLocation);
    }
}

bool ABlacksiteEnemyCharacter::CanSeePlayer(FVector& OutPlayerLocation) const
{
    const ABlacksitePlayerCharacter* Player = Cast<ABlacksitePlayerCharacter>(UGameplayStatics::GetPlayerPawn(this, 0));
    if (!Player || Player->IsDead())
    {
        return false;
    }

    OutPlayerLocation = Player->GetActorLocation();
    const float DistanceSq = FVector::DistSquared(GetActorLocation(), OutPlayerLocation);
    const float MaxRange = Archetype == 2 ? 3600.0f : 3000.0f;
    if (DistanceSq > FMath::Square(MaxRange))
    {
        return false;
    }

    const FVector Start = GetActorLocation() + FVector(0.0f, 0.0f, 65.0f);
    const FVector End = Player->GetActorLocation() + FVector(0.0f, 0.0f, 58.0f);

    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlacksiteEnemyLOS), true, this);
    if (!GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params))
    {
        return false;
    }

    return Hit.GetActor() == Player;
}

void ABlacksiteEnemyCharacter::UpdateMovement(float DeltaSeconds, const FVector& PlayerLocation, bool bHasLOS)
{
    AAIController* AI = Cast<AAIController>(GetController());
    FVector Destination = TacticalDestination;

    if (State == EBlacksiteEnemyState::Combat && bHasLOS)
    {
        const FVector ToPlayer = PlayerLocation - GetActorLocation();
        const float Distance = ToPlayer.Size2D();

        if (Archetype == 0)
        {
            Destination = PlayerLocation + FVector(ToPlayer.Y, -ToPlayer.X, 0.0f).GetSafeNormal() * 520.0f;
        }
        else if (Archetype == 1)
        {
            Destination = Distance > 1450.0f ? PlayerLocation : GetActorLocation();
        }
        else
        {
            Destination = PlayerLocation - ToPlayer.GetSafeNormal() * 1150.0f;
        }
    }
    else if (State == EBlacksiteEnemyState::Investigate)
    {
        Destination = LastSeenLocation;
    }

    if (AI)
    {
        AI->MoveToLocation(Destination, 90.0f, true, true, true, true, nullptr, true);
    }
    else
    {
        const FVector Dir = (Destination - GetActorLocation()).GetSafeNormal2D();
        AddMovementInput(Dir, 1.0f);
    }

    if (State == EBlacksiteEnemyState::Patrol && FVector::DistSquared2D(GetActorLocation(), TacticalDestination) < FMath::Square(180.0f))
    {
        TacticalDestination = HomeLocation + FVector(FMath::FRandRange(-1100.0f, 1100.0f), FMath::FRandRange(-1100.0f, 1100.0f), 0.0f);
    }
}

void ABlacksiteEnemyCharacter::FireAtPlayer(const FVector& PlayerLocation)
{
    ABlacksitePlayerCharacter* Player = Cast<ABlacksitePlayerCharacter>(UGameplayStatics::GetPlayerPawn(this, 0));
    if (!Player || Player->IsDead())
    {
        return;
    }

    const FVector Start = GetActorLocation() + FVector(0.0f, 0.0f, 58.0f);
    FVector AimPoint = PlayerLocation + FVector(0.0f, 0.0f, 55.0f);

    const float Spread = Archetype == 2 ? 1.2f : (Archetype == 1 ? 1.7f : 2.5f);
    FVector Direction = (AimPoint - Start).GetSafeNormal();
    Direction = FMath::VRandCone(Direction, FMath::DegreesToRadians(Spread));

    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlacksiteEnemyFire), true, this);
    const FVector End = Start + Direction * 10000.0f;

    MuzzleIntensity = Archetype == 2 ? 8500.0f : 6800.0f;
    BlacksitePrototype::PlayProceduralSound(this, Start, Archetype == 2 ? 82.0f : 105.0f, 0.15f, 0.72f, true);

    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params) && Hit.GetActor() == Player)
    {
        const float Damage = Archetype == 2 ? FMath::FRandRange(20.0f, 29.0f) : FMath::FRandRange(12.0f, 21.0f);
        UGameplayStatics::ApplyPointDamage(Player, Damage, Direction, Hit, GetController(), this, nullptr);
    }

    FireCooldown = Archetype == 0 ? FMath::FRandRange(0.25f, 0.48f) :
        (Archetype == 1 ? FMath::FRandRange(0.38f, 0.68f) : FMath::FRandRange(0.55f, 0.88f));

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->BroadcastGunshot(Start);
    }
}

void ABlacksiteEnemyCharacter::Alert(const FVector& SourceLocation)
{
    if (bDead || State == EBlacksiteEnemyState::Combat)
    {
        return;
    }

    LastSeenLocation = SourceLocation;
    State = EBlacksiteEnemyState::Investigate;
    StateTime = 0.0f;
}

bool ABlacksiteEnemyCharacter::IsHeadComponent(const UPrimitiveComponent* Component) const
{
    return Component == HeadMesh;
}

float ABlacksiteEnemyCharacter::TakeDamage(float DamageAmount, FDamageEvent const& DamageEvent,
    AController* EventInstigator, AActor* DamageCauser)
{
    if (bDead)
    {
        return 0.0f;
    }

    const float Applied = FMath::Max(0.0f, DamageAmount);
    Health -= Applied;

    if (Health <= 0.0f)
    {
        Die();
    }
    else
    {
        Alert(DamageCauser ? DamageCauser->GetActorLocation() : GetActorLocation());
    }

    return Applied;
}

void ABlacksiteEnemyCharacter::Die()
{
    if (bDead)
    {
        return;
    }

    bDead = true;
    State = EBlacksiteEnemyState::Dead;
    GetCharacterMovement()->DisableMovement();
    SetActorEnableCollision(false);

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->OnEnemyKilled();
    }

    TorsoMesh->SetRelativeRotation(FRotator(0.0f, 0.0f, 78.0f));
    HeadMesh->SetRelativeLocation(FVector(0.0f, 0.0f, 24.0f));
    SetLifeSpan(20.0f);
}

ABlacksiteObjective::ABlacksiteObjective()
{
    PrimaryActorTick.bCanEverTick = false;

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);

    CaseMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("ArchiveDrive"));
    CaseMesh->SetupAttachment(Root);
    CaseMesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    CaseMesh->SetRelativeScale3D(FVector(0.38f, 0.26f, 0.09f));
    CaseMesh->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    CaseMesh->SetCollisionResponseToAllChannels(ECR_Ignore);
    CaseMesh->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);

    MarkerLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("MarkerLight"));
    MarkerLight->SetupAttachment(Root);
    MarkerLight->SetRelativeLocation(FVector(0.0f, 0.0f, 35.0f));
    MarkerLight->SetLightColor(FLinearColor(0.08f, 0.72f, 1.0f));
    MarkerLight->SetIntensity(1300.0f);
    MarkerLight->SetAttenuationRadius(420.0f);
}

void ABlacksiteObjective::Interact(ABlacksitePlayerCharacter* Player)
{
    if (bSecured)
    {
        return;
    }

    bSecured = true;
    BlacksitePrototype::PlayProceduralSound(this, GetActorLocation(), 920.0f, 0.10f, 0.18f, false);

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->SecureObjective();
    }

    SetActorHiddenInGame(true);
    SetActorEnableCollision(false);
}

ABlacksiteExtractionZone::ABlacksiteExtractionZone()
{
    PrimaryActorTick.bCanEverTick = true;

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);

    Zone = CreateDefaultSubobject<UBoxComponent>(TEXT("ExtractionVolume"));
    Zone->SetupAttachment(Root);
    Zone->SetBoxExtent(FVector(290.0f, 290.0f, 150.0f));
    Zone->SetRelativeLocation(FVector(0.0f, 0.0f, 100.0f));
    Zone->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    Zone->SetCollisionResponseToAllChannels(ECR_Ignore);
    Zone->SetCollisionResponseToChannel(ECC_Pawn, ECR_Overlap);

    FloorMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CheckpointFloor"));
    FloorMesh->SetupAttachment(Root);
    FloorMesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    FloorMesh->SetRelativeLocation(FVector(0.0f, 0.0f, 10.0f));
    FloorMesh->SetRelativeScale3D(FVector(5.5f, 5.5f, 0.18f));
    FloorMesh->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    FloorMesh->SetCollisionResponseToAllChannels(ECR_Ignore);

    LeftPost = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("LeftPost"));
    LeftPost->SetupAttachment(Root);
    LeftPost->SetStaticMesh(BlacksitePrototype::LoadCube());
    LeftPost->SetRelativeLocation(FVector(0.0f, -250.0f, 180.0f));
    LeftPost->SetRelativeScale3D(FVector(0.35f, 0.35f, 3.6f));
    LeftPost->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    RightPost = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("RightPost"));
    RightPost->SetupAttachment(Root);
    RightPost->SetStaticMesh(BlacksitePrototype::LoadCube());
    RightPost->SetRelativeLocation(FVector(0.0f, 250.0f, 180.0f));
    RightPost->SetRelativeScale3D(FVector(0.35f, 0.35f, 3.6f));
    RightPost->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    HeaderBeam = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("HeaderBeam"));
    HeaderBeam->SetupAttachment(Root);
    HeaderBeam->SetStaticMesh(BlacksitePrototype::LoadCube());
    HeaderBeam->SetRelativeLocation(FVector(0.0f, 0.0f, 360.0f));
    HeaderBeam->SetRelativeScale3D(FVector(0.35f, 5.35f, 0.28f));
    HeaderBeam->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    StatusLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("StatusLight"));
    StatusLight->SetupAttachment(Root);
    StatusLight->SetRelativeLocation(FVector(0.0f, 0.0f, 300.0f));
    StatusLight->SetAttenuationRadius(1200.0f);
    StatusLight->SetIntensity(4200.0f);
    StatusLight->SetLightColor(FLinearColor(0.85f, 0.08f, 0.03f));
}

void ABlacksiteExtractionZone::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    const ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>();
    if (!GM)
    {
        return;
    }

    const FLinearColor Target = GM->IsObjectiveSecured() ?
        FLinearColor(0.05f, 0.95f, 0.22f) :
        FLinearColor(0.95f, 0.08f, 0.03f);

    StatusLight->SetLightColor(FLinearColor::LerpUsingHSV(StatusLight->GetLightColor(), Target, FMath::Clamp(DeltaSeconds * 4.0f, 0.0f, 1.0f)));
}

bool ABlacksiteExtractionZone::IsPlayerInside(const ABlacksitePlayerCharacter* Player) const
{
    return Player && Zone->IsOverlappingActor(Player);
}

void ABlacksiteHUD::DrawBar(float X, float Y, float Width, float Height, float Fraction,
    const FLinearColor& FillColor, const FLinearColor& BackColor)
{
    DrawRect(BackColor, X, Y, Width, Height);
    DrawRect(FillColor, X, Y, Width * FMath::Clamp(Fraction, 0.0f, 1.0f), Height);
}

void ABlacksiteHUD::DrawHUD()
{
    Super::DrawHUD();

    if (!Canvas || !GEngine)
    {
        return;
    }

    ABlacksitePlayerCharacter* Player = PlayerOwner ? Cast<ABlacksitePlayerCharacter>(PlayerOwner->GetPawn()) : nullptr;
    ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>();
    if (!Player || !GM)
    {
        return;
    }

    const float W = Canvas->ClipX;
    const float H = Canvas->ClipY;
    UFont* SmallFont = GEngine->GetSmallFont();
    UFont* MediumFont = GEngine->GetMediumFont();

    const FLinearColor White(0.88f, 0.93f, 0.94f, 1.0f);
    const FLinearColor Cyan(0.20f, 0.86f, 0.94f, 1.0f);
    const FLinearColor Red(0.95f, 0.18f, 0.12f, 1.0f);
    const FLinearColor Green(0.20f, 0.90f, 0.38f, 1.0f);
    const FLinearColor Dark(0.01f, 0.02f, 0.025f, 0.78f);

    DrawRect(Dark, 24.0f, H - 128.0f, 310.0f, 92.0f);
    DrawText(FString::Printf(TEXT("VXR-11   %02d / %03d"), Player->GetAmmo(), Player->GetReserve()),
        White, 42.0f, H - 108.0f, MediumFont, 1.0f, false);

    DrawText(TEXT("VITALS"), White, 42.0f, H - 76.0f, SmallFont, 0.9f, false);
    DrawBar(104.0f, H - 70.0f, 194.0f, 9.0f, Player->GetHealth() / Player->GetMaxHealth(), Green, FLinearColor(0.12f, 0.12f, 0.12f, 0.95f));

    DrawRect(Dark, W - 412.0f, 24.0f, 388.0f, 82.0f);
    DrawText(GM->GetObjectiveText(), GM->IsObjectiveSecured() ? Green : Cyan,
        W - 394.0f, 42.0f, SmallFont, 0.95f, false);
    DrawText(FString::Printf(TEXT("HOSTILES %02d   KILLS %02d"), GM->GetEnemiesRemaining(), GM->GetKills()),
        White, W - 394.0f, 70.0f, SmallFont, 0.85f, false);

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
        DrawBar(W * 0.5f - 145.0f, H * 0.72f + 28.0f, 290.0f, 8.0f,
            Player->GetInteractionProgress(), GM->IsObjectiveSecured() ? Green : Cyan,
            FLinearColor(0.12f, 0.12f, 0.12f, 1.0f));
        DrawText(GM->IsObjectiveSecured() ? TEXT("HOLD F // EXTRACTING") : TEXT("HOLD F // SECURING DRIVE"),
            White, W * 0.5f - 112.0f, H * 0.72f + 6.0f, SmallFont, 0.85f, false);
    }

    DrawText(TEXT("WASD MOVE   SHIFT SPRINT   CTRL CROUCH   RMB ADS   R RELOAD   F INTERACT   F5 RESTART"),
        FLinearColor(0.58f, 0.64f, 0.66f, 1.0f), 28.0f, 24.0f, SmallFont, 0.72f, false);

    if (GM->IsRaidComplete())
    {
        DrawRect(FLinearColor(0.0f, 0.0f, 0.0f, 0.76f), 0.0f, H * 0.36f, W, 150.0f);
        DrawText(GM->WasExtracted() ? TEXT("EXTRACTION COMPLETE") : TEXT("OPERATOR KIA"),
            GM->WasExtracted() ? Green : Red, W * 0.5f - 160.0f, H * 0.40f, MediumFont, 1.35f, false);
        DrawText(TEXT("F5 // RUN HARBOR AGAIN"), White, W * 0.5f - 92.0f, H * 0.46f, SmallFont, 0.9f, false);
    }
}

ABlacksiteGameMode::ABlacksiteGameMode()
{
    DefaultPawnClass = ABlacksitePlayerCharacter::StaticClass();
    HUDClass = ABlacksiteHUD::StaticClass();
}

void ABlacksiteGameMode::StartPlay()
{
    Super::StartPlay();

    BuildLighting();
    BuildHarbor();
    CreateNavigationBounds();
    EnsurePlayer();
    SpawnObjectiveAndExtraction();
    SpawnCombatants();
}

void ABlacksiteGameMode::BuildLighting()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    ADirectionalLight* Sun = World->SpawnActor<ADirectionalLight>(FVector::ZeroVector, FRotator(-32.0f, -28.0f, 0.0f));
    if (Sun)
    {
        Sun->GetLightComponent()->SetIntensity(5.0f);
        Sun->GetLightComponent()->SetLightColor(FLinearColor(1.0f, 0.71f, 0.46f));
        Sun->GetLightComponent()->SetCastShadows(true);
    }

    ASkyAtmosphere* Atmosphere = World->SpawnActor<ASkyAtmosphere>();
    if (Atmosphere)
    {
        Atmosphere->SetActorLocation(FVector::ZeroVector);
    }

    ASkyLight* Sky = World->SpawnActor<ASkyLight>();
    if (Sky)
    {
        Sky->GetLightComponent()->SetIntensity(0.85f);
        Sky->GetLightComponent()->SetMobility(EComponentMobility::Movable);
    }

    AExponentialHeightFog* Fog = World->SpawnActor<AExponentialHeightFog>();
    if (Fog)
    {
        Fog->GetComponent()->SetFogDensity(0.012f);
        Fog->GetComponent()->SetFogHeightFalloff(0.24f);
        Fog->GetComponent()->SetFogInscatteringColor(FLinearColor(0.12f, 0.17f, 0.20f));
    }

    APostProcessVolume* Post = World->SpawnActor<APostProcessVolume>();
    if (Post)
    {
        Post->bUnbound = true;
        Post->Settings.bOverride_VignetteIntensity = true;
        Post->Settings.VignetteIntensity = 0.24f;
        Post->Settings.bOverride_BloomIntensity = true;
        Post->Settings.BloomIntensity = 0.34f;
    }

    const TArray<FVector> WorkLights = {
        FVector(-5200.0f, 2800.0f, 440.0f),
        FVector(-1800.0f, -3600.0f, 520.0f),
        FVector(2600.0f, 1800.0f, 420.0f),
        FVector(5600.0f, -2400.0f, 460.0f)
    };

    for (const FVector& Location : WorkLights)
    {
        APointLight* Light = World->SpawnActor<APointLight>(Location, FRotator::ZeroRotator);
        if (Light)
        {
            Light->GetLightComponent()->SetIntensity(5200.0f);
            Light->GetLightComponent()->SetAttenuationRadius(2200.0f);
            Light->GetLightComponent()->SetLightColor(FLinearColor(0.15f, 0.56f, 0.72f));
        }
    }
}

AActor* ABlacksiteGameMode::SpawnBox(const FVector& Location, const FVector& Scale, const FRotator& Rotation)
{
    AStaticMeshActor* Actor = GetWorld()->SpawnActor<AStaticMeshActor>(Location, Rotation);
    if (!Actor)
    {
        return nullptr;
    }

    UStaticMeshComponent* Mesh = Actor->GetStaticMeshComponent();
    Mesh->SetMobility(EComponentMobility::Movable);
    Mesh->SetStaticMesh(BlacksitePrototype::LoadCube());
    Mesh->SetWorldScale3D(Scale);
    Mesh->SetCollisionProfileName(TEXT("BlockAll"));
    Mesh->SetMobility(EComponentMobility::Static);
    return Actor;
}

AActor* ABlacksiteGameMode::SpawnCylinder(const FVector& Location, const FVector& Scale, const FRotator& Rotation)
{
    AStaticMeshActor* Actor = GetWorld()->SpawnActor<AStaticMeshActor>(Location, Rotation);
    if (!Actor)
    {
        return nullptr;
    }

    UStaticMeshComponent* Mesh = Actor->GetStaticMeshComponent();
    Mesh->SetMobility(EComponentMobility::Movable);
    Mesh->SetStaticMesh(BlacksitePrototype::LoadCylinder());
    Mesh->SetWorldScale3D(Scale);
    Mesh->SetCollisionProfileName(TEXT("BlockAll"));
    Mesh->SetMobility(EComponentMobility::Static);
    return Actor;
}

void ABlacksiteGameMode::BuildHarbor()
{
    SpawnBox(FVector(0.0f, 0.0f, -60.0f), FVector(200.0f, 200.0f, 1.2f));

    SpawnBox(FVector(0.0f, -9600.0f, 500.0f), FVector(200.0f, 2.0f, 10.0f));
    SpawnBox(FVector(0.0f, 9600.0f, 500.0f), FVector(200.0f, 2.0f, 10.0f));
    SpawnBox(FVector(-9600.0f, 0.0f, 500.0f), FVector(2.0f, 200.0f, 10.0f));
    SpawnBox(FVector(9600.0f, 0.0f, 500.0f), FVector(2.0f, 200.0f, 10.0f));

    const TArray<FVector> ContainerCenters = {
        FVector(-5200.0f, 3400.0f, 135.0f), FVector(-5200.0f, 2500.0f, 135.0f),
        FVector(-3600.0f, 3400.0f, 135.0f), FVector(-3600.0f, 2500.0f, 135.0f),
        FVector(-2000.0f, 3400.0f, 135.0f), FVector(-2000.0f, 2500.0f, 135.0f)
    };

    for (int32 Index = 0; Index < ContainerCenters.Num(); ++Index)
    {
        const FVector Scale = (Index % 2 == 0) ? FVector(12.0f, 2.5f, 2.7f) : FVector(2.5f, 12.0f, 2.7f);
        SpawnBox(ContainerCenters[Index], Scale);
    }

    SpawnBox(FVector(700.0f, -2500.0f, 360.0f), FVector(30.0f, 1.2f, 7.2f));
    SpawnBox(FVector(700.0f, -5200.0f, 360.0f), FVector(30.0f, 1.2f, 7.2f));
    SpawnBox(FVector(-2200.0f, -3850.0f, 360.0f), FVector(1.2f, 28.0f, 7.2f));
    SpawnBox(FVector(3600.0f, -4550.0f, 360.0f), FVector(1.2f, 14.0f, 7.2f));
    SpawnBox(FVector(3600.0f, -3000.0f, 360.0f), FVector(1.2f, 7.0f, 7.2f));

    for (int32 Row = 0; Row < 4; ++Row)
    {
        SpawnBox(FVector(-900.0f + Row * 1150.0f, -4200.0f, 120.0f), FVector(3.8f, 0.55f, 2.4f));
        SpawnBox(FVector(-900.0f + Row * 1150.0f, -3350.0f, 120.0f), FVector(3.8f, 0.55f, 2.4f));
    }

    for (int32 Pipe = 0; Pipe < 6; ++Pipe)
    {
        SpawnCylinder(FVector(2200.0f + Pipe * 580.0f, 2600.0f, 160.0f), FVector(1.1f, 1.1f, 3.2f));
        SpawnBox(FVector(2200.0f + Pipe * 580.0f, 1650.0f, 85.0f), FVector(2.6f, 1.0f, 1.7f));
    }

    const TArray<FVector> Barricades = {
        FVector(-900.0f, 400.0f, 85.0f), FVector(950.0f, 350.0f, 85.0f),
        FVector(2600.0f, -300.0f, 85.0f), FVector(4300.0f, -1600.0f, 85.0f),
        FVector(5600.0f, -3100.0f, 85.0f), FVector(4600.0f, -5100.0f, 85.0f),
        FVector(-3500.0f, -800.0f, 85.0f), FVector(-5200.0f, -1800.0f, 85.0f)
    };

    for (int32 Index = 0; Index < Barricades.Num(); ++Index)
    {
        SpawnBox(Barricades[Index], FVector(3.6f, 0.7f, 1.7f), FRotator(0.0f, Index * 17.0f, 0.0f));
    }

    SpawnBox(FVector(7600.0f, -4300.0f, 180.0f), FVector(10.0f, 3.0f, 0.3f));
    SpawnBox(FVector(7000.0f, -4300.0f, 200.0f), FVector(0.5f, 3.0f, 4.0f));
    SpawnBox(FVector(8200.0f, -4300.0f, 200.0f), FVector(0.5f, 3.0f, 4.0f));

    SpawnBox(FVector(-6800.0f, 6400.0f, 100.0f), FVector(5.0f, 0.8f, 2.0f));
    SpawnBox(FVector(-5700.0f, 5550.0f, 100.0f), FVector(0.8f, 5.0f, 2.0f));
}

void ABlacksiteGameMode::CreateNavigationBounds()
{
    ANavMeshBoundsVolume* NavBounds = GetWorld()->SpawnActor<ANavMeshBoundsVolume>(
        FVector(0.0f, 0.0f, 300.0f), FRotator::ZeroRotator);

    if (NavBounds)
    {
        NavBounds->SetActorScale3D(FVector(110.0f, 110.0f, 8.0f));

        if (UNavigationSystemV1* NavSystem = FNavigationSystem::GetCurrent<UNavigationSystemV1>(GetWorld()))
        {
            NavSystem->OnNavigationBoundsUpdated(NavBounds);
        }
    }
}

void ABlacksiteGameMode::EnsurePlayer()
{
    const FVector SpawnLocation(-8200.0f, 7200.0f, 120.0f);
    const FRotator SpawnRotation(0.0f, -28.0f, 0.0f);

    APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0);
    if (!PC)
    {
        return;
    }

    if (ABlacksitePlayerCharacter* Existing = Cast<ABlacksitePlayerCharacter>(PC->GetPawn()))
    {
        Existing->SetActorLocationAndRotation(SpawnLocation, SpawnRotation);
        PC->SetControlRotation(SpawnRotation);
        return;
    }

    ABlacksitePlayerCharacter* Player = GetWorld()->SpawnActor<ABlacksitePlayerCharacter>(SpawnLocation, SpawnRotation);
    if (Player)
    {
        PC->Possess(Player);
        PC->SetControlRotation(SpawnRotation);
    }
}

void ABlacksiteGameMode::SpawnObjectiveAndExtraction()
{
    Objective = GetWorld()->SpawnActor<ABlacksiteObjective>(
        FVector(1200.0f, -3850.0f, 95.0f), FRotator(0.0f, 25.0f, 0.0f));

    ExtractionZone = GetWorld()->SpawnActor<ABlacksiteExtractionZone>(
        FVector(7600.0f, -4300.0f, 0.0f), FRotator::ZeroRotator);
}

void ABlacksiteGameMode::SpawnCombatants()
{
    const TArray<FVector> Positions = {
        FVector(-4200.0f, 1800.0f, 110.0f),
        FVector(-1800.0f, 2900.0f, 110.0f),
        FVector(600.0f, -1900.0f, 110.0f),
        FVector(2100.0f, -4300.0f, 110.0f),
        FVector(2700.0f, 1700.0f, 110.0f),
        FVector(4400.0f, 700.0f, 110.0f),
        FVector(5600.0f, -2600.0f, 110.0f),
        FVector(6900.0f, -5100.0f, 110.0f),
        FVector(-3400.0f, -2400.0f, 110.0f)
    };

    for (int32 Index = 0; Index < Positions.Num(); ++Index)
    {
        ABlacksiteEnemyCharacter* Enemy = GetWorld()->SpawnActor<ABlacksiteEnemyCharacter>(
            Positions[Index], FRotator(0.0f, FMath::FRandRange(-180.0f, 180.0f), 0.0f));

        if (Enemy)
        {
            Enemy->SetArchetype(Index % 3);
            Enemies.Add(Enemy);
            ++EnemiesRemaining;
        }
    }
}

void ABlacksiteGameMode::SecureObjective()
{
    if (bRaidComplete || bObjectiveSecured)
    {
        return;
    }

    bObjectiveSecured = true;
    BlacksitePrototype::PlayProceduralSound(this, ExtractionZone ? ExtractionZone->GetActorLocation() : FVector::ZeroVector,
        760.0f, 0.16f, 0.18f, false);
}

void ABlacksiteGameMode::CompleteExtraction()
{
    if (bRaidComplete || !bObjectiveSecured)
    {
        return;
    }

    bRaidComplete = true;
    bExtracted = true;

    if (ABlacksitePlayerCharacter* Player = Cast<ABlacksitePlayerCharacter>(UGameplayStatics::GetPlayerPawn(this, 0)))
    {
        Player->GetCharacterMovement()->DisableMovement();
        if (APlayerController* PC = Cast<APlayerController>(Player->GetController()))
        {
            Player->DisableInput(PC);
        }
    }

    BlacksitePrototype::PlayProceduralSound(this,
        ExtractionZone ? ExtractionZone->GetActorLocation() : FVector::ZeroVector,
        520.0f, 0.34f, 0.28f, false);
}

void ABlacksiteGameMode::FailRaid()
{
    if (bRaidComplete)
    {
        return;
    }

    bRaidComplete = true;
    bExtracted = false;
}

void ABlacksiteGameMode::OnEnemyKilled()
{
    ++Kills;
    EnemiesRemaining = FMath::Max(0, EnemiesRemaining - 1);
}

void ABlacksiteGameMode::BroadcastGunshot(const FVector& Location)
{
    constexpr float AlertRadius = 3200.0f;

    for (TWeakObjectPtr<ABlacksiteEnemyCharacter>& EnemyPtr : Enemies)
    {
        if (ABlacksiteEnemyCharacter* Enemy = EnemyPtr.Get())
        {
            if (FVector::DistSquared(Enemy->GetActorLocation(), Location) <= FMath::Square(AlertRadius))
            {
                Enemy->Alert(Location);
            }
        }
    }
}

FString ABlacksiteGameMode::GetObjectiveText() const
{
    if (bRaidComplete)
    {
        return bExtracted ? TEXT("BLACK TIDE // EXTRACTED") : TEXT("BLACK TIDE // FAILED");
    }

    if (!bObjectiveSecured)
    {
        return TEXT("BLACK TIDE // SECURE ARCHIVE DRIVE");
    }

    return TEXT("SERVICE ROAD // HOLD F IN EXTRACTION");
}
