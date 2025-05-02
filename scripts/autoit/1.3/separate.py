import logging
import os
import sys
import time
from datetime import datetime
import soundfile as sf
import torch
import librosa
import numpy as np
import onnxruntime as ort
from pathlib import Path
from argparse import ArgumentParser
from tqdm import tqdm
import psutil


# Optional VRAM logging
try:
    import pynvml
    pynvml.nvmlInit()
    HAS_PYNVML = True
except (ImportError, pynvml.NVMLError):
    HAS_PYNVML = False
    logging.warning("pynvml not available; VRAM logging disabled")


# Setup logging
log_dir = os.path.join(os.path.dirname(__file__), "logs")
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, "separate_log.txt")
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger()

# Rotate log file if >10MB
if os.path.exists(log_file) and os.path.getsize(log_file) > 10 * 1024 * 1024:
    backup_file = log_file.replace(".txt", f"_{datetime.now().strftime('%Y%m%d%H%M%S')}.txt")
    os.rename(log_file, backup_file)
    logger.info(f"Rotated log file to {backup_file}")


def log_resource_usage():
    """Log CPU, memory, and optional VRAM usage."""
    process = psutil.Process()
    mem_info = process.memory_info()
    cpu_percent = psutil.cpu_percent(interval=0.1)
    log_msg = f"Resource usage: CPU={cpu_percent}%, Memory={mem_info.rss / 1024 / 1024:.2f}MB"

    if HAS_PYNVML:
        try:
            device_count = pynvml.nvmlDeviceGetCount()
            for i in range(device_count):
                handle = pynvml.nvmlDeviceGetHandleByIndex(i)
                mem_info = pynvml.nvmlDeviceGetMemoryInfo(handle)
                log_msg += f", GPU{i}-VRAM={mem_info.used / 1024 / 1024:.2f}/{mem_info.total / 1024 / 1024:.2f}MB"
        except pynvml.NVMLError as e:
            logger.warning(f"Failed to log VRAM: {str(e)}")

    logger.info(log_msg)


class ConvTDFNet:
    def __init__(self, target_name, L, dim_f, dim_t, n_fft, hop=1024):
        super(ConvTDFNet, self).__init__()
        self.dim_c = 4
        self.dim_f = dim_f
        self.dim_t = 2**dim_t
        self.n_fft = n_fft
        self.hop = hop
        self.n_bins = self.n_fft // 2 + 1
        self.chunk_size = hop * (self.dim_t - 1)
        self.window = torch.hann_window(window_length=self.n_fft, periodic=True)
        self.target_name = target_name
        
        out_c = self.dim_c * 4 if target_name == "*" else self.dim_c
        
        self.freq_pad = torch.zeros([1, out_c, self.n_bins - self.dim_f, self.dim_t])
        self.n = L // 2
        logger.info(f"Initialized ConvTDFNet: target={target_name}, L={L}, dim_f={dim_f}, dim_t={self.dim_t}, n_fft={n_fft}, hop={hop}")


    def stft(self, x):
        logger.info(f"Computing STFT: input shape={x.shape}")
        x = x.reshape([-1, self.chunk_size])
        x = torch.stft(
            x,
            n_fft=self.n_fft,
            hop_length=self.hop,
            window=self.window,
            center=True,
            return_complex=True,
        )
        x = torch.view_as_real(x)
        x = x.permute([0, 3, 1, 2])
        x = x.reshape([-1, 2, 2, self.n_bins, self.dim_t]).reshape(
            [-1, self.dim_c, self.n_bins, self.dim_t]
        )
        logger.info(f"STFT output shape={x.shape}")
        return x[:, :, : self.dim_f]


    def istft(self, x, freq_pad=None):
        logger.info(f"Computing ISTFT: input shape={x.shape}")
        freq_pad = (
            self.freq_pad.repeat([x.shape[0], 1, 1, 1])
            if freq_pad is None
            else freq_pad
        )
        x = torch.cat([x, freq_pad], -2)
        c = 4 * 2 if self.target_name == "*" else 2
        x = x.reshape([-1, c, 2, self.n_bins, self.dim_t]).reshape(
            [-1, 2, self.n_bins, self.dim_t]
        )
        x = x.permute([0, 2, 3, 1])
        x = x.contiguous()
        x = torch.view_as_complex(x)
        x = torch.istft(
            x, n_fft=self.n_fft, hop_length=self.hop, window=self.window, center=True
        )
        logger.info(f"ISTFT output shape={x.shape}")
        return x.reshape([-1, c, self.chunk_size])


class Predictor:
    def __init__(self, args):
        self.args = args
        self.model_ = ConvTDFNet(
            target_name="vocals",
            L=11,
            dim_f=args["dim_f"], 
            dim_t=args["dim_t"], 
            n_fft=args["n_fft"]
        )
        
        logger.info(f"Loading ONNX model: {args['model_path']}")
        if torch.cuda.is_available():
            self.model = ort.InferenceSession(args['model_path'], providers=['CUDAExecutionProvider'])
            logger.info("Using CUDAExecutionProvider")
        else:
            self.model = ort.InferenceSession(args['model_path'], providers=['CPUExecutionProvider'])
            logger.info("Using CPUExecutionProvider")
        log_resource_usage()


    def demix(self, mix):
        logger.info(f"Demixing: mix shape={mix.shape}")
        samples = mix.shape[-1]
        margin = self.args["margin"]
        chunk_size = self.args["chunks"] * 44100
        
        if margin == 0:
            logger.error("Margin cannot be zero")
            raise ValueError("margin cannot be zero!")
        
        if margin > chunk_size:
            logger.warning(f"Margin ({margin}) exceeds chunk_size ({chunk_size}), setting margin to chunk_size")
            margin = chunk_size

        segmented_mix = {}
        logger.info(f"Demix: samples={samples}, chunk_size={chunk_size}, margin={margin}")

        if self.args["chunks"] == 0 or samples < chunk_size:
            chunk_size = samples

        counter = -1
        for skip in range(0, samples, chunk_size - margin):
            counter += 1
            s_margin = 0 if counter == 0 else margin
            end = min(skip + chunk_size + margin, samples)
            start = skip - s_margin
            segmented_mix[skip] = mix[:, start:end].copy()
            logger.info(f"Segment {counter}: start={start}, end={end}, shape={segmented_mix[skip].shape}")
            if end == samples:
                break

        if not segmented_mix:
            logger.error("No segments created")
            raise ValueError("No segments created. Check audio length and chunk size.")

        sources = self.demix_base(segmented_mix, margin_size=margin)
        return sources


    def demix_base(self, mixes, margin_size):
        chunked_sources = []
        total_steps = len(mixes)
        progress_bar = tqdm(total=total_steps)
        progress_bar.set_description("Processing")
        
        for i, mix in enumerate(mixes):
            cmix = mixes[mix]
            sources = []
            n_sample = cmix.shape[1]
            model = self.model_
            trim = model.n_fft // 2
            gen_size = model.chunk_size - 2 * trim
            pad = gen_size - n_sample % gen_size
            mix_p = np.concatenate(
                (np.zeros((2, trim)), cmix, np.zeros((2, pad)), np.zeros((2, trim))), 1
            )
            mix_waves = []
            i = 0
            while i < n_sample + pad:
                waves = np.array(mix_p[:, i : i + model.chunk_size])
                mix_waves.append(waves)
                i += gen_size
            
            mix_waves = torch.tensor(np.array(mix_waves), dtype=torch.float32)
            logger.info(f"demix_base: mix_waves shape={mix_waves.shape}")
            
            with torch.no_grad():
                _ort = self.model
                spek = model.stft(mix_waves)
                logger.info(f"Spek shape={spek.shape}")
                try:
                    if self.args["denoise"]:
                        logger.info("Applying denoising")
                        spec_pred = (
                            -_ort.run(None, {"input": -spek.cpu().numpy()})[0] * 0.5
                            + _ort.run(None, {"input": spek.cpu().numpy()})[0] * 0.5
                        )
                    else:
                        spec_pred = _ort.run(None, {"input": spek.cpu().numpy()})[0]
                    logger.info(f"spec_pred shape={spec_pred.shape}")
                    tar_waves = model.istft(torch.tensor(spec_pred))
                    logger.info(f"tar_waves shape={tar_waves.shape}")
                except Exception as e:
                    logger.error(f"Model inference failed: {str(e)}", exc_info=True)
                    progress_bar.update(1)
                    continue

                tar_signal = (
                    tar_waves[:, :, trim:-trim]
                    .transpose(0, 1)
                    .reshape(2, -1)
                    .numpy()[:, :-pad]
                )
                logger.info(f"tar_signal shape={tar_signal.shape}")

                start = 0 if mix == 0 else margin_size
                end = None if mix == list(mixes.keys())[::-1][0] else -margin_size
                
                if margin_size == 0:
                    end = None
                
                sliced_signal = tar_signal[:, start:end]
                logger.info(f"sliced_signal shape={sliced_signal.shape}")
                if sliced_signal.size > 0:
                    sources.append(sliced_signal)
                else:
                    logger.warning(f"Empty sliced_signal for mix {mix}")

                # Update progress for GUI
                progress = ((i + 1) / total_steps) * 100
                progress_bar_chars = "#" * int(progress / 10) + " " * (10 - int(progress / 10))
                logger.info(f"Processing: {progress:.0f}%|{progress_bar_chars}|")
                print(f"Processing: {progress:.0f}%|{progress_bar_chars}|", flush=True)
                log_resource_usage()
                progress_bar.update(1)

            if sources:
                chunked_sources.append(sources)
            else:
                logger.warning(f"No sources for mix {mix}")

        progress_bar.close()
        if not chunked_sources:
            logger.error("No valid sources to concatenate")
            raise ValueError("No valid sources to concatenate. Check model output or audio input.")
        _sources = np.concatenate(chunked_sources, axis=-1)
        logger.info(f"_sources shape={_sources.shape}")
        return _sources


    def predict(self, file_path):
        logger.info(f"Loading audio for prediction: {file_path}")
        mix, rate = librosa.load(file_path, mono=False, sr=44100)
        logger.info(f"Predict: mix shape={mix.shape}, rate={rate}")
        log_resource_usage()
        
        if mix.ndim == 1:
            mix = np.asfortranarray([mix, mix])
        
        mix = mix.T
        sources = self.demix(mix.T)
        opt = sources[0].T
        return (mix - opt, opt, rate)


def main():
    parser = ArgumentParser()
    
    parser.add_argument("files", nargs="+", type=Path, default=[], help="Source audio path")
    parser.add_argument("-o", "--output", type=Path, default=Path("separated"), help="Output folder")
    parser.add_argument("-m", "--model_path", type=Path, help="MDX Net ONNX Model path")
    parser.add_argument("-d", "--denoise", type=lambda x: x.lower() == 'true', default=True, help="Enable or disable denoising")
    parser.add_argument("-M", "--margin", type=int, default=44100, help="Margin in samples")
    parser.add_argument("-c", "--chunks", type=int, default=15, help="Chunk size in seconds")
    parser.add_argument("-F", "--n_fft", type=int, default=6144)
    parser.add_argument("-t", "--dim_t", type=int, default=8)
    parser.add_argument("-f", "--dim_f", type=int, default=2048)
    
    args = parser.parse_args()
    dict_args = vars(args)
    
    logger.info("Script started with arguments: " + " ".join(sys.argv))
    os.makedirs(args.output, exist_ok=True)
    log_resource_usage()
    
    for file_path in args.files:
        logger.info(f"Processing file: {file_path}")
        try:
            predictor = Predictor(args=dict_args)
            vocals, no_vocals, sampling_rate = predictor.predict(file_path)
            filename = os.path.splitext(os.path.split(file_path)[-1])[0]
            no_vocals_path = os.path.join(args.output, filename + "_no_vocals.wav")
            vocals_path = os.path.join(args.output, filename + "_vocals.wav")
            sf.write(no_vocals_path, no_vocals, sampling_rate)
            logger.info(f"Saved stem: {no_vocals_path}, Size={os.path.getsize(no_vocals_path)} bytes")
            sf.write(vocals_path, vocals, sampling_rate)
            logger.info(f"Saved stem: {vocals_path}, Size={os.path.getsize(vocals_path)} bytes")
        except Exception as e:
            logger.error(f"Error processing {file_path}: {str(e)}", exc_info=True)


if __name__ == "__main__":
    main()