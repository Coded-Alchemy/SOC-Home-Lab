# Troubleshooting

## Common issues that prevent app deployment

- Hostname does not match server class whitelist.
- Deployment server not reloaded after configuration changes.
- Forwarder not connected to deployment server.
- App missing configuration files (empty apps will not deploy).
- Incorrect permissions on deployment-apps directory.

## Verification

On Linux forwarders:

    ```ls /opt/splunkforwarder/etc/apps```

On Windows forwarders:

    ```C:\Program Files\SplunkUniversalForwarder\etc\apps```

Expected apps:

TA_base_forwarder
TA_linux_logs
TA_windows_logs
TA_sysmon_logs