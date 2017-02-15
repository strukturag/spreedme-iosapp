solutions = [
  { "name"        : "sorteddictionary",
    "url"         : "https://github.com/strukturag/SortedDictionary.git@sorteddictionary_v102",
    "deps_file"   : "DEPS",
    "managed"     : True,
  },

  { "name"        : "PocketSocket",
    "url"         : "https://github.com/strukturag/PocketSocket.git@8135eef2be6d584da1e1fbaafa0ab5d966c55e8e",
    "deps_file"   : "DEPS",
    "managed"     : True,
  },

  { "name"        : "DAKeyboardControl",
    "url"         : "https://github.com/strukturag/DAKeyboardControl.git@9d634576297981e38a20728efa2067659c4219df",
    "deps_file"   : "DEPS",
    "managed"     : True,
  },

  { "name"        : "ios-file-browser",
    "url"         : "https://github.com/strukturag/file-browser-ios.git@c99c0e0f3a2a3d38e3fbdbf1b621d40fd1edf138",
    "deps_file"   : "DEPS",
    "managed"     : True,
  },

  { "name"        : "ios_font_awesome",
    "url"         : "https://github.com/strukturag/ios-fontawesome.git@a285913a2681c358fb1cb1a9ed2c52bd0c50df3e",
    "deps_file"   : "DEPS",
    "managed"     : True,
  },

  { "name"        : "AFNetworking",
    "url"         : "https://github.com/AFNetworking/AFNetworking.git@49f2f8c9a907977ec1b3afb182404ae0a6bce883",
    "deps_file"   : "DEPS",
    "managed"     : True,
  },

  { "name"        : "UICKeyChainStore",
    "url"         : "https://github.com/strukturag/UICKeyChainStore.git@c47e7dffde3c653126141d7794e72acb751237cd",
    "deps_file"   : "DEPS",
    "managed"     : True,
  },
]

hooks = [
  {
    "name": "Sync webrtc",
    "pattern": ".",
    "action": ["bash", "sync_webrtc.sh", "webrtc_fork_v1.0"],
  },
]

target_os = ["ios", "mac"]
