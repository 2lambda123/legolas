import pytest
import pylbo

# @note: all fixtures defined here will be accessible to all tests
#        in the same directory as this file.


@pytest.fixture
def ds_test(setup):
    if setup["test_needs_run"]:
        parfile = pylbo.generate_parfiles(
            parfile_dict=setup["config"],
            basename=setup["datfile"].stem,
            output_dir=setup["config"]["output_folder"],
        )
        pylbo.run_legolas(parfile, remove_parfiles=True)
        setup["test_needs_run"] = False
    return pylbo.load(setup["datfile"])


@pytest.fixture
def log_test(setup):
    return pylbo.load_logfile(setup["logfile"], sort=True)


@pytest.fixture
def eigfuncs_test(ds_test, setup):
    if setup.get("ev_guesses", None) is not None:
        return ds_test.get_eigenfunctions(ev_guesses=setup["ev_guesses"])
    else:
        return None


@pytest.fixture
def ds_answer(setup):
    return pylbo.load(setup["answer_datfile"])


@pytest.fixture
def log_answer(setup):
    return pylbo.load_logfile(setup["answer_logfile"], sort=True)


@pytest.fixture
def eigfuncs_answer(ds_answer, setup):
    if setup.get("ev_guesses", None) is not None:
        return ds_answer.get_eigenfunctions(ev_guesses=setup["ev_guesses"])
    else:
        return None
