from typing import Union

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.axes import Axes
from matplotlib.figure import Figure
from pylbo.utilities.logger import pylboLogger
from pylbo.visualisation.figure_window import FigureWindow
from pylbo.visualisation.modes.mode_data import ModeVisualisationData
from pylbo.visualisation.utils import add_axis_label


class ModeFigure(FigureWindow):
    """
    Main class to hold the figure, axes and colorbar for eigenmode visualisations.

    Parameters
    ----------
    figsize : tuple[int, int]
        The size of the figure.
    data : ModeVisualisationData
        The data used for eigenmode visualisations.

    Attributes
    ----------
    fig : matplotlib.figure.Figure
        The figure.
    axes : dict[str, matplotlib.axes.Axes]
        The axes.
    cbar : matplotlib.colorbar.Colorbar
        The colorbar.
    cbar_ax : matplotlib.axes.Axes
        The axes for the colorbar.
    data : ModeVisualisationData
        Data object containing all data associated with the selected eigenmode.
    u1_data : np.ndarray
        The data for the :math:`u_1` coordinate.
    u2_data : Union[float, np.ndarray]
        The data for the :math:`u_2` coordinate.
    u3_data : Union[float, np.ndarray]
        The data for the :math:`u_3` coordinate.
    ef_data : Union[complex, np.ndarray]
        The data for the eigenfunction.
    t_data : Union[float, np.ndarray]
        The data for the time.
    """

    def __init__(self, figsize: tuple[int, int], data: ModeVisualisationData) -> None:
        fig, axes = self._create_figure_layout(figsize)
        super().__init__(fig)
        self.axes = axes
        self.data = data
        [setattr(self, f"{val}_data", None) for val in ("u1", "u2", "u3", "t", "ef")]
        self._solutions = None
        self.cbar = None
        self.cbar_ax = self.create_cbar_axes()

    @property
    def ax(self) -> Axes:
        """
        Returns
        -------
        matplotlib.axes.Axes
            Alias for the axes containing the eigenmode solution view.
        """
        return self.axes["view"]

    @property
    def solutions(self) -> np.ndarray:
        """
        Returns
        -------
        np.ndarray
            The solutions for the eigenmode
        """
        return self._solutions

    def _create_figure_layout(
        self, figsize: tuple[int, int], **kwargs
    ) -> tuple[Figure, dict]:
        raise NotImplementedError()

    def create_cbar_axes(self) -> Axes:
        """
        Returns
        -------
        matplotlib.axes.Axes
            The axes for the colorbar.
        """
        box = self.ax.get_position()
        position = (box.x0 + box.width + 0.01, box.y0)
        dims = (0.02, box.height)
        return self.fig.add_axes([*position, *dims])

    def set_plot_data(
        self,
        u1_data: np.ndarray,
        u2_data: Union[float, np.ndarray],
        u3_data: Union[float, np.ndarray],
        ef_data: Union[float, np.ndarray],
        t_data: Union[float, np.ndarray],
    ) -> None:
        """
        Sets the data to be plotted.

        Parameters
        ----------
        u1_data : np.ndarray
            The data for the :math:`u_1` coordinate.
        u2_data : Union[float, np.ndarray]
            The data for the :math:`u_2` coordinate.
        u3_data : Union[float, np.ndarray]
            The data for the :math:`u_3` coordinate.
        ef_data : Union[complex, np.ndarray]
            The data for the eigenfunction.
        t_data : Union[float, np.ndarray]
            The data for the time.
        """
        pylboLogger.info("setting plot data")
        self.u1_data = u1_data
        self.u2_data = u2_data
        self.u3_data = u3_data
        self.t_data = t_data
        self.ef_data = ef_data
        # set solutions
        self._solutions = self.data.get_mode_solution(
            ef=self.ef_data, u2=self.u2_data, u3=self.u3_data, t=self.t_data
        )
        pylboLogger.info(f"eigenmode solution shape {self._solutions.shape}")


class ModeFigure2D(ModeFigure):
    """
    Class for 2D eigenmode visualisations.

    Parameters
    ----------
    figsize : tuple[int, int]
        The size of the figure.
    data : ModeVisualisationData
        The data used for eigenmode visualisations.
    polar : bool
        Whether to use polar coordinates for the bottom panel

    Attributes
    ----------
    omega_txt : matplotlib.text.Text
        The textbox for the eigenmode frequency.
    u2u3_txt : matplotlib.text.Text
        The textbox for the :math:`u_2` and :math:`u_3` coordinates.
    k2k3_txt : matplotlib.text.Text
        The textbox for the :math:`k_2` and :math:`k_3` coordinates.
    t_txt : matplotlib.text.Text
        The textbox for the time.
    """

    def __init__(
        self, figsize: tuple[int, int], data: ModeVisualisationData, polar=False
    ) -> None:
        if figsize is None:
            figsize = (14, 8)
        self._use_polar_axes = polar
        super().__init__(figsize, data)

        # init textboxes
        self.omega_txt = None
        self.u2u3_txt = None
        self.k2k3_txt = None
        self.t_txt = None

    def draw(self) -> None:
        """Draws the figure."""
        self.add_eigenfunction()
        self.add_mode_solution()
        self.add_omega_txt(self.axes["eigfunc"], loc="top left", outside=True)
        self.add_u2u3_txt(self.axes["eigfunc"], loc="top right", outside=True)
        self.add_k2k3_txt(self.ax, loc="bottom left", color="white", alpha=0.5)

    def _create_figure_layout(self, figsize: tuple[int, int]) -> tuple[Figure, dict]:
        """
        Create the figure layout for the visualisation. Two panels are created:
        the top one for the eigenfunction and the bottom one for the visualisation.

        Parameters
        ----------
        figsize : tuple[int, int]
            The size of the figure.

        Returns
        -------
        fig : ~matplotlib.figure.Figure
            The figure to use for the visualisation.
        axes : dict
            The axes to use for the visualisation.
        """
        mosaic = [["eigfunc"], ["view"], ["view"]]
        fig = plt.figure(figsize=figsize)
        axes = fig.subplot_mosaic(mosaic, gridspec_kw={"hspace": 0.11}, sharex=True)
        return fig, axes

    def add_eigenfunction(self) -> None:
        """Adds the eigenfunction to the figure."""
        ax = self.axes["eigfunc"]
        ef = getattr(self.data.eigenfunction, self.data.part_name)
        ax.plot(self.u1_data, ef, lw=2)
        ax.axvline(x=0, color="grey", ls="--", lw=1)
        ax.set_xlim(np.min(self.u1_data), np.max(self.u1_data))
        ax.set_ylabel(self.data._ef_name_latex)

    def add_mode_solution(self) -> None:
        """Adds the mode solution to the figure, should be implemented in subclasses."""
        raise NotImplementedError()

    def add_omega_txt(self, ax, **kwargs) -> None:
        """
        Creates a textbox on the figure with the value of the eigenfrequency.

        Parameters
        ----------
        ax : ~matplotlib.axes.Axes
            The axes to use for the textbox.
        **kwargs
            Additional keyword arguments to pass to :meth:`add_axis_label`.
        """
        self.omega_txt = add_axis_label(
            ax, rf"$\omega$ = {self.data.omega:.5f}", **kwargs
        )

    def add_u2u3_txt(self, ax, **kwargs) -> None:
        """
        Creates a textbox on the figure with the value of the :math:`u_2-u_3`
        coordinates.

        Parameters
        ----------
        ax : ~matplotlib.axes.Axes
            The axes to use for the textbox.
        **kwargs
            Additional keyword arguments to pass to :meth:`add_axis_label`.
        """
        self.u2u3_txt = add_axis_label(
            ax,
            rf"{self.data.ds.u2_str} = {self._u2} | {self.data.ds.u3_str} = {self._u3}",
            **kwargs,
        )

    def add_k2k3_txt(self, ax, **kwargs) -> None:
        """
        Creates a textbox on the figure with the value of the k2 and k3 coordinates.

        Parameters
        ----------
        ax : ~matplotlib.axes.Axes
            The axes to use for the textbox.
        **kwargs
            Additional keyword arguments to pass to :meth:`add_axis_label`.
        """
        self.k2k3_txt = add_axis_label(
            ax,
            f"{self.data.ds.k2_str} = {self.data.k2} | "
            f"{self.data.ds.k3_str} = {self.data.k3}",
            **kwargs,
        )

    def add_t_txt(self, ax, **kwargs) -> None:
        """
        Creates a textbox on the figure with the value of the time.

        Parameters
        ----------
        ax : ~matplotlib.axes.Axes
            The axes to use for the textbox.
        **kwargs
            Additional keyword arguments to pass to :meth:`add_axis_label`.
        """
        self.t_txt = None

    def _validate_slicing_axis(self, slicing_axis: str, allowed_axes: list[str]) -> str:
        """
        Validates the slicing axis.

        Parameters
        ----------
        slicing_axis : str
            The slicing axis.
        allowed_axes : list[str]
            The list of allowed axes.

        Returns
        -------
        str
            The validated slicing axis.
        """
        if slicing_axis not in allowed_axes:
            raise ValueError(f"Slicing axis must be one of {allowed_axes}.")
        return slicing_axis

    def _validate_u2(self, u2: float, slicing_axis: str, coord_axis: str) -> float:
        """
        Validates the combination of u2 and slicing axis.

        Parameters
        ----------
        u2 : float
            The :math:`u_2` coordinate.
        slicing_axis : str
            The slicing axis.
        coord_axis : str
            The coordinate axis corresponding to :math:`u_2`.

        Returns
        -------
        float
            The validated :math:`u_2` coordinate.
        """
        if slicing_axis == coord_axis and not isinstance(u2, (int, float)):
            raise ValueError(f"u2 must be a number for slicing axis '{coord_axis}'.")
        return u2

    def _validate_u3(self, u3: float, slicing_axis: str, coord_axis: str) -> float:
        """
        Validates the combination of u3 and slicing axis.

        Parameters
        ----------
        u3 : float
            The :math:`u_3` coordinate.
        slicing_axis : str
            The slicing axis.
        coord_axis : str
            The coordinate axis corresponding to :math:`u_3`.

        Returns
        -------
        float
            The validated :math:`u_3` coordinate.
        """
        if slicing_axis == coord_axis and not isinstance(u3, (int, float)):
            raise ValueError(f"u3 must be a number for slicing axis '{coord_axis}'.")
        return u3
