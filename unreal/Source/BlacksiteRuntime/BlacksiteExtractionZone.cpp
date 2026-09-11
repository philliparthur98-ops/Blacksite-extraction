#include "BlacksiteExtractionZone.h"

#include "BlacksiteGameMode.h"
#include "BlacksitePlayerCharacter.h"
#include "Components/BoxComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"

namespace
{
    UStaticMesh* CubeMesh()
    {
        static UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube"));
        return Mesh;
    }
}

ABlacksiteExtractionZone::ABlacksiteExtractionZone()
{
    PrimaryActorTick.bCanEverTick = true;

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);

    ExtractionVolume = CreateDefaultSubobject<UBoxComponent>(TEXT("ExtractionVolume"));
    ExtractionVolume->SetupAttachment(Root);
    ExtractionVolume->SetBoxExtent(FVector(290.0f, 290.0f, 150.0f));
    ExtractionVolume->SetRelativeLocation(FVector(0.0f, 0.0f, 100.0f));
    ExtractionVolume->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    ExtractionVolume->SetCollisionResponseToAllChannels(ECR_Ignore);
    ExtractionVolume->SetCollisionResponseToChannel(ECC_Pawn, ECR_Overlap);

    Floor = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CheckpointFloor"));
    Floor->SetupAttachment(Root);
    Floor->SetStaticMesh(CubeMesh());
    Floor->SetRelativeLocation(FVector(0.0f, 0.0f, 10.0f));
    Floor->SetRelativeScale3D(FVector(5.5f, 5.5f, 0.18f));
    Floor->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    LeftPost = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("LeftPost"));
    LeftPost->SetupAttachment(Root);
    LeftPost->SetStaticMesh(CubeMesh());
    LeftPost->SetRelativeLocation(FVector(0.0f, -250.0f, 180.0f));
    LeftPost->SetRelativeScale3D(FVector(0.35f, 0.35f, 3.6f));
    LeftPost->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    RightPost = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("RightPost"));
    RightPost->SetupAttachment(Root);
    RightPost->SetStaticMesh(CubeMesh());
    RightPost->SetRelativeLocation(FVector(0.0f, 250.0f, 180.0f));
    RightPost->SetRelativeScale3D(FVector(0.35f, 0.35f, 3.6f));
    RightPost->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    HeaderBeam = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("HeaderBeam"));
    HeaderBeam->SetupAttachment(Root);
    HeaderBeam->SetStaticMesh(CubeMesh());
    HeaderBeam->SetRelativeLocation(FVector(0.0f, 0.0f, 360.0f));
    HeaderBeam->SetRelativeScale3D(FVector(0.35f, 5.35f, 0.28f));
    HeaderBeam->SetCollisionEnabled(ECollisionEnabled::NoCollision);

    StatusLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("StatusLight"));
    StatusLight->SetupAttachment(Root);
    StatusLight->SetRelativeLocation(FVector(0.0f, 0.0f, 300.0f));
    StatusLight->SetAttenuationRadius(1200.0f);
    StatusLight->SetIntensity(4200.0f);
    StatusLight->SetLightColor(FLinearColor(0.95f, 0.08f, 0.03f), false);
}

void ABlacksiteExtractionZone::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    const ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>();
    if (!GM)
    {
        return;
    }

    const FLinearColor Target = GM->IsObjectiveSecured()
        ? FLinearColor(0.05f, 0.95f, 0.22f)
        : FLinearColor(0.95f, 0.08f, 0.03f);

    const FLinearColor Current = StatusLight->GetLightColor();
    StatusLight->SetLightColor(
        FLinearColor::LerpUsingHSV(Current, Target, FMath::Clamp(DeltaSeconds * 4.0f, 0.0f, 1.0f)),
        false);

    const float Pulse = GM->IsObjectiveSecured() ? 1.0f + 0.12f * FMath::Sin(GetWorld()->GetTimeSeconds() * 5.0f) : 1.0f;
    StatusLight->SetIntensity(4200.0f * Pulse);
}

bool ABlacksiteExtractionZone::IsPlayerInside(const ABlacksitePlayerCharacter* Player) const
{
    return Player && ExtractionVolume->IsOverlappingActor(Player);
}
