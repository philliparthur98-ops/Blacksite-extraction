#include "BlacksiteGameMode.h"

#include "BlacksiteAudio.h"
#include "BlacksiteEnemyCharacter.h"
#include "BlacksiteExtractionZone.h"
#include "BlacksiteHUD.h"
#include "BlacksiteObjective.h"
#include "BlacksitePlayerCharacter.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/PointLight.h"
#include "Engine/PostProcessVolume.h"
#include "Engine/SkyAtmosphere.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMeshActor.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
#include "NavigationSystem.h"
#include "NavMesh/NavMeshBoundsVolume.h"

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

    const FLinearColor Asphalt(0.055f, 0.065f, 0.07f);
    const FLinearColor Concrete(0.15f, 0.16f, 0.16f);
    const FLinearColor Steel(0.09f, 0.11f, 0.12f);
    const FLinearColor ContainerBlue(0.05f, 0.12f, 0.16f);
    const FLinearColor ContainerRust(0.22f, 0.085f, 0.045f);
    const FLinearColor SafetyYellow(0.58f, 0.35f, 0.035f);
}

ABlacksiteGameMode::ABlacksiteGameMode()
{
    DefaultPawnClass = ABlacksitePlayerCharacter::StaticClass();
    HUDClass = ABlacksiteHUD::StaticClass();
    BasicMaterial = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
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

void ABlacksiteGameMode::ApplyColor(UStaticMeshComponent* Mesh, const FLinearColor& Color)
{
    if (!Mesh || !BasicMaterial)
    {
        return;
    }

    UMaterialInstanceDynamic* MID = UMaterialInstanceDynamic::Create(BasicMaterial, Mesh);
    if (MID)
    {
        MID->SetVectorParameterValue(TEXT("Color"), Color);
        Mesh->SetMaterial(0, MID);
    }
}

AActor* ABlacksiteGameMode::SpawnBox(
    const FVector& Location,
    const FVector& Scale,
    const FRotator& Rotation,
    const FLinearColor& Color)
{
    AStaticMeshActor* Actor = GetWorld()->SpawnActor<AStaticMeshActor>(Location, Rotation);
    if (!Actor)
    {
        return nullptr;
    }

    UStaticMeshComponent* Mesh = Actor->GetStaticMeshComponent();
    Mesh->SetMobility(EComponentMobility::Movable);
    Mesh->SetStaticMesh(CubeMesh());
    Mesh->SetWorldScale3D(Scale);
    Mesh->SetCollisionProfileName(TEXT("BlockAll"));
    ApplyColor(Mesh, Color);
    return Actor;
}

AActor* ABlacksiteGameMode::SpawnCylinder(
    const FVector& Location,
    const FVector& Scale,
    const FRotator& Rotation,
    const FLinearColor& Color)
{
    AStaticMeshActor* Actor = GetWorld()->SpawnActor<AStaticMeshActor>(Location, Rotation);
    if (!Actor)
    {
        return nullptr;
    }

    UStaticMeshComponent* Mesh = Actor->GetStaticMeshComponent();
    Mesh->SetMobility(EComponentMobility::Movable);
    Mesh->SetStaticMesh(CylinderMesh());
    Mesh->SetWorldScale3D(Scale);
    Mesh->SetCollisionProfileName(TEXT("BlockAll"));
    ApplyColor(Mesh, Color);
    return Actor;
}

void ABlacksiteGameMode::BuildLighting()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }

    ADirectionalLight* Sun = World->SpawnActor<ADirectionalLight>(
        FVector::ZeroVector,
        FRotator(-32.0f, -28.0f, 0.0f));
    if (Sun)
    {
        Sun->GetLightComponent()->SetIntensity(5.0f);
        Sun->GetLightComponent()->SetLightColor(FLinearColor(1.0f, 0.71f, 0.46f), false);
        Sun->GetLightComponent()->SetCastShadows(true);
    }

    World->SpawnActor<ASkyAtmosphere>();

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
            Light->GetLightComponent()->SetLightColor(FLinearColor(0.15f, 0.56f, 0.72f), false);
        }
    }
}

void ABlacksiteGameMode::BuildHarbor()
{
    // 200m x 200m ground plane and perimeter. The vertical slice uses five compact combat districts.
    SpawnBox(FVector(0.0f, 0.0f, -60.0f), FVector(200.0f, 200.0f, 1.2f), FRotator::ZeroRotator, Asphalt);
    SpawnBox(FVector(0.0f, -9600.0f, 500.0f), FVector(200.0f, 2.0f, 10.0f), FRotator::ZeroRotator, Steel);
    SpawnBox(FVector(0.0f, 9600.0f, 500.0f), FVector(200.0f, 2.0f, 10.0f), FRotator::ZeroRotator, Steel);
    SpawnBox(FVector(-9600.0f, 0.0f, 500.0f), FVector(2.0f, 200.0f, 10.0f), FRotator::ZeroRotator, Steel);
    SpawnBox(FVector(9600.0f, 0.0f, 500.0f), FVector(2.0f, 200.0f, 10.0f), FRotator::ZeroRotator, Steel);

    // District 1: west container yard — alternating orientation breaks long sightlines.
    const TArray<FVector> Containers = {
        FVector(-5200.0f, 3400.0f, 135.0f), FVector(-5200.0f, 2500.0f, 135.0f),
        FVector(-3600.0f, 3400.0f, 135.0f), FVector(-3600.0f, 2500.0f, 135.0f),
        FVector(-2000.0f, 3400.0f, 135.0f), FVector(-2000.0f, 2500.0f, 135.0f)
    };
    for (int32 Index = 0; Index < Containers.Num(); ++Index)
    {
        const FVector Scale = (Index % 2 == 0) ? FVector(12.0f, 2.5f, 2.7f) : FVector(2.5f, 12.0f, 2.7f);
        SpawnBox(
            Containers[Index],
            Scale,
            FRotator::ZeroRotator,
            (Index % 3 == 0) ? ContainerRust : ContainerBlue);
    }

    // District 2: archive warehouse — objective sits inside a readable, breached shell.
    SpawnBox(FVector(700.0f, -2500.0f, 360.0f), FVector(30.0f, 1.2f, 7.2f), FRotator::ZeroRotator, Concrete);
    SpawnBox(FVector(700.0f, -5200.0f, 360.0f), FVector(30.0f, 1.2f, 7.2f), FRotator::ZeroRotator, Concrete);
    SpawnBox(FVector(-2200.0f, -3850.0f, 360.0f), FVector(1.2f, 28.0f, 7.2f), FRotator::ZeroRotator, Concrete);
    SpawnBox(FVector(3600.0f, -4550.0f, 360.0f), FVector(1.2f, 14.0f, 7.2f), FRotator::ZeroRotator, Concrete);
    SpawnBox(FVector(3600.0f, -3000.0f, 360.0f), FVector(1.2f, 7.0f, 7.2f), FRotator::ZeroRotator, Concrete);
    for (int32 Row = 0; Row < 4; ++Row)
    {
        SpawnBox(FVector(-900.0f + Row * 1150.0f, -4200.0f, 120.0f), FVector(3.8f, 0.55f, 2.4f), FRotator::ZeroRotator, Steel);
        SpawnBox(FVector(-900.0f + Row * 1150.0f, -3350.0f, 120.0f), FVector(3.8f, 0.55f, 2.4f), FRotator::ZeroRotator, Steel);
    }

    // District 3: pump lane — vertical tank silhouettes with low machinery cover.
    for (int32 Pipe = 0; Pipe < 6; ++Pipe)
    {
        SpawnCylinder(
            FVector(2200.0f + Pipe * 580.0f, 2600.0f, 160.0f),
            FVector(1.1f, 1.1f, 3.2f),
            FRotator::ZeroRotator,
            Steel);
        SpawnBox(
            FVector(2200.0f + Pipe * 580.0f, 1650.0f, 85.0f),
            FVector(2.6f, 1.0f, 1.7f),
            FRotator::ZeroRotator,
            SafetyYellow);
    }

    // District 4: central hard-cover spine.
    const TArray<FVector> Barricades = {
        FVector(-900.0f, 400.0f, 85.0f), FVector(950.0f, 350.0f, 85.0f),
        FVector(2600.0f, -300.0f, 85.0f), FVector(4300.0f, -1600.0f, 85.0f),
        FVector(5600.0f, -3100.0f, 85.0f), FVector(4600.0f, -5100.0f, 85.0f),
        FVector(-3500.0f, -800.0f, 85.0f), FVector(-5200.0f, -1800.0f, 85.0f)
    };
    for (int32 Index = 0; Index < Barricades.Num(); ++Index)
    {
        SpawnBox(
            Barricades[Index],
            FVector(3.6f, 0.7f, 1.7f),
            FRotator(0.0f, Index * 17.0f, 0.0f),
            Concrete);
    }

    // District 5: east service road / extraction checkpoint approach.
    SpawnBox(FVector(7600.0f, -4300.0f, 180.0f), FVector(10.0f, 3.0f, 0.3f), FRotator::ZeroRotator, Steel);
    SpawnBox(FVector(7000.0f, -4300.0f, 200.0f), FVector(0.5f, 3.0f, 4.0f), FRotator::ZeroRotator, Steel);
    SpawnBox(FVector(8200.0f, -4300.0f, 200.0f), FVector(0.5f, 3.0f, 4.0f), FRotator::ZeroRotator, Steel);

    // Spawn protection and opening read: immediate cover instead of an exposed starting lane.
    SpawnBox(FVector(-6800.0f, 6400.0f, 100.0f), FVector(5.0f, 0.8f, 2.0f), FRotator(0.0f, 12.0f, 0.0f), Concrete);
    SpawnBox(FVector(-5700.0f, 5550.0f, 100.0f), FVector(0.8f, 5.0f, 2.0f), FRotator(0.0f, -8.0f, 0.0f), Concrete);
}

void ABlacksiteGameMode::CreateNavigationBounds()
{
    ANavMeshBoundsVolume* NavBounds = GetWorld()->SpawnActor<ANavMeshBoundsVolume>(
        FVector(0.0f, 0.0f, 300.0f),
        FRotator::ZeroRotator);

    if (!NavBounds)
    {
        return;
    }

    NavBounds->SetActorScale3D(FVector(110.0f, 110.0f, 8.0f));
    if (UNavigationSystemV1* NavSystem = FNavigationSystem::GetCurrent<UNavigationSystemV1>(GetWorld()))
    {
        NavSystem->OnNavigationBoundsUpdated(NavBounds);
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
        FVector(1200.0f, -3850.0f, 95.0f),
        FRotator(0.0f, 25.0f, 0.0f));

    ExtractionZone = GetWorld()->SpawnActor<ABlacksiteExtractionZone>(
        FVector(7600.0f, -4300.0f, 0.0f),
        FRotator::ZeroRotator);
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
            Positions[Index],
            FRotator(0.0f, FMath::FRandRange(-180.0f, 180.0f), 0.0f));
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
    BlacksiteAudio::PlayTransient(
        this,
        ExtractionZone ? ExtractionZone->GetActorLocation() : FVector::ZeroVector,
        760.0f,
        0.16f,
        0.18f,
        0.08f);
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

    BlacksiteAudio::PlayTransient(
        this,
        ExtractionZone ? ExtractionZone->GetActorLocation() : FVector::ZeroVector,
        520.0f,
        0.34f,
        0.28f,
        0.10f);
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

    return bObjectiveSecured
        ? TEXT("SERVICE ROAD // HOLD F IN EXTRACTION")
        : TEXT("BLACK TIDE // SECURE ARCHIVE DRIVE");
}
