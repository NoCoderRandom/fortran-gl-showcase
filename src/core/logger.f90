module core_logger
  implicit none (type, external)
  private

  public :: log_error, log_info, log_warn

  interface
    module subroutine log_info(message)
      character(len=*), intent(in) :: message
    end subroutine log_info

    module subroutine log_warn(message)
      character(len=*), intent(in) :: message
    end subroutine log_warn

    module subroutine log_error(message)
      character(len=*), intent(in) :: message
    end subroutine log_error
  end interface
end module core_logger

