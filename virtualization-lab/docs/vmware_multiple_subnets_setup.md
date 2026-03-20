# How to Set Up Multiple Subnets in VMware Workstation / Fusion

## What Is a Subnet and Why Use Multiple?

A **subnet** (subnetwork) is a smaller, isolated network within a larger network. In VMware, each subnet is represented by a **virtual network (VMnet)**. Using multiple subnets lets you:

- Isolate different types of VMs (e.g., web servers vs. database servers)
- Simulate real-world multi-tier network architectures
- Test firewall rules and routing between networks
- Prevent VMs on one subnet from directly communicating with VMs on another

---

## Key Concepts

| Term | Meaning |
|------|---------|
| **VMnet** | A virtual network switch in VMware. Each VMnet is its own subnet. |
| **Host-only** | VMs can talk to each other and your host PC, but not the internet. |
| **NAT** | VMs share your host's internet connection (one VMnet for NAT). |
| **Bridged** | VMs appear as separate devices on your physical network. |
| **Subnet** | Defined by an IP range, e.g., `192.168.10.0/24` means IPs from `.1` to `.254`. |

> **Default VMnets:** VMware pre-creates VMnet0 (Bridged), VMnet1 (Host-only), and VMnet8 (NAT). You will create new ones for additional subnets.

---

## Part 1 — Open the Virtual Network Editor

### VMware Workstation (Windows/Linux)

1. Open VMware Workstation.
2. Click the **Edit** menu in the top menu bar.
3. Select **Virtual Network Editor**.
4. If prompted by a UAC (User Account Control) dialog, click **Yes** to allow admin access. The editor requires administrator privileges to make changes.

### VMware Fusion (macOS)

1. Open VMware Fusion.
2. Click **VMware Fusion** in the top menu bar.
3. Select **Preferences**.
4. Click the **Network** tab.
5. Click the **lock icon** at the bottom and enter your macOS password to unlock changes.

---

## Part 2 — Create The First New Subnet (e.g., Subnet A)

This example creates a **Host-only** subnet at `192.168.10.0/24`. Repeat these steps for each additional subnet needed.

### Step 1 — Add a New Virtual Network

**Workstation:**
1. In the Virtual Network Editor, click **Add Network** (bottom left).
2. Select an unused VMnet number from the dropdown — for example, **VMnet2**.
3. Click **OK**.

**Fusion:**
1. In the Network preferences panel, click the **+** button to add a new network.
2. VMware Fusion will assign the next available VMnet number automatically.

### Step 2 — Configure the Network Type

1. Select your newly created VMnet (e.g., VMnet2) in the list.
2. Under **Network Type**, select **Host-only**.
   - This keeps the subnet isolated to your host machine and VMs — a safe starting point.

### Step 3 — Set the Subnet IP Address and Mask

1. Look for the **Subnet IP** field and enter: `192.168.10.0`
2. In the **Subnet mask** field, enter: `255.255.255.0`
   - This gives you 254 usable IP addresses: `192.168.10.1` through `192.168.10.254`.

> **Tip:** Each VMnet must use a **unique** IP range. If VMnet1 uses `192.168.50.x`, your new VMnet2 must use a different range like `192.168.10.x`.

### Step 4 — Configure the DHCP Server (Optional but Recommended)

DHCP automatically assigns IP addresses to VMs on this subnet so you don't have to set them manually.

1. Check the box labelled **Use local DHCP service to distribute IP addresses to VMs**.
2. Click **DHCP Settings** to review or adjust the IP range.
   - **Start IP:** `192.168.10.128` (addresses below this can be reserved for static assignment)
   - **End IP:** `192.168.10.254`
3. Click **OK** to close the DHCP Settings dialog.

### Step 5 — Apply the Changes

1. Click **Apply** (Workstation) or close the panel (Fusion).
2. VMware will create the virtual network adapter for this subnet on your host machine.

---

## Part 3 — Create a Second Subnet (e.g., Subnet B)

Repeat Part 2 with different values:

| Setting | Subnet A (VMnet2) | Subnet B (VMnet3) |
|---------|-------------------|-------------------|
| VMnet | VMnet2 | VMnet3 |
| Type | Host-only | Host-only |
| Subnet IP | 192.168.10.0 | 192.168.20.0 |
| Subnet Mask | 255.255.255.0 | 255.255.255.0 |
| DHCP Range | .128 – .254 | .128 – .254 |

You can create as many subnets as you need (VMware supports up to VMnet19).

---

## Part 4 — Assign VMs to a Subnet

Each VM's **network adapter** must be set to the VMnet for the subnet you want it on.

### Step 1 — Open VM Settings

1. Right-click the VM in the VMware library panel.
2. Select **Settings** (Workstation) or **Virtual Machine Settings** (Fusion).

### Step 2 — Select the Network Adapter

1. In the settings window, click **Network Adapter** in the hardware list.

### Step 3 — Choose the Custom VMnet

1. Under **Network connection**, select **Custom: Specific virtual network**.
2. From the dropdown, choose the VMnet for the desired subnet:
   - **VMnet2** → Subnet A (`192.168.10.x`)
   - **VMnet3** → Subnet B (`192.168.20.x`)
3. Click **OK**.

### Step 4 — Add a Second Network Adapter (If a VM Needs to Be on Two Subnets)

Some VMs, like a **router** or **gateway VM**, need to sit on multiple subnets at once.

1. In VM Settings, click **Add** (bottom of the hardware list).
2. Select **Network Adapter** and click **Next** / **Finish**.
3. Assign this new adapter to a different VMnet (e.g., VMnet3).
4. The VM now has one foot in each subnet and can route traffic between them.

---

## Part 5 — Verify Connectivity

### Check the VM's IP Address

After powering on the VM:

**Linux VM:**
```bash
ip addr show
```
Look for an IP in the expected range (e.g., `192.168.10.x`).

**Windows VM:**
```cmd
ipconfig
```
Look for the Ethernet adapter showing the expected IP and subnet mask.

### Test Connectivity Between VMs on the Same Subnet

From VM1 (on VMnet2, e.g., `192.168.10.5`), ping VM2 (also on VMnet2, e.g., `192.168.10.6`):
```bash
ping 192.168.10.6
```
You should see replies. If not, check that both VMs are assigned to the same VMnet.

### Test That Subnets Are Isolated

From VM1 on VMnet2 (`192.168.10.x`), try to ping a VM on VMnet3 (`192.168.20.x`):
```bash
ping 192.168.20.5
```
This should **fail** (timeout or unreachable) — confirming the subnets are isolated from each other. If you want them to communicate, you need a router VM (see Part 4, Step 4).

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| VM gets no IP address | DHCP not enabled on the VMnet | Enable DHCP in Virtual Network Editor |
| VM gets an unexpected IP | Adapter assigned to wrong VMnet | Check VM Settings → Network Adapter |
| Two subnets can communicate | Both VMs on same VMnet | Confirm each is on its own VMnet |
| Virtual Network Editor is greyed out | Not running as administrator | Re-open VMware as admin (Windows) or unlock with password (Mac) |
| VMnet not visible in dropdown | Changes not applied | Click Apply in Virtual Network Editor |

---

## Summary

1. Open **Virtual Network Editor** (Workstation) or **Network Preferences** (Fusion).
2. **Add a new VMnet** for each subnet and assign it a unique IP range.
3. **Enable DHCP** on each VMnet for automatic IP assignment.
4. **Assign each VM** to the correct VMnet via its Network Adapter settings.
5. **Test** with ping to confirm isolation and connectivity.

Each VMnet is its own isolated subnet — VMs can only communicate across subnets if you introduce a VM configured as a router between them.
