import configparser
import argparse
import os
import soundfile as sf
import logging
import sys
from datetime import datetime

# Setup logging
# Use absolute path relative to script location
script_dir = os.path.dirname(os.path.abspath(__file__))
log_dir = os.path.join(script_dir, '..', '..', '..', 'logs')  # scripts\autoit\1.3\logs
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, 'separation_log.txt')

# Ensure logging works even on early failure
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s Separation: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger()
logger.addHandler(logging.StreamHandler(sys.stdout))  # Also log to console

# Dummy Predictor class (replace with actual implementation)
class Predictor:
    def __init__(self, args):
        self.args = args
        logger.info("Predictor initialized with args: %s", args)

    def predict(self, file_path):
        logger.info("Predicting for file: %s", file_path)
        # Simulate prediction (replace with actual model inference)
        # This is a placeholder; replace with actual MDX-Net inference
        stems = {
            "vocals": [[0, 0], [1, 1]],  # Dummy data
            "no_vocals": [[0, 0], [1, 1]]
        }
        sampling_rate = 44100
        return stems, sampling_rate

def load_model_config(model_name):
    logger.info(f"Loading model config for {model_name}")
    config = configparser.ConfigParser()
    config_path = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'installs', 'models.ini')
    config.read(config_path)
    if model_name not in config:
        logger.error(f"Model {model_name} not found in models.ini at {config_path}")
        raise ValueError(f"Model {model_name} not found in models.ini")
    yaml_path = os.path.join(os.path.dirname(__file__), '..', 'Models', 'Config', f"{model_name}.yaml")
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
    return config[model_name]

def main():
    logger.info("Starting separation process")
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs='+', help="Source audio path")
    parser.add_argument("-o", "--output", required=True, help="Output folder")
    parser.add_argument("-m", "--model_path", required=True, help="MDX Net ONNX Model path")
    parser.add_argument("-d", "--denoise", action="store_true", help="Enable denoising")
    parser.add_argument("-M", "--margin", type=int, default=10, help="Margin")
    parser.add_argument("-c", "--chunks", type=int, default=512, help="Chunk size")
    parser.add_argument("-F", "--n_fft", type=int, default=6144, help="FFT size")
    parser.add_argument("-t", "--dim_t", type=int, default=256, help="Time dimension")
    parser.add_argument("-f", "--dim_f", type=int, default=2048, help="Frequency dimension")
    args = parser.parse_args()

    # Extract model name
    model_name = os.path.basename(args.model_path).rsplit(".", 1)[0]
    logger.info(f"Processing model: {model_name}")

    # Load config
    try:
        config = load_model_config(model_name)
    except Exception as e:
        logger.error(f"Failed to load config: {str(e)}")
        raise

    # Load parameters
    chunks = args.chunks if args.chunks != 512 else config.getint("Chunks", 512)
    margin = args.margin if args.margin != 10 else config.getint("Margin", 10)
    n_fft = args.n_fft if args.n_fft != 6144 else config.getint("N_FFT", 6144)
    dim_t = args.dim_t if args.dim_t != 256 else config.getint("Dim_T", 256)
    dim_f = args.dim_f if args.dim_f != 2048 else config.getint("Dim_F", 2048)
    denoise = args.denoise if args.denoise else (config.get("Denoise", "") == "--denoise")

    logger.info(f"Parameters: chunks={chunks}, margin={margin}, n_fft={n_fft}, dim_t={dim_t}, dim_f={dim_f}, denoise={denoise}")

    # Initialize predictor
    dict_args = {
        "chunks": chunks,
        "margin": margin,
        "n_fft": n_fft,
        "dim_t": dim_t,
        "dim_f": dim_f,
        "denoise": denoise
    }
    try:
        predictor = Predictor(args=dict_args)
        logger.info("Initialized predictor")
    except Exception as e:
        logger.error(f"Failed to initialize predictor: {str(e)}")
        raise

    # Process files
    for file_path in args.files:
        logger.info(f"Processing file: {file_path}")
        try:
            stems, sampling_rate = predictor.predict(file_path)
            filename = os.path.splitext(os.path.basename(file_path))[0]
            output_stems = config.get("OutputStems", "vocals,no_vocals").split(",")
            for stem_name in output_stems:
                stem_name = stem_name.strip()
                if stem_name not in stems:
                    logger.error(f"Stem {stem_name} not found in prediction output")
                    continue
                output_file = os.path.join(args.output, f"{filename}_{stem_name}.wav")
                sf.write(output_file, stems[stem_name], sampling_rate)
                logger.info(f"Generated stem: {output_file}")
        except Exception as e:
            logger.error(f"Failed to process {file_path}: {str(e)}")
            raise

if __name__ == "__main__":
    try:
        logger.info("Script started")
        main()
        logger.info("Script completed successfully")
    except Exception as e:
        logger.error(f"Separation failed: {str(e)}")
        raise