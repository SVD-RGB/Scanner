function Install-TestsFolder {

    <#
    .SYNOPSIS

        This is a simple script to download the atttack definitions.
        Required Dependencies: powershell-yaml
        Optional Dependencies: None

    .PARAMETER DownloadPath

        Specifies the desired path to download atomics zip archive to.

    .PARAMETER InstallPath

        Specifies the desired path for where to unzip the atomics folder.

    .PARAMETER Force

        Delete the existing atomics folder before installation if it exists.


    .NOTES

        Use the '-Verbose' option to print detailed information.

#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False, Position = 0)]
        [string]$InstallPath = $( if ($IsLinux -or $IsMacOS) { $Env:HOME + "/Scanner" } else { $env:HOMEDRIVE + "\Scanner" }),

        [Parameter(Mandatory = $False, Position = 1)]
        [string]$DownloadPath = $InstallPath,

        [Parameter(Mandatory = $False, Position = 2)]
        [string]$RepoOwner = "redcanaryco",

        [Parameter(Mandatory = $False, Position = 3)]
        [string]$Branch = "master",

        [Parameter(Mandatory = $False)]
        [switch]$Force = $False, # delete the existing install directory and reinstall

        [Parameter(Mandatory = $False)]
        [switch]$NoPayloads = $False
    )
    Try {
        $InstallPathwAtomics = Join-Path $InstallPath "tests"
        if ($Force -or -Not (Test-Path -Path $InstallPathwAtomics )) {
            write-verbose "Directory Creation"
            if ($Force) {
                Try {
                    if ((Test-Path $InstallPathwAtomics) -and (-not $NoPayloads)) { Remove-Item -Path $InstallPathwAtomics -Recurse -Force -ErrorAction Stop | Out-Null }
                }
                Catch {
                    Write-Host -ForegroundColor Red $_.Exception.Message
                    return
                }
            }
            if (-not (Test-Path $InstallPath)) { New-Item -ItemType directory -Path $InstallPath | Out-Null }

            $url = "https://github.com/$RepoOwner/atomic-red-team/archive/$Branch.zip"
            $path = Join-Path $DownloadPath "$Branch.zip"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            write-verbose "Beginning download of tests folder from Github"

            # disable progress bar for faster performances
            $ProgressPreference_backup = $global:ProgressPreference
            $global:ProgressPreference = "SilentlyContinue"

            if ($NoPayloads) {
                # download zip to memory and only extract atomic yaml files
                # load ZIP methods
                Write-Host -ForegroundColor Yellow "Reading the repo into a memory stream. This could take up to 3 minutes."
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression') | Out-Null

                # read github zip archive into memory
                $ms = New-Object IO.MemoryStream
                [Net.ServicePointManager]::SecurityProtocol = ([Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12)

                Add-Type -AssemblyName System.Net.Http
                $httpClient = New-Object System.Net.Http.HttpClient
                $httpClient.Timeout = New-Object System.TimeSpan(0, 3, 0)
                $response = $httpClient.GetAsync($url).Result
                $response.Content.CopyToAsync($ms).Wait()
                $zip = New-Object System.IO.Compression.ZipArchive($ms)

                $Filter = '*.yaml'

                # ensure the output folder exists
                $exists = Test-Path -Path $InstallPathwAtomics
                if ($exists -eq $false) {
                    $null = New-Item -Path $InstallPathwAtomics -ItemType Directory -Force
                }

                # find all files in ZIP that match the filter (i.e. file extension)
                $zip.Entries |
                Where-Object {
                        ($_.FullName -like $Filter) `
                        -and (($_.FullName | split-path | split-path -Leaf) -eq [System.IO.Path]::GetFileNameWithoutExtension($_.Name)) `
                        -and ($_.FullName | split-path | split-path | split-path -Leaf) -eq "atomics"
                } |
                ForEach-Object {
                    # extract the selected items from the ZIP archive
                    # and copy them to the out folder
                    $dstDir = Join-Path $InstallPathwAtomics ($_.FullName | split-path | split-path -Leaf)
                    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, (Join-Path $dstDir $_.Name), $true)
                }
                $zip.Dispose()
            }
            else {
                Invoke-WebRequest $url -OutFile $path

                write-verbose "Extracting ART to $InstallPath"
                $zipDest = Join-Path "$DownloadPath" "tmp"
                Microsoft.PowerShell.Archive\Expand-Archive -LiteralPath $path -DestinationPath "$zipDest" -Force:$Force
                $atomicsFolderUnzipped = Join-Path (Join-Path $zipDest "atomic-red-team-$Branch") "tests"
                Move-Item $atomicsFolderUnzipped $InstallPath
                Remove-Item $zipDest -Recurse -Force
                Remove-Item $path
            }

            # restore progress bar preferences
            $global:ProgressPreference = $ProgressPreference_backup
        }
        else {
            Write-Host -ForegroundColor Yellow "A folder already exists. No changes were made."
            Write-Host -ForegroundColor Cyan "Try the install again with the '-Force' parameter if you want to delete the existing installion and re-install."
            Write-Host -ForegroundColor Red "Warning: All files within the folder will be deleted when using the '-Force' parameter."
        }
    }
    Catch {
        Write-Error "Installation of the TestsFolder Failed."
        Write-Host $_.Exception.Message`n
    }
}
