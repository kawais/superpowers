$ErrorActionPreference = "Stop"

# Configuration
$GEMINI_DIR = Join-Path $HOME ".gemini"
$SKILLS_LINK = Join-Path $GEMINI_DIR "skills"
$GEMINI_MD = Join-Path $GEMINI_DIR "GEMINI.md"
$REPO_SKILLS_DIR = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\skills"))

# Check if the repo skills directory actually exists
if (-not (Test-Path -Path $REPO_SKILLS_DIR -PathType Container)) {
    Write-Host "Error: Skills directory not found at $REPO_SKILLS_DIR"
    exit 1
}

# Ensure .gemini directory exists
if (-not (Test-Path -Path $GEMINI_DIR -PathType Container)) {
    Write-Host "Creating $GEMINI_DIR..."
    New-Item -ItemType Directory -Force -Path $GEMINI_DIR | Out-Null
}

# Link skills (Hub Pattern)
Write-Host "Linking skills from $REPO_SKILLS_DIR to $SKILLS_LINK..."

# Ensure skills directory exists as a directory
if (Test-Path -LiteralPath $SKILLS_LINK) {
    $item = Get-Item -LiteralPath $SKILLS_LINK -Force
    if ($item.LinkType -ne $null -or ($item.Attributes -match "ReparsePoint")) {
        Write-Host "Converting $SKILLS_LINK from symlink to directory..."
        Remove-Item -LiteralPath $SKILLS_LINK -Force
    }
    elseif (-not ($item -is [System.IO.DirectoryInfo])) {
        Write-Host "Error: $SKILLS_LINK exists but is not a directory."
        Write-Host "Please remove this file/link and try again:"
        Write-Host "  Remove-Item -LiteralPath `"$SKILLS_LINK`""
        exit 1
    }
}

if (-not (Test-Path -LiteralPath $SKILLS_LINK -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $SKILLS_LINK | Out-Null
}

# iterate through skills in the repo and symlink them individually
Get-ChildItem -Path $REPO_SKILLS_DIR -Directory | ForEach-Object {
    $skill_path = $_.FullName
    $skill_name = $_.Name
    $target_path = Join-Path $SKILLS_LINK $skill_name
    
    # Safety check: Only replace if it's a symlink or doesn't exist
    if (Test-Path -LiteralPath $target_path) {
        $target_item = Get-Item -LiteralPath $target_path -Force
        if ($target_item.LinkType -ne $null -or ($target_item.Attributes -match "ReparsePoint")) {
            Remove-Item -LiteralPath $target_path -Force
        }
        else {
            Write-Host "Warning: $target_path exists and is not a symlink. Skipping to protect user data."
            return # 'continue' in ForEach-Object
        }
    }
    
    # Create the symbolic link
    New-Item -ItemType SymbolicLink -Path $target_path -Target $skill_path -Force | Out-Null
    Write-Host "  - Linked $skill_name"
}

# Context Injection Block
$CONTEXT_HEADER = "<!-- SUPERPOWERS-CONTEXT-START -->"
$CONTEXT_FOOTER = "<!-- SUPERPOWERS-CONTEXT-END -->"

$CONTEXT_BLOCK = @"
$CONTEXT_HEADER
# Superpowers Configuration

You have been granted Superpowers. These are specialized skills located in ``~/.gemini/skills``.

## Skill Discovery & Usage
- **ALWAYS** check for relevant skills in ``~/.gemini/skills`` before starting a task.
- If a skill applies (e.g., "brainstorming", "testing"), you **MUST** follow it.
- To "use" a skill, read its content and follow the instructions.

## Terminology Mapping (Bootstrap)
The skills were originally written for Claude Code. You will interpret them as follows:
- **"Claude"** or **"Claude Code"** -> **"Gemini"** (You).
- **"Task" tool** -> **Sequential Execution**. You do not have parallel sub-agents yet. Perform tasks sequentially yourself.
- **"Skill" tool** -> **ReadFile**. To "invoke" a skill, read the markdown file at ``~/.gemini/skills/<skill-name>/SKILL.md``.

$CONTEXT_FOOTER
"@

# Update GEMINI.md
if (-not (Test-Path -LiteralPath $GEMINI_MD -PathType Leaf)) {
    Write-Host "Creating $GEMINI_MD..."
    New-Item -ItemType File -Force -Path $GEMINI_MD | Out-Null
}

$fileContent = Get-Content -LiteralPath $GEMINI_MD -Raw
if ($null -eq $fileContent) { $fileContent = "" }

# Remove existing context block if present (idempotent update)
if ($fileContent -match [regex]::Escape($CONTEXT_HEADER)) {
    Write-Host "Updating Superpowers context in $GEMINI_MD..."
    $escapedHeader = [regex]::Escape($CONTEXT_HEADER)
    $escapedFooter = [regex]::Escape($CONTEXT_FOOTER)
    # Use Regex to replace the multiline block
    $pattern = '(?sm)' + $escapedHeader + '.*?' + $escapedFooter + '\r?\n?'
    $fileContent = $fileContent -replace $pattern, ""
}
else {
    Write-Host "Injecting Superpowers context into $GEMINI_MD..."
}

# Trim trailing whitespace from the file to prevent accumulation of blank lines
$fileContent = $fileContent.TrimEnd()

# Append the current/updated block with exactly one newline separator
if ($fileContent -ne "") {
    $newContent = $fileContent + "`r`n`r`n" + $CONTEXT_BLOCK + "`r`n"
}
else {
    $newContent = $CONTEXT_BLOCK + "`r`n"
}

Set-Content -LiteralPath $GEMINI_MD -Value $newContent -NoNewline

Write-Host "Installation complete! Restart your session to activate Superpowers."
Write-Host "Try asking: 'Do you have superpowers?'"
