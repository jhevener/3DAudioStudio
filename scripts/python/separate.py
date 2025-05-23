# separate.py @ScriptDir & "\s2S\installs\UVR\uvr-main\separate.py"
import os
import argparse
import numpy as np
import logging
from uvr5_pack.utils import load_audio, save_audio, get_model_hash, _get_name_params
from uvr5_pack.spec_utils import SpectrogramProcessor
from uvr5_pack.model_loader import load_model

# Logging setup
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class AudioSeparator:
    def __init__(self, model_path, input_file, output_dir, segment_size, overlap, denoise, batch_size, aggressiveness, tta, high_end_process):
        self.model_path = model_path
        self.input_file = input_file
        self.output_dir = output_dir
        self.segment_size = segment_size
        self.overlap = overlap
        self.denoise = denoise
        self.batch_size = batch_size
        self.aggressiveness = aggressiveness
        self.tta = tta
        self.high_end_process = high_end_process
        self.sr = 44100  # Default sample rate

    def _audio_pre_(self, model_path, model_hash):
        logging.info(f"Initializing audio preprocessing for model: {model_path}, hash: {model_hash}")
        param_name, model_params_d = _get_name_params(model_path, model_hash)
        logging.info(f"Model parameters: param_name={param_name}, params={model_params_d}")
        self.audio, self.sr = load_audio(self.input_file, sr=self.sr)
        self.spec_processor = SpectrogramProcessor(model_params_d)
        return self.audio, self.spec_processor

    def separate(self):
        logging.info(f"Starting separation process for {self.input_file}")
        os.makedirs(self.output_dir, exist_ok=True)
        model_hash = get_model_hash(self.model_path)
        audio, spec_processor = self._audio_pre_(self.model_path, model_hash)
        model = load_model(self.model_path, spec_processor)

        # Process audio in segments
        total_length = audio.shape[-1]
        segment_samples = int(self.segment_size * self.sr)
        overlap_samples = int(segment_samples * self.overlap)
        step = segment_samples - overlap_samples
        separated_stems = {}

        for start in range(0, total_length, step):
            end = min(start + segment_samples, total_length)
            segment = audio[:, start:end]
            if segment.shape[-1] < segment_samples:
                pad_length = segment_samples - segment.shape[-1]
                segment = np.pad(segment, ((0, 0), (0, pad_length)), mode='constant')

            # Apply model to segment
            stem_outputs = model.process(segment, batch_size=self.batch_size, denoise=self.denoise,
                                        aggressiveness=self.aggressiveness, tta=self.tta,
                                        high_end_process=self.high_end_process)
            
            for stem_name, stem_audio in stem_outputs.items():
                if stem_name not in separated_stems:
                    separated_stems[stem_name] = np.zeros((audio.shape[0], total_length), dtype=np.float32)
                # Overlap-add
                separated_stems[stem_name][:, start:end] += stem_audio[:, :end-start]

            # Progress update
            progress = (start + step) / total_length * 100
            print(f"Progress: {int(progress)}%", flush=True)

        # Save separated stems
        base_name = os.path.splitext(os.path.basename(self.input_file))[0]
        for stem_name, stem_audio in separated_stems.items():
            output_path = os.path.join(self.output_dir, f"{base_name}_{stem_name}.wav")
            save_audio(output_path, stem_audio, self.sr)

        logging.info("Separation completed successfully")

def parse_args():
    parser = argparse.ArgumentParser(description="Separate audio into stems using UVR5 models.")
    parser.add_argument("--model", type=str, required=True, help="Path to the model file (.onnx)")
    parser.add_argument("--input_file", type=str, required=True, help="Path to the input audio file")
    parser.add_argument("--output_dir", type=str, required=True, help="Output directory for separated stems")
    parser.add_argument("--segment_size", type=int, default=256, help="Segment size in seconds")
    parser.add_argument("--overlap", type=float, default=0.25, help="Overlap ratio between segments (0 to 1)")
    parser.add_argument("--denoise", type=lambda x: (str(x).lower() == 'true'), default=False, help="Enable denoising (true/false)")
    parser.add_argument("--batch_size", type=int, default=1, help="Batch size for processing")
    parser.add_argument("--aggressiveness", type=float, default=10, help="Aggressiveness of separation (0 to 100)")
    parser.add_argument("--tta", type=lambda x: (str(x).lower() == 'true'), default=False, help="Enable Test-Time Augmentation (true/false)")
    parser.add_argument("--high_end_process", type=str, default="mirroring", choices=["none", "mirroring", "mirroring2"], help="High-end processing method")
    return parser.parse_args()

def main():
    args = parse_args()
    separator = AudioSeparator(
        model_path=args.model,
        input_file=args.input_file,
        output_dir=args.output_dir,
        segment_size=args.segment_size,
        overlap=args.overlap,
        denoise=args.denoise,
        batch_size=args.batch_size,
        aggressiveness=args.aggressiveness,
        tta=args.tta,
        high_end_process=args.high_end_process
    )
    separator.separate()

if __name__ == "__main__":
    main()