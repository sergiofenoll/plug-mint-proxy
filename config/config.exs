# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

defmodule CH do
  def system_boolean(name) do
    case String.downcase(System.get_env(name) || "") do
      "true" -> true
      "yes" -> true
      "1" -> true
      "on" -> true
      _ -> false
    end
  end
end

config :plug_mint_proxy,
  author: :"mu-semtech",
  log_backend_communication: CH.system_boolean("LOG_BACKEND_COMMUNICATION"),
  log_frontend_communication: CH.system_boolean("LOG_FRONTEND_COMMUNICATION"),
  log_request_processing: CH.system_boolean("LOG_FRONTEND_PROCESSING"),
  log_response_processing: CH.system_boolean("LOG_BACKEND_PROCESSING"),
  log_connection_setup: CH.system_boolean("LOG_CONNECTION_SETUP"),
  log_request_body: CH.system_boolean("LOG_REQUEST_BODY"),
  log_response_body: CH.system_boolean("LOG_RESPONSE_BODY"),
  log_connection_failures: CH.system_boolean("LOG_CONNECTION_FAILURES"),
  log_connection_pool_processing: CH.system_boolean("LOG_CONNECTION_POOL_PROCESSING"),
  log_proxy_url_on_call: CH.system_boolean("LOG_PROXY_URL_ON_CALL")

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :plug_mint_proxy, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:plug_mint_proxy, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"
