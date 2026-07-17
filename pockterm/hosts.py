import ipaddress
import subprocess
from dataclasses import dataclass

from pockterm.pairing import lan_ip

_CGNAT = ipaddress.ip_network("100.64.0.0/10")


@dataclass
class Host:
    label: str
    ip: str


def _tailscale_ip() -> str | None:
    try:
        result = subprocess.run(["tailscale", "ip", "-4"],
                                capture_output=True, text=True, timeout=3)
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    for token in result.stdout.split():
        try:
            addr = ipaddress.ip_address(token.strip())
        except ValueError:
            continue
        if addr in _CGNAT:
            return str(addr)
    return None


def reachable_hosts() -> list[Host]:
    hosts = [Host("LAN", lan_ip())]
    ts = _tailscale_ip()
    if ts:
        hosts.append(Host("Tailscale", ts))
    return hosts
