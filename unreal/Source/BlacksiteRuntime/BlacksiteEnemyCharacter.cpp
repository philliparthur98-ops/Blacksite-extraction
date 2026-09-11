#include "BlacksiteEnemyCharacter.h"

#include "AIController.h"
#include "BlacksiteAudio.h"
#include "BlacksiteGameMode.h"
#include "BlacksitePlayerCharacter.h"
#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"

namespace
{
    UStaticMesh* CubeMesh()
    {
        static UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube"));
        return Mesh;
    }

    UStaticMesh* SphereMesh()
    {
        static UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Sphere.Sphere"));
        return Mesh;
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

    Torso = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Torso"));
    Torso->SetupAttachment(GetCapsuleComponent());
    Torso->SetStaticMesh(CubeMesh());
    Torso->SetRelativeLocation(FVector(0.0f, 0.0f, 12.0f));
    Torso->SetRelativeScale3D(FVector(0.42f, 0.28f, 0.72f));
    Torso->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    Torso->SetCollisionResponseToAllChannels(ECR_Ignore);
    Torso->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);

    Head = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Head"));
    Head->SetupAttachment(GetCapsuleComponent());
    Head->SetStaticMesh(SphereMesh());
    Head->SetRelativeLocation(FVector(0.0f, 0.0f, 76.0f));
    Head->SetRelativeScale3D(FVector(0.20f));
    Head->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    Head->SetCollisionResponseToAllChannels(ECR_Ignore);
    Head->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);

    Weapon = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Weapon"));
    Weapon->SetupAttachment(GetCapsuleComponent());
    Weapon->SetStaticMesh(CubeMesh());
    Weapon->SetRelativeLocation(FVector(28.0f, 16.0f, 42.0f));
    Weapon->SetRelativeScale3D(FVector(0.48f, 0.055f, 0.055f));
    Weapon->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    MuzzleFlash = CreateDefaultSubobject<UPointLightComponent>(TEXT("MuzzleFlash"));
    MuzzleFlash->SetupAttachment(Weapon);
    MuzzleFlash->SetRelativeLocation(FVector(55.0f, 0.0f, 0.0f));
    MuzzleFlash->SetLightColor(FLinearColor(1.0f, 0.24f, 0.04f), false);
    MuzzleFlash->SetAttenuationRadius(420.0f);
    MuzzleFlash->SetIntensity(0.0f);
}

void ABlacksiteEnemyCharacter::BeginPlay()
{
    Super::BeginPlay();
    HomeLocation = GetActorLocation();
    TacticalDestination = HomeLocation + FVector(
        FMath::FRandRange(-900.0f, 900.0f),
        FMath::FRandRange(-900.0f, 900.0f),
        0.0f);
}

void ABlacksiteEnemyCharacter::SetArchetype(int32 InArchetype)
{
    Archetype = FMath::Clamp(InArchetype, 0, 2);

    switch (Archetype)
    {
    case 0: // raider: quicker lateral pressure
        Health = 80.0f;
        GetCharacterMovement()->MaxWalkSpeed = 360.0f;
        Torso->SetRelativeScale3D(FVector(0.38f, 0.25f, 0.67f));
        break;
    case 1: // guard: deliberate hold / medium range
        Health = 110.0f;
        GetCharacterMovement()->MaxWalkSpeed = 300.0f;
        break;
    default: // heavy: slower, tougher, closes to pressure range
        Health = 165.0f;
        GetCharacterMovement()->MaxWalkSpeed = 240.0f;
        Torso->SetRelativeScale3D(FVector(0.48f, 0.34f, 0.78f));
        Head->SetRelativeScale3D(FVector(0.23f));
        break;
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
    StateTimer += DeltaSeconds;
    MuzzleEnergy = FMath::FInterpTo(MuzzleEnergy, 0.0f, DeltaSeconds, 32.0f);
    MuzzleFlash->SetIntensity(MuzzleEnergy);

    FVector PlayerLocation = FVector::ZeroVector;
    const bool bHasLOS = CanSeePlayer(PlayerLocation);

    if (bHasLOS)
    {
        LastSeenLocation = PlayerLocation;
        State = EBlacksiteAIState::Combat;
        StateTimer = 0.0f;
    }
    else if (State == EBlacksiteAIState::Combat)
    {
        State = EBlacksiteAIState::Investigate;
        StateTimer = 0.0f;
        TacticalDestination = LastSeenLocation;
    }
    else if (State == EBlacksiteAIState::Investigate)
    {
        if (StateTimer > 6.0f)
        {
            State = EBlacksiteAIState::Patrol;
            StateTimer = 0.0f;
            TacticalDestination = HomeLocation + FVector(
                FMath::FRandRange(-1100.0f, 1100.0f),
                FMath::FRandRange(-1100.0f, 1100.0f),
                0.0f);
        }
        else if (FVector::DistSquared2D(GetActorLocation(), TacticalDestination) < FMath::Square(160.0f))
        {
            TacticalDestination = LastSeenLocation + FVector(
                FMath::FRandRange(-520.0f, 520.0f),
                FMath::FRandRange(-520.0f, 520.0f),
                0.0f);
        }
    }

    UpdateTactics(PlayerLocation, bHasLOS);

    if (bHasLOS && FireCooldown <= 0.0f)
    {
        FireAtPlayer(PlayerLocation);
    }
}

bool ABlacksiteEnemyCharacter::CanSeePlayer(FVector& OutLocation) const
{
    const ABlacksitePlayerCharacter* Player = Cast<ABlacksitePlayerCharacter>(UGameplayStatics::GetPlayerPawn(this, 0));
    if (!Player || Player->IsDead())
    {
        return false;
    }

    OutLocation = Player->GetActorLocation();
    const float MaxRange = Archetype == 2 ? 3600.0f : 3000.0f;
    if (FVector::DistSquared(GetActorLocation(), OutLocation) > FMath::Square(MaxRange))
    {
        return false;
    }

    const FVector Start = GetActorLocation() + FVector(0.0f, 0.0f, 65.0f);
    const FVector End = Player->GetActorLocation() + FVector(0.0f, 0.0f, 58.0f);
    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlacksiteEnemyLOS), true, this);

    return GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params) && Hit.GetActor() == Player;
}

void ABlacksiteEnemyCharacter::UpdateTactics(const FVector& PlayerLocation, bool bHasLOS)
{
    FVector Destination = TacticalDestination;

    if (State == EBlacksiteAIState::Combat && bHasLOS)
    {
        const FVector ToPlayer = PlayerLocation - GetActorLocation();
        const float Distance = ToPlayer.Size2D();
        const FVector Side = FVector(ToPlayer.Y, -ToPlayer.X, 0.0f).GetSafeNormal();

        if (Archetype == 0)
        {
            Destination = PlayerLocation + Side * ((GetUniqueID() & 1) ? 620.0f : -620.0f);
        }
        else if (Archetype == 1)
        {
            Destination = Distance > 1500.0f ? PlayerLocation : GetActorLocation();
        }
        else
        {
            Destination = Distance > 1100.0f ? PlayerLocation : GetActorLocation() - ToPlayer.GetSafeNormal() * 180.0f;
        }
    }
    else if (State == EBlacksiteAIState::Investigate)
    {
        Destination = TacticalDestination;
    }
    else if (State == EBlacksiteAIState::Patrol)
    {
        Destination = TacticalDestination;
        if (FVector::DistSquared2D(GetActorLocation(), Destination) < FMath::Square(180.0f))
        {
            TacticalDestination = HomeLocation + FVector(
                FMath::FRandRange(-1100.0f, 1100.0f),
                FMath::FRandRange(-1100.0f, 1100.0f),
                0.0f);
            Destination = TacticalDestination;
        }
    }

    MoveToward(Destination);
}

void ABlacksiteEnemyCharacter::MoveToward(const FVector& Destination)
{
    bool bPathAccepted = false;
    if (AAIController* AI = Cast<AAIController>(GetController()))
    {
        const EPathFollowingRequestResult::Type Result = AI->MoveToLocation(
            Destination,
            90.0f,
            true,
            true,
            true,
            true,
            nullptr,
            true);
        bPathAccepted = Result != EPathFollowingRequestResult::Failed;
    }

    if (!bPathAccepted)
    {
        const FVector Direction = (Destination - GetActorLocation()).GetSafeNormal2D();
        AddMovementInput(Direction, 1.0f);
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
    FVector Direction = (PlayerLocation + FVector(0.0f, 0.0f, 55.0f) - Start).GetSafeNormal();
    const float SpreadDegrees = Archetype == 2 ? 1.2f : (Archetype == 1 ? 1.7f : 2.5f);
    Direction = FMath::VRandCone(Direction, FMath::DegreesToRadians(SpreadDegrees));

    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlacksiteEnemyFire), true, this);

    MuzzleEnergy = Archetype == 2 ? 8500.0f : 6800.0f;
    BlacksiteAudio::PlayTransient(this, Start, Archetype == 2 ? 82.0f : 105.0f, 0.15f, 0.70f, 0.84f);

    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, Start + Direction * 10000.0f, ECC_Visibility, Params)
        && Hit.GetActor() == Player)
    {
        const float Damage = Archetype == 2
            ? FMath::FRandRange(20.0f, 29.0f)
            : FMath::FRandRange(12.0f, 21.0f);
        UGameplayStatics::ApplyPointDamage(Player, Damage, Direction, Hit, GetController(), this, nullptr);
    }

    FireCooldown = Archetype == 0
        ? FMath::FRandRange(0.25f, 0.48f)
        : (Archetype == 1 ? FMath::FRandRange(0.38f, 0.68f) : FMath::FRandRange(0.55f, 0.88f));

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->BroadcastGunshot(Start);
    }
}

void ABlacksiteEnemyCharacter::Alert(const FVector& SourceLocation)
{
    if (bDead || State == EBlacksiteAIState::Combat)
    {
        return;
    }

    LastSeenLocation = SourceLocation;
    TacticalDestination = SourceLocation;
    State = EBlacksiteAIState::Investigate;
    StateTimer = 0.0f;
}

bool ABlacksiteEnemyCharacter::IsHeadComponent(const UPrimitiveComponent* Component) const
{
    return Component == Head;
}

float ABlacksiteEnemyCharacter::TakeDamage(
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
    State = EBlacksiteAIState::Dead;
    GetCharacterMovement()->DisableMovement();
    SetActorEnableCollision(false);

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->OnEnemyKilled();
    }

    Torso->SetRelativeRotation(FRotator(0.0f, 0.0f, 78.0f));
    Head->SetRelativeLocation(FVector(0.0f, 0.0f, 24.0f));
    SetLifeSpan(20.0f);
}
