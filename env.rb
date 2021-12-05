require "bundler"
Bundler.require :default
require "json"
require "yaml"
require "lib/load_config"

CONFIG  = load_config
SECRETS = load_secrets

MORALIS_API_KEY = SECRETS.f :moralis_api_key
raise "ConfigNotSetError - MORALIS_API_KEY" if MORALIS_API_KEY.nil? || MORALIS_API_KEY.empty?

R = Redis.new
