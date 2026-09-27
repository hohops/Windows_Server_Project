# Windows Server Project

## Purpose:

Build a understanding of **Active Directory**, including **user provisioning**, **Group Policy management**, and **DNS/DHCP** configuration in a closed virtual lab.

## OS

*Windows Server 2022*
 
 
 
## Software Used

*Oracle VirtualBox*

 
 
## Virtual Machines

**2** virtual machines were used for this project, 1 for *Windows Server* (to act as the server) and 1 *Windows 11* (to act as a client machine)


### Config:

**Windows Server**
**CPU**: *AMD Ryzen 7 7730U with Radeon Graphics* (Using 6 cores);

**RAM**: ~5GB (Available);

**Storage**: 50GB available (20GB used);

**Windows 11**

**CPU**: *AMD Ryzen 7 7730U with Radeon Graphics* (Using 2 cores);

**RAM**: ~4GB (Available);

**Storage**: 80GB available (24GB used);


**Both** VMs had 2 network adapters, *Internal Network Adapter* and a NAT Adapter (*Network Address Translation*)

# Structure

### Departments:

IT, Sales, HR, Engineering, Finance, Marketing, Legal

### Users

For each Department there is 1 User. 

Ramon M. Stacy - IT

Edwardo J. Briggs - Sales

Kristyn J. Boren - HR

John L. Pritchett - Engineering

Chris L. Cortez - Finance

Carla J. Thomas - Marketing

Carolee J. Horton - Legal





## Problems I had

"_msdcs, _sites, _tcp, and _udp" folders **missing** in the DNS foward lookup zones. That problem didnt let me connect in an other VM to the Domain Controller. To fix this in the type of the domain I had to enable " Store the zone in Active Directory ...".

