import numpy as np
from matplotlib import pyplot as plt
from matplotlib.cm import ScalarMappable
from matplotlib.figure import Figure
from pylbo.visualisation.modes.cartesian_2d import CartesianSlicePlot2D
from pylbo.visualisation.modes.mode_data import ModeVisualisationData


class CartesianSlicePlot3D(CartesianSlicePlot2D):
    """
    Class for handling Cartesian 3D plots of the eigenmode solution.

    Parameters
    ----------
    data : ModeVisualisationData
        The data for the visualisation.
    u2 : np.ndarray
        The :math:`y` coordinate of the eigenmode solution.
    u3 : np.ndarray
        The :math:`z` coordinate of the eigenmode solution.
    time : float
        The time at which the eigenmode solution is calculated.
    slicing_axis : str
        The axis along which the eigenmode solution is sliced.
    figsize : tuple[int, int]
        The size of the figure.
    vmin : float
        The minimum value of the colourbar. If None, the minimum value of the
        solution is used.
    vmax : float
        The maximum value of the colourbar. If None, the maximum value of the
        solution is used.
    """

    def __init__(
        self,
        data: ModeVisualisationData,
        u2: np.ndarray,
        u3: np.ndarray,
        time: float,
        slicing_axis: str,
        figsize: tuple[int, int],
        vmin: float = None,
        vmax: float = None,
        **kwargs,
    ) -> None:
        if figsize is None:
            figsize = (8, 8)
        if slicing_axis == "y":
            raise NotImplementedError("3D slicing is not implemented for y-axis.")
        super().__init__(data, u2, u3, time, slicing_axis, figsize, **kwargs)

        self.vmin = np.min(self._solutions) if vmin is None else vmin
        self.vmax = np.max(self._solutions) if vmax is None else vmax
        self._view = [None] * len(self._u3)

    def _create_figure_layout(self, figsize: tuple[int, int]) -> tuple[Figure, dict]:
        fig = plt.figure(figsize=figsize)
        ax = fig.add_subplot(111, projection="3d")
        for side in ("top", "bottom", "left", "right"):
            ax.spines[side].set_color("none")
        ax.grid(False)
        for attr in "xyz":
            getattr(ax, f"w_{attr}axis").set_pane_color((1.0, 1.0, 1.0, 1.0))
        return fig, {"view": ax}

    def _create_cbar_axes(self):
        box = self.ax.get_position()
        position = (box.x0, box.height + 0.02 + 0.1)
        dims = (box.width, 0.02)
        return self.fig.add_axes([*position, *dims])

    def _validate_u2(self, u2: np.ndarray, *args, **kwargs) -> np.ndarray:
        return u2

    def _validate_u3(self, u3: np.ndarray, *args, **kwargs) -> np.ndarray:
        return u3

    def set_plot_arrays(self) -> None:
        ef = self.data.eigenfunction
        x_2d, y_2d = np.meshgrid(self.data.ds.ef_grid, self._u2, indexing="ij")
        self.ef_data = np.broadcast_to(ef, shape=(len(self._u2), len(ef))).transpose()
        self.u1_data = x_2d
        self.u2_data = y_2d
        self.u3_data = self._u3
        self.time_data = self._time

    def calculate_mode_solution(
        self, ef: np.ndarray, u2: np.ndarray, u3: np.ndarray, t: np.ndarray
    ) -> np.ndarray:
        solutions = np.empty(shape=(*ef.shape, len(u3)))
        for i, z in enumerate(u3):
            solutions[..., i] = super().calculate_mode_solution(ef, u2, z, t)
        return solutions

    def draw_eigenfunction(self) -> None:
        pass

    def draw_solution(self) -> None:
        for i, z in enumerate(self._u3):
            self._view[i] = self.ax.contourf(
                self.u1_data,
                self.u2_data,
                self.solutions[..., i],
                levels=50,
                zdir="z",
                offset=z,
                alpha=max(0.4, 1 - i * 0.1),
                vmin=self.vmin,
                vmax=self.vmax,
            )
        self.cbar = self.fig.colorbar(
            ScalarMappable(norm=self._view[0].norm, cmap=self._view[0].cmap),
            cax=self.cbar_ax,
            orientation="horizontal",
        )
        self.ax.set_xlim(np.min(self._u1), np.max(self._u1))
        self.ax.set_ylim(np.min(self._u2), np.max(self._u2))
        self.ax.set_zlim(np.min(self._u3), np.max(self._u3))

    def add_axes_labels(self) -> None:
        super().add_axes_labels()
        self.ax.set_zlabel("z")

    def draw_textboxes(self) -> None:
        self.t_txt = self.ax.text2D(
            0.9,
            0.9,
            f"t = {self._time:.2f}",
            fontsize=15,
            transform=self.ax.transAxes,
            ha="center",
            bbox=dict(facecolor="grey", alpha=0.2, boxstyle="round", pad=0.2),
        )

    def create_animation(
        self, times: np.ndarray, filename: str, fps: float = 10, dpi: int = 200
    ) -> None:
        super().create_animation(times, filename, fps, dpi)

    def _update_view(self, updated_solution: np.ndarray) -> None:
        # sadly contourf does not support updating the data, so we have to
        # delete the old contours and create new ones every frame...
        for view in self._view:
            for coll in view.collections:
                try:
                    coll.remove()
                except ValueError:
                    pass
        self._solutions = updated_solution
        self.vmin = np.min(self._solutions)
        self.vmax = np.max(self._solutions)
        self.draw_solution()
        self.cbar.set_ticks(np.linspace(self.vmin, self.vmax, 5))
        self.add_axes_labels()

    def _update_view_clims(self, solution: np.ndarray) -> None:
        pass

    def _set_t_txt(self, t):
        self.t_txt.set_text(f"t = {t:.2f}")
