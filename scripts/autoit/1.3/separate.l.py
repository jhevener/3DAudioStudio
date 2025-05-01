import argparse
import os
import numpy as np
import soundfile as sf
import torch
from pathlib import Path
from tqdm import tqdm
import onnxruntime as ort
from pydub import AudioSegment

class MDX:
    def __init__(self, model_path, params, device="cpu"):
        self.params = params
        self.num_stems = params.get("num_stems", 2)
        self.device = device
        providers = ["CUDAExecutionProvider" if "cuda" in device else "CPUExecutionProvider"]
        self.model = ort.InferenceSession(model_path, providers=providers)
        self.input_name = self.model.get_inputs()[0].name
        self.output_names = [output.name for output in self.model.get_outputs()]

    def run(self, mag):
        mag = mag.cpu().numpy()
        ort_inputs = {self.input_name: mag}
        ort_outs = self.model.run(self.output_names, ort_inputs)
        return torch.tensor(np.array(ort_outs[0])).to(self.device)

class Predictor:
    def __init__(self, args):
        self.args = args
        self.params = {
            "n_fft": 6144,
            "dim_f": 2048,
            "dim_t": 256,
            "hop_length": 1024,
            "sample_rate": 44100,
            "num_stems": 2
        }
        self.stems = args["stems"].split(",")
        self.model = MDX(args["model_path"], self.params)

    def demix(self, mix):
        samples = mix.shape[-1]
        margin = self.args["margin"]
        chunk_size = self.args["chunk_samples"] if self.args["chunk_samples"] else self.args["chunks"] * 44100

        min_chunk_size = self.params["n_fft"]
        if chunk_size < min_chunk_size:
            print(f"Warning: Chunk size {chunk_size} is too small for n_fft={self.params['n_fft']}. Adjusting to {min_chunk_size} samples.")
            chunk_size = min_chunk_size

        if margin > chunk_size:
            margin = chunk_size

        segmented_mix = {}
        if chunk_size == 0 or samples < chunk_size:
            chunk_size = samples

        counter = -1
        for skip in range(0, samples, chunk_size):
            counter += 1
            s_margin = 0 if counter == 0 else margin
            end = min(skip + chunk_size + margin, samples)
            start = skip - s_margin
            segmented_mix[skip] = mix[:, start:end].copy()
            if end == samples:
                break

        sources = self.demix_base(segmented_mix, margin_size=margin)
        return sources

    def demix_base(self, mixes, margin_size):
        sources = []
        progress_bar = tqdm(total=len(mixes))
        progress_bar.set_description("Processing")

        for mix in mixes:
            cmix = torch.tensor(mixes[mix], dtype=torch.float32).to(self.device)
            if cmix.ndim == 2:
                cmix = cmix.unsqueeze(0)
            batch, channels, samples = cmix.shape

            window = torch.hann_window(self.params["n_fft"]).to(self.device)
            spec = torch.stft(
                cmix.view(-1, samples),
                n_fft=self.params["n_fft"],
                hop_length=self.params["hop_length"],
                window=window,
                center=True,
                return_complex=True
            )
            spec = spec.view(batch, channels, *spec.shape[-2:])

            with torch.no_grad():
                mag = torch.abs(spec)
                phase = torch.angle(spec)
                mag = mag[:, :, :self.params["dim_f"], :]
                phase = phase[:, :, :self.params["dim_f"], :]

                mag = mag.repeat(1, 2, 1, 1)[:, :self.model.num_stems, :, :]
                phase = phase.repeat(1, 2, 1, 1)[:, :self.model.num_stems, :, :]

                pad_t = self.params["dim_t"] - (mag.shape[-1] % self.params["dim_t"]) % self.params["dim_t"]
                mag = torch.nn.functional.pad(mag, (0, pad_t))
                phase = torch.nn.functional.pad(phase, (0, pad_t))

                masks = []
                for i in range(0, mag.shape[-1], self.params["dim_t"]):
                    mag_chunk = mag[..., i:i+self.params["dim_t"]]
                    if mag_chunk.shape[-1] < self.params["dim_t"]:
                        pad_t_chunk = self.params["dim_t"] - mag_chunk.shape[-1]
                        mag_chunk = torch.nn.functional.pad(mag_chunk, (0, pad_t_chunk))
                    mask_chunk = self.model.run(mag_chunk)
                    if mask_chunk.shape[-1] != mag_chunk.shape[-1]:
                        mask_chunk = torch.nn.functional.interpolate(
                            mask_chunk, size=mag_chunk.shape[-1], mode="linear", align_corners=False
                        )
                    masks.append(mask_chunk)

                masks = torch.cat(masks, dim=-1)
                if self.args["denoise"]:
                    masks = torch.where(masks < 0.1, torch.zeros_like(masks), masks)

                masked_spec = mag * masks * torch.exp(1j * phase)

                masked_spec = torch.view_as_real(masked_spec)
                masked_spec = masked_spec.permute(0, 1, 4, 2, 3)
                masked_spec = masked_spec.reshape(-1, 2, masked_spec.shape[-2], masked_spec.shape[-1])

                signal = torch.istft(
                    torch.view_as_complex(masked_spec),
                    n_fft=self.params["n_fft"],
                    hop_length=self.params["hop_length"],
                    window=window,
                    center=True,
                    length=samples
                )
                signal = signal.view(batch, self.model.num_stems, channels, -1)

            start = 0 if mix == 0 else margin_size
            end = None if mix == list(mixes.keys())[::-1][0] else -margin_size
            if margin_size == 0:
                end = None

            sources.append(signal.cpu().numpy()[:, :, :, start:end])
            progress_bar.update(1)

        _sources = np.concatenate(sources, axis=-1)
        progress_bar.close()

        return _sources

    def predict(self, file_path):
        mix, sr = sf.read(file_path)
        if mix.ndim == 1:
            mix = np.asfortranarray([mix, mix])
        mix = mix.T
        sources = self.demix(mix)
        return sources, sr

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+", type=str, help="Source audio path or directory")
    parser.add_argument("-o", "--output", default="separated", type=str, help="Output folder")
    parser.add_argument("-m", "--model_path", type=str, help="MDX Net ONNX Model path")
    parser.add_argument("-d", "--denoise", action="store_true", help="Enable Denoising")
    parser.add_argument("-M", "--margin", default=44100, type=int, help="Margin")
    parser.add_argument("-C", "--chunk_samples", type=int, default=None, help="Chunk size in samples")
    parser.add_argument("--chunks", type=int, default=15, help="Chunk size in seconds")
    parser.add_argument("--stems", type=str, default="vocals,instrumental", help="Comma-separated list of stems")
    parser.add_argument("--format", type=str, default="wav", choices=["wav", "flac", "mp3"], help="Output format (wav, flac, mp3)")

    args = parser.parse_args()
    dict_args = vars(args)

    file_paths = []
    for file_arg in args.files:
        file_path = Path(file_arg)
        if file_path.is_dir():
            for ext in ("*.wav", "*.flac", "*.mp3"):
                file_paths.extend(file_path.rglob(ext))
        else:
            file_paths.append(file_path)

    if not file_paths:
        print("No audio files found. Please provide valid audio files or directories.")
        return

    os.makedirs(args.output, exist_ok=True)
    print(f"Processing {len(file_paths)} audio files...")

    processed_files = 0
    failed_files = 0

    for file_path in file_paths:
        try:
            print(f"\nProcessing: {file_path}")
            predictor = Predictor(args=dict_args)
            predictor.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            result = predictor.predict(file_path)
            filename = os.path.splitext(os.path.split(file_path)[-1])[0]
            stems, sampling_rate = result
            for i, stem_name in enumerate(predictor.stems):
                output_path = os.path.join(args.output, f"{filename}_{stem_name}.{args.format}")
                audio_data = stems[i][0]
                audio_data = (audio_data / np.max(np.abs(audio_data)) * 32767).astype(np.int16)
                if args.format in ["wav", "flac"]:
                    sf.write(output_path, audio_data, sampling_rate)
                elif args.format == "mp3":
                    audio_segment = AudioSegment(
                        audio_data.tobytes(),
                        frame_rate=sampling_rate,
                        sample_width=audio_data.dtype.itemsize,
                        channels=1
                    )
                    audio_segment.export(output_path, format="mp3")
                print(f"Saved: {output_path}")
            processed_files += 1
        except Exception as e:
            print(f"Failed to process {file_path}: {str(e)}")
            failed_files += 1

    print("\nSummary:")
    print(f"Total files processed: {processed_files}")
    print(f"Total files failed: {failed_files}")

if __name__ == "__main__":
    main()