# README for xAI (Grok) - 3DAudioStudio Repository

#Number 1 Rule: NO ASSUMPTIONS, EVER, ALWAYS ASK FRETZCAPO
#Number 2 Rule: Always Include Entire "Parts" #Region/#EndRegion Including the Existing Three Line Comment Headers Preceding Them
#Number 3 Rule: Always Follow Rule 1 and 2

#Purpose
This file provides guidance for xAI's Grok (or similar AI agents) when accessing, analyzing, and modifying scripts in the 3DAudioStudio repository (https://github.com/jhevener/3DAudioStudio). It ensures accurate retrieval of the repository's structure and contents, prevents errors like misidentifying the repository or its purpose, and establishes best practices for coding, troubleshooting, and script modification, especially for AutoIt scripts. Grok should read this file at the start of every coding session to understand the correct procedure, context, and best practices.
Repository Overview
URL: https://github.com/jhevener/3DAudioStudio

Owner: jhevener

Branch: main

Created: Approximately April 26, 2025

#Focus: Audio stem separation using AutoIt and Python scripts, with SQLite for model management, inspired by Ultimate Vocal Remover (UVR). Key directories include scripts/autoit/, scripts/python/, and docs/.

Procedure for Accessing and Analyzing the Repository
To explore this repository, follow these steps:
Verify Repository Details:
Confirm the repository is https://github.com/jhevener/3DAudioStudio.

Use the main branch unless otherwise specified.

Access is public; no authentication is required for API calls.

Use GitHub API:
Query https://api.github.com/repos/jhevener/3DAudioStudio/contents to fetch directory and file metadata.

Recursively retrieve contents for specified paths (e.g., scripts/autoit/).

Access file contents via raw URLs (e.g., https://raw.githubusercontent.com/jhevener/3DAudioStudio/main/<path>).

Analyze Structure:
Generate a directory tree using ASCII characters (e.g., |--, |   ).

Validate the structure against the repository’s current state.

Examine Files:
For text files (.au3, .txt, .ini, .md, .properties), summarize purpose, functionality, and dependencies.

For binary files (.db, .dll), describe their role based on context.

Focus on key directories like scripts/autoit/ for core functionality.

Handle Errors:
Avoid misinterpreting the repository (e.g., confusing with other 3D audio projects).

Monitor GitHub API rate limits (60 requests/hour unauthenticated).

Verify branch and file existence.

Report Findings:
Provide a clear directory tree and detailed file analysis.

Compare with user-provided outputs if applicable.

Note observations or suggest improvements (e.g., redundant files).

#Coding Session Guidelines for Grok

Grok, please follow these guidelines at the start of every coding session to ensure accurate analysis, effective troubleshooting, and high-quality script modifications:
#1. Verify Code Line Counts Accurately
To prevent misinterpreting code line counts, always verify scripts in Notepad++ or a similar editor that preserves all lines, including blank lines and comments, as displayed to humans. Copy code directly from provided sources (e.g., task focus documents or threads) using the web interface’s copy button, paste into Notepad++, and confirm the exact line count matches the user’s reported count (e.g., 237 lines) before proceeding. Cross-check with the original formatting to ensure no lines are stripped or misinterpreted, and clarify with the user if discrepancies arise.
#2. Cross-Verify File Content for Consistency
To ensure accurate file analysis and avoid discrepancies, always cross-verify the file's content by directly accessing the raw version from the repository (e.g., https://raw.githubusercontent.com/jhevener/3DAudioStudio/main/) and compare it with the user-provided context, such as screenshots or reported line counts (e.g., 338 lines in SciTE), using a reliable editor like Notepad++ to confirm the exact line count, including all blank lines and comments, before reporting any results.
#3. Troubleshoot Edited Scripts Proactively, Especially for AutoIt
To avoid unnecessary back-and-forth and premature testing, always troubleshoot an edited script immediately after modification by validating all inputs, file paths, and data structures (e.g., ensuring arrays are non-empty and complete), verifying syntax, and implementing comprehensive error handling with user-friendly feedback (e.g., console logging, file logging, and MsgBox for critical failures in AutoIt). This prevents issues like missing files, invalid parameters, or logical errors early, avoiding runtime failures that require iterative debugging. This is especially critical for AutoIt scripts, as Grok is more experienced in other languages and AutoIt has unique syntax and conventions (e.g., using / for division instead of \, ensuring constants like $STDERR_MERGED are defined in AutoItConstants.au3). Consult the AutoIt help file (available in the AutoIt installation or online at https://www.autoitscript.com/autoit3/docs/) religiously for syntax, constants, and function references, and use SciTE output to debug errors during compilation and runtime.
#4. Best Practices for Script Modification and Compatibility
When modifying scripts, especially those interacting with external programs (e.g., calling separate.py from AutoIt in the 3DAudioStudio project), ensure compatibility by aligning command-line arguments with the target script’s expectations (e.g., verify argument names, types, and defaults in separate.py’s argparse setup). Handle platform-specific issues, such as quoting file paths with spaces in Windows commands (e.g., "C:\Path With Spaces\file.wav"), and validate file existence before execution (e.g., check for Python executable and script paths). For AutoIt, double-check GUI element positioning to avoid overlap and ensure user inputs (e.g., integers for chunks or margin) are validated before use to prevent downstream errors in external scripts.
#5. Coding Session Checklist
Before starting any coding task, follow this checklist to set the stage for success:
Confirm the task focus and relevant files (e.g., TestModelsIniGUI_1.1.au3, separate.py) from the user or task focus document (e.g., docs/task-focus/task-focus-050225-0756.md in the 3DAudioStudio repository).

Verify all file paths (e.g., INI files, Python scripts, executables) exist and are accessible, logging errors if not.

Check for external dependencies (e.g., Python 3.9+, libraries like librosa, torch, and model files like UVR_MDXNET_1_420k.pth) as specified in the task focus document, and validate their availability.

For AutoIt scripts, ensure all includes (e.g., AutoItConstants.au3) cover required constants and functions, and cross-reference with the AutoIt help file.

Review the script’s logic for edge cases (e.g., empty arrays, invalid user inputs) and add error handling where needed.

After editing, troubleshoot the script as per guideline 3 before delivering it to the user for testing.

6. Resources and Tools
AutoIt Help File: Use the AutoIt help file (https://www.autoitscript.com/autoit3/docs/) for syntax, functions, and constants reference, especially for AutoIt-specific conventions.

SciTE Editor: Leverage SciTE’s output pane for compilation errors (via AU3Check) and runtime logs to debug issues quickly.

Notepad++: Use for line count verification and raw file content checks to ensure accuracy.

Repository Access: Always fetch raw file content from repositories (e.g., https://raw.githubusercontent.com/jhevener/3DAudioStudio/main/) to avoid discrepancies in file versions or formatting.

3DAudioStudio Task Focus: Refer to the task focus document (e.g., docs/task-focus/task-focus-050225-0756.md) for project-specific details, including dependencies (e.g., Python version, required libraries), testing plans, and notes on error handling and logging.

DEVELOPMENT_GUIDELINES.md: Consult DEVELOPMENT_GUIDELINES.md (located at https://raw.githubusercontent.com/jhevener/3DAudioStudio/main/DEVELOPMENT_GUIDELINES.md) for coding standards, version control, testing, and configuration management guidelines specific to the 3DAudioStudio project.

#Instructions for Grok
Grok, please read this file before accessing or working on the 3DAudioStudio repository. Follow the procedure above to ensure accurate analysis of the repository’s structure and contents. If the user requests specific files or directories (e.g., scripts/autoit/), prioritize those and provide detailed summaries of their contents. If discrepancies arise (e.g., unexpected structure), verify the branch and consult the user. Before starting any coding task, follow the Coding Session Guidelines to ensure a robust approach to script modification and troubleshooting. Thanks for keeping things accurate and fun! 

