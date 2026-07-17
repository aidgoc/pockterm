import pockterm.menubar as menubar


def test_module_imports_without_rumps():
    # Module import must not require rumps/a display (lazy import in __init__).
    assert hasattr(menubar, "PocktermMenuBar")
    assert callable(menubar.main)
