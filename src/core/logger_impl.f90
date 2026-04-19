submodule (core_logger) core_logger_impl
  implicit none (type, external)
contains
  module procedure log_info
    write (*, '(a)') '[info]  ' // trim(message)
  end procedure log_info

  module procedure log_warn
    write (*, '(a)') '[warn]  ' // trim(message)
  end procedure log_warn

  module procedure log_error
    write (*, '(a)') '[error] ' // trim(message)
  end procedure log_error
end submodule core_logger_impl

