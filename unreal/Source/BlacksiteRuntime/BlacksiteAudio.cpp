#include "BlacksiteAudio.h"

#include "Kismet/GameplayStatics.h"
#include "Sound/SoundWaveProcedural.h"

void BlacksiteAudio::PlayTransient(
    UObject* WorldContext,
    const FVector& Location,
    float FundamentalHz,
    float DurationSeconds,
    float Volume,
    float NoiseMix)
{
    if (!WorldContext || DurationSeconds <= 0.0f)
    {
        return;
    }

    constexpr uint32 SampleRate = 44100;
    const int32 SampleCount = FMath::Max(1, FMath::RoundToInt(DurationSeconds * static_cast<float>(SampleRate)));
    TArray<int16> PCM;
    PCM.SetNumUninitialized(SampleCount);

    float Phase = 0.0f;
    const float PhaseStep = 2.0f * PI * FundamentalHz / static_cast<float>(SampleRate);
    const float SafeNoiseMix = FMath::Clamp(NoiseMix, 0.0f, 1.0f);

    for (int32 Index = 0; Index < SampleCount; ++Index)
    {
        const float T = static_cast<float>(Index) / static_cast<float>(SampleCount);
        const float Envelope = FMath::Square(1.0f - T);
        const float Tone = FMath::Sin(Phase);
        const float Noise = FMath::FRandRange(-1.0f, 1.0f);
        const float Mixed = FMath::Lerp(Tone, Noise, SafeNoiseMix);
        const float Sample = FMath::Clamp(Mixed * Envelope * Volume, -1.0f, 1.0f);
        PCM[Index] = static_cast<int16>(Sample * 32767.0f);
        Phase += PhaseStep;
    }

    USoundWaveProcedural* Sound = NewObject<USoundWaveProcedural>(WorldContext);
    Sound->SetSampleRate(SampleRate, false);
    Sound->NumChannels = 1;
    Sound->bLooping = false;
    Sound->QueueAudio(reinterpret_cast<const uint8*>(PCM.GetData()), PCM.Num() * sizeof(int16));

    UGameplayStatics::PlaySoundAtLocation(WorldContext, Sound, Location, 1.0f);
}
