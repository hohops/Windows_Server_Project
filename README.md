# Windows Server & Active Directory Lab

## 1. Project Overview
*   **Purpose:** Build an understanding of Active Directory, including user provisioning, Group Policy management, and DNS/DHCP configuration in a closed virtual lab environment.
*   **Hypervisor:** Oracle VirtualBox
*   **Operating Systems:** Windows Server 2022 (Server), Windows 11 (Client)

## 2. Virtual Machine Specifications

| Role | Hostname | OS | CPU | RAM | Storage | Network Adapters |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Server / DC** | `EDU-DC1` | Windows Server 2022 | AMD Ryzen 7 7730U (6 Cores) | ~5 GB | 50 GB Total (20 GB Used) | 1x Internal, 1x NAT |
| **Client** | `Win11-PC1` | Windows 11 | AMD Ryzen 7 7730U (2 Cores) | ~4 GB | 80 GB Total (24 GB Used) | 1x Internal, 1x NAT |

## 3. Network & Domain Configuration
*   **Domain Name:** `hohops.com`
*   **Server Static IP:** `192.168.10.10`
*   **Subnet Mask:** `255.255.255.0`
*   **DNS Server:** `127.0.0.1` (Loopback)
*   **Installed Roles:** Active Directory Domain Services (AD DS), DNS, DHCP

## 4. Active Directory Structure

**Organizational Units (OUs) & Security Groups:** 
A dedicated OU and Security Group were created for each of the following departments: IT, Sales, HR, Engineering, Finance, Marketing, Legal.

**Provisioned Users:**
*   **IT:** Ramon M. Stacy
*   **Sales:** Edwardo J. Briggs
*   **HR:** Kristyn J. Boren
*   **Engineering:** John L. Pritchett
*   **Finance:** Chris L. Cortez
*   **Marketing:** Carla J. Thomas
*   **Legal:** Carolee J. Horton

**Group Policy Objects (GPOs):**
The following GPOs are linked and enabled at the `hohops.com` domain level:
*   Default Domain Policy
*   Control Panel
*   Command prompt
*   Deny all removable storage access

![Active Directory OUs and Groups](docs/OU_ScreenShot.png)

## 5. Troubleshooting & Lessons Learned

**Issue:** Unable to join the Windows 11 client VM (`Win11-PC1`) to the domain. Upon inspection of the DNS Manager on the server, the standard Active Directory folders (`_msdcs`, `_sites`, `_tcp`, and `_udp`) were missing from the Forward Lookup Zones.

**Resolution:** The DNS zone was not properly integrated with Active Directory. To resolve this, the domain zone properties were modified to enable **"Store the zone in Active Directory"**. This regenerated the missing SRV records and allowed the client VM to successfully discover the Domain Controller (`EDU-DC1`) and join the domain.
