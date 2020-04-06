module mod_output
  use mod_global_variables, only: dp, str_len, matrix_gridpts
  implicit none

  private

  !! IO units -- do not use 0/5/6/7, these are system-reserved
  !> IO unit for eigenvalues array omega
  integer, parameter  :: omega_unit = 10
  !> IO unit for configuration file
  integer, parameter  :: config_unit = 20
  !> IO unit for matrix A
  integer, parameter  :: mat_a_unit = 30
  !> IO unit for matrix B
  integer, parameter  :: mat_b_unit = 40
  !> IO (base) unit for eigenfunctions (incremented by eigenfunction index 1-8)
  integer, parameter  :: base_ef_unit = 50
  !> IO unit for left eigenvectors
  integer, parameter  :: eigenvector_l_unit = 70
  !> IO unit for right eigenvectors
  integer, parameter  :: eigenvector_r_unit = 80
  !> IO unit for eigenfunction grid (2*gridpts - 1 = ef_gridpts)
  integer, parameter  :: ef_grid_unit = 90
  !> IO unit for equilibrium values
  integer, parameter  :: equil_unit = 110

  !! Format settings
  !> long exponential format
  character(8), parameter    :: form_e = '(e30.20)'
  !> long float format
  character(8), parameter    :: form_f = '(f30.20)'
  !> shorter exponential format
  character(8), parameter    :: form_eout = '(e20.10)'
  !> shorter float format
  character(8), parameter    :: form_fout = '(f20.10)'
  !> integer format
  character(4), parameter    :: form_int  = '(i8)'

  !> name of base output folder
  character(len=7)    :: output_folder = 'output/'
  !> filename extension
  character(len=4)    :: file_extension = '.dat'

  public :: eigenvalues_tofile
  public :: matrices_tofile
  public :: eigenvectors_tofile
  public :: ef_grid_tofile
  public :: equilibrium_tofile
  public :: eigenfunctions_tofile
  public :: configuration_tofile
  public :: startup_info_toconsole

contains

  !> Opens a file with given unit and filename.
  !! @param[in] file_unit   IO unit for opening the file
  !! @param[in] filename    filename to open
  subroutine open_file(file_unit, filename)
    integer, intent(in)           :: file_unit
    character(len=*), intent(in)  :: filename

    open(unit=file_unit, file=filename, access='stream', &
         status='unknown', action='write')
  end subroutine open_file


  !> Creates a filename, prepending the output directory and appending the
  !! file extension
  !! @param[in] base_filename   the base filename to use
  !! @param[out] filename       the resulting filename, of the form
  !!                            output_folder/base_filename.extension
  subroutine make_filename(base_filename, filename)
    character(len=*), intent(in)  :: base_filename
    character(len=*), intent(out) :: filename

    filename = trim(trim(output_folder) // trim(base_filename) // &
                    trim(file_extension))
  end subroutine make_filename


  !> Writes the eigenvalues to a file.
  !! @param[in] omega           the array of eigenvalues
  !! @param[in] base_filename   filename to use, default 'eigenvalues'
  subroutine eigenvalues_tofile(omega, base_filename)
    complex(dp), intent(in)       :: omega(matrix_gridpts)
    character(len=*), intent(in)  :: base_filename

    character(str_len)            :: filename

    call make_filename(base_filename, filename)

    call open_file(omega_unit, filename)
    write(unit=omega_unit) omega

    close(unit=omega_unit)
  end subroutine eigenvalues_tofile


  !> Writes the matrices A and B to a file.
  !! @param[in] matrix_A    the A-matrix
  !! @param[in] matrix_B    the B-matrix
  !! @param[in] base_filename   filename to use, default 'matrix'
  subroutine matrices_tofile(matrix_A, matrix_B, base_filename)
    complex(dp), intent(in)       :: matrix_A(matrix_gridpts, matrix_gridpts)
    real(dp), intent(in)          :: matrix_B(matrix_gridpts, matrix_gridpts)
    character(len=*), intent(in)  :: base_filename

    character(str_len)            :: filenameA, filenameB
    integer                       :: i

    call make_filename(trim(base_filename) // '_A', filenameA)
    call make_filename(trim(base_filename) // '_B', filenameB)

    call open_file(mat_a_unit, filenameA)
    call open_file(mat_b_unit, filenameB)

    do i = 1, matrix_gridpts
      write(mat_a_unit) matrix_A(i, :)
      write(mat_b_unit) matrix_B(i, :)
    end do

    close(mat_a_unit)
    close(mat_b_unit)
  end subroutine matrices_tofile


  !> Writes the left and right eigenvectors to a file.
  !! @param[in] ev_l    matrix containing the left eigenvectors in columns
  !! @param[in] ev_r    matrix containing the right eigenvectors in columns
  !! @param[in] base_filename   filename to use, default 'eigenvectors'
  subroutine eigenvectors_tofile(ev_l, ev_r, base_filename)
    complex(dp), intent(in)       :: ev_l(matrix_gridpts, matrix_gridpts)
    complex(dp), intent(in)       :: ev_r(matrix_gridpts, matrix_gridpts)
    character(len=*), intent(in)  :: base_filename

    character(str_len)            :: filenameL, filenameR
    integer                       :: i

    call make_filename(trim(base_filename) // '_L', filenameL)
    call make_filename(trim(base_filename) // '_R', filenameR)

    call open_file(eigenvector_l_unit, filenameL)
    call open_file(eigenvector_r_unit, filenameR)

    do i = 1, matrix_gridpts
      write(eigenvector_l_unit) ev_l(i, :)
      write(eigenvector_r_unit) ev_r(i, :)
    end do

    close(eigenvector_l_unit)
    close(eigenvector_r_unit)
  end subroutine eigenvectors_tofile


  !> Writes the eigenfunction grid to a file
  !! @param[in] ef_grid     array containing the grid for an eigenfunction
  !! @param[in] base_filename   filename to use, default 'ef_grid'
  subroutine ef_grid_tofile(ef_grid, base_filename)
    use mod_global_variables, only: ef_gridpts

    real(dp), intent(in)            :: ef_grid(ef_gridpts)
    character(len=*), intent(in)    :: base_filename

    character(str_len)              :: filename

    call make_filename(base_filename, filename)

    call open_file(ef_grid_unit, filename)

    write(ef_grid_unit) ef_grid
    close(ef_grid_unit)
  end subroutine ef_grid_tofile


  !> Writes the eigenfunctions to a file. This saves the eigenfunctions for
  !! exactly one variable (rho, v1, etc.) through the passed type. If all
  !! eigenfunctions should be saved, this method should be called multiple
  !! times, once for every variable.
  !! @param[in] single_ef   type containing all eigenfunctions for one single
  !!                        variable through single_ef % eigenfunctions.
  subroutine eigenfunctions_tofile(single_ef)
    use mod_types, only: ef_type

    type(ef_type), intent(in)       :: single_ef

    character                       :: idx
    character(str_len)              :: base_filename, filename
    integer                         :: single_ef_unit, w_idx

    ! current eigenfunction index (1 = rho, 2 = v1 etc.)
    write(idx, '(i0)') single_ef % index
    ! get output unit for this eigenfunction, increment base unit with index
    single_ef_unit = base_ef_unit + single_ef % index

    ! extend base filename with output folder and index
    base_filename = 'eigenfunctions/' // trim(idx) // '_' &
                    // trim(single_ef % savename)
    call make_filename(base_filename, filename)

    call open_file(single_ef_unit, filename)

    do w_idx = 1, matrix_gridpts
      write(single_ef_unit) single_ef % eigenfunctions(:, w_idx)
    end do
    close(single_ef_unit)
  end subroutine eigenfunctions_tofile


  subroutine equilibrium_tofile(grid_gauss, rho_field, T_field, B_field, v_field, &
                                rc_field, kappa_field, base_filename)
    use mod_global_variables, only: gauss_gridpts
    use mod_types, only: density_type, temperature_type, bfield_type, &
                         velocity_type, cooling_type, conduction_type

    real(dp), intent(in)                :: grid_gauss(gauss_gridpts)
    type(density_type), intent(in)      :: rho_field
    type(temperature_type), intent(in)  :: T_field
    type(bfield_type), intent(in)       :: B_field
    type(velocity_type), intent(in)     :: v_field
    type(cooling_type), intent(in)      :: rc_field
    type(conduction_type), intent(in)   :: kappa_field
    character(len=*), intent(in)        :: base_filename

    character(str_len)                  :: filename, filename_names
    real(dp)                            :: equil_vars(18, gauss_gridpts)

    call make_filename(base_filename, filename)
    call make_filename(trim(base_filename) // '_names', filename_names)

    equil_vars(1, :) = grid_gauss
    equil_vars(2, :) = rho_field % rho0
    equil_vars(3, :) = rho_field % d_rho0_dr
    equil_vars(4, :) = T_field % T0
    equil_vars(5, :) = T_field % d_T0_dr
    equil_vars(6, :) = B_field % B02
    equil_vars(7, :) = B_field % B03
    equil_vars(8, :) = B_field % d_B02_dr
    equil_vars(9, :) = B_field % d_B03_dr
    equil_vars(10, :) = B_field % B0
    equil_vars(11, :) = v_field % v02
    equil_vars(12, :) = v_field % d_v02_dr
    equil_vars(13, :) = v_field % v03
    equil_vars(14, :) = v_field % d_v03_dr
    equil_vars(15, :) = rc_field % d_L_dT
    equil_vars(16, :) = rc_field % d_L_drho
    equil_vars(17, :) = kappa_field % kappa_para
    equil_vars(18, :) = kappa_field % kappa_perp

    call open_file(equil_unit, filename)
    write(equil_unit) equil_vars
    close(equil_unit)
    call open_file(equil_unit + 1, filename_names)
    write(equil_unit + 1) "grid ", "rho0 ", "drho0 ", "T0 ", "dT0 ", "B02 ", "B03 ", &
                          "dB02 ", "dB03 ", "B0 ", "v02 ", "dv02 ", "v03 ", "dv03 ", "dLdT ", &
                          "dLdrho ", "kappa_para ", "kappa_perp "
    close(equil_unit + 1)

  end subroutine equilibrium_tofile


  !> Converts a Fortran logical ('T' or 'F') to a string ('true', 'false').
  !! @param[in] boolean   Fortran logical to convert
  !! @param[out] boolean_string   'true' if boolean == True, 'false' otherwise
  subroutine logical_tostring(boolean, boolean_string)
    logical, intent(in)             :: boolean
    character(len=20), intent(out)  :: boolean_string

    if (boolean) then
      boolean_string = 'true'
    else
      boolean_string = 'false'
    end if
  end subroutine logical_tostring


  !> Saves the current configuration to a dedicated namelist so it can be
  !! read in using Python.
  !! @param[in] base_filename   base filename of the configuration file
  !! @param[out] filename       filename of the configuration file, in the form
  !!                            'output_folder/base_filename.nml'
  subroutine configuration_tofile(base_filename, filename)
    use mod_global_variables
    use mod_equilibrium_params

    character(len=*), intent(in)    :: base_filename
    character(str_len), intent(out) :: filename

    namelist /gridlist/ geometry, x_start, x_end, gridpts, gauss_gridpts, &
                        matrix_gridpts, ef_gridpts
    namelist /equilibriumlist/ gamma, equilibrium_type, boundary_type, use_defaults
    namelist /savelist/ write_matrices, write_eigenvectors, &
                        write_eigenfunctions, write_equilibrium, &
                        show_results, show_matrices, show_eigenfunctions, show_equilibrium
    namelist /filelist/ savename_eigenvalues, savename_efgrid, &
                        savename_matrix, savename_eigenvectors, savename_equil, &
                        savename_eigenfunctions, savename_config, output_folder, file_extension
    namelist /paramlist/ k2, k3, cte_rho0, cte_T0, cte_B02, cte_B03, cte_v02, cte_v03, &
                         cte_p0, p1, p2, p3, p4, p5, p6, p7, p8, &
                         alpha, beta, delta, theta, tau, lambda, nu, &
                         r0, rc, rj, Bth0, Bz0, V, j0, g

    filename = trim('output/' // trim(base_filename) // '.nml')
    open(unit=config_unit, file=filename, status='unknown', action='write')

    write(config_unit, gridlist)
    write(config_unit, equilibriumlist)
    write(config_unit, savelist)
    write(config_unit, filelist)
    write(config_unit, paramlist)
    close(config_unit)
  end subroutine configuration_tofile


  !> Prints basic information of the current configuration to the console.
  subroutine startup_info_toconsole()
    use mod_global_variables
    use mod_equilibrium_params, only: k2, k3

    character(20)                   :: char

    write(*, *) ""
    write(*, *) "------------------------------"
    write(*, *) "----------- LEGOLAS ----------"
    write(*, *) "------------------------------"
    write(*, *) ""

    write(*, *) "Running with the following configuration:"
    write(*, *) ""

    ! Geometry info
    write(*, *) "-- Geometry settings --"
    write(*, *) "Coordinate system  : ", geometry
    write(char, form_fout) x_start
    write(*, *) "Start              : ", adjustl(char)
    write(char, form_fout) x_end
    write(*, *) "End                : ", adjustl(char)
    write(char, form_int) gridpts
    write(*, *) "Gridpoints         : ", adjustl(char)
    write(char, form_int) gauss_gridpts
    write(*, *) "Gaussian gridpoints: ", adjustl(char)
    write(char, form_int) matrix_gridpts
    write(*, *) "Matrix gridpoints  : ", adjustl(char)
    write(*, *) ""

    ! Equilibrium info
    write(*, *) "-- Equilibrium settings --"
    write(*, *) "Equilibrium type   : ", equilibrium_type
    write(*, *) "Boundary conditions: ", boundary_type
    write(char, form_fout) gamma
    write(*, *) "Gamma              : ", adjustl(char)
    write(char, form_fout) k2
    write(*, *) "Wave number k2     : ", adjustl(char)
    write(char, form_fout) k3
    write(*, *) "Wave number k3     : ", adjustl(char)
    write(*, *) ""

    ! Save info
    write(*, *) "-- DataIO settings --"
    call logical_tostring(write_matrices, char)
    write(*, *) "Write matrices to file       : ", char
    call logical_tostring(write_eigenvectors, char)
    write(*, *) "Write eigenvectors to file   : ", char
    call logical_tostring(write_eigenfunctions, char)
    write(*, *) "Write eigenfunctions to file : ", char
    call logical_tostring(write_equilibrium, char)
    write(*, *) "Write equilibrium to file    : ", char
    call logical_tostring(show_results, char)
    write(*, *) "Showing results              : ", char
    call logical_tostring(show_matrices, char)
    write(*, *) "Showing matrices             : ", char
    call logical_tostring(show_eigenfunctions, char)
    write(*, *) "Showing eigenfunctions       : ", char
    call logical_tostring(show_equilibrium, char)
    write(*, *) "Showing equilibrium config   : ", char

    write(*, *) '----------------------------------------------------'
    write(*, *) ''

  end subroutine startup_info_toconsole

end module mod_output
