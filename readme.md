Personal script to set up a new server with Caddy, CrowdSec, firewall, rate limiting, `kopia` for backups, and some other QOL things.

CrowdSec should work out of the box with any service. It also supports Cloudflare proxying.

Rate limiting can be configured in [proxy/docker-compose.yml](proxy/docker-compose.yml). There is an existing snippet for rate limiting on WordPress websites. (You would use `- caddy_0.1_import=wordpress_rate_limit` in the labels section of the service.)

```bash
apt update && apt install gpg git unzip -y && git clone https://github.com/henrygd/server-setup --depth 1 /tmp/cs && /tmp/cs/setup.sh
```

**Notes:**

- You should only use ed25519 keys to connect to the server via SSH.
- The server runs Watchtower to keep containers up to date, so it's a good idea to use version tags to keep things from breaking.

## Reverse Proxy

We're using a custom Caddy image with [Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy).

### TLS

If a service is proxied through Cloudflare, use `caddy_0.tls=internal` with CF's "Strict" SSL setting.


## CrowdSec

CrowdSec is configured with [a Caddy bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer) to block malicious traffic at the proxy level.

It processes logs directly from Caddy, so should work with any service as long as it includes the proper label:

```yaml
labels:
  - caddy_0.0_import=crowdsec
```

### CrowdSec CLI

Use the `cscli` command to manage the crowdsec instance. Prefix with `docker exec crowdsec` to run it in the crowdsec container.

<https://docs.crowdsec.net/docs/cscli/>

#### Example commands

**Metrics**

```bash
docker exec crowdsec cscli metrics
```

**Ban / Unban IP**

```bash
# ban ip
docker exec crowdsec cscli decisions add --ip 1.2.3.4
# delete ban
docker exec crowdsec cscli decisions delete --ip 1.2.3.4
# ban range
docker exec crowdsec cscli decisions add --range 1.2.3.0/24
# customize length of ban (default is 4h)
docker exec crowdsec cscli decisions add --ip 1.2.3.4 --duration 1w
```

**List recent alerts**

```bash
docker exec crowdsec cscli alerts list -h
```

**List current bans**

```bash
docker exec crowdsec cscli decisions list
```

#### Manually adding a ban

```bash
docker exec crowdsec cscli decisions add --ip <ip>
```

## Firewall (UFW)

This setup uses UFW with [ufw-docker](https://github.com/chaifeng/ufw-docker).

The firewall is configured to allow HTTP (port 80), HTTPS (port 443), and SSH (your chosen port).

If you need to allow ingress on other ports, do this:

```bash
PORT=45876 && sudo ufw allow $PORT && sudo ufw route allow proto tcp from any to any port $PORT
```

If you need to block an IP range, do this, but be careful not to block Cloudflare IPs:

```bash
IP_RANGE="45.135.232.0/24" && sudo ufw prepend deny from $IP_RANGE && sudo ufw route prepend deny from $IP_RANGE
```

<!-- After making changes to UFW rules, you need to save them to persist across reboots:

```bash
sudo ufw save
``` -->
