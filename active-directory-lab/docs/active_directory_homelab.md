# Active Directory Virtualized Home Lab Setup Guide

## Prerequisites

### Hardware Requirements
- **CPU:** Modern multi-core processor (Intel i5/i7 or AMD Ryzen 5/7+)
- **RAM:** 16GB minimum (32GB recommended)
- **Storage:** 100GB+ free disk space (SSD preferred)

### Software Requirements

| Software | Purpose | Cost |
|---|---|---|
| VMware Workstation Pro | Hypervisor | Free (personal use) |
| VirtualBox | Hypervisor (alternative) | Free |
| Hyper-V | Hypervisor (Windows built-in) | Free (Win 10/11 Pro) |
| Windows Server 2019/2022 ISO | Domain Controller OS | Free 180-day eval |
| Windows 10/11 ISO | Client VM OS | Free eval |

---

## Lab Topology

```
[Host Machine]
     |
     ├── DC01 (Windows Server 2022)   192.168.1.10
     │      └── Roles: AD DS, DNS, DHCP
     │
     ├── CLIENT01 (Windows 11)        192.168.1.20 (DHCP)
     │
     └── CLIENT02 (Optional)          192.168.1.21 (DHCP)
```

---

## Step 1: Install Hypervisor

Download and install one of the following:

- **VMware Workstation Pro** — Most feature-rich; free for personal use as of 2024
- **VirtualBox** — Fully free and open source; great for beginners
- **Hyper-V** — Built into Windows 10/11 Pro; enable via *Turn Windows features on or off*

---

## Step 2: Create the Domain Controller (DC) VM

### VM Specifications

| Setting | Value |
|---|---|
| OS | Windows Server 2022 (Desktop Experience) |
| vCPUs | 2–4 |
| RAM | 4GB |
| Disk | 60GB |
| Network | Host-Only or Internal |

### Setup Steps

1. Create a new VM in the hypervisor and attach the Windows Server ISO
2. Install Windows Server — choose **Desktop Experience** for a GUI
3. After install, set a **static IP address**:
   - IP: `192.168.1.10`
   - Subnet: `255.255.255.0`
   - Gateway: `192.168.1.1`
   - DNS: `127.0.0.1` (points to itself)
4. Rename the computer to `DC01`:
   - Right-click **Start** → **System** → **Rename this PC**
   - Restart when prompted

---

## Step 3: Install Active Directory Domain Services (AD DS)

1. Open **Server Manager** → **Add Roles and Features**
2. Click **Next** through the wizard until *Server Roles*
3. Check **Active Directory Domain Services** → click **Add Features**
4. Continue clicking **Next** → **Install**
5. After installation, click the **flag notification** in Server Manager
6. Click **Promote this server to a domain controller**

### Domain Controller Promotion Wizard

| Option | Value |
|---|---|
| Deployment operation | Add a new forest |
| Root domain name | `lab.local` |
| Forest/Domain functional level | Windows Server 2016 (or latest) |
| DSRM password | Set a strong password (save it!) |

7. Accept all other defaults → click **Install**
8. The server will **automatically restart**

---

## Step 4: Verify Active Directory is Working

After reboot, log in as `LAB\Administrator`.

### Verify AD

Open **Server Manager** → **Tools** → **Active Directory Users and Computers (ADUC)**

You should see the domain tree with default OUs (Users, Computers, etc.).

### Verify DNS

Open **Command Prompt** and run:

```cmd
nslookup lab.local
```

Expected output: The DC's IP address (`192.168.1.10`). If DNS fails, AD will not function correctly.

---

## Step 5: Add a Client VM (Windows 10/11)

### VM Specifications

| Setting | Value |
|---|---|
| OS | Windows 10 or 11 |
| vCPUs | 2 |
| RAM | 4GB |
| Disk | 50GB |
| Network | Same as DC (Host-Only or Internal) |

### Setup Steps

1. Install Windows 10/11 on the VM
2. Set the **DNS server** to point to your DC:
   - Open **Network Adapter Settings** → **IPv4 Properties**
   - Preferred DNS: `192.168.1.10`
3. Join the domain:
   - **Settings** → **System** → **About** → **Domain or workgroup** → **Change**
   - Select **Domain** and enter `lab.local`
   - Enter domain admin credentials when prompted
4. Restart the VM

### Verify Domain Join

Log in with: `LAB\Administrator` (or any domain user you create)

---

## Step 6: Configure VM Networking

### Recommended Network Setup

```
Host Machine
    │
    ├── Host-Only Adapter (192.168.1.x)
    │       ├── DC01 — Static: 192.168.1.10
    │       ├── CLIENT01 — DHCP: 192.168.1.20
    │       └── CLIENT02 — DHCP: 192.168.1.21
    │
    └── NAT Adapter (on DC01 only — for Windows Updates)
```

- Use **Host-Only** or **Internal** networking so VMs talk to each other without exposing the lab to the internet
- Add a **NAT adapter** to DC01 only if you need internet access for Windows Updates

---

## Step 7: Populate The Lab

Once the domain is running, explore these core AD features:

### Organizational Units (OUs)
Organize users and computers logically. Example structure:

```
lab.local
├── IT
│   ├── Workstations
│   └── Servers
├── HR
│   └── Users
└── Finance
    └── Users
```

Create in ADUC: Right-click domain → **New** → **Organizational Unit**

### Users and Groups
- Create test users: ADUC → Right-click OU → **New** → **User**
- Create security groups: Right-click OU → **New** → **Group**
- Add users to groups for access control testing

### Group Policy Objects (GPOs)
Push settings to machines/users across the domain.

1. Open **Group Policy Management** (Server Manager → Tools)
2. Right-click an OU → **Create a GPO in this domain and link it here**
3. Edit the GPO to configure settings (wallpaper, drive maps, software, etc.)

### Add DHCP Role (Optional)
Automatically assign IPs to client VMs:

1. Server Manager → **Add Roles and Features** → **DHCP Server**
2. After install: **Tools** → **DHCP**
3. Create a new scope (e.g., `192.168.1.20` – `192.168.1.100`)
4. Set the DNS server option to `192.168.1.10`

---

## Step 8: Take Snapshots

> **Always snapshot before making major changes.**

This is one of the biggest advantages of a virtualized lab — instant rollback.

| Snapshot | When to Take |
|---|---|
| `DC01 - Fresh Install` | After AD promotion |
| `DC01 - Base Config` | After DNS, DHCP, initial GPOs |
| `CLIENT01 - Domain Joined` | After joining the domain |
| `Lab - Working Baseline` | When everything is working |

---

## Next Steps & Ideas

- **AD Replication** — Add a second DC (`DC02`) and replicate the domain
- **Read-Only Domain Controller (RODC)** — Simulate a branch office scenario
- **Active Directory Certificate Services (AD CS)** — Issue internal SSL certs
- **File Server with Permissions** — Practice NTFS and share permissions
- **Attack & Defense** — Simulate AD attacks (BloodHound, Mimikatz) in an isolated environment
- **Azure AD Connect** — Sync your on-prem AD to an Azure free-tier tenant

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Client can't find domain | Verify DNS on client points to DC (`192.168.1.10`) |
| `nslookup lab.local` fails | Restart DNS Server service on DC; check forwarders |
| Can't log in after domain join | Use `LAB\Administrator` format, not just `Administrator` |
| VMs can't ping each other | Verify both VMs are on the same virtual network adapter |
| AD DS install fails | Ensure static IP is set and computer is renamed before promoting |
