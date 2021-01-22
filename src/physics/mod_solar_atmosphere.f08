! =============================================================================
!> Module to set a realistic solar atmosphere, using tabulated density and
!! temperature profiles (see <tt>mod_atmosphere_curves</tt>), in Cartesian
!! geometries only.
module mod_solar_atmosphere
  use mod_global_variables, only: dp, gauss_gridpts
  use mod_logging, only: log_message, char_log, int_fmt
  implicit none

  !> interpolated heights from atmosphere tables
  real(dp), allocatable :: h_interp(:)
  !> interpolated temperatures from atmosphere tables
  real(dp), allocatable :: T_interp(:)
  !> interpolated numberdensity from atmosphere tables
  real(dp), allocatable :: nh_interp(:)
  !> derivative of interpolated temperature with respect to height
  real(dp), allocatable :: dT_interp(:)
  !> amount of points used for interpolation, defaults to <tt>ncool</tt>
  integer   :: nbpoints

  abstract interface
    function b_func(x)
      use mod_global_variables, only: dp
      real(dp), intent(in) :: x(:)
      real(dp)  :: b_func(size(x))
    end function b_func
  end interface

  private

  public :: set_solar_atmosphere

contains


  !> Sets the density, temperature and gravity attributes of the respective
  !! fields to a realistic solar atmosphere profile. This uses the (Gaussian) grid
  !! to interpolate the correct values from the tables, and should already be set.
  !! This routine first interpolates the temperature and numberdensity table at
  !! <tt>n_interp</tt> resolution, then solves the following ODE for the density:
  !! $$ \rho'(x) = -\frac{T'(x) + g(x)}{T(x)}\rho(x) -
  !!               \frac{B_{02}(x)B'_{02}(x) + B_{03}(x)B'_{03}(x)}{T(x)} $$
  !! using a fifth order Runge-Kutta method, assuming an initial density corresponding
  !! to the first (tabulated) density value in the grid. Integration is done using
  !! <tt>n_interp</tt> values.
  !! @warning   Throws an error if the geometry is not Cartesian.
  subroutine set_solar_atmosphere(b02_func, db02_func, b03_func, db03_func, n_interp)
    use mod_global_variables, only: ncool, geometry
    use mod_grid, only: grid_gauss
    use mod_interpolation, only: lookup_table_value, get_numerical_derivative
    use mod_integration, only: integrate_ode_rk
    use mod_physical_constants, only: gsun_cgs, Rsun_cgs
    use mod_units, only: unit_length, unit_time
    use mod_equilibrium, only: rho_field, T_field, B_field, grav_field

    !> function reference for calculation of B02
    procedure(b_func) :: b02_func
    !> function reference for calculation of B02'
    procedure(b_func) :: db02_func
    !> function reference for calculation of B03
    procedure(b_func) :: b03_func
    !> function reference for calculation of B03'
    procedure(b_func) :: db03_func
    !> points used for interpolation, defaults to <tt>ncool</tt> if not present
    integer, intent(in), optional         :: n_interp

    integer   :: i
    real(dp)  :: x, rhoinit
    real(dp), allocatable :: g_interp(:), rho_interp(:), drho_interp(:)
    real(dp), allocatable  :: axvalues(:), bxvalues(:)

    nbpoints = ncool
    if (present(n_interp)) then
      nbpoints = n_interp
    end if

    if (geometry /= "Cartesian") then
      call log_message( &
        "solar atmosphere can only be set in Cartesian geometries!", &
        level="error" &
      )
      return
    end if

    ! interpolate atmospheric tables
    allocate(h_interp(nbpoints), T_interp(nbpoints), dT_interp(nbpoints))
    allocate(nh_interp(nbpoints))
    call log_message("interpolating solar atmosphere", level="info")
    ! curves are normalised on return
    call create_atmosphere_curves()

    ! create gravitational field
    allocate(g_interp(nbpoints))
    g_interp = ( &
      gsun_cgs &
      * (Rsun_cgs / (Rsun_cgs + h_interp * unit_length))**2 &
      / (unit_length / unit_time**2) &
    )

    ! fill ODE functions, use high resolution arrays
    allocate(axvalues(nbpoints), bxvalues(nbpoints))
    axvalues = -(dT_interp + g_interp) / (T_interp)
    bxvalues = ( &
      -( &
        b02_func(h_interp) * db02_func(h_interp) &
        + b03_func(h_interp) * db03_func(h_interp) &
      ) &
      / T_interp &
    )

    ! find initial density value (numberdensity = density in normalised units)
    rhoinit = nh_interp(1)
    ! solve differential equation
    write(char_log, int_fmt) nbpoints
    call log_message( &
      "solving equilibrium ODE for density... (" &
      // trim(adjustl(char_log)) &
      // " points)", &
      level="info" &
    )
    allocate(rho_interp(nbpoints), drho_interp(nbpoints))
    call integrate_ode_rk( &
      h_interp, axvalues, bxvalues, nbpoints, rhoinit, rho_interp, drho_interp &
    )

    ! set the various equilibrium attributes
    do i = 1, gauss_gridpts
      x = grid_gauss(i)
      ! density
      rho_field % rho0(i) = lookup_table_value(x, h_interp, rho_interp)
      rho_field % d_rho0_dr(i) = lookup_table_value(x, h_interp, drho_interp)
      ! temperature
      T_field % T0(i) = lookup_table_value(x, h_interp, T_interp)
      T_field % d_T0_dr(i) = lookup_table_value(x, h_interp, dT_interp)
      ! gravitational field
      grav_field % grav(i) = lookup_table_value(x, h_interp, g_interp)
    end do
    ! magnetic fields
    B_field % B02 = b02_func(grid_gauss)
    B_field % d_B02_dr = db02_func(grid_gauss)
    B_field % B03 = b03_func(grid_gauss)
    B_field % d_B03_dr = db03_func(grid_gauss)

    call log_message( &
      "solar atmosphere: rho, T, B and gravity attributes have been set", level="info" &
    )

    deallocate(h_interp, T_interp, nh_interp, dT_interp)
    deallocate(g_interp, axvalues, bxvalues)
    deallocate(rho_interp, drho_interp)
  end subroutine set_solar_atmosphere


  subroutine create_atmosphere_curves()
    use mod_atmosphere_curves, only: h_alc7, T_alc7, nh_alc7
    use mod_interpolation, only: interpolate_table, get_numerical_derivative
    use mod_units, only: unit_length, unit_temperature, unit_numberdensity

    ! interpolate T vs height
    call interpolate_table(nbpoints, h_alc7, T_alc7, h_interp, T_interp)
    ! interpolate nh vs height
    call interpolate_table(nbpoints, h_alc7, nh_alc7, h_interp, nh_interp)

    ! rescale interpolated tables to actual values and normalise
    h_interp = h_interp * 1.0d5 / unit_length ! height is in km, so scale to cm first
    T_interp = T_interp / unit_temperature
    nh_interp = nh_interp / unit_numberdensity

    ! find temperature derivative
    call get_numerical_derivative(h_interp, T_interp, dT_interp)
  end subroutine create_atmosphere_curves

end module mod_solar_atmosphere