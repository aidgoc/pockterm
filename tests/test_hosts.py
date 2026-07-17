import pockterm.hosts as hosts


class _Result:
    def __init__(self, code, out):
        self.returncode = code
        self.stdout = out


def test_lan_only_when_no_tailscale(monkeypatch):
    monkeypatch.setattr(hosts, "lan_ip", lambda: "192.168.1.5")

    def boom(*a, **k):
        raise FileNotFoundError()

    monkeypatch.setattr(hosts.subprocess, "run", boom)
    hs = hosts.reachable_hosts()
    assert len(hs) == 1
    assert hs[0].label == "LAN" and hs[0].ip == "192.168.1.5"


def test_tailscale_added_for_cgnat(monkeypatch):
    monkeypatch.setattr(hosts, "lan_ip", lambda: "192.168.1.5")
    monkeypatch.setattr(hosts.subprocess, "run",
                        lambda *a, **k: _Result(0, "100.100.100.100\n"))
    hs = hosts.reachable_hosts()
    assert any(h.label == "Tailscale" and h.ip == "100.100.100.100" for h in hs)


def test_non_cgnat_ip_ignored(monkeypatch):
    monkeypatch.setattr(hosts, "lan_ip", lambda: "192.168.1.5")
    monkeypatch.setattr(hosts.subprocess, "run",
                        lambda *a, **k: _Result(0, "10.0.0.5\n"))
    assert len(hosts.reachable_hosts()) == 1  # 10.x is not the tailnet range
