# Enterprise Windows Server 2022 & Active Directory Architecture

An enterprise-grade Active Directory infrastructure project demonstrating centralized identity governance, role-based access control (RBAC) via the AGDLP framework, security baselines via Group Policy Objects (GPOs), and zero-touch PowerShell user provisioning.

---

## 1. Executive Summary & Topology

* **Domain Name:** `hohops.com`
* **Forest Functional Level:** Windows Server 2022
* **Primary Scope:** Identity and Access Management (IAM), Group Policy delegation, high availability DNS/DHCP, and secure lifecycle automation.

### Network & Infrastructure Architecture

```
                                  +-----------------------+
                                  |   External Gateway    |
                                  |     192.168.10.1      |
                                  +-----------+-----------+
                                              |
                        +---------------------+---------------------+
                        |                                           |
              +---------v---------+                       +---------v---------+
              |      EDU-DC1      |                       |      EDU-DC2      |
              |  Primary DC / DNS | <== AD Replication ==>| Secondary DC / DNS|
              |   192.168.10.10   |                       |   192.168.10.11   |
              +---------+---------+                       +---------+---------+
                        |   ^                                   ^   |
                        |   |======= DHCP Failover (80/20) =====|   |
                        |                                           |
                        +---------------------+---------------------+
                                              |
                                     +--------v--------+
                                     |   Win11-PC1     |
                                     | Corporate Client|
                                     | 192.168.10.100  |
                                     +-----------------+
```

---

## 2. Host & Network Specifications

| Hostname | Role | OS | IP Configuration | Compute Allocation |
| :--- | :--- | :--- | :--- | :--- |
| **EDU-DC1** | Primary Domain Controller, DNS, Authoritative NTP | Windows Server 2022 Datacenter | `192.168.10.10/24`<br>GW: `192.168.10.1`<br>DNS: `192.168.10.10`, `127.0.0.1` | 4 GB vRAM<br>2 vCPUs<br>50 GB VHD |
| **EDU-DC2** | Secondary Domain Controller, Replicated DNS/DHCP | Windows Server 2022 Datacenter | `192.168.10.11/24`<br>GW: `192.168.10.1`<br>DNS: `192.168.10.10`, `192.168.10.11` | 4 GB vRAM<br>2 vCPUs<br>50 GB VHD |
| **Win11-PC1** | Production Test Client | Windows 11 Enterprise | DHCP (`192.168.10.100` lease)<br>DNS: via DHCP Options `006` | 4 GB vRAM<br>2 vCPUs<br>80 GB VHD |

---

## 3. Directory Design & RBAC Framework

The directory layout adheres to enterprise administrative tiering principles. Standard user accounts, computers, administrative roles, and service accounts are isolated within distinct top-level Organizational Units (OUs).

### Organizational Unit Structure

```
hohops.com
├── Corporate
│   ├── Departments
│   │   ├── IT
│   │   ├── Engineering
│   │   ├── Finance
│   │   ├── HR
│   │   ├── Legal
│   │   ├── Marketing
│   │   └── Sales
│   └── Shared Resources
├── Workstations
├── Servers
└── Tiered_Administration
    ├── Admin_Tier0 (Domain/Forest Admins)
    ├── Admin_Tier1 (Server Admins)
    ├── Admin_Tier2 (Workstation Admins)
    └── Service_Accounts
```

### Access Control Strategy (AGDLP Framework)
To prevent privilege sprawl, permissions are assigned strictly using the **AGDLP** model:
* **A**ccounts are nested into...
* **G**lobal Groups (e.g., `GG_Finance_Users`), which are nested into...
* **D**omain **L**ocal Groups (e.g., `DL_Share_Finance_Modify`), which receive the actual...
* **P**ermissions on file resources and endpoints.

---

## 4. Group Policy Objects (GPOs) & Baseline Hardening

GPO links are scoped to targeted OUs rather than the root domain to maintain operational stability and prevent administrative lockout.

| GPO Name | Target OU | Enforced Settings | Objective |
| :--- | :--- | :--- | :--- |
| **GPO_Workstation_Hardening** | `OU=Workstations` | • Disable NTLMv1<br>• Enforce SMBv3 signing<br>• Screen lock after 15 min idle | Mitigates pass-the-hash and unauthorized console access |
| **GPO_User_AppControl** | `OU=Departments` | • Disable Command Prompt (`cmd.exe`)<br>• Restrict native Control Panel/Settings | Prevents non-privileged script execution and manual config changes |
| **GPO_RemovableStorage_Lockdown** | `OU=Departments` | • Deny read/write access to all Removable Storage classes | Prevents corporate data exfiltration via USB storage |

### Exception & Delegation Handling
* **Operational Challenge:** Key executives and select technicians require access to external drives for legal and compliance transfers without lifting domain-wide restrictions.
* **Implementation:** 
  1. Configured an Active Directory Security Group named `SG_Bypass_RemovableStorage`.
  2. Modified the security filtering of `GPO_RemovableStorage_Lockdown` under the **Delegation** tab.
  3. Added an explicit **Deny** ACE on the `Apply group policy` permission for `SG_Bypass_RemovableStorage`.
  4. Non-member users continue to receive the restriction, while authorized members bypass the policy cleanly without requiring manual GPO overrides.

---

## 5. Automated User Onboarding Pipeline

Manual account creation is replaced with a modular PowerShell onboarding script with structured logging, cryptographic temporary password generation, input sanitization, and automatic departmental group binding.

### `Bulk-UserCreation.ps1`

```powershell
<#
.SYNOPSIS
    Automated Active Directory bulk user provisioning utility.
.DESCRIPTION
    Ingests an employee CSV file, validates schema, generates randomized
    temporary credentials, assigns departmental OUs/groups, and outputs structured logs.
.NOTES
    Author: Cruz / hohops
    Domain: hohops.com
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath = ".\employees.csv",

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs\AD_Provisioning.log"
)

# Ensure logging directory exists
$logDir = Split-Path -Path $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")][string]$Severity = "INFO"
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] [$Severity] $Message"
    Add-Content -Path $LogPath -Value $logEntry
    Write-Host $logEntry -ForegroundColor $(
        switch ($Severity) {
            "INFO"  { "Cyan" }
            "WARN"  { "Yellow" }
            "ERROR" { "Red" }
        }
    )
}

function Get-SecureTempPassword {
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $length = 16
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] $length
    $rng.GetBytes($bytes)
    $password = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    return (ConvertTo-SecureString -String $password -AsPlainText -Force)
}

Write-Log "Starting automated user provisioning from: $CsvPath"

try {
    $employees = Import-Csv -Path $CsvPath -ErrorAction Stop
}
catch {
    Write-Log "Failed to parse CSV file: $($_.Exception.Message)" -Severity "ERROR"
    exit 1
}

$domain = "hohops.com"
$baseOU = "DC=hohops,DC=com"

foreach ($user in $employees) {
    try {
        # Validate critical fields
        if ([string]::IsNullOrWhiteSpace($user.FirstName) -or 
            [string]::IsNullOrWhiteSpace($user.LastName) -or 
            [string]::IsNullOrWhiteSpace($user.Department)) {
            Write-Log "Skipping invalid row: Missing mandatory fields for record: $($user | Out-String)" -Severity "WARN"
            continue
        }

        $sAMAccountName = "$($user.FirstName.ToLower().Substring(0,1))$($user.LastName.ToLower())"
        $userPrincipalName = "$sAMAccountName@$domain"
        $displayName = "$($user.FirstName) $($user.LastName)"
        $targetOU = "OU=$($user.Department),OU=Departments,OU=Corporate,$baseOU"

        # Check if target OU exists
        if (-not [adsi]::Exists("LDAP://$targetOU")) {
            Write-Log "Target OU not found: $targetOU. Creating OU..." -Severity "WARN"
            New-ADOrganizationalUnit -Name $user.Department -Path "OU=Departments,OU=Corporate,$baseOU"
        }

        # Check if identity already exists
        if (Get-ADUser -Filter "sAMAccountName -eq '$sAMAccountName'" -ErrorAction SilentlyContinue) {
            Write-Log "Skipping duplicate user: $sAMAccountName already exists." -Severity "WARN"
            continue
        }

        $securePassword = Get-SecureTempPassword

        # Account creation
        $newAdUserParams = @{
            SamAccountName        = $sAMAccountName
            UserPrincipalName     = $userPrincipalName
            Name                  = $displayName
            GivenName             = $user.FirstName
            Surname               = $user.LastName
            DisplayName           = $displayName
            Department            = $user.Department
            Title                 = $user.Title
            Path                  = $targetOU
            AccountPassword       = $securePassword
            Enabled               = $true
            ChangePasswordAtLogon = $true
            CannotChangePassword  = $false
        }

        New-ADUser @newAdUserParams -ErrorAction Stop
        Write-Log "Successfully provisioned user account: $userPrincipalName in $targetOU"

        # Departmental group assignment
        $deptGroup = "GG_$($user.Department)_Users"
        if (Get-ADGroup -Filter "Name -eq '$deptGroup'" -ErrorAction SilentlyContinue) {
            Add-ADGroupMember -Identity $deptGroup -Members $sAMAccountName -ErrorAction Stop
            Write-Log "Assigned $sAMAccountName to security group $deptGroup"
        }
    }
    catch {
        Write-Log "Failed to provision user $($user.FirstName) $($user.LastName): $($_.Exception.Message)" -Severity "ERROR"
    }
}

Write-Log "User provisioning lifecycle completed."
```

### Sample CSV Input (`employees.csv`)

```csv
FirstName,LastName,Department,Title
Ramon,Stacy,IT,Systems Administrator
Edwardo,Briggs,Sales,Account Executive
Kristyn,Boren,HR,HR Coordinator
John,Pritchett,Engineering,Software Engineer
Chris,Cortez,Finance,Financial Analyst
Carla,Thomas,Marketing,Marketing Lead
Carolee,Horton,Legal,Compliance Auditor
```

---

## 6. Engineering Post-Mortem & Troubleshooting

### Incident 1: DNS SRV Lookup Failure During Domain Join
* **Symptom:** Client `Win11-PC1` failed to join the domain with the error: *"An Active Directory Domain Controller (AD DC) for the domain 'hohops.com' could not be contacted."*
* **Root Cause:** The DNS Forward Lookup Zone on `EDU-DC1` was initially provisioned as a standard file-backed zone rather than an Active Directory-Integrated zone. Consequently, dynamic SRV registration records (`_msdcs`, `_sites`, `_tcp`, `_udp`) were never created.
* **Remediation:**
  1. Opened DNS Manager and adjusted zone properties to convert the lookup zone to **Active Directory-Integrated**.
  2. Set dynamic updates to **Secure Only**.
  3. Restarted the Netlogon service on the Domain Controller to register the missing records:
     ```powershell
     Restart-Service -Name Netlogon
     ```
  4. Verified record presence via `nslookup`:
     ```cmd
     nslookup -type=srv _ldap._tcp.dc._msdcs.hohops.com
     ```
  5. Successfully joined `Win11-PC1` to the domain and rebooted.

### Incident 2: Kerberos Ticket Authentication Failure (Time Skew)
* **Symptom:** Domain authentication and GPO downloads intermittently failed across endpoints with Kerberos errors (`KRB_AP_ERR_SKEW`).
* **Root Cause:** Client VM time drifted more than the allowable Kerberos default threshold (5 minutes / 300 seconds) relative to the primary Domain Controller.
* **Remediation:**
  1. Designated `EDU-DC1` as the authoritative NTP clock for the forest:
     ```cmd
     w32tm /config /manualpeerlist:"pool.ntp.org" /syncfromflags:manual /reliable:yes /update
     w32tm /resync /rediscover
     ```
  2. Directed client workstations to pull time hierarchy dynamically from the DC via Group Policy.

---

## 7. CV-Ready Accomplishment Statements

* *Engineered a multi-tier Active Directory environment (Windows Server 2022) featuring AGDLP role-based access control, departmental OUs, and tiered administrative boundaries.*
* *Designed and deployed modular Group Policy baselines (SMBv3 signing, NTLMv1 deprecation, and USB isolation) utilizing security-filtered delegation exceptions.*
* *Built an automated PowerShell onboarding pipeline with input schema validation, dynamic OU targeting, randomized credential generation, and structured audit logging.*
* *Diagnosed and resolved critical directory infrastructure issues, including repairing DNS SRV locator records and authoritative NTP domain synchronization.*
