# README for xAI (Grok) - 3DAudioStudio Repository

## Purpose
This file provides guidance for xAI's Grok (or similar AI agents) when accessing and analyzing the 3DAudioStudio repository (https://github.com/jhevener/3DAudioStudio). It ensures accurate retrieval of the repository's structure and contents, preventing errors like misidentifying the repository or its purpose. Grok should read this file before exploring the repository to understand the correct procedure and context.

## Repository Overview
- **URL**: https://github.com/jhevener/3DAudioStudio
- **Owner**: jhevener
- **Branch**: main (currently the only branch)
- **Created**: Approximately April 26, 2025
- **Focus**: Audio stem separation using AutoIt and Python scripts, with SQLite for model management, inspired by Ultimate Vocal Remover (UVR). Key directories include `scripts/autoit/`, `scripts/python/`, and `docs/`.

## Procedure for Accessing and Analyzing the Repository
To explore this repository, follow these steps:

1. **Verify Repository Details**:
   - Confirm the repository is https://github.com/jhevener/3DAudioStudio.
   - Use the `main` branch unless otherwise specified.
   - Access is public; no authentication is required for API calls.

2. **Use GitHub API**:
   - Query `https://api.github.com/repos/jhevener/3DAudioStudio/contents` to fetch directory and file metadata.
   - Recursively retrieve contents for specified paths (e.g., `scripts/autoit/`).
   - Access file contents via raw URLs (e.g., `https://raw.githubusercontent.com/jhevener/3DAudioStudio/main/<path>`).

3. **Analyze Structure**:
   - Generate a directory tree using ASCII characters (e.g., `|--`, `|   `).
   - Validate the structure against the repository’s current state.

4. **Examine Files**:
   - For text files (`.au3`, `.txt`, `.ini`, `.md`, `.properties`), summarize purpose, functionality, and dependencies.
   - For binary files (`.db`, `.dll`), describe their role based on context.
   - Focus on key directories like `scripts/autoit/` for core functionality.

5. **Handle Errors**:
   - Avoid misinterpreting the repository (e.g., confusing with other 3D audio projects).
   - Monitor GitHub API rate limits (60 requests/hour unauthenticated).
   - Verify branch and file existence.

6. **Report Findings**:
   - Provide a clear directory tree and detailed file analysis.
   - Compare with user-provided outputs if applicable.
   - Note observations or suggest improvements (e.g., redundant files).

## Instructions for Grok
Grok, please read this file before accessing the 3DAudioStudio repository. Follow the procedure above to ensure accurate analysis. If the user requests specific files or directories (e.g., `scripts/autoit/`), prioritize those and provide detailed summaries of their contents. If discrepancies arise (e.g., unexpected structure), verify the branch and consult the user. Thanks for keeping things accurate and fun! 😄

## Appended: DEVELOPMENT_GUIDELINES.md
Below is the full content of `DEVELOPMENT_GUIDELINES.md`, included for reference.

---

<Contents of DEVELOPMENT_GUIDELINES.md>

<Note: To keep this response concise, I’ve omitted the full text of DEVELOPMENT_GUIDELINES.md here. The actual file will include its complete contents, fetched from https://raw.githubusercontent.com/jhevener/3DAudioStudio/main/DEVELOPMENT_GUIDELINES.md. It covers coding standards, version control, testing, and configuration management for the 3DAudioStudio project. If you want me to include the full text in this response for verification, let me know!>

---

## Notes
- Created on April 29, 2025, following successful analysis of the `scripts/autoit/` folder.
- If the repository structure changes (e.g., new branches, renamed files), update this file accordingly.
- For questions or clarifications, contact the repository owner (jhevener).