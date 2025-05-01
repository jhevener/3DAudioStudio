import os
import sys
import torch
import librosa
import numpy as np
import soundfile as sf
from time import time
from tqdm import tqdm
import onnxruntime as ort
import argparse
import configparser
import logging
from datetime import datetime

# Setup logging
script_dir = os.path.dirname(os.path.abspath(__file__))
log_dir = os.path.join(script_dir, '..', '..', '..', 'logs')
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, 'separation_log.txt')

logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s Separation: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger()
logger.addHandler(logging.StreamHandler(sys.stdout))

class ConvTDFNet:
    def __init__(self, device, model_path, args):
        self.device = device
        self.dim_f = args['dim_f']
        self.dim_t = args['dim_t']
        self.n_fft = args['n_fft']
        self.hop = args.get('hop_length', 1024)  # Default from YAML
        self.window = torch.hann_window(self.n_fft).to(self.device)
        self.n_bins = self.n_fft // 2 + 1
        logger.info(f"ConvTDFNet params: n_bins={self.n_bins}, dim_f={self.dim_f}, dim_t={self.dim_t}")
        if self.n_bins - self.dim_f <= 0:
            logger.error(f"Invalid dimensions: n_bins ({self.n_bins}) - dim_f ({self.dim_f}) must be positive")
            raise ValueError(f"n_bins ({self.n_bins}) must be greater than dim_f ({self.dim_f})")
        self.freq_pad = torch.zeros([1, 1, self.n_bins - self.dim_f, self.dim_t]).to(device)
        self.model = ort.InferenceSession(model_path, providers=['CUDAExecutionProvider', 'CPUExecutionProvider'])
        self.args = args

    def stft(self, x):
        spec = torch.stft(
            x,
            n_fft=self.n_fft,
            hop_length=self.hop,
            window=self.window,
            center=True,
            return_complex=True
        )
        return torch.view_as_real(spec)

    def istft(self, spec):
        spec = torch.view_as_complex(spec)
        return torch.istft(
            spec,
            n_fft=self.n_fft,
            hop_length=self.hop,
            window=self.window,
            center=True,
            length=self.args['length']
        )

    def spec_effects(self, spec):
        spec = spec[:, :self.dim_f, :]
        spec = torch.cat([spec, self.freq_pad], dim=-2)
        spec = torch.cat([spec, torch.flip(spec, dims=[-1])], dim=-1)[..., :self.dim_t]
        return spec

    def inference(self, mix):
        self.args['length'] = len(mix)
        mix = torch.tensor(mix, dtype=torch.float32).to(self.device)
        spec = self.stft(mix)
        spec = spec.permute(0, 3, 1, 2)
        mag = spec.norm(p=2, dim=-1)

        mag = mag.transpose(-1, -2)[..., :-1]
        mag = self.spec_effects(mag)

        mag = mag.cpu().numpy()
        mag = np.expand_dims(mag, axis=1)

        output = self.model.run(None, {'input': mag})[0]
        output = torch.tensor(output).to(self.device)

        output = output.squeeze(1).transpose(-1, -2)
        output = torch.cat([output, torch.zeros([*output.shape[:-1], 1], device=self.device)], dim=-1)
        output = torch.cat([output[..., :self.dim_t], torch.flip(output, dims=[-1])[..., 1:self.dim_t+1]], dim=-1)

        mask = torch.softmax(output, dim=1)
        mask = torch.cat([mask, torch.zeros([*mask.shape[:-1], self.n_bins - self.dim_f], device=self.device)], dim=-1)

        mask = mask.transpose(-1, -2)[..., :spec.shape[-2]]
        mask = torch.stack([mask, mask], dim=-1)

        spec = spec * mask[1] + spec * (1 - mask[0])
        stems = torch.stack([self.istft(spec[i]) for i in range(self.args['num_stems'])])

        return stems.cpu().numpy()

class Separator:
    def __init__(self, model_path, args):
        self.device = torch.device('cuda' if torch.cuda.is_available() and not args['no_cuda'] else 'cpu')
        self.model_path = model_path
        self.args = args
        self.model = ConvTDFNet(self.device, model_path, args)

    def pad_audio(self, audio):
        length = len(audio)
        if length % self.args['chunks']:
            padding = (self.args['chunks'] - (length % self.args['chunks'])) % self.args['chunks']
            audio = np.pad(audio, (0, padding), mode='constant')
        return audio, length

    def separate(self, filepath):
        audio, sr = librosa.load(filepath, sr=44100, mono=True)
        audio, length = self.pad_audio(audio)
        chunk_size = sr * self.args['chunks']

        if self.args['chunks'] == 0:
            stems = self.model.inference(audio)
        else:
            stems = np.zeros([self.args['num_stems'], len(audio)], dtype=np.float32)
            for i in tqdm(range(0, len(audio), chunk_size)):
                chunk = audio[i:i + chunk_size]
                if len(chunk) != chunk_size:
                    chunk, _ = self.pad_audio(chunk)
                chunk_stems = self.model.inference(chunk)
                stems[:, i:i + chunk_size] = chunk_stems[:, :len(chunk)]

        stems = stems[..., :length]
        return stems

def load_model_config(model_name):
    logger.info(f"Loading model config for {model_name}")
    config_path = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'installs', 'models.ini')
    config = configparser.ConfigParser()
    config.read(config_path)
    if model_name not in config:
        logger.error(f"Model {model_name} not found in models.ini at {config_path}")
        raise ValueError(f"Model {model_name} not found in models.ini")
    # Use Config field if specified, otherwise construct default path
    yaml_path = config[model_name].get('Config', os.path.join(os.path.dirname(__file__), '..', 'config', f"{model_name}.yaml"))
    yaml_config = None
    if os.path.exists(yaml_path):
        logger.info(f"Found config.yaml at {yaml_path}")
        try:
            import yaml
            with open(yaml_path, 'r') as f:
                yaml_config = yaml.safe_load(f)
            logger.info(f"Loaded config.yaml: {yaml_config}")
        except Exception as e:
            logger.error(f"Failed to load config.yaml: {str(e)}")
    else:
        logger.warning(f"No config.yaml found at {yaml_path}, using models.ini parameters")
    return config[model_name], yaml_config

def main():
    logger.info("Starting separation process")
    parser = argparse.ArgumentParser()
    parser.add_argument('--files', nargs='+', required=True, help='Source audio path')
    parser.add_argument('-o', '--output', default='stems', help='Output folder')
    parser.add_argument('-m', '--model_path', required=True, help='MDX Net ONNX Model path')
    parser.add_argument('-c', '--config_path', help='Path to config YAML file')
    parser.add_argument('--model-type', choices=['mdx', 'roformer'], default='mdx', help='Model type')
    parser.add_argument('--stems', type=int, help='Number of stems to separate into')
    parser.add_argument('-d', action='store_true', help='Enable denoising')
    parser.add_argument('--no-cuda', action='store_true', help='Disable CUDA')
    parser.add_argument('-M', '--margin', type=int, default=10, help='Margin')
    parser.add_argument('-C', '--chunks', type=int, default=512, help='Chunk size')
    parser.add_argument('-F', '--n_fft', type=int, default=6144, help='FFT size')
    parser.add_argument('-t', '--dim_t', type=int, default=256, help='Time dimension')
    parser.add_argument('-f', '--dim_f', type=int, default=2048, help='Frequency dimension')
    args = parser.parse_args()

    # Extract model name
    model_name = os.path.basename(args.model_path).rsplit(".", 1)[0]
    logger.info(f"Processing model: {model_name}")

    # Load config
    try:
        ini_config, yaml_config = load_model_config(model_name)
    except Exception as e:
        logger.error(f"Failed to load config: {str(e)}")
        raise

    # Load parameters (prioritize YAML, then INI, then command-line)
    if yaml_config and 'model' in yaml_config:
        yaml_params = yaml_config['model']
        chunks = yaml_params.get('chunks', ini_config.getint("Chunks", args.chunks))
        margin = yaml_params.get('margin', ini_config.getint("Margin", args.margin))
        n_fft = yaml_params.get('n_fft', ini_config.getint("N_FFT", args.n_fft))
        dim_t = yaml_params.get('dim_t', ini_config.getint("Dim_T", args.dim_t))
        dim_f = yaml_params.get('dim_f', ini_config.getint("Dim_F", args.dim_f))
        num_stems = yaml_params.get('num_stems', ini_config.getint("Stems", args.stems or 2))
        hop_length = yaml_config.get('audio', {}).get('hop_length', 1024)
    else:
        chunks = ini_config.getint("Chunks", args.chunks)
        margin = ini_config.getint("Margin", args.margin)
        n_fft = ini_config.getint("N_FFT", args.n_fft)
        dim_t = ini_config.getint("Dim_T", args.dim_t)
        dim_f = ini_config.getint("Dim_F", args.dim_f)
        num_stems = ini_config.getint("Stems", args.stems or 2)
        hop_length = 1024  # Default
    denoise = args.d
    no_cuda = args.no_cuda

    logger.info(f"Parameters: chunks={chunks}, margin={margin}, n_fft={n_fft}, dim_t={dim_t}, dim_f={dim_f}, num_stems={num_stems}, hop_length={hop_length}, denoise={denoise}")

    args_dict = {
        'chunks': chunks,
        'margin': margin,
        'n_fft': n_fft,
        'dim_t': dim_t,
        'dim_f': dim_f,
        'num_stems': num_stems,
        'hop_length': hop_length,
        'denoise': denoise,
        'no_cuda': no_cuda
    }

    separator = Separator(args.model_path, args_dict)

    output_stems = ini_config.get("OutputStems", "vocals,no_vocals").split(",")
    if len(output_stems) != num_stems:
        logger.error(f"Number of output stems ({len(output_stems)}) does not match num_stems ({num_stems})")
        raise ValueError(f"OutputStems ({output_stems}) does not match num_stems ({num_stems})")

    for file_path in args.files:
        logger.info(f'Separating: {file_path}')
        start = time()
        stems = separator.separate(file_path)
        logger.info(f'Time: {time() - start:.2f}s')

        filename = os.path.splitext(os.path.basename(file_path))[0]
        os.makedirs(args.output, exist_ok=True)
        for i, stem_name in enumerate(output_stems):
            stem_name = stem_name.strip()
            sf.write(os.path.join(args.output, f'{filename}_{stem_name}.wav'), stems[i], 44100)
            logger.info(f"Generated stem: {stem_name}")

if __name__ == '__main__':
    try:
        logger.info("Script started")
        main()
        logger.info("Script completed successfully")
    except Exception as e:
        logger.error(f"Separation failed: {str(e)}")
        raise