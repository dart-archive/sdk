Pod::Spec.new do |s|
  s.name         = "DartinoPod"
  s.version      = "0.1"
  s.source_files = "include/**/*.h", "src/vm/osx_ia32_workaround.c"
  s.header_mappings_dir = "."
end
