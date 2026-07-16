from pockterm.shells import default_shell, home_dir


def test_default_shell_returns_list():
    argv = default_shell()
    assert isinstance(argv, list) and argv and isinstance(argv[0], str)


def test_home_dir_exists():
    import os
    assert os.path.isdir(home_dir())
