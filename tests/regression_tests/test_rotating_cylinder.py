rotating_cylinder_setup = {
    "name": "rotating_cylinder",
    "config": {
        "geometry": "cylindrical",
        "x_start": 0,
        "x_end": 1,
        "gridpoints": 51,
        "parameters": {
            "k2": 1.0,
            "k3": 0.0,
            "p1": 8.0,
            "p2": 0.0,
            "p3": 0.0,
            "p4": 1.0,
            "p5": 0.0,
            "p6": 0.0,
            "cte_p0": 0.1,
            "cte_rho0": 1,
        },
        "flow": True,
        "equilibrium_type": "rotating_plasma_cylinder",
        "logging_level": 0,
        "show_results": False,
        "write_eigenfunctions": False,
        "write_matrices": False,
    },
    "image_limits": [
        {"xlims": (-2400, 2400), "ylims": (-2, 2)},
        {"xlims": (-100, 120), "ylims": (-2, 2)},
        {"xlims": (-5, 20), "ylims": (-2, 2)},
        {"xlims": (4.5, 9.5), "ylims": (-2, 2)},
    ]
}
