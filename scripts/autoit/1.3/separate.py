import soundfile as sf
import torch 
import os 
import librosa
import numpy as np
import onnxruntime as ort
from pathlib import Path
from argparse import ArgumentParser
from tqdm import tqdm
import logging

# Setup logging
def setup_logging(log_dir="logs"):
    log_dir = Path(log_dir)
    log_dir.mkdir(exist_ok=True)
    log_file = log_dir / "separate_log.txt"
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
    logging.debug("Logging initialized")

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
        logging.debug(f"ConvTDFNet initialized: dim_f={dim_f}, dim_t={self.dim_t}, n_fft={n_fft}, hop={hop}")

    def stft(self, x):
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
        return x[:, :, : self.dim_f]

    def istft(self, x, freq_pad=None):
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
        logging.debug(f"Predictor initializing with args: {args}")
        try:
            if torch.cuda.is_available():
                logging.info(f"CUDA available, using CUDAExecutionProvider for model: {args['model_path']}")
                self.model = ort.InferenceSession(args['model_path'], providers=['CUDAExecutionProvider'])
            else:
                logging.info(f"CUDA not available, using CPUExecutionProvider for model: {args['model_path']}")
                self.model = ort.InferenceSession(args['model_path'], providers=['CPUExecutionProvider'])
        except Exception as e:
            logging.error(f"Failed to load model {args['model_path']}: {str(e)}")
            raise

    def demix(self, mix):
        samples = mix.shape[-1]
        margin = self.args["margin"]
        chunk_size = self.args["chunks"] * 44100
        logging.debug(f"Demixing audio: samples={samples}, margin={margin}, chunk_size={chunk_size}")
        
        assert not margin == 0, "margin cannot be zero!"
        
        if margin > chunk_size:
            margin = chunk_size

        segmented_mix = {}

        if self.args["chunks"] == 0 or samples < chunk_size:
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
        logging.debug(f"Created {counter + 1} chunks for demixing")

        sources = self.demix_base(segmented_mix, margin_size=margin)
        return sources

    def demix_base(self, mixes, margin_size):
        chunked_sources = []
        progress_bar = tqdm(total=len(mixes))
        progress_bar.set_description("Processing")
        
        for mix in mixes:
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
            logging.debug(f"Processing chunk: {len(mix_waves)} waves")
            
            with torch.no_grad():
                _ort = self.model
                spek = model.stft(mix_waves)
                if self.args["denoise"]:
                    spec_pred = (
                        -_ort.run(None, {"input": -spek.cpu().numpy()})[0] * 0.5
                        + _ort.run(None, {"input": spek.cpu().numpy()})[0] * 0.5
                    )
                    tar_waves = model.istft(torch.tensor(spec_pred))
                else:
                    tar_waves = model.istft(
                        torch.tensor(_ort.run(None, {"input": spek.cpu().numpy() })[0])
                    )
                tar_signal = (
                    tar_waves[:, :, trim:-trim]
                    .transpose(0, 1)
                    .reshape(2, -1)
                    .numpy()[:, :-pad]
                )

                start = 0 if mix == 0 else margin_size
                end = None if mix == list(mixes.keys())[::-1][0] else -margin_size
                
                if margin_size == 0:
                    end = None
                
                sources.append(tar_signal[:, start:end])

                progress_bar.update(1)

            chunked_sources.append(sources)
        _sources = np.concatenate(chunked_sources, axis=-1)
        
        progress_bar.close()
        logging.debug("Demixing complete")
        return _sources

    def predict(self, file_path):
        logging.info(f"Loading audio file: {file_path}")
        try:
            mix, rate = librosa.load(file_path, mono=False, sr=44100)
            logging.debug(f"Audio loaded: shape={mix.shape}, sample_rate={rate}")
        except Exception as e:
            logging.error(f"Failed to load audio {file_path}: {str(e)}")
            raise
        
        if mix.ndim == 1:
            mix = np.asfortranarray([mix, mix])
        
        mix = mix.T
        sources = self.demix(mix.T)
        opt = sources[0].T
        
        return (mix - opt, opt, rate)

def main():
    setup_logging()
    parser = ArgumentParser()
    
    parser.add_argument("files", nargs="+", type=Path, default=[], help="Source audio path")
    parser.add_argument("-o", "--output", type=Path, default=Path("separated"), help="Output folder")
    parser.add_argument("-m", "--model_path", type=Path, help="MDX Net ONNX Model path")
    parser.add_argument("-s", "--stems", type=str, default="vocals,no_vocals", help="Comma-separated list of output stems (e.g., vocals,no_vocals)")
    
    parser.add_argument("-d", "--no-denoise", dest="denoise", action="store_false", default=True, help="Disable denoising")
    parser.add_argument("-M", "--margin", type=int, default=44100, help="Margin")
    parser.add_argument("-c", "--chunks", type=int, default=15, help="Chunk size")
    parser.add_argument("-F", "--n_fft", type=int, default=6144)
    parser.add_argument("-t", "--dim_t", type=int, default=8)
    parser.add_argument("-f", "--dim_f", type=int, default=2048)
    
    args = parser.parse_args()
    dict_args = vars(args)
    logging.info(f"Parsed arguments: {dict_args}")
    
    os.makedirs(args.output, exist_ok=True)
    logging.debug(f"Output directory created: {args.output}")
    
    for file_path in args.files:
        logging.info(f"Processing file: {file_path}")
        try:
            predictor = Predictor(args=dict_args)
            vocals, no_vocals, sampling_rate = predictor.predict(file_path)
            filename = os.path.splitext(os.path.split(file_path)[-1])[0]
            # Use the stems from the command-line argument
            stems = args.stems.split(",")
            if len(stems) != 2:
                raise ValueError("Expected exactly two stems in --stems argument")
            stem1_path = os.path.join(args.output, filename + "_" + stems[0] + ".wav")
            stem2_path = os.path.join(args.output, filename + "_" + stems[1] + ".wav")
            sf.write(stem1_path, vocals, sampling_rate)
            sf.write(stem2_path, no_vocals, sampling_rate)
            logging.info(f"Generated outputs: {stem1_path}, {stem2_path}")
        except Exception as e:
            logging.error(f"Failed to process {file_path}: {str(e)}")
            raise
  
if __name__ == "__main__":
    main()