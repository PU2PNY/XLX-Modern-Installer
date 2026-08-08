# XLX firewall ports: which ports to open on Debian 12

[🇧🇷 Versão em Português](FIREWALL-PORTAS-XLX.pt-BR.md) • [Back to documentation index](README.md)

This guide explains **which network ports an XLX server may use**, how to verify what is actually listening, and how to avoid exposing unnecessary services.

> Main rule: **open only the ports required by the protocols and features your reflector actually uses**.

## Common XLX ports

| Port | Transport | Typical use |
|---:|:---:|---|
| 22 | TCP | SSH administration |
| 80 | TCP | HTTP and certificate validation/renewal |
| 443 | TCP | HTTPS dashboard |
| 8080 | TCP | RepNet, when used |
| 20001-20005 | TCP/UDP | DPlus, depending on configuration |
| 40001 | TCP | Icom G3, when applicable |
| 8880 | UDP | DMR+ DMO |
| 10001 | UDP | XLXD JSON interface |
| 10002 | UDP | XLX interlink |
| 10100 | UDP | AMBE controller |
| 10101-10199 | UDP | AMBE transcoding |
| 12345-12346 | UDP | Icom Terminal presence/request |
| 21110 | UDP | Yaesu IMRS |
| 30001 | UDP | DExtra |
| 30051 | UDP | DCS |
| 40000 | UDP | Icom Terminal DV |
| 42000 | UDP | YSF, common/configurable value |
| 62030 | UDP | MMDVM/DMR |

Not every installation uses every port above. The real requirement depends on XLXD configuration, optional services and enabled protocols.

## Check what is actually listening

```bash
sudo ss -lntup
```

Filter common XLX-related processes:

```bash
sudo ss -lntup | grep -Ei 'xlx|apache|php|ssh'
```

## UFW

Inspect the current firewall before changing it:

```bash
sudo ufw status verbose
```

Do not blindly apply every port from a documentation table. Confirm which services are enabled and make sure administrative access remains available before changing firewall rules.

## NAT and port forwarding

If the server is behind NAT, CGNAT, a router or an external firewall, opening a port on Debian may not be enough. Verify:

1. reachable public IP;
2. port forwarding on the router/firewall;
3. VPS/provider firewall rules;
4. DNS pointing to the correct address;
5. local firewall rules;
6. a process actually listening on the expected port.

## Diagnose a specific port

Example for 62030/UDP:

```bash
sudo ss -lunp | grep ':62030'
```

Example for HTTPS:

```bash
sudo ss -lntp | grep ':443'
```

## Recommended troubleshooting order

```text
SERVICE → EXPECTED PORT → LISTENING PROCESS → LOCAL FIREWALL → EXTERNAL FIREWALL/NAT → TEST
```

This prevents unnecessary changes and helps distinguish application failures from network filtering.

## Related documentation

- [Install XLX on Debian 12](INSTALL-XLX-DEBIAN-12.en.md)
- [Update and recover XLX](UPDATE-RECOVER-XLX.en.md)
- [XLX files and logs](XLX-FILES-LOGS.en.md)
- [Post-installation tasks](XLX-POST-INSTALL.en.md)

## Related search terms

XLX firewall ports, XLXD ports, D-STAR reflector ports, DMR XLX port, YSF XLX port, Debian 12 amateur radio firewall, UFW XLXD, XLX reflector network ports.
