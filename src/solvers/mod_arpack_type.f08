module mod_arpack_type
  use mod_logging, only: char_log, char_log2, dp_fmt, int_fmt, log_message
  use mod_global_variables, only: dp, dp_LIMIT

  implicit none

  type arpack_type
    !> reverse communication flag
    integer           :: ido
    !> maximum number of iterations
    integer           :: maxiter
    !> mode for the solver
    integer           :: mode
    !> specifies type of B-matrix ("I" = unit matrix, "G" = general)
    character(len=1)  :: bmat
    !> dimension of the eigenvalue problem
    integer           :: evpdim
    !> which eigenvalues to calculate
    character(len=2)  :: which
    !> number of eigenvalues to calculate
    integer           :: nev
    !> stopping criteria, relative accuracy of Ritz eigenvalues
    real(dp)          :: tol
    !> residual vector used for initialisation
    complex(dp), allocatable  :: residual(:)
    !> number of Arnoldi basis vectors
    integer                   :: ncv
    !> contains the Arnoldi basis vectors
    complex(dp), allocatable  :: arnoldi_vectors(:, :)
    !> integer array containing mode and parameters
    integer                   :: iparam(11)
    !> integer array containing pointers to mark work array locations
    integer                   :: ipntr(14)
    !> complex work array, length 3N
    complex(dp), allocatable  :: workd(:)
    !> complex work array, length lworkl
    complex(dp), allocatable  :: workl(:)
    !> length of workl array, at least 3*ncv**2 + 5*ncv
    integer                   :: lworkl
    !> real work array, length ncv
    real(dp), allocatable     :: rwork(:)
    !> info parameter
    integer                   :: info
    !> if .true., also calculate eigenvectors
    logical                   :: rvec
    !> specifies form of basis: "A" = nev Ritz vectors, "P" = nev Schur vectors
    character(len=1)          :: howmny
    !> logical array of dimension ncv, selects Ritz vectors
    logical, allocatable      :: select_vectors(:)
    !> represents the shift (only referenced if shift-invert is used)
    complex(dp)               :: sigma
    !> work array for eigenvalues, size 2*ncv
    complex(dp), allocatable  :: workev(:)
    !> number of converged eigenvalues
    integer                   :: nconv

    contains

      procedure, public   :: initialise
      procedure, public   :: set_mode
      procedure, public   :: parse_znaupd_info
      procedure, public   :: parse_zneupd_info
      procedure, public   :: tear_down

      procedure, private  :: set_nev
      procedure, private  :: set_which
      procedure, private  :: set_maxiter

  end type arpack_type

  private

  public :: arpack_type

contains

  subroutine initialise(this, evpdim)
    !> reference to arpack_type
    class(arpack_type)  :: this
    !> dimension of eigenvalue problem
    integer, intent(in) :: evpdim

    ! set dimension and related parameters
    this % evpdim = evpdim
    call this % set_nev()
    call this % set_which()
    call this % set_maxiter()
    this % ncv = min(this % evpdim, 2 * this % nev)
    this % tol = dp_LIMIT

    ! allocate and initialise Arnoldi vectors
    allocate(this % arnoldi_vectors(this % evpdim, this % ncv))
    this % arnoldi_vectors = (0.0d0, 0.0d0)

    ! allocate work arrays
    this % lworkl = 3 * this % ncv * (this % ncv + 2)
    allocate(this % workl(this % lworkl))
    allocate(this % rwork(this % ncv))
    allocate(this % workd(3 * this % evpdim))

    ! set parameters and solver mode
    this % iparam(1) = 1    ! select implicit shifts (1 = restart)
    this % iparam(3) = this % maxiter   ! maximum number of iterations
    this % iparam(4) = 1    ! blocksize, HAS to be 1
    this % ido = 0    ! 0 means first call to interface
    this % info = 0   ! info = 0 at input means use a random residual starting vector
    allocate(this % residual(this % evpdim))

    ! allocate eigenvalue-related things
    allocate(this % select_vectors(this % ncv))
    allocate(this % workev(2 * this % ncv))
    this % rvec = .true.    ! always calculate eigenvectors, not expensive in ARPACK
    this % howmny = "A"     ! currently hardcoded to Ritz vectors
  end subroutine initialise


  subroutine set_mode(this, mode)
    class(arpack_type)  :: this
    integer, intent(in) :: mode

    if (mode < 1 .or. mode > 3) then
      write(char_log, int_fmt) mode
      call log_message( &
        "mode must be 1, 2 or 3 but mode = " // adjustl(trim(char_log)) &
          // " was given", &
        level="error" &
      )
    end if
    this % mode = mode
    this % iparam(7) = this % mode
  end subroutine set_mode


  subroutine parse_znaupd_info(this, converged)
    class(arpack_type)    :: this
    logical, intent(out)  :: converged

    converged = .false.

    select case(this % info)
    case(0)
      converged = .true.
    case(1)
      call log_message("ARPACK failed to converge! (maxiter reached)", level="warning")
      write(char_log, int_fmt) this % maxiter
      call log_message( &
        "number of iterations: " // adjustl(trim(char_log)), &
        level="warning", &
        use_prefix=.false. &
      )
      write(char_log, int_fmt) this % iparam(5)
      write(char_log2, int_fmt) this % nev
      call log_message( &
        "number of converged eigenvalues: " // adjustl(trim(char_log)) // &
        " / " // adjustl(trim(char_log2)), &
        level="warning", &
        use_prefix=.false. &
      )
    case(3)
      call log_message( &
        "znaupd: no shifts could be applied during Arnoldi iteration", &
        level="error" &
      )
    case(-6)
      call log_message("znaupd: bmat must be 'I' or 'G'", level="error")
    case(-8)
      call log_message( &
        "znaupd: error from LAPACK eigenvalue calculation", &
        level="error" &
      )
    case(-11)
      call log_message("mode = 1 and bmat = 'G' are incompatible", level="error")
    case(-9999)
      call log_message("ARPACK could not build, something went wrong", level="error")
    case default
      write(char_log, int_fmt) this % info
      call log_message( &
        "znaupd: unexpected info = " // adjustl(trim(char_log)) // " encountered", &
        level="error" &
      )
    end select
  end subroutine parse_znaupd_info


  subroutine parse_zneupd_info(this)
    class(arpack_type)  :: this

    select case(this % info)
    case(0)
      return
    case(-8)
      call log_message( &
        "zneupd: error from LAPACK eigenvalue calculation", &
        level="error" &
      )
    case(-9)
      call log_message( &
        "zneupd: error from LAPACK eigenvector calculation (ztrevc)", &
        level="error" &
      )
    case(-14)
      call log_message( &
        "zneupd: no eigenvalues with sufficient accuracy found", &
        level="error" &
      )
    case(-15)
      call log_message( &
        "zneupd: different count for converged eigenvalues than znaupd", &
        level="error" &
      )
    case default
      write(char_log, int_fmt) this % info
      call log_message( &
        "zneupd: unexpected info = " // trim(adjustl(char_log)) // " value", &
        level="error" &
      )
    end select
  end subroutine parse_zneupd_info


  subroutine set_nev(this)
    use mod_global_variables, only: number_of_eigenvalues

    class(arpack_type)  :: this

    if (number_of_eigenvalues <= 0) then
      write(char_log, int_fmt) number_of_eigenvalues
      call log_message( &
        "number_of_eigenvalues must be >= 0, but is equal to " &
          // adjustl(trim(char_log)), &
        level="error" &
      )
      return
    end if
    if (number_of_eigenvalues >= this % evpdim) then
      write(char_log, int_fmt) number_of_eigenvalues
      write(char_log2, int_fmt) this % evpdim
      call log_message( &
        "number_of_eigenvalues larger than matrix size! (" &
          // trim(adjustl(char_log)) // " > " // trim(adjustl(char_log2)) // ")", &
        level="error" &
      )
      return
    end if
    this % nev = number_of_eigenvalues
  end subroutine set_nev


  subroutine set_which(this)
    use mod_global_variables, only: which_eigenvalues

    class(arpack_type)  :: this
    character(2)        :: allowed_which(6) = ["LM", "SM", "LR", "SR", "LI", "SI"]

    if (.not. any(which_eigenvalues == allowed_which)) then
      call log_message( &
        "which_eigenvalues = " // which_eigenvalues // " is invalid", &
        level="error" &
      )
      return
    end if
    this % which = which_eigenvalues
  end subroutine set_which


  subroutine set_maxiter(this)
    use mod_global_variables, only: maxiter

    class(arpack_type)  :: this

    ! is maxiter is not set in the parfile it's still 0, default to 10*N
    if (maxiter == 0) then
      maxiter = 10 * this % evpdim
    else if (maxiter < 0) then
      write(char_log, int_fmt) maxiter
      call log_message( &
        "maxiter has to be positive, but is equal to " &
          // trim(adjustl(char_log)), level="error" &
      )
      return
    else if (maxiter < 10 * this % evpdim) then
      write(char_log, int_fmt) maxiter
      write(char_log2, int_fmt) 10 * this % evpdim
      call log_message( &
        "maxiter is below recommended 10*N: (" &
          // trim(adjustl(char_log)) // " < " // trim(adjustl(char_log2)) // ")", &
        level="warning" &
      )
    end if
    this % maxiter = maxiter
  end subroutine set_maxiter


  subroutine tear_down(this)
    class(arpack_type)  :: this

    if (allocated(this % arnoldi_vectors)) then
      deallocate(this % arnoldi_vectors)
    end if
    if (allocated(this % workl)) then
      deallocate(this % workl)
    end if
    if (allocated(this % rwork)) then
      deallocate(this % rwork)
    end if
    if (allocated(this % workd)) then
      deallocate(this % workd)
    end if
    if (allocated(this % residual)) then
      deallocate(this % residual)
    end if
    if (allocated(this % select_vectors)) then
      deallocate(this % select_vectors)
    end if
    if (allocated(this % workev)) then
      deallocate(this % workev)
    end if
  end subroutine tear_down



end module mod_arpack_type