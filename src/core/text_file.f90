module core_text_file
  implicit none (type, external)
  private

  public :: read_text_file

contains
  function read_text_file(path) result(contents)
    character(len=*), intent(in) :: path
    character(len=:), allocatable :: contents
    character(len=4096) :: line
    integer :: ios
    integer :: unit

    contents = ""
    open(newunit=unit, file=path, status="old", action="read", iostat=ios)
    if (ios /= 0) error stop "Failed to open text file."

    do
      read(unit, "(A)", iostat=ios) line
      if (ios /= 0) exit
      contents = contents//trim(line)//new_line("a")
    end do

    close(unit)
    if (ios > 0) error stop "Failed while reading text file."
  end function read_text_file
end module core_text_file
