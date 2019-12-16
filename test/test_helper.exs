Code.require_file("support/shared.ex", __DIR__)
Logger.configure(level: :info)
ExUnit.start(exclude: [:proxy, :proxy_auth])
