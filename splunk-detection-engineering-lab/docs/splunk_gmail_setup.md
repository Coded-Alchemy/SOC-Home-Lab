# How to Configure Splunk to Send Email with Gmail

## 1. Enable Gmail App Password (Required)

Since Google blocks "less secure apps," you need an **App Password**:

1. Go to your Google Account → **Security**
2. Enable **2-Step Verification** (required for App Passwords)
3. Go to **Security → App Passwords**
4. Generate a new App Password (select "Mail" and your device)
5. Copy the 16-character password

---

## 2. Configure Splunk's Email Settings

### Via Splunk Web UI

1. Go to **Settings → Server Settings → Email Settings**
2. Fill in:
   - **Mail host:** `smtp.gmail.com:587`
   - **Email security:** `TLS`
   - **Username:** `your-email@gmail.com`
   - **Password:** *(paste the 16-char App Password)*
   - **From email:** `your-email@gmail.com`
3. Click **Save**

### Or Edit the Config File Directly

Edit `$SPLUNK_HOME/etc/system/local/alert_actions.conf`:

```ini
[email]
mailserver = smtp.gmail.com:587
use_ssl = 0
use_tls = 1
auth_username = your-email@gmail.com
auth_password = your-app-password-here
from = your-email@gmail.com
```

---

## 3. Test the Configuration

In Splunk Web, go to **Settings → Server Settings → Email Settings** and click **Send Test Email** to verify it works.

You can also test via CLI:

```bash
$SPLUNK_HOME/bin/splunk sendemail to="recipient@example.com" \
  subject="Test" body="Splunk email test"
```

---

## 4. Use in Alerts

When creating an alert, choose **Send Email** as the action. The configured Gmail account will be used as the sender.

---

## Common Issues

| Problem | Fix |
|---|---|
| Authentication failed | Double-check App Password (not your regular Gmail password) |
| Connection refused | Ensure port 587 is not blocked by your firewall |
| TLS errors | Try port 465 with `use_ssl = 1` instead |
| "Less secure app" error | App Password is required — regular password won't work |

> **Note:** If you're using **Google Workspace** (business Gmail), an admin may need to allow SMTP relay or create the App Password on your behalf.
