function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $Account,
        [parameter(Mandatory = $false)] [ValidateSet("Present","Absent")] [System.String] $Ensure = "Present",
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $InstallAccount,
        [parameter(Mandatory = $false)] [System.UInt32] $EmailNotification,
        [parameter(Mandatory = $false)] [System.UInt32] $PreExpireDays,
        [parameter(Mandatory = $false)] [System.String] $Schedule,
        [parameter(Mandatory = $true)]  [System.String] $AccountName
    )

    Write-Verbose -Message "Checking for managed account $AccountName"

    $result = Invoke-xSharePointCommand -Credential $InstallAccount -Arguments $PSBoundParameters -ScriptBlock {
        $params = $args[0]
        
        $ma = Get-SPManagedAccount -Identity $params.Account.UserName -ErrorAction SilentlyContinue
        if ($null -eq $ma) { return @{
            AccountName    = $params.AccountName
            Account        = $params.Account
            Ensure         = "Absent"
            InstallAccount = $params.InstallAccount
        } }
        $schedule = $null
        if ($ma.ChangeSchedule -ne $null) { $schedule = $ma.ChangeSchedule.ToString() }
        return @{
            AccountName       = $ma.Username
            EmailNotification = $ma.DaysBeforeChangeToEmail
            PreExpireDays     = $ma.DaysBeforeExpiryToChange
            Schedule          = $schedule
            Account           = $params.Account
            Ensure            = "Present"
            InstallAccount    = $params.InstallAccount
        }
    }
    return $result
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $Account,
        [parameter(Mandatory = $false)] [ValidateSet("Present","Absent")] [System.String] $Ensure = "Present",
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $InstallAccount,
        [parameter(Mandatory = $false)] [System.UInt32] $EmailNotification,
        [parameter(Mandatory = $false)] [System.UInt32] $PreExpireDays,
        [parameter(Mandatory = $false)] [System.String] $Schedule,
        [parameter(Mandatory = $true)]  [System.String] $AccountName
    )

    if ($Ensure -eq "Present" -and $Account -eq $null) {
        throw "You must specify the 'Account' property as a PSCredential to create a managed account"
        return
    }
    
    $currentValues = Get-TargetResource @PSBoundParameters
    if ($currentValues.Ensure -eq "Absent" -and $Ensure -eq "Present") {
        Write-Verbose "Managed account does not exist but should, creating the managed account"
        Invoke-xSharePointCommand -Credential $InstallAccount -Arguments $PSBoundParameters -ScriptBlock {
            $params = $args[0]
            New-SPManagedAccount -Credential $params.Account
        }
    }
    
    if ($Ensure -eq "Present") {
        Write-Verbose -Message "Updating settings for managed account"
        Invoke-xSharePointCommand -Credential $InstallAccount -Arguments $PSBoundParameters -ScriptBlock {
            $params = $args[0]
            
            $updateParams = @{ 
                Identity = $params.Account.UserName 
            }
            if ($params.ContainsKey("EmailNotification")) { $updateParams.Add("EmailNotification", $params.EmailNotification) }
            if ($params.ContainsKey("PreExpireDays")) { $updateParams.Add("PreExpireDays", $params.PreExpireDays) }
            if ($params.ContainsKey("Schedule")) { $updateParams.Add("Schedule", $params.Schedule) }

            Set-SPManagedAccount @updateParams
        }    
    } else {
        Write-Verbose -Message "Removing managed account"
        Invoke-xSharePointCommand -Credential $InstallAccount -Arguments $PSBoundParameters -ScriptBlock {
            $params = $args[0]
            Remove-SPManagedAccount -Identity $params.AccountName -Confirm:$false
        }
    }

    
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $Account,
        [parameter(Mandatory = $false)] [ValidateSet("Present","Absent")] [System.String] $Ensure = "Present",
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $InstallAccount,
        [parameter(Mandatory = $false)] [System.UInt32] $EmailNotification,
        [parameter(Mandatory = $false)] [System.UInt32] $PreExpireDays,
        [parameter(Mandatory = $false)] [System.String] $Schedule,
        [parameter(Mandatory = $true)]  [System.String] $AccountName
    )

    $CurrentValues = Get-TargetResource @PSBoundParameters
    Write-Verbose -Message "Testing managed account $AccountName"
    $PSBoundParameters.Ensure = $Ensure
    return Test-xSharePointSpecificParameters -CurrentValues $CurrentValues -DesiredValues $PSBoundParameters -ValuesToCheck @("AccountName", "Schedule","PreExpireDays","EmailNotification", "Ensure") 
}


Export-ModuleMember -Function *-TargetResource

