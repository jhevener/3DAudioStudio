# 3D Audio Studio

A powerful audio processing tool for separating and playing audio stems using advanced models like UVR, Spleeter, and Demucs. Built with AutoIt and Python, this project aims to deliver high-quality audio separation and playback for enthusiasts and professionals.

## Features
- Separate audio into stems (vocals, instruments, etc.) using UVR, Spleeter, or Demucs.
- Play separated audio with BASS library integration.
- Manage audio models and settings via SQLite database.
- Cross-platform scripts in AutoIt and Python.

## Prerequisites
- **Windows**: Tested on Windows 11.
- **AutoIt**: For running `.au3` scripts (https://www.autoitscript.com/site/autoit/downloads/).
- **Python 3.9+**: For Python scripts (https://www.python.org/downloads/).
- **Dependencies**:
  - BASS library (DLLs and UDFs in `AutoIt/AudioWizard/`).
  - SQLite (`sqlite3_x64.dll` in `AutoIt/AudioWizard/`).
  - UVR/Spleeter/Demucs models (place in `installs/` folder, excluded from Git).

## Setup
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/jhevener/3DAudioStudio.git
   cd 3DAudioStudio