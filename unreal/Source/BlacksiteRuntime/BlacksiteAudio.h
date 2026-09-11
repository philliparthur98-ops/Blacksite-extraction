#pragma once

#include "CoreMinimal.h"

namespace BlacksiteAudio
{
    BLACKSITERUNTIME_API void PlayTransient(
        UObject* WorldContext,
        const FVector& Location,
        float FundamentalHz,
        float DurationSeconds,
        float Volume,
        float NoiseMix = 0.5f);
}
