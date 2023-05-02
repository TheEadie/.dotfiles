function git
    if [ (string split "/mnt/c/" "$PWD" | wc -l) -eq 2 ]
        echo "Using git.exe as on Windows Filesystem"
        command git.exe $argv
    else
        echo "Using git as on WSL Filesystem"
        command git $argv
    end
end