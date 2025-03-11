param (
    [string]$target,
    [string]$link
)

New-Item -ItemType SymbolicLink -Path $link -Target $target
