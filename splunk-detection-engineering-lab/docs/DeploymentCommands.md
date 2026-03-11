# Deployment Server Commands

Reload deployment configuration:
    ```/opt/splunk/bin/splunk reload deploy-server```

List connected deployment clients:
    ```/opt/splunk/bin/splunk list deploy-clients```

----

# Forwarder Commands

Verify deployment server connection:
    ```/opt/splunkforwarder/bin/splunk list deploy-poll```

Force forwarder to check for new apps:
    ```/opt/splunkforwarder/bin/splunk reload deploy-client```

Restart forwarder:
    ```/opt/splunkforwarder/bin/splunk restart```