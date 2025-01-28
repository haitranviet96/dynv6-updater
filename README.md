# Dynv6 DDNS Updater

A shell script to automatically update Dynv6 dynamic DNS (DDNS) records with your current public IP address.

## Prerequisites

1. **Dynv6 Account**: A Dynv6 account with a hosted zone and DNS record to update.
2. **API Token**: Obtain your Dynv6 API token from the [Dynv6 Dashboard](https://dynv6.com/).
3. **Bash**: Ensure Bash is installed (most Unix-like systems include it by default).

## Setup

### 1. Clone the Repository
```bash
git clone https://github.com/haitranviet96/dynv6-updater.git
cd dynv6-updater
```

2. Configure the .env File
Copy the .env.template file to .env and update it with your credentials:

```bash
cp .env.template .env
nano .env
```

Replace the placeholder values:

```sh
# .env
DYNV6_TOKEN="your_dynv6_api_token"
DYNV6_ZONE="your_domain.dynv6.net"
```

### 3. Make the Script Executable

```sh
chmod +x update_ddns.sh
```

### 4. Test the Script

Run manually to verify functionality:

```sh
./update_ddns.sh
```

Automation with Cron
--------------------

Schedule the script to run every 30 minutes:

1.  Open your crontab:

```sh
    crontab -e
```

2.  Add this line (adjust paths if needed):

```sh
    */30 * * * * $HOME/scripts/dynv6/update_ddns.sh >> $HOME/scripts/dynv6/update_ddns.log 2>&1
```

Explain:

- Runs every 30 minutes.

- Logs output to `update_ddns.log`.

Script Structure (update_ddns.sh)
---------------------------------

The script loads variables from the `.env` file:

```bash
#!/bin/bash

# Load environment variables
source "$(dirname "$0")/.env"

# Fetch current public IPv4/IPv6
# ... (script logic using $DYNV6_TOKEN and $DYNV6_ZONE)
```

Monitoring Logs
---------------

View real-time logs with `tail`:

```sh
tail -f $HOME/scripts/dynv6/update_ddns.log
```

Troubleshooting
---------------

-   **Permissions**: Ensure the script is executable (`chmod +x update_ddns.sh`).

-   **Cron Issues**: Check cron logs via `journalctl -u cron` or `/var/log/syslog`.

-   **DNS Failures**: Verify your token and domain in `update_ddns.sh`.

Security Note
-------------

❗ Never commit sensitive data like API tokens to version control.

License
-------

[MIT License](https://chat.deepseek.com/a/chat/s/LICENSE)