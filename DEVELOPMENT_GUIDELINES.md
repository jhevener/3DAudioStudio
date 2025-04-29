# Development Guidelines for 3DAudioStudio

This document outlines the guidelines for collaborating on the `3DAudioStudio` project, specifically for editing AutoIt scripts.

## Script Editing Guidelines

### Posting Edited Regions
When multiple edits are required in any script, follow these steps to ensure clarity and ease of application:

1. **Identify Affected Regions**:
   - The script is divided into numbered `#Region` blocks (e.g., `#Region Part1`, `#Region Part2`, etc.).
   - Identify the specific `#Region` block(s) that contain the lines needing edits based on Au3Check errors or runtime issues.

2. **Edit the Entire Region**:
   - Provide the complete `#Region` block (from `#Region` to `#EndRegion`) that contains the edits.
   - Include the comment header above the region (e.g., `;******************** Part 1 **********************`).
   - Apply all necessary fixes within that region, even if multiple lines are affected.

3. **Include a Comment Header**:
   - At the top of the edited region, add a comment header describing the purpose of the changes and the affected lines.
   - Example:
     ```
     ; Region: Part 1 - Directives, Includes, Globals, and Logging
     ; Purpose: Update includes and initialize BASS to support GUI and separation routines
     ; Changes:
     ; - Verified includes for GUI event handling (WindowsConstants.au3 already present)
     ; - Added BASS initialization after includes
     ; - Added logging for BASS initialization to diagnose script closing issue
     ```

4. **Provide the Code in a Block**:
   - Present the edited region in a code block (using triple backticks ```) for easy copy-pasting.
   - Example:
     ```
     ;******************** Part 1 **********************
     #Region Part1
     ; [Edited code here]
     #EndRegion Part1
     ```

5. **Pause for Confirmation**:
   - After presenting the edited region, pause and wait for confirmation before proceeding to the next region.
   - Include instructions for applying the changes and testing the script.

### Example Workflow
- **Scenario**: Au3Check reports errors on lines 263 and 320, which are in `#Region Part2`.
- **Action**:
  - Edit the entire `#Region Part2 #EndRegion` block.
  - Include a comment header explaining the changes.
  - Provide the updated region in a code block.
  - Pause for confirmation before moving to the next region.

## Applying Changes
1. Open `scripts/AutoIt/[SCRIPT] in SciTE.
2. Locate the specified `#Region` block in the script.
3. Replace the entire block with the provided edited version.
4. Save the file and test the script (e.g., run Au3Check or execute the script).
5. Confirm the changes and provide feedback.

## Additional Notes
- Always check the latest commit in the branch to ensure you’re working with the most recent version.
- Update `docs/task-focus/task-focus-042825-1.md` with Au3Check results and runtime observations after testing.