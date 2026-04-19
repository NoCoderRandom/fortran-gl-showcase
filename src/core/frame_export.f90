module core_frame_export
  use core_kinds, only: int8
  implicit none (type, external)
  private

  public :: export_rgba_frame_png

contains
  subroutine export_rgba_frame_png(out_dir, frame_index, width, height, rgba)
    character(len=*), intent(in) :: out_dir
    integer, intent(in), value :: frame_index
    integer, intent(in), value :: width
    integer, intent(in), value :: height
    integer(int8), intent(in) :: rgba(:)
    character(len=:), allocatable :: png_path
    character(len=:), allocatable :: ppm_path
    character(len=:), allocatable :: command
    integer :: unit_id

    if (size(rgba) < 4 * width * height) error stop "RGBA frame buffer too small."
    ppm_path = trim(out_dir)//"/frame_"//frame_label(frame_index)//".ppm"
    png_path = trim(out_dir)//"/frame_"//frame_label(frame_index)//".png"

    open(newunit=unit_id, file=ppm_path, access="stream", form="unformatted", status="replace", action="write")
    write (unit_id) "P6"//new_line("a")
    write (unit_id) trim(adjustl(int_to_string(width)))//" "//trim(adjustl(int_to_string(height)))//new_line("a")
    write (unit_id) "255"//new_line("a")
    call write_rgb_rows(unit_id, width, height, rgba)
    close(unit_id)

    command = "ffmpeg -y -loglevel error -i "//shell_quote(ppm_path)//" "//shell_quote(png_path)
    call execute_command_line(command, exitstat=unit_id)
    if (unit_id /= 0) error stop "ffmpeg failed while converting frame to PNG."
    call execute_command_line("rm -f "//shell_quote(ppm_path))
  end subroutine export_rgba_frame_png

  subroutine write_rgb_rows(unit_id, width, height, rgba)
    integer, intent(in), value :: unit_id
    integer, intent(in), value :: width
    integer, intent(in), value :: height
    integer(int8), intent(in) :: rgba(:)
    integer(int8), allocatable :: row(:)
    integer :: x
    integer :: y
    integer :: src
    integer :: dst

    allocate(row(3 * width))
    do y = height - 1, 0, -1
      do x = 0, width - 1
        src = 4 * (y * width + x)
        dst = 3 * x
        row(dst + 1) = rgba(src + 1)
        row(dst + 2) = rgba(src + 2)
        row(dst + 3) = rgba(src + 3)
      end do
      write (unit_id) row
    end do
    deallocate(row)
  end subroutine write_rgb_rows

  character(len=6) function frame_label(frame_index) result(label)
    integer, intent(in), value :: frame_index

    write (label, '(i6.6)') frame_index
  end function frame_label

  character(len=32) function int_to_string(value) result(text)
    integer, intent(in), value :: value

    write (text, '(i0)') value
  end function int_to_string

  function shell_quote(path) result(quoted)
    character(len=*), intent(in) :: path
    character(len=:), allocatable :: quoted

    quoted = "'"//replace_single_quotes(trim(path))//"'"
  end function shell_quote

  function replace_single_quotes(text) result(value)
    character(len=*), intent(in) :: text
    character(len=:), allocatable :: value
    integer :: i

    value = ""
    do i = 1, len_trim(text)
      if (text(i:i) == "'") then
        value = value//"'\''"
      else
        value = value//text(i:i)
      end if
    end do
  end function replace_single_quotes
end module core_frame_export
