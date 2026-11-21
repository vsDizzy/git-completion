$git = Get-Command git -ErrorAction Stop

# Ask git itself where it is installed instead of deriving it from the path of
# git.exe: that path may be a shim (scoop, winget links), and the runtime
# prefix differs between Git for Windows builds (mingw64, ucrt64, clangarm64).
# --exec-path prints <root>/<prefix>/libexec/git-core.
$execPath = (& $git.Source --exec-path) -replace '/', '\'
$prefix = Split-Path -Parent (Split-Path -Parent $execPath)
$gitRoot = Split-Path -Parent $prefix

$bash = Join-Path $gitRoot 'bin\bash.exe'
$completion = Join-Path $prefix 'share\git\completion\git-completion.bash'

$helperScript = @'
source "$1"

shift
COMP_WORDS=()
COMP_CWORD=0
COMP_LINE=""
COMP_POINT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --words)
            shift
            COMP_WORDS=("$@")
            break
            ;;
        --cword)
            shift
            COMP_CWORD=$1
            shift
            ;;
        --line)
            shift
            COMP_LINE="$1"
            shift
            ;;
        --point)
            shift
            COMP_POINT=$1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

cur= words=() cword=0 prev=
_get_comp_words_by_ref -n =: cur words cword prev
__git_main
printf "%s\n" "${COMPREPLY[@]}"
'@

# bash reads the helper from a file. Piping it through stdin breaks in Windows
# PowerShell when the console code page is UTF-8: a BOM is prepended and bash
# fails on the first line.
$helperFile = Join-Path ([System.IO.Path]::GetTempPath()) 'GitCompletion-helper.sh'
$helperText = $helperScript -replace "`r`n", "`n"

if (-not (Test-Path -LiteralPath $helperFile) -or
    [System.IO.File]::ReadAllText($helperFile) -ne $helperText) {
    [System.IO.File]::WriteAllText($helperFile, $helperText)
}

# Windows PowerShell and PowerShell 7 in Legacy mode drop empty-string
# arguments to native commands, so the empty word being completed has to be
# passed as explicit quotes.
$emptyWord = if ((Get-Variable PSNativeCommandArgumentPassing -ValueOnly -ErrorAction Ignore) -in 'Standard', 'Windows') { '' } else { '""' }

Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $words = @(
        $commandAst.CommandElements | ForEach-Object ToString
    )

    if ($wordToComplete -eq '') {
        $words += $emptyWord
    }
    else {
        $words[-1] = $wordToComplete
    }

    $cword = $words.Count - 1
    $line = $commandAst.ToString()

    $output = & $bash $helperFile `
        $completion `
        --cword $cword `
        --line $line `
        --point $cursorPosition `
        --words @words `
        2>$null

    foreach ($candidate in $output) {
        if ($candidate) {
            [System.Management.Automation.CompletionResult]::new(
                $candidate,
                $candidate,
                [System.Management.Automation.CompletionResultType]::ParameterValue,
                $candidate
            )
        }
    }
}
