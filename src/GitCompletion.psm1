$git = Get-Command git -ErrorAction Stop
$gitRoot = Split-Path -Parent (Split-Path -Parent $git.Source)

$bash = Join-Path $gitRoot 'bin\bash.exe'
$completion = Join-Path $gitRoot 'mingw64\share\git\completion\git-completion.bash'

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

Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $words = @(
        $commandAst.CommandElements | ForEach-Object ToString
    )

    if ($wordToComplete -eq '') {
        $words += ''
    }
    else {
        $words[-1] = $wordToComplete
    }

    $cword = $words.Count - 1
    $line = $commandAst.ToString()

    $output = $helperScript | & $bash -s -- `
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
