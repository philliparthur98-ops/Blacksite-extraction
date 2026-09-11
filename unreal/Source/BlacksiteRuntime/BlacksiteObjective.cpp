#include "BlacksiteObjective.h"

#include "BlacksiteAudio.h"
#include "BlacksiteGameMode.h"
#include "BlacksitePlayerCharacter.h"
#include "Components/PointLightComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"

ABlacksiteObjective::ABlacksiteObjective()
{
    PrimaryActorTick.bCanEverTick = false;

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);

    DriveCase = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("ArchiveDrive"));
    DriveCase->SetupAttachment(Root);
    DriveCase->SetStaticMesh(LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube")));
    DriveCase->SetRelativeScale3D(FVector(0.38f, 0.26f, 0.09f));
    DriveCase->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    DriveCase->SetCollisionResponseToAllChannels(ECR_Ignore);
    DriveCase->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);

    MarkerLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("MarkerLight"));
    MarkerLight->SetupAttachment(Root);
    MarkerLight->SetRelativeLocation(FVector(0.0f, 0.0f, 35.0f));
    MarkerLight->SetLightColor(FLinearColor(0.08f, 0.72f, 1.0f), false);
    MarkerLight->SetIntensity(1300.0f);
    MarkerLight->SetAttenuationRadius(420.0f);
}

void ABlacksiteObjective::Interact(ABlacksitePlayerCharacter* Player)
{
    if (bSecured || !Player)
    {
        return;
    }

    bSecured = true;
    BlacksiteAudio::PlayTransient(this, GetActorLocation(), 920.0f, 0.10f, 0.18f, 0.08f);

    if (ABlacksiteGameMode* GM = GetWorld()->GetAuthGameMode<ABlacksiteGameMode>())
    {
        GM->SecureObjective();
    }

    SetActorHiddenInGame(true);
    SetActorEnableCollision(false);
}
