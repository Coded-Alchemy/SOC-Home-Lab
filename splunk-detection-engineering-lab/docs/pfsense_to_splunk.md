# How to Send pfSense Logs to Splunk

## 1. Configure Splunk to Receive Syslog

**Create a UDP Data Input in Splunk:**

- Go to **Settings → Data Inputs → UDP**
- Click **New Local UDP**
- Set port to **514** (or another port like 5514 if 514 requires root)
- Set Source type to `syslog` or create a custom one like `pfsense`
- Optionally assign to an index (e.g., `pfsense`)

---

## 2. Configure pfSense to Send Logs

In pfSense, go to **Status → System Logs → Settings:**

- Check **Enable Remote Logging**
- Set **Remote log servers** to your Splunk server IP and port (e.g., `192.168.1.10:514`)
- Select which log content to forward (Firewall events, DHCP, VPN, etc.)
- Protocol: **UDP** (standard) or TCP if you prefer

---

## 3. Improve Parsing with a Splunk Add-on

Install the **Splunk Add-on for pfSense** from Splunkbase:

- Search for "pfSense" on [splunkbase.splunk.com](https://splunkbase.splunk.com)
- It provides pre-built field extractions, CIM mapping, and dashboards
- After installing, set the sourcetype to `pfsense` in your data input

---

## 4. Verify Logs Are Arriving

In Splunk Search:

```spl
index=* sourcetype=pfsense
```

or

```spl
index=pfsense earliest=-15m
```

---

## Tips

- **Firewall logs** are the most valuable — make sure "Firewall Events" is checked in pfSense
- Use a **dedicated index** (`index=pfsense`) to keep things organized and control retention
- If using **Splunk Universal Forwarder**, you can instead write pfSense logs to a file and forward from there, but direct syslog UDP is simpler
- For **TLS/encrypted** log forwarding, use a syslog relay (like `syslog-ng` or `rsyslog`) between pfSense and Splunk, since pfSense's built-in remote logging doesn't support TLS natively

---

> Most environments are sending logs within 5–10 minutes of configuration.
