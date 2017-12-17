return {
  functions = {
    {
      name = "f1",
      parameters = { { "buffer", "buffer" } },
      return_type = "integer",
      since = 1
    },
    {
      name = "f2",
      parameters = { { "buffer", "buffer" } },
      return_type = "integer",
      since = 2
    },
    {
      name = "f3",
      parameters = { { "buffer", "buffer" } },
      return_type = "integer",
      since = 3
    },
    {
      deprecated_since = 1,
      name = "f4",
      parameters = { { "buffer", "buffer" } },
      return_type = "integer",
      since = 2
    },
    {
      deprecated_since = 1,
      name = "f5",
      parameters = { { "buffer", "buffer" } },
      return_type = "integer",
      since = 3
    },
    {
      deprecated_since = 2,
      name = "f6",
      parameters = { { "buffer", "buffer" } },
      return_type = "integer",
      since = 3
    },
  },
  version = {
    api_compatible = 0,
    api_level = 3
  }
}
