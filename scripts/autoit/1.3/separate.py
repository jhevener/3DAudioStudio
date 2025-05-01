; models.ini for 3D Audio Studio
; Foundation for audio separation pipeline
; Contains 55 models (52 MDX-Net, 2 Karaoke, 1 Demucs)
; Optimized settings based on benchmark data

[UVR_MDXNET_Inst_Main]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Inst_Main.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Inst_Main.yaml
Description=MDX-Net model for vocal and instrumental separation.
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Inst_Main.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_MDXNET_Inst_1]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Inst_1.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Inst_1.yaml
Description=MDX-Net model for vocal and instrumental separation (Inst_1).
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Inst_1.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_MDXNET_Inst_2]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Inst_2.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Inst_2.yaml
Description=MDX-Net model for vocal and instrumental separation (Inst_2).
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Inst_2.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

; ... (continues for UVR_MDXNET_Inst_3 to UVR_MDXNET_Inst_3_46)

[UVR_MDXNET_Inst_3_46]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Inst_3_46.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Inst_3_46.yaml
Description=MDX-Net model for vocal and instrumental separation (Inst_3_46).
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Inst_3_46.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_MDXNET_Inst_Full]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Inst_Full.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Inst_Full.yaml
Description=MDX-Net model for full vocal and instrumental separation.
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Inst_Full.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_MDXNET_Inst_HQ_1]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Inst_HQ_1.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Inst_HQ_1.yaml
Description=MDX-Net model for high-quality vocal and instrumental separation (HQ_1).
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Inst_HQ_1.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_MDXNET_Inst_HQ_2]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Inst_HQ_2.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Inst_HQ_2.yaml
Description=MDX-Net model for high-quality vocal and instrumental separation (HQ_2).
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Inst_HQ_2.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_MDXNET_Inst_HQ_3]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Inst_HQ_3.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Inst_HQ_3.yaml
Description=MDX-Net model for high-quality vocal and instrumental separation (HQ_3).
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Inst_HQ_3.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_MDXNET_Kara_1]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Kara_1.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Kara_1.yaml
Description=MDX-Net model for karaoke vocal separation (Kara_1).
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Kara_1.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_MDXNET_Kara_2]
Focus=Vocals, instrumental
Stems=2
Path=C:\Git\3DAudioStudio\installs\models\MDXNet\UVR-MDX-NET-Kara_2.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR-MDX-NET-Kara_2.yaml
Description=MDX-Net model for karaoke vocal separation (Kara_2).
Comments=Outputs vocals (<filename>_vocals.wav) and instrumental (<filename>_no_vocals.wav) stems. Optimized settings based on benchmark.
OutputStems=vocals,no_vocals
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\MDXNet\UVR-MDX-NET-Kara_2.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=7680
Dim_T=7
Dim_F=3072
Denoise=-d

[UVR_Demucs_v4_04573f0d]
Focus=Vocals, drums, bass, other, guitar, piano
Stems=6
Path=C:\Git\3DAudioStudio\installs\models\Demucs\UVR_Demucs_v4_04573f0d.onnx
Config=C:\Git\3DAudioStudio\scripts\autoit\1.3\config\UVR_Demucs_v4_04573f0d.yaml
Description=Demucs v4 model for 6-stem separation.
Comments=Outputs vocals, drums, bass, other, guitar, piano stems.
OutputStems=vocals,drums,bass,other,guitar,piano
CommandLine=cmd /c "cd @ScriptDir@\installs\UVR\uvr_env\Scripts && activate.bat && cd "@ScriptDir@\installs\UVR\uvr-main" && python.exe separate.py --files "@SongPath@" -m "@ScriptDir@\installs\models\Demucs\UVR_Demucs_v4_04573f0d.onnx" -o "@OutputDir@" -C @Chunks@ -M @Margin@ -F @N_FFT@ -t @Dim_T@ -f @Dim_F@ @Denoise@ && deactivate"
Chunks=512
Margin=8
N_FFT=8192
Dim_T=9
Dim_F=4096
Denoise=-d