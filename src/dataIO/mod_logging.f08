! =============================================================================
!> Main handler for console print statements. The level of information
!! printed to the console depends on the corresponding global variable
!! called <tt>logging_level</tt> defined in the parfile.
!! @note Values for <tt>logging_level</tt> can be set to
!!
!! - If <tt>logging_level = 0</tt>: only critical errors are printed, everything else is suppressed.
!! - If <tt>logging_level = 1</tt>: only errors and warnings are printed.
!! - If <tt>logging_level = 2</tt>: errors, warnings and info messages are printed. This
!!                                  is the default value
!! - If <tt>logging_level = 3+</tt>: prints all of the above, including debug messages. @endnote
module mod_logging
  use mod_global_variables, only: logging_level, str_len
  use mod_painting, only: paint_string
  implicit none

  !> exponential format
  character(8), parameter    :: exp_fmt = '(e20.8)'
  !> shorter float format
  character(8), parameter    :: dp_fmt = '(f20.8)'
  !> integer format
  character(4), parameter    :: int_fmt  = '(i8)'
  !> character used as variable to log non-strings
  character(20) :: char_log

  private

  public :: log_message
  public :: print_logo
  public :: print_console_info
  public :: print_whitespace
  public :: char_log, exp_fmt, dp_fmt, int_fmt

contains


  !> Logs messages to the console. Every message will be prepended by
  !! [  LEVEL  ] to indicate its type. If this is not desired, set
  !! <tt>use_prefix = .false.</tt>.
  !! @warning An error is thrown if a wrong level is passed. @endwarning
  !! @note The argument <tt>level</tt> can be 'error', 'warning', 'info' or 'debug'.
  !!       The 'error' level corresponds to throwing a critical error and stops code execution.
  !!       Error messages are printed in red, warnings in yellow, info messages have
  !!       default colouring and debug messages are in green.
  subroutine log_message(msg, level, use_prefix)
    use mod_exceptions, only: raise_exception

    !> the message to print to the console
    character(len=*), intent(in)  :: msg
    !> the level (severity) of the message
    character(len=*), intent(in)  :: level
    !> prefixes message type to string, default is <tt>.true.</tt>
    logical, intent(in), optional :: use_prefix

    character(len=str_len) :: msg_painted
    logical                :: add_prefix

    add_prefix = .true.
    if (present(use_prefix)) then
      add_prefix = use_prefix
    end if

    select case(level)
    case("error")
      call raise_exception(msg)
    case("warning")
      if (logging_level >= 1) then
        if (add_prefix) then
          call paint_string(" WARNING | " // msg, "yellow", msg_painted)
        else
          call paint_string("           " // msg, "yellow", msg_painted)
        end if
        write(*, *) msg_painted
      end if
    case("info")
      if (logging_level >= 2) then
        if (add_prefix) then
          write(*, *) " INFO    | " // msg
        else
          write(*, *) "           " // msg
        end if
      end if
    case("debug")
      if (logging_level >=3) then
        if (add_prefix) then
          call paint_string(" DEBUG   | " // msg, "green", msg_painted)
        else
          call paint_string("         | " // msg, "green", msg_painted)
        end if
        write(*, *) msg_painted
      end if
    case default
      call raise_exception("argument 'level' should be 'error', 'warning', 'info' or 'debug'")
      error stop
    end select
  end subroutine log_message


  !> Prints the Legolas logo to the console.
  !! The logo is wrapped in 1 whitespace at the top and
  !! two at the bottom. Only for logging level 'warning' (1) and above
  subroutine print_logo()
    use mod_version, only: LEGOLAS_VERSION

    !> array containing the different logo lines
    character(len=str_len) :: logo(11)
    !> whitespace prepended to logo
    character(len=3)       :: spaces_logo = ""
    !> whitespace prepended to versioning
    character(len=57)      :: spaces_v = ""
    integer :: i

    if (logging_level <= 1) then
      return
    end if

    logo(1)  = " __       ________  ________   _______   __          ___     __________ "
    logo(2)  = "|  |     |   ____ \|   ____ \ /   _   \ |  |        /   \   |   ______ \"
    logo(3)  = "|  |     |  |    \/|  |    \/|   / \   ||  |       /  _  \  |  |      \/"
    logo(4)  = "|  |     |  |__    |  |      |  |   |  ||  |      /  / \  \ |  \_______ "
    logo(5)  = "|  |     |   __/   |  | ____ |  |   |  ||  |     /  /   \  \\_______   \"
    logo(6)  = "|  |     |  |      |  | \_  ||  |   |  ||  |    /  /     \  \       |  |"
    logo(7)  = "|  |_____|  |____/\|  |___| ||   \_/   ||  |___/  /  /\___\  \      |  |"
    logo(8)  = "|_______/|________/|________| \_______/ |________/   \_______/      |  |"
    logo(9)  = "                                                        /\__________/  |"
    logo(10) = "Large Eigensystem Generator for One-dimensional pLASmas \______________/"
    logo(11) = spaces_v // "v. " // trim(adjustl(LEGOLAS_VERSION))

    call print_whitespace(1)
    do i = 1, size(logo)
      call paint_string(spaces_logo // trim(logo(i)), "cyan", logo(i))
      write(*, *) logo(i)
    end do
    call print_whitespace(2)
  end subroutine print_logo


  !> Prints various console messages showing geometry, grid parameters,
  !! equilibrium parameters etc. Only for logging level "info" or above.
  subroutine print_console_info()
    use mod_global_variables
    use mod_equilibrium_params, only: k2, k3

    if (logging_level <= 1) then
      return
    end if

    call log_message("---------------------------------------------", level="info")
    call log_message("              << Grid settings >>", level="info", use_prefix=.false.)
    call log_message("geometry             : " // adjustl(trim(geometry)), level="info", use_prefix=.false.)
    write(char_log, dp_fmt) x_start
    call log_message("grid start           : " // adjustl(char_log), level="info", use_prefix=.false.)
    write(char_log, dp_fmt) x_end
    call log_message("grid end             : " // adjustl(char_log), level="info", use_prefix=.false.)
    write(char_log, int_fmt) gridpts
    call log_message("gridpoints (base)    : " // adjustl(char_log), level="info", use_prefix=.false.)
    write(char_log, int_fmt) gauss_gridpts
    call log_message("gridpoints (Gauss)   : " // adjustl(char_log), level="info", use_prefix=.false.)
    write(char_log, int_fmt) matrix_gridpts
    call log_message("gridpoints (matrix)  : " // adjustl(char_log), level="info", use_prefix=.false.)

    call log_message("          << Equilibrium settings >>", level="info", use_prefix=.false.)
    call log_message("selected equilibrium : " // adjustl(trim(equilibrium_type)), level="info", use_prefix=.false.)
    call log_message("boundary conditions  : " // adjustl(trim(boundary_type)), level="info", use_prefix=.false.)
    write(char_log, dp_fmt) k2
    call log_message("wave number k2       : " // adjustl(char_log), level="info", use_prefix=.false.)
    write(char_log, dp_fmt) k3
    call log_message("wave number k3       : " // adjustl(char_log), level="info", use_prefix=.false.)

    if (flow .or. external_gravity .or. radiative_cooling .or. thermal_conduction .or. resistivity) then
      call log_message("            << Physics settings >>", level="info", use_prefix=.false.)
      if (flow) then
        call logical_tostring(flow, char_log)
        call log_message("flow                 : " // adjustl(char_log), level="info", use_prefix=.false.)
      end if
      if (external_gravity) then
        call logical_tostring(external_gravity, char_log)
        call log_message("external gravity     : " // adjustl(char_log), level="info", use_prefix=.false.)
      end if
      if (radiative_cooling) then
        call logical_tostring(radiative_cooling, char_log)
        call log_message("radiative cooling    : " // adjustl(char_log), level="info", use_prefix=.false.)
      end if
      if (thermal_conduction) then
        call logical_tostring(thermal_conduction, char_log)
        call log_message("thermal conduction   : " // adjustl(char_log), level="info", use_prefix=.false.)
      end if
      if (resistivity) then
        call logical_tostring(resistivity, char_log)
        call log_message("resistivity          : " // adjustl(char_log), level="info", use_prefix=.false.)
      end if
    end if

    call log_message("            << DataIO settings >>", level="info", use_prefix=.false.)
    call log_message("datfile name         : " // adjustl(trim(basename_datfile)), level="info", use_prefix=.false.)
    call log_message("output folder        : " // adjustl(trim(output_folder)), level="info", use_prefix=.false.)
    call logical_tostring(write_matrices, char_log)
    call log_message("write matrices       : " // adjustl(char_log), level="info", use_prefix=.false.)
    call logical_tostring(write_eigenfunctions, char_log)
    call log_message("write eigenfunctions : " // adjustl(char_log), level="info", use_prefix=.false.)
    call log_message("---------------------------------------------", level="info", use_prefix=.false.)
    call print_whitespace(1)
  end subroutine print_console_info


  !> Converts a given Fortran logical to a string "true" or "false".
  subroutine logical_tostring(boolean, boolean_string)
    !> logical to convert
    logical, intent(in)             :: boolean
    !> <tt>True</tt> if boolean == True, <tt>False</tt> otherwise
    character(len=20), intent(out)  :: boolean_string

    if (boolean) then
      boolean_string = 'True'
    else
      boolean_string = 'False'
    end if
  end subroutine logical_tostring


  !> Prints an empty line to the console.
  !! Only if logging level is 'warning' or above.
  subroutine print_whitespace(lines)
    !> amount of empty lines to print
    integer, intent(in) :: lines
    integer :: i

    if (logging_level >= 1) then
      do i = 1, lines
        write(*, *) ""
      end do
    end if
  end subroutine print_whitespace

end module mod_logging