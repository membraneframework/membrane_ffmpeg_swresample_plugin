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
  ],
  linux: [
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
  ],
  windows32: [
    nif: [
      membrane_element_ffmpeg_swresample_converter: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "./ext/include",
          "converter.c",
          "converter_lib.c",
        ],
        libs: [
          "ext/windows/32/avutil.lib",
          "ext/windows/32/swresample.lib",
        ],
      ]
    ]
  ],
  windows64: [
    nif: [
      membrane_element_ffmpeg_swresample_converter: [
        includes: [
          "./ext/include",
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "converter.c",
          "converter_lib.c",
        ],
        libs: [
          "ext/windows/64/avutil.lib",
          "ext/windows/64/swresample.lib",
        ],

      ]
    ]
  ]
