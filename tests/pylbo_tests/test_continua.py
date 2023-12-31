import pytest
import numpy as np
from pylbo.visualisation.continua import calculate_continua


def test_continua(fake_ds):
    calculate_continua(fake_ds)


def test_continua_temp_zero(fake_ds, monkeypatch):
    monkeypatch.setitem(fake_ds.equilibria, "T0", np.zeros(fake_ds.gauss_gridpoints))
    continua = calculate_continua(fake_ds)
    assert np.allclose(continua["thermal"], 0)


def test_continua_hydro(fake_ds, monkeypatch):
    for name in ("B02", "B03", "B0", "v01", "v02", "v03"):
        monkeypatch.setitem(
            fake_ds.equilibria, name, np.zeros(fake_ds.gauss_gridpoints)
        )
    continua = calculate_continua(fake_ds)
    # hydro: no slow/alfven continua
    for key in ("slow-", "slow+", "alfven-", "alfven+"):
        assert np.allclose(continua[key], 0)


def test_continua_slow_zero(fake_ds, monkeypatch):
    for name in ("B02", "v01", "v02", "v03"):
        monkeypatch.setitem(
            fake_ds.equilibria, name, np.zeros(fake_ds.gauss_gridpoints)
        )
    monkeypatch.setitem(fake_ds.parameters, "k3", 0)
    continua = calculate_continua(fake_ds)
    assert np.allclose(continua["slow+"], 0)
    assert np.allclose(continua["slow-"], 0)


def test_continua_handler_colors(c_handle):
    assert isinstance(c_handle.continua_colors, list)


def test_continua_handler_prevent_colors_none(c_handle):
    colors = c_handle.continua_colors
    c_handle.continua_colors = None
    assert c_handle.continua_colors == colors


def test_continua_handler_set_colors_invalid(c_handle):
    with pytest.raises(ValueError):
        c_handle.continua_colors = "blue"


def test_continua_handler_set_colors_wrong_size(c_handle):
    with pytest.raises(ValueError):
        c_handle.continua_colors = ["blue", "red", "green", "orange"]


def test_continua_handler_set_colors(c_handle):
    new_colors = ["blue", "red", "green", "cyan", "yellow", "orange"]
    c_handle.continua_colors = new_colors
    assert c_handle.continua_colors == new_colors
