# Author: Original script by [Your Name or Source, if applicable]
# Modifier: Grok 3 (xAI), last modified April 30, 2025
# Description: Script for audio source separation using BandSplit RoFormer models with multi-resolution STFT.

import soundfile as sf
import torch
import torch.nn as nn
import torch.nn.functional as F
import os
import librosa
import numpy as np
import onnxruntime as ort
from pathlib import Path
from argparse import ArgumentParser
from tqdm import tqdm
import yaml
from yaml.loader import SafeLoader
import einops
import math

# Custom constructor for !!python/tuple tag
def tuple_constructor(loader, node):
    return tuple(loader.construct_sequence(node))

SafeLoader.add_constructor('tag:yaml.org,2002:python/tuple', tuple_constructor)

# RoFormer components adapted from Ultimate Vocal Remover (UVR) codebase
class LayerNorm(nn.Module):
    def __init__(self, dim):
        super().__init__()
        self.gamma = nn.Parameter(torch.ones(dim))
        self.register_buffer("beta", torch.zeros(dim))  # Reverted to buffer

    def forward(self, x):
        return F.layer_norm(x, x.shape[-1:], self.gamma, self.beta)

class PreNorm(nn.Module):
    def __init__(self, dim, fn):
        super().__init__()
        self.fn = fn
        self.norm = LayerNorm(dim)

    def forward(self, x, **kwargs):
        x = self.norm(x)
        return self.fn(x, **kwargs)

class FeedForward(nn.Module):
    def __init__(self, dim, mult=4, dropout=0.0):
        super().__init__()
        inner_dim = int(dim * mult)
        self.net = nn.Sequential(
            LayerNorm(dim),
            nn.Linear(dim, inner_dim),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(inner_dim, dim),
            nn.Dropout(dropout),
        )

    def forward(self, x):
        return self.net(x)

class RotaryEmbedding(nn.Module):
    def __init__(self, dim, max_freq=10):
        super().__init__()
        self.dim = dim
        inv_freq = 1.0 / (max_freq ** (torch.arange(0, dim, 2).float() / dim))
        self.register_buffer("freqs", inv_freq)

    def forward(self, t, device):
        t = t.to(device)
        freqs = torch.einsum("i, j -> i j", t, self.freqs.to(device))
        freqs = torch.cat((freqs, freqs), dim=-1)
        return freqs

class Attention(nn.Module):
    def __init__(self, dim, heads=8, dim_head=64, dropout=0.0):
        super().__init__()
        inner_dim = dim_head * heads
        self.heads = heads
        self.scale = dim_head**-0.5

        self.rotary_embed = RotaryEmbedding(dim_head // 2)
        self.to_qkv = nn.Linear(dim, inner_dim * 3, bias=False)
        self.to_gates = nn.Linear(dim, heads)
        self.to_out = nn.Linear(inner_dim, dim)

        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        b, n, d, h = *x.shape, self.heads

        t = torch.arange(n, device=x.device)
        freqs = self.rotary_embed(t, x.device)

        qkv = self.to_qkv(x).chunk(3, dim=-1)
        q, k, v = map(lambda t: einops.rearrange(t, "b n (h d) -> b h n d", h=h), qkv)

        q = self.apply_rotary_pos_emb(q, freqs)
        k = self.apply_rotary_pos_emb(k, freqs)

        dots = torch.einsum("b h i d, b h j d -> b h i j", q, k) * self.scale
        attn = dots.softmax(dim=-1)

        gates = self.to_gates(x)
        gates = einops.rearrange(gates, "b n h -> b h n 1").sigmoid()

        out = torch.einsum("b h i j, b h j d -> b h i d", attn, v)
        out = out * gates
        out = einops.rearrange(out, "b h n d -> b n (h d)")

        return self.dropout(self.to_out(out))

    def apply_rotary_pos_emb(self, x, freqs):
        x_ = x
        x = einops.rearrange(x, "b h n (d r) -> b h n d r", r=2)
        x_cos, x_sin = freqs.cos()[None, None, :, None, :], freqs.sin()[None, None, :, None, :]
        x1, x2 = x[..., 0], x[..., 1]
        x = torch.stack((-x2 * x_sin + x1 * x_cos, x1 * x_sin + x2 * x_cos), dim=-1)
        x = einops.rearrange(x, "b h n d r -> b h n (d r)")
        return x

class Transformer(nn.Module):
    def __init__(self, dim, depth, heads, dim_head, dropout=0.0):
        super().__init__()
        self.layers = nn.ModuleList([])
        for _ in range(depth):
            self.layers.append(
                nn.ModuleList([
                    PreNorm(dim, Attention(dim, heads=heads, dim_head=dim_head, dropout=dropout)),
                    PreNorm(dim, FeedForward(dim, dropout=dropout)),
                ])
            )

    def forward(self, x):
        for attn, ff in self.layers:
            x = attn(x) + x
            x = ff(x) + x
        return x

class BandSplit(nn.Module):
    def __init__(self, freqs_per_bands, dim, dim_freqs_in):
        super().__init__()
        self.freqs_per_bands = freqs_per_bands
        self.to_features = nn.ModuleList([])
        for freqs in freqs_per_bands:
            self.to_features.append(
                nn.Sequential(
                    LayerNorm(dim_freqs_in),         # 0: LayerNorm (gamma only)
                    nn.Linear(dim_freqs_in, dim),    # 1: Linear (weight, bias)
                )
            )

    def forward(self, x):
        batch, channels, freqs, time = x.shape
        x = einops.rearrange(x, "b c f t -> b t c f")

        split_bands = []
        start = 0
        for i, freqs in enumerate(self.freqs_per_bands):
            end = start + freqs
            if end > freqs:
                break
            band = x[..., start:end]
            band = self.to_features[i](band)
            split_bands.append(band)
            start = end

        return split_bands

class RoFormer(nn.Module):
    def __init__(self, freqs_per_bands, dim, depth, heads, dim_head, attn_dropout, ff_dropout, dim_freqs_in, mask_estimator_depth=2):
        super().__init__()
        self.freqs_per_bands = freqs_per_bands
        self.num_bands = len(freqs_per_bands)
        self.dim_freqs_in = dim_freqs_in

        self.band_split = BandSplit(freqs_per_bands, dim, dim_freqs_in)
        self.layers = nn.ModuleList(
            [Transformer(dim, depth, heads, dim_head, dropout=attn_dropout) for _ in range(2)]
        )
        self.final_norm = LayerNorm(dim)

        self.mask_estimators = nn.ModuleList([])
        for _ in range(mask_estimator_depth):
            estimators = nn.ModuleList([])
            for freqs in freqs_per_bands:
                estimator = nn.Sequential(
                    nn.Linear(dim, dim_freqs_in),
                    nn.ReLU(),
                    nn.Linear(dim_freqs_in, freqs),
                    nn.Sigmoid(),
                )
                estimators.append(estimator)
            self.mask_estimators.append(estimators)

    def forward(self, spec):
        split_bands = self.band_split(spec)

        for transformer in self.layers:
            split_bands = [transformer(band) for band in split_bands]

        split_bands = [self.final_norm(band) for band in split_bands]

        masks = []
        for mask_estimator in self.mask_estimators:
            band_masks = []
            for i, band in enumerate(split_bands):
                mask = mask_estimator[i](band)
                band_masks.append(mask)
            masks.append(band_masks)

        masks = list(map(lambda x: sum(x) / len(x), zip(*masks)))
        masks = torch.cat(masks, dim=-1)

        return masks

class Predictor:
    def __init__(self, args):
        self.args = args
        self.device = 'cuda' if torch.cuda.is_available() else 'cpu'

        # Set target_name based on stems for dynamic stem separation
        self.stems = args["stems"].split(',')
        self.target_name = "*" if len(self.stems) > 2 else self.stems[0]

        if args["model_type"] == 'roformer':
            with open(args["config_path"], 'r') as f:
                config = yaml.load(f, Loader=SafeLoader)
            
            # Extract model parameters from config
            model_config = config.get("model", {})
            audio_config = config.get("audio", {})
            training_config = config.get("training", {})
            freqs_per_bands = model_config.get("freqs_per_bands", [])
            dim = model_config.get("dim", 384)
            depth = model_config.get("depth", 12)
            heads = model_config.get("heads", 8)
            dim_head = model_config.get("dim_head", 64)
            attn_dropout = model_config.get("attn_dropout", 0.1)
            ff_dropout = model_config.get("ff_dropout", 0.1)
            dim_freqs_in = model_config.get("dim_freqs_in", 1025)
            mask_estimator_depth = model_config.get("mask_estimator_depth", 2)
            self.num_stems = model_config.get("num_stems", 1)
            self.target_instrument = training_config.get("target_instrument", "No Drum-Bass")

            # Multi-resolution STFT parameters
            self.multi_stft_resolutions = model_config.get("multi_stft_resolutions_window_sizes", [2048])
            self.multi_stft_hop_size = model_config.get("multi_stft_hop_size", 147)
            self.stft_params = []
            for win_length in self.multi_stft_resolutions:
                n_fft = win_length
                hop_length = self.multi_stft_hop_size
                window = torch.hann_window(win_length).to(self.device)
                self.stft_params.append({
                    "n_fft": n_fft,
                    "hop_length": hop_length,
                    "win_length": win_length,
                    "window": window
                })

            # Initialize the RoFormer model
            self.model = RoFormer(
                freqs_per_bands=freqs_per_bands,
                dim=dim,
                depth=depth,
                heads=heads,
                dim_head=dim_head,
                attn_dropout=attn_dropout,
                ff_dropout=ff_dropout,
                dim_freqs_in=dim_freqs_in,
                mask_estimator_depth=mask_estimator_depth
            )
            checkpoint = torch.load(args["model_path"], map_location=self.device)
            self.model.load_state_dict(checkpoint['state_dict'] if 'state_dict' in checkpoint else checkpoint)
            self.model.to(self.device)
            self.model.eval()
        else:
            raise NotImplementedError("Only RoFormer model type is supported in this version.")

    def demix(self, mix):
        samples = mix.shape[-1]
        margin = self.args["margin"]
        chunk_size = self.args["chunks"] * 44100
        
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

        sources = self.demix_base(segmented_mix, margin_size=margin)
        return sources

    def demix_base(self, mixes, margin_size):
        sources = []
        progress_bar = tqdm(total=len(mixes))
        progress_bar.set_description("Processing")
        
        for mix in mixes:
            cmix = torch.tensor(mixes[mix], dtype=torch.float32).to(self.device)
            batch, channels, samples = cmix.shape

            # Multi-resolution STFT and mask estimation
            masks_multi = []
            for stft_params in self.stft_params:
                n_fft = stft_params["n_fft"]
                hop_length = stft_params["hop_length"]
                win_length = stft_params["win_length"]
                window = stft_params["window"]

                spec = torch.stft(
                    cmix.view(-1, samples),
                    n_fft=n_fft,
                    hop_length=hop_length,
                    window=window,
                    center=True,
                    return_complex=True
                )
                spec = spec.view(batch, channels, *spec.shape[-2:])

                with torch.no_grad():
                    mag = torch.abs(spec)
                    phase = torch.angle(spec)
                    mag = mag.unsqueeze(-1)

                    if self.args["denoise"]:
                        mag_pos = mag
                        mag_neg = -mag
                        masks_pos = self.model(mag_pos)
                        masks_neg = self.model(mag_neg)
                        masks = (masks_pos + masks_neg) * 0.5
                    else:
                        masks = self.model(mag)

                    masks = masks.squeeze(-1)
                    masks_multi.append((masks, spec, mag, phase, n_fft, hop_length, win_length, window))

            # Combine multi-resolution masks and reconstruct
            tar_signal = None
            for masks, spec, mag, phase, n_fft, hop_length, win_length, window in masks_multi:
                masked_spec = spec * masks
                masked_spec = torch.view_as_real(masked_spec)
                masked_spec = masked_spec.permute(0, 1, 4, 2, 3)
                masked_spec = masked_spec.reshape(-1, 2, masked_spec.shape[-2], masked_spec.shape[-1])

                signal = torch.istft(
                    torch.view_as_complex(masked_spec),
                    n_fft=n_fft,
                    hop_length=hop_length,
                    window=window,
                    center=True,
                    length=samples
                )
                signal = signal.view(batch, channels, -1)

                if tar_signal is None:
                    tar_signal = signal
                else:
                    tar_signal += signal

            tar_signal = tar_signal / len(self.multi_stft_resolutions)

            start = 0 if mix == 0 else margin_size
            end = None if mix == list(mixes.keys())[::-1][0] else -margin_size
            if margin_size == 0:
                end = None

            sources.append(tar_signal.cpu().numpy()[:, :, start:end])
            progress_bar.update(1)

        _sources = np.concatenate(sources, axis=-1)
        progress_bar.close()

        # Handle single-stem output ("No Drum-Bass") and map to vocals/instrumental
        if self.num_stems == 1:
            # Assume "No Drum-Bass" is the vocals stem
            vocals = _sources[0]  # Shape: (channels, samples)
            instrumental = mixes[list(mixes.keys())[0]][0] - vocals  # Subtract vocals from mix
            _sources = np.stack([instrumental, vocals], axis=0)  # Shape: (2, channels, samples)

        return _sources

    def predict(self, file_path):
        mix, rate = librosa.load(file_path, mono=False, sr=44100)
        
        if mix.ndim == 1:
            mix = np.asfortranarray([mix, mix])
        
        mix = mix.T
        sources = self.demix(mix.T)
        
        if len(self.stems) == 2:
            mix_minus_vocals, vocals = sources[0].T, sources[1].T
            return (mix_minus_vocals, vocals, rate)
        else:
            stems = []
            num_stems = len(self.stems)
            for i in range(num_stems):
                stem = sources[i].T
                stems.append(stem)
            return stems, rate

def main():
    parser = ArgumentParser()
    
    parser.add_argument("--files", nargs="+", type=Path, required=True, help="Source audio paths (one or more)")
    parser.add_argument("-o", "--output", type=Path, default=Path("separated"), help="Output folder path")
    parser.add_argument("-m", "--model_path", type=Path, required=True, help="Model file path (.ckpt for RoFormer)")
    parser.add_argument("-c", "--config_path", type=Path, help="Config YAML path (required for RoFormer)")
    parser.add_argument("--model-type", type=str, choices=['roformer'], default='roformer', help="Model type (only roformer supported)")
    parser.add_argument("--stems", type=str, default="vocals,instrumental", help="Comma-separated list of stems to separate")
    parser.add_argument("-d", "--no-denoise", dest="denoise", action="store_false", default=True, help="Disable denoising")
    parser.add_argument("-M", "--margin", type=int, default=44100, help="Margin size in samples")
    parser.add_argument("-C", "--chunks", type=int, default=15, help="Chunk size in seconds")
    parser.add_argument("-F", "--n_fft", type=int, default=6144, help="Number of FFT bins (ignored if config provides STFT params)")
    parser.add_argument("-t", "--dim_t", type=int, default=8, help="Time dimension (ignored if config provides dim_t)")
    parser.add_argument("-f", "--dim_f", type=int, default=2048, help="Frequency dimension (ignored if config provides dim_f)")

    args = parser.parse_args()
    dict_args = vars(args)
    
    if args.model_type == 'roformer' and not args.config_path:
        raise ValueError("Config path (--config_path) is required for RoFormer models")
    
    os.makedirs(args.output, exist_ok=True)
    
    for file_path in args.files:  
        predictor = Predictor(args=dict_args)
        result = predictor.predict(file_path)
        
        filename = os.path.splitext(os.path.split(file_path)[-1])[0]
        if len(predictor.stems) == 2:
            mix_minus_vocals, vocals, sampling_rate = result
            sf.write(os.path.join(args.output, filename+"_no_vocals.wav"), mix_minus_vocals, sampling_rate)
            sf.write(os.path.join(args.output, filename+"_vocals.wav"), vocals, sampling_rate)
        else:
            stems, sampling_rate = result
            for i, stem_name in enumerate(predictor.stems):
                sf.write(os.path.join(args.output, filename+f"_{stem_name}.wav"), stems[i], sampling_rate)

if __name__ == "__main__":
    main()