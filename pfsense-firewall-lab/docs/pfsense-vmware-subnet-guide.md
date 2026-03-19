# Connecting pfSense VM to VMware Workstation/Fusion Subnets

## Overview

This guide walks through setting up a pfSense VM as a virtual router/firewall within VMware Workstation or Fusion, connecting it to one or more VMware virtual subnets (VMnets). The end result is a pfSense instance that routes traffic between your VMware virtual networks and optionally out to the internet.

---

## Prerequisites

- VMware Workstation Pro or VMware Fusion (Pro recommended for full virtual network editor access)
- pfSense ISO downloaded from [https://www.pfsense.org/download/](https://www.pfsense.org/download/)
- Basic familiarity with VMware VM creation

---

## Step 1: Plan Your Network Layout

Before touching VMware, decide on your subnet layout. A typical setup looks like this:

| VMnet | Type | Purpose | Example Subnet |
|-------|------|---------|----------------|
| VMnet0 | Bridged | WAN — connects to physical network | DHCP from host |
| VMnet2 | Host-only | LAN — internal subnet A | 192.168.10.0/24 |
| VMnet3 | Host-only | OPT1 — internal subnet B | 192.168.20.0/24 |

> **Rule of thumb:** Use **Bridged** for WAN (gives pfSense a real IP on your physical network), and **Host-only** for each internal subnet you want pfSense to route between. Avoid NAT type VMnets for internal interfaces — pfSense handles NAT itself.

---

## Step 2: Create VMware Virtual Networks

### VMware Workstation (Windows/Linux)

1. Open **Edit → Virtual Network Editor** (run as Administrator on Windows).
2. Click **Add Network** and select an unused VMnet (e.g., `VMnet2`).
3. Set the type to **Host-only**.
4. **Uncheck** "Use local DHCP service" — pfSense will handle DHCP.
5. Set the **Subnet IP** (e.g., `192.168.10.0`) and **Subnet mask** (`255.255.255.0`).
6. Click **Apply**.
7. Repeat for each additional internal subnet (e.g., VMnet3 for `192.168.20.0/24`).

### VMware Fusion (macOS)

1. Open **VMware Fusion → Settings → Network**.
2. Click the **+** button to add a custom network.
3. Note the assigned name (e.g., `vmnet2`).
4. Disable the built-in DHCP for that network.
5. Repeat for additional subnets.

---

## Step 3: Create the pfSense VM

1. In VMware, select **Create a New Virtual Machine**.
2. Choose the pfSense ISO as the installer disc image.
3. Set the guest OS to **Other → FreeBSD 64-bit**.
4. Allocate resources:
   - **RAM:** 1 GB minimum (2 GB recommended)
   - **CPU:** 1–2 cores
   - **Disk:** 8–16 GB (thin provisioned is fine)
5. **Do not start the VM yet** — you need to configure the NICs first.

---

## Step 4: Add and Assign NICs to the pfSense VM

Each pfSense interface (WAN, LAN, OPT) needs its own virtual NIC, each connected to a different VMnet.

### Adding NICs

1. Open the VM's **Settings → Hardware**.
2. The default NIC is your **WAN**. Set its network connection to:
   - **Bridged** (to use your physical network as WAN), or
   - A specific VMnet if WAN is another virtual network.
3. Click **Add → Network Adapter** for the **LAN** interface:
   - Set the connection to your first internal VMnet (e.g., `VMnet2`).
4. Repeat step 3 for each additional subnet (OPT1, OPT2, etc.), assigning each to its own VMnet.

### NIC Summary Example

| VM NIC | VMnet | pfSense Interface | Role |
|--------|-------|-------------------|------|
| Network Adapter 1 | VMnet0 (Bridged) | em0 / vtnet0 | WAN |
| Network Adapter 2 | VMnet2 (Host-only) | em1 / vtnet1 | LAN |
| Network Adapter 3 | VMnet3 (Host-only) | em2 / vtnet2 | OPT1 |

> **Tip:** In pfSense, NICs are typically named `em0`, `em1`, etc. (Intel driver) or `vtnet0`, `vtnet1`, etc. (VirtIO). The order corresponds to the order NICs appear in the VM settings.

---

## Step 5: Install pfSense

1. Start the pfSense VM and boot from the ISO.
2. Accept the copyright notice and select **Install**.
3. Choose default keymap and **Auto (ZFS)** or **Auto (UFS)** partitioning.
4. Complete the installation and **reboot**.
5. Remove the ISO from the virtual CD drive before or after reboot.

---

## Step 6: Assign Interfaces in pfSense Console

After rebooting, pfSense displays the console menu.

1. Select **Option 1 — Assign Interfaces**.
2. When asked about VLANs, type `n` (no VLANs needed for this setup).
3. Assign interfaces when prompted:

   ```
   WAN interface:  em0    (or vtnet0)
   LAN interface:  em1    (or vtnet1)
   OPT1 interface: em2    (or vtnet2)   ← press Enter to finish if no more
   ```

4. Confirm the assignments.

---

## Step 7: Set Interface IP Addresses via Console

### Set LAN IP

1. Select **Option 2 — Set interface(s) IP address**.
2. Choose the **LAN** interface.
3. Enter the IP address for pfSense on that subnet (e.g., `192.168.10.1`).
4. Enter the subnet bit count (e.g., `24` for /24).
5. Press **Enter** to skip the upstream gateway (LAN has none).
6. Decline IPv6 if not needed.
7. Type `y` to enable the DHCP server on LAN and set a range (e.g., `192.168.10.100` – `192.168.10.200`).

### Set OPT1 IP (repeat for each additional interface)

1. Select **Option 2** again.
2. Choose **OPT1**.
3. Enter its IP on the corresponding subnet (e.g., `192.168.20.1`).
4. Enter `24` for the subnet mask.
5. Enable DHCP if desired.

---

## Step 8: Access the pfSense Web UI

From any VM connected to the LAN VMnet:

1. Open a browser and navigate to `https://192.168.10.1` (or whatever LAN IP you set).
2. Log in with the default credentials:
   - **Username:** `admin`
   - **Password:** `pfsense`
3. Complete the **Setup Wizard**:
   - Set hostname and DNS servers.
   - Configure WAN (DHCP is typical for a bridged WAN).
   - Confirm LAN IP.
   - Change the admin password.

---

## Step 9: Enable OPT Interfaces in the Web UI

Optional interfaces are disabled by default after assignment.

1. Go to **Interfaces → OPT1** (or the relevant interface).
2. Check **Enable Interface**.
3. Set **IPv4 Configuration Type** to `Static IPv4`.
4. Enter the IP address (e.g., `192.168.20.1`) and subnet mask (`/24`).
5. Click **Save**, then **Apply Changes**.
6. Repeat for any additional OPT interfaces.

---

## Step 10: Configure Firewall Rules for Inter-Subnet Routing

By default, pfSense blocks traffic between interfaces. Add rules to allow the traffic you need.

1. Go to **Firewall → Rules**.
2. Select the interface tab (e.g., **LAN** or **OPT1**).
3. Click **Add** to create a new rule:
   - **Action:** Pass
   - **Interface:** (the source interface, e.g., LAN)
   - **Protocol:** Any (or restrict as needed)
   - **Source:** LAN subnet
   - **Destination:** OPT1 subnet (e.g., `192.168.20.0/24`) — or `any` to allow all
4. Click **Save** and **Apply Changes**.
5. Repeat from the OPT1 tab to allow return traffic if needed.

> **Note:** The WAN interface blocks all unsolicited inbound traffic by default — this is the correct behavior. Only add WAN rules if you need inbound port forwarding.

---

## Verification Checklist

- [ ] VMware virtual networks created with correct subnets and DHCP disabled
- [ ] pfSense VM has one NIC per subnet, each mapped to the correct VMnet
- [ ] pfSense interfaces assigned and IPs set via console
- [ ] OPT interfaces enabled in the web UI
- [ ] Firewall rules permit traffic between desired subnets
- [ ] Test VMs can ping pfSense gateway IPs on their respective subnets
- [ ] Test VMs on different subnets can ping each other (if rules allow)

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Can't reach pfSense web UI | Wrong VMnet assigned to NIC | Verify VM NIC → VMnet mapping matches pfSense interface assignment |
| VMs on same VMnet can't get DHCP | VMware DHCP still enabled on VMnet | Disable VMware's built-in DHCP in Virtual Network Editor |
| Cross-subnet ping fails | Missing firewall rules | Add pass rules on both source and destination interface tabs |
| WAN has no internet | Bridged adapter not connected | Check host physical adapter is up; try switching to a different bridged adapter in VM settings |
| pfSense shows wrong NIC count | NIC added after installation | Shut down VM, add NIC, then reassign interfaces via console Option 1 |
