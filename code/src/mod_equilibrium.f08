!
! MODULE: mod_equilibrium
!
!> @author
!> Niels Claes
!> niels.claes@kuleuven.be
!
! DESCRIPTION:
!> Module containing all equilibrium arrays.
!
module mod_equilibrium
  use mod_global_variables
  implicit none

  public

  !> Wavenumber in y-direction (Cartesian) or theta-direction (cylindrical)
  real(dp)                      :: k2
  !> Wavenumber in z-direction (Cartesian) or z-direction (cylindrical)
  real(dp)                      :: k3

  !! Default equilibrium variables
  !> Equilibrium density
  real(dp), allocatable         :: rho0_eq(:)
  !> Equilibrium temperature
  real(dp), allocatable         :: T0_eq(:)
  !> Equilibrium magnetic field in the y or theta-direction
  real(dp), allocatable         :: B02_eq(:)
  !> Equilibrium magnetic field in the z direction
  real(dp), allocatable         :: B03_eq(:)
  !> Equilibrium magnetic field
  real(dp), allocatable         :: B0_eq(:)

  !! Flow equilibrium variables
  !> Equilibrium velocity in the y or theta-direction
  real(dp), allocatable         :: v02_eq(:)
  !> Equilibrium velocity in the z direction
  real(dp), allocatable         :: v03_eq(:)

  !! Thermal conduction equilibrium variables
  !> Equilibrium parallel conduction
  real(dp), allocatable         :: tc_para_eq(:)
  !> Equilibrium perpendicular conduction
  real(dp), allocatable         :: tc_perp_eq(:)

  !! Radiative cooling equilibrium variables
  !> Equilibrium heat-loss function
  real(dp), allocatable         :: heat_loss_eq(:)

  !! Resistivity equilibrium variables
  !> Equilibrium resistivity
  real(dp), allocatable         :: eta_eq(:)

  private :: suydam_cluster_eq



contains

  !> Initialises the equilibrium by allocating all equilibrium arrays and
  !! setting them to zero.
  subroutine initialise_equilibrium()
    allocate(rho0_eq(gauss_gridpts))
    allocate(T0_eq(gauss_gridpts))
    allocate(B02_eq(gauss_gridpts))
    allocate(B03_eq(gauss_gridpts))
    allocate(B0_eq(gauss_gridpts))

    allocate(v02_eq(gauss_gridpts))
    allocate(v03_eq(gauss_gridpts))

    allocate(tc_para_eq(gauss_gridpts))
    allocate(tc_perp_eq(gauss_gridpts))

    allocate(heat_loss_eq(gauss_gridpts))

    allocate(eta_eq(gauss_gridpts))

    rho0_eq = 0.0d0
    T0_eq   = 0.0d0
    B02_eq  = 0.0d0
    B03_eq  = 0.0d0
    B0_eq   = 0.0d0

    v02_eq  = 0.0d0
    v03_eq  = 0.0d0

    tc_para_eq = 0.0d0
    tc_perp_eq = 0.0d0

    heat_loss_eq = 0.0d0

    eta_eq = 0.0d0

    k2 = 1.0d0
    k3 = 1.0d0

  end subroutine initialise_equilibrium

  !> Determines which pre-coded equilibrium configuration has to be loaded.
  !! These set the physics, overriding the ones defined in mod_global_variables.
  subroutine set_equilibrium()
    use mod_gravity, only: initialise_gravity
    use mod_radiative_cooling, only: initialise_radiative_cooling
    use mod_thermal_conduction, only: get_kappa_para, get_kappa_perp
    use mod_resistivity, only: get_eta
    use mod_equilibrium_derivatives

    if (use_precoded) then

      write(*, *) "Using precoded equilibrium: ", equilibrium_type

      select case(equilibrium_type)

      case("Adiabatic homogeneous")
        call adiabatic_homo_eq()
        ! derivatives remain zero so don't have to be set

      case("Resistive homogeneous")
        call resistive_homo_eq()
        ! no explicit derivatives needed

      case("Suydam cluster modes")
        call suydam_cluster_eq()

      case("Kelvin-Helmholtz")
        call KH_instability_eq()

      case default
        write(*, *) "Precoded equilibrium not recognised."
        write(*, *) "Currently set on: ", equilibrium_type
        stop

      end select

    else
      write(*, *) "Not using precoded equilibrium."
    end if

    !! Calculate total magnetic field
    B0_eq   = sqrt(B02_eq**2 + B03_eq**2)

    !! Enable additional physics if defined in the above configuration
    if (external_gravity) then
      call initialise_gravity()
    end if
    if (radiative_cooling) then
      call initialise_radiative_cooling()
      call set_cooling_derivatives(T0_eq, rho0_eq)
      ! this is L_0, should balance out in thermal equilibrium.
      heat_loss_eq = 0.0d0
    end if
    if (thermal_conduction) then
      call get_kappa_para(T0_eq, tc_para_eq)
      call get_kappa_perp(T0_eq, rho0_eq, B0_eq, tc_perp_eq)
      call set_conduction_derivatives(T0_eq, rho0_eq, B0_eq)
    end if
    if (resistivity) then
      write(*, *) "true"
      call get_eta(T0_eq, eta_eq)
      call set_resistivity_derivatives(T0_eq)
    end if

  end subroutine set_equilibrium

  !> Initialises equilibrium for an adiabatic homogeneous medium in Cartesian
  !! geometry.
  subroutine adiabatic_homo_eq()
    use mod_grid
    use mod_physical_constants

    k2 = 0.0d0
    k3 = dpi

    geometry = "Cartesian"
    flow = .false.
    radiative_cooling = .false.
    thermal_conduction = .false.
    resistivity = .false.
    external_gravity = .false.

    !! Parameters
    rho0_eq = 1.0d0
    T0_eq   = 1.0d0
    B02_eq  = 0.0d0
    B03_eq  = 1.0d0

  end subroutine adiabatic_homo_eq


  subroutine resistive_homo_eq()
    use mod_grid
    use mod_physical_constants

    real(dp)  :: beta

    geometry = "Cartesian"
    flow = .false.
    radiative_cooling = .false.
    thermal_conduction = .false.
    resistivity = .true.
    external_gravity = .false.

    k2 = 0.0d0
    k3 = 1.0d0

    beta = 0.25d0

    !! Parameters
    rho0_eq = 1.0d0
    B02_eq  = 0.0d0
    B03_eq  = 1.0d0

    B0_eq   = 1.0d0
    T0_eq   = beta * B0_eq**2 / (8*dpi)
  end subroutine resistive_homo_eq


  !> Initialises equilibrium for Suydam cluster modes in cylindrical geometry.
  !! Obtained from Bondeson et al., Phys. Fluids 30 (1987)
  subroutine suydam_cluster_eq()
    use mod_grid

    real(dp)      :: v_z0, p0, p1, alpha, r
    real(dp)      :: P0_eq(gauss_gridpts)
    integer       :: i

    geometry = "cylindrical"
    flow = .true.
    radiative_cooling = .false.
    thermal_conduction = .false.
    resistivity = .false.
    external_gravity = .false.

    !! Parameters
    v_z0  = 0.14d0
    p0    = 0.05d0
    p1    = 0.1d0
    alpha = 2

    !! Filling equilibria
    rho0_eq = 1.0d0
    v02_eq  = 0.0d0

    k2 = 1.0d0
    k3 = -1.2d0

    do i = 1, gauss_gridpts
      r = grid_gauss(i)

      v03_eq(i) = v_z0 * (1.0d0 - r**2)
      B02_eq(i) = bessel_jn(1, alpha * r)
      B03_eq(i) = sqrt(1.0d0 - p1) * bessel_jn(0, alpha * r)

      P0_eq(i)  = p0 + 0.5 * p1 * bessel_jn(0, alpha * r)**2

      T0_eq(i)  = P0_eq(i) / rho0_eq(i)
    end do

  end subroutine suydam_cluster_eq

  !> Initialises equilibrium for the Kelvin-Helmholtz instability in
  !! Cartesian geometry.
  !! From Miura et al., J. Geophys. Res. 87 (1982)
  subroutine KH_instability_eq()
    use mod_grid

    real(dp)    :: a, x, p0, v0y, v0z
    integer     :: i

    geometry = "Cartesian"
    flow = .false.
    radiative_cooling = .false.
    thermal_conduction = .false.
    resistivity = .false.
    external_gravity = .false.

    !! Parameters
    a   = 0.05d0
    P0  = 3.6d0
    v0y = 1.67d0
    v0z = 0.0d0   ! so B is perpendicular to v

    !! Filling equilibria
    rho0_eq = 1.0d0
    B02_eq  = 0.0d0
    B03_eq  = 1.0d0

    k2 = 10
    k3 = 0

    do i = 1, gauss_gridpts
      x = grid_gauss(i)
      v02_eq(i) = -v0y * tanh((x - 0.5d0) / a)
      v03_eq(i) = -v0z * tanh((x - 0.5d0) / a)

      T0_eq(i)  = P0 / rho0_eq(i)
    end do

  end subroutine KH_instability_eq

  !> Cleaning routine, deallocates all arrays in this module.
  subroutine equilibrium_clean()
    if (allocated(rho0_eq)) then
      deallocate(rho0_eq)
    end if
    if (allocated(T0_eq)) then
      deallocate(T0_eq)
    end if
    if (allocated(B02_eq)) then
      deallocate(B02_eq)
    end if
    if (allocated(B03_eq)) then
      deallocate(B03_eq)
    end if
    if (allocated(B0_eq)) then
      deallocate(B0_eq)
    end if
    if (allocated(v02_eq)) then
      deallocate(v02_eq)
    end if
    if (allocated(v03_eq)) then
      deallocate(v03_eq)
    end if
    if (allocated(tc_para_eq)) then
      deallocate(tc_para_eq)
    end if
    if (allocated(tc_perp_eq)) then
      deallocate(tc_perp_eq)
    end if
    if (allocated(heat_loss_eq)) then
      deallocate(heat_loss_eq)
    end if
    if (allocated(eta_eq)) then
      deallocate(eta_eq)
    end if

  end subroutine equilibrium_clean


end module mod_equilibrium
