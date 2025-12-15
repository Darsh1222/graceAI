import os
import ffmpeg
import soundfile as sf
import numpy as np
from basic_pitch.inference import predict
from basic_pitch import ICASSP_2022_MODEL_PATH
import pretty_midi

def m4a_to_wav(input_path, wav_path, sample_rate=44100):
    os.makedirs(os.path.dirname(wav_path), exist_ok=True)
    (
        ffmpeg.input(input_path)
        .output(wav_path, ar=sample_rate, ac=1, format='wav')
        .overwrite_output()
        .run(quiet=True)
    )
    data, sr = sf.read(wav_path)
    if sr != sample_rate:
        raise ValueError(f"Sample rate is {sr}, expected {sample_rate}")
    if len(data.shape) > 1 and data.shape[1] != 1:
        raise ValueError("Audio is not mono after conversion.")
    return wav_path

def transcribe_audio(input_m4a_path, output_dir):
    if not os.path.exists(input_m4a_path):
        raise FileNotFoundError(f"Input file {input_m4a_path} does not exist.")
    os.makedirs(output_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(input_m4a_path))[0]
    wav_path = os.path.join(output_dir, base + "_converted.wav")
    midi_path = os.path.join(output_dir, base + "_userRecording.mid")
    m4a_to_wav(input_m4a_path, wav_path)

    model_output, midi_data, note_events = predict(
    wav_path,
    onset_threshold=0.5,
    frame_threshold=0.5,
)

    midi_data.write(midi_path)
    return midi_path 