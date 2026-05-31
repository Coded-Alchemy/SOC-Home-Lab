# Troubleshooting

---

## No Internet To VMs

Depending on the order VMs are started, sometimes they dont have Internet access.

#### Fix
- Restart the Firewall

---

## Host <-> VM File sharing

The host machine and virtual machines can be set to share files. 
On Linux VM's some tweaks are needed:

In Linux with kernel prior to 4.0:
```commandline
mount -t vmhgfs .host:/ /home/user1/shares
```

In Linux with kernel 4.0 or newer:
```commandline
/usr/bin/vmhgfs-fuse .host:/ /home/user1/shares -o subtype=vmhgfs-fuse,allow_other
```
A file may need a line uncommented, the output will indicate this when this snippet is ran.