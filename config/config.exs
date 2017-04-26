use Mix.Config

config :membrane_element_ffmpeg_swresample, :bundlex_lib,
  macosx: [
    nif: [
      membrane_element_ffmpeg_swresample_converter: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "converter.c",
          "converter_lib.c",
        ],
        libs: [
          "avutil",
          "swresample",
        ],
        pkg_configs: [
        ]
      ]
    ]
  ]
