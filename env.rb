require "bundler"
Bundler.require :default
require "json"
require "yaml"
require "time"
require_relative "lib/monkeypatches"
require_relative "lib/load_config"
include LoadConfig

PATH = File.expand_path "../", __FILE__

CONFIG  = load_config
SECRETS = load_secrets

MORALIS_API_KEY = SECRETS.f :moralis_api_key
raise "ConfigNotSetError - MORALIS_API_KEY" if MORALIS_API_KEY.nil? || MORALIS_API_KEY.empty?

R = Redis.new
