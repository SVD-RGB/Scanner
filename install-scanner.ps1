#Requires -Version 5.0
function Install-scanner {

    <#

        Function: Install-scanner
        Required Dependencies: powershell-yaml
        Optional Dependencies: None

    .PARAMETER DownloadPath

        Specifies the desired path to scanner.

    .PARAMETER InstallPath

        Specifies the desired path for where to install scanner.

    .PARAMETER Force

        Delete the existing InstallPath before installation if it exists.

    .EXAMPLE

        Install scanner
        PS> Install-scanner.ps1

    .NOTES

        Use the '-Verbose' option to print detailed information.

#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False, Position = 0)]
        [string]$InstallPath = $( if ($IsLinux -or $IsMacOS) { $Env:HOME + "/scanner" } else { $env:HOMEDRIVE + "\scanner" }),

        [Parameter(Mandatory = $False, Position = 1)]
        [string]$DownloadPath = $InstallPath,

        [Parameter(Mandatory = $False, Position = 2)]
        [string]$RepoOwner = "SVD-RGB",

        [Parameter(Mandatory = $False, Position = 3)]
        [string]$Branch = "master",

        [Parameter(Mandatory = $False, Position = 4)]
        [switch]$getTests = $True,

        [Parameter(Mandatory = $False)]
        [switch]$Force = $False, # delete the existing install directory and reinstall

        [Parameter(Mandatory = $False)]
        [switch]$NoPayloads = $False # only download yaml files during -getTests operation (no /src or /bin dirs)
    )
    Try {
        (New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

        $InstallPathwIart = Join-Path $InstallPath "invoke-scanner"
        $modulePath = Join-Path "$InstallPath" "invoke-scanner\Invoke-scanner.psd1"
        if ($Force -or -Not (Test-Path -Path $InstallPathwIart )) {
            write-verbose "Directory Creation"
            if ($Force) {
                Try {
                    if (Test-Path $InstallPathwIart) { Remove-Item -Path $InstallPathwIart -Recurse -Force -ErrorAction Stop | Out-Null }
                }
                Catch {
                    Write-Host -ForegroundColor Red $_.Exception.Message
                    return
                }
            }
            if (-not (Test-Path $InstallPath)) { New-Item -ItemType directory -Path $InstallPath | Out-Null }

            $url = "https://github.com/$RepoOwner/Scanner/archive/$Branch.zip"
            $path = Join-Path $DownloadPath "$Branch.zip"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            write-verbose "Beginning download from Github"
            Invoke-WebRequest $url -OutFile $path

            write-verbose "Extracting ART to $InstallPath"
            $zipDest = Join-Path "$DownloadPath" "tmp"
            Microsoft.PowerShell.Archive\Expand-Archive -LiteralPath $path -DestinationPath "$zipDest" -Force:$Force
            $iartFolderUnzipped = Join-Path $zipDest "scanner-$Branch"
            Move-Item $iartFolderUnzipped $InstallPathwIart
            Remove-Item $zipDest -Recurse -Force
            Remove-Item $path

            if (-not (Get-InstalledModule -Name "powershell-yaml" -ErrorAction:SilentlyContinue)) {
                write-verbose "Installing powershell-yaml"
                Install-Module -Name powershell-yaml -Scope CurrentUser -Force
            }

            write-verbose "Importing invoke-scanner module"
            Import-Module $modulePath -Force

            if ($getTests) {
                Write-Verbose "Installing Tests Folder"
                Invoke-Expression (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/SVD-RGB/Scanner/master/install-testsfolder.ps1"); Install-TestsFolder -InstallPath $InstallPath 
            }

            Write-Host "Installation of scanner is complete. You can now use the Invoke-scannerTest function" -Fore Yellow
        }
        else {
            Write-Host -ForegroundColor Yellow "scanner already exists at $InstallPathwIart. No changes were made."
            Write-Host -ForegroundColor Cyan "Try the install again with the '-Force' parameter if you want to delete the existing installion and re-install."
            Write-Host -ForegroundColor Red "Warning: All files within the install directory ($InstallPathwIart) will be deleted when using the '-Force' parameter."
        }
    }
    Catch {
        Write-Error "Installation of scanner Failed."
        Write-Host $_.Exception.Message`n
    }
}
