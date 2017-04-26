#!/bin/sh
cc -fPIC -W -dynamiclib -undefined dynamic_lookup -o membrane_element_ffmpeg_swresample_converter.so -I"/usr/local/Cellar/erlang/19.3/lib/erlang/usr/include" -I"../membrane_common_c/c_src" -I"./deps/membrane_common_c/c_src" -lavutil -lswresample  "c_src/converter.c" "c_src/converter_lib.c"
