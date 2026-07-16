import os
import shutil
import sys


def default_shell() -> list[str]:
    if sys.platform == "win32":
        pwsh = shutil.which("powershell.exe") or shutil.which("pwsh.exe")
        return [pwsh] if pwsh else ["cmd.exe"]
    return [os.environ.get("SHELL") or "/bin/bash"]


def home_dir() -> str:
    return os.path.expanduser("~")
