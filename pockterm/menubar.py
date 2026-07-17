import os
import socket
import subprocess
import threading

import uvicorn

from pockterm.__main__ import DEFAULT_PORT, build_runtime
from pockterm.hosts import reachable_hosts
from pockterm.pairing import qr_payload
from pockterm.qrimage import write_qr_png

STATE_DIR = os.path.expanduser("~/.pockterm")


class PocktermMenuBar:
    """A macOS menu-bar app that owns a threaded pockterm server and shows QRs.

    `rumps` is imported lazily so this module imports on any platform (tests,
    CI); only constructing the app requires rumps + a display.
    """

    def __init__(self, port: int | None = None):
        import rumps

        self._rumps = rumps
        self.port = port or int(os.environ.get("POCKTERM_PORT", DEFAULT_PORT))
        self.rt = build_runtime(port=self.port)
        self.name = socket.gethostname()
        self.app = rumps.App("pockterm", title="● pockterm")
        self._server: uvicorn.Server | None = None
        self._build_menu()
        self._start_server()

    def _build_menu(self) -> None:
        rumps = self._rumps
        connect = rumps.MenuItem("Connect via")
        for host in reachable_hosts():
            connect.add(rumps.MenuItem(f"{host.label} {host.ip}",
                                       callback=self._qr_callback(host)))
        self.app.menu = [
            connect,
            None,
            rumps.MenuItem("Open /pair page", callback=self._open_pair),
            rumps.MenuItem("Restart server (new QR token)", callback=self._restart),
            None,
            rumps.MenuItem("Quit", callback=self._quit),
        ]

    def _qr_callback(self, host):
        def cb(_):
            payload = qr_payload(host.ip, self.port, self.rt.auth.pairing_token,
                                 self.rt.fingerprint, self.name)
            path = os.path.join(STATE_DIR, f"qr-{host.label}.png")
            write_qr_png(payload, path)
            subprocess.run(["open", path])
        return cb

    def _open_pair(self, _):
        hosts = reachable_hosts()
        if hosts:
            subprocess.run(["open", f"https://{hosts[0].ip}:{self.port}/pair"])

    def _restart(self, _):
        self.rt.auth.rotate_pairing()
        self._rumps.notification("pockterm", "Pairing token rotated",
                                 "Previous QR codes are no longer valid.")

    def _start_server(self) -> None:
        config = uvicorn.Config(
            self.rt.app, host="0.0.0.0", port=self.port,
            ssl_certfile=self.rt.cert_path, ssl_keyfile=self.rt.key_path,
            ws="websockets-sansio", log_level="warning")
        self._server = uvicorn.Server(config)
        # uvicorn skips signal handlers automatically off the main thread.
        threading.Thread(target=self._server.run, daemon=True).start()

    def _quit(self, _):
        if self._server:
            self._server.should_exit = True
        self._rumps.quit_application()

    def run(self) -> None:
        self.app.run()


def main() -> None:
    PocktermMenuBar().run()


if __name__ == "__main__":
    main()
