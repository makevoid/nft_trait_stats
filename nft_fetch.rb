require_relative "env"

module CacheLib
  def cache_set(cache_key:, value:)
    one_day = 86400 # seconds, 1 day
    timeout = one_day * 10
    value_yaml = JSON.dump value
    R.setex cache_key, timeout, value_yaml
    # res = R.setex cache_key, timeout, value_yaml
    # puts "redis setex #{cache_key.inspect}: #{res}" if DEBUG
    value
  end

  def cache_exists?(cache_key)
    R.exists? cache_key
  end

  def cache_read(cache_key:)
    value = R.get cache_key
    # puts "got value from cache - #{cache_key.inspect}" if DEBUG
    JSON.parse value
  end

  def cache(cache_key, &block)
    if cache_exists? cache_key
      cache_read cache_key: cache_key
    else
      cache_set cache_key: cache_key, value: block.()
    end
  end
end

module MoralisHeaders
  def moralis_headers
    {
      "X-API-Key": MORALIS_API_KEY,
    }
  end
end

class MoralisCollection
  include CacheLib
  include MoralisHeaders

  def self.nfts(collection_address:, limit: 12, offset: 0)
    new.nfts collection_address: collection_address, limit: limit, offset: offset
  end

  def collection_nfts(collection_address:, limit: 12, offset: 0)
    query = {
      address: collection_address,
      chain:   "eth",
      format:  "decimal",
      limit:   limit,
      offset:  offset,
      # TODO
      # order: "ASC", # (blocknumber ASC)
    }
    # TODO: validate address - presence, length and hex format - collection_address
    url = "https://deep-index.moralis.io/api/v2/nft/#{collection_address}"

    resp = Excon.get url, query: query, headers: moralis_headers
    resp = resp.body
    resp = JSON.parse resp
    result = resp.f "result"
    result.each do |nft|
      nft.delete "token_uri"
    end
    p result
    result
  end

  def nfts(collection_address:, limit: 12, offset: 0)
    cache "collection:address:#{collection_address}:offset:#{offset}" do
      collection_nfts collection_address: collection_address, limit: limit, offset: offset
    end
  end
end

# OpenseaCollectionInfo
class CollectionInfo
  include CacheLib

  def self.fetch(collection_name:)
    new.fetch collection_name: collection_name
  end

  def collection_info(collection_name:)
    query = {
    }

    url = "https://api.opensea.io/api/v1/collection/#{collection_name}"

    # contract_address = "0x..."
    # url = "https://api.opensea.io/api/v1/asset/#{contract_address}/1/"

    resp = Excon.get url, query: query, headers: { }
    resp = resp.body
    resp = JSON.parse resp
    resp = resp.f "collection"
    ignored_keys = %w[
      payment_tokens
      description
      editors
    ]
    ignored_keys.each do |ignored_key|
      resp.delete ignored_key
    end
    stats = resp.f "stats"
    count = stats.f "count"
    resp["nfts_count"] = count.to_i
    resp
  end

  def fetch(collection_name:)
    cache "collections:name:#{collection_name}" do
      collection_info collection_name: collection_name
    end
  end
end

# OpenseaCollection
class NFT
  include CacheLib

  attr_reader :nft_idx

  def self.fetch(collection_address:, nft_idx:)
    new.fetch collection_address: collection_address, nft_idx: nft_idx
  end

  def collection_nfts(collection_address:, nft_idx:)
    query = { }
    url = "https://api.opensea.io/api/v1/asset/#{collection_address}/#{nft_idx}/"
    resp = Excon.get url, query: query, headers: { }
    resp = resp.body
    resp = JSON.parse resp
    ignored_keys = %w[
      background_color
      animation_url
      animation_original_url
      image_original_url
      image_preview_url
      image_url
      related_assets
      supports_wyvern
      token_metadata
      description
      asset_contract
      external_link
      collection
      orders
      top_ownerships
    ]
    ignored_keys.each do |ignored_key|
      resp.delete ignored_key
    end
    resp
  end

  def fetch(collection_address:, nft_idx:)
    cache "nfts:collection:#{collection_address}:idx:#{nft_idx}" do
      collection_nfts collection_address: collection_address, nft_idx: nft_idx
    end
  end
end

DEBUG = true

class CollectionFetcher
  def self.fetch(collection_name:, collection_address:)
    new(collection_name: collection_name, collection_address: collection_address).fetch
  end

  attr_reader :collection_name, :collection_address

  def initialize(collection_name:, collection_address:)
    @collection_name = collection_name
    @collection_address = collection_address
  end

  def fetch
    # reset
    # R.del "collections:name:#{collection_name}:info"
    # R.flushdb # Warning: resets everything

    collection_info = CollectionInfo.fetch collection_name: collection_name
    R.set "collections:name:#{collection_name}:info", collection_info.to_json

    nfts_count = collection_info.f "nfts_count"
    R.set "collections:name:#{collection_name}:count", nfts_count

    # 1.upto(nfts_count) do |nft_idx|
    concurrency_size = 10
    1.step(nfts_count, concurrency_size).each do |nft_idx|
      threads = []
      0.upto(concurrency_size - 1) do |thread_idx|
        threads << Thread.new { fetch_nft nft_idx: nft_idx + thread_idx }
      end
      threads.map(&:join)
    end
    true
  end

  def fetch_nft(nft_idx:)
    puts "fetching ##{nft_idx}"
    nft_data = NFT.fetch collection_address: collection_address, nft_idx: nft_idx
    if nft_data["detail"] == "Request was throttled."
      puts "Request throttled, exiting - NFT idx: #{nft_idx}"
      exit
    end
    save_nft_data nft_data: nft_data, nft_idx: nft_idx
  end

  def flatten_hash(hash:)
    hash.each_with_object({ }) do |(k, v), h|
      if v.is_a? Hash
        flatten_hash(hash: v).map do |h_k, h_v|
          h["#{k}_#{h_k}"] = h_v
        end
      else
        h[k] = v
      end
    end
  end

  def transform_trait(trait:)
    name = "#{trait.f "trait_type"} - #{trait.f "value"}"
    {
      "name"        => name,
      "trait_count" => trait.f("trait_count"),
    }
  end

  def transform_traits(traits:)
    traits.map do |trait|
      transform_trait trait: trait
    end
  end

  def save_nft_data nft_data:, nft_idx:
    nft_key = "nfts:#{collection_address}:idx:#{nft_idx}:details"
    traits = nft_data.delete "traits"
    if traits
      traits = transform_traits traits: traits
      traits = traits.to_json
    end
    nft_data["traits"] = traits
    # raise nft_data.inspect
    nft_data = flatten_hash hash: nft_data
    # TODO: we can delete the keys before flattening to save computing time
    nft_data_ignored_keys.each do |ignored_key|
      nft_data.delete ignored_key
    end
    nft_data.transform_values! { |value| value&.to_s { |val| val.strip } }
    R.hmset nft_key, *nft_data
    true
  end

  def nft_data_ignored_keys
    %w[
      decimals
      owner_config
      sell_orders
      creator
      last_sale_asset_token_id
      last_sale_asset_decimals
      last_sale_asset_bundle
      last_sale_auction_type
      last_sale_payment_token_id
      last_sale_payment_token_image_url
      last_sale_payment_token_name
      last_sale_payment_token_decimals
      last_sale_transaction_from_account_config
      last_sale_transaction_to_account_config
      last_sale_transaction_transaction_index
      is_presale
      auctions
    ]
  end
end

# https://opensea.io/collection/wizards-dragons-game-v2
# https://etherscan.io/address/0x999e88075692bcee3dbc07e7e64cd32f39a1d3ab
# https://wnd.game
WND_CONTRACT_ADDRESS = "0x999e88075692bCeE3dBC07e7E64cD32f39A1D3ab"
WND_COLLECTION_NAME = "wizards-dragons-game-v2"

MONACO_CONTRACT_ADDRESS = "0x21bf3da0cf0f28da27169239102e26d3d46956e5"
MONACO_COLLECTION_NAME = "monacoplanetyacht"

# COLLECTION_NAME  = WND_COLLECTION_NAME
# CONTRACT_ADDRESS = WND_CONTRACT_ADDRESS

COLLECTION_NAME  = MONACO_COLLECTION_NAME
CONTRACT_ADDRESS = MONACO_CONTRACT_ADDRESS

if $0 == __FILE__
  CollectionFetcher.fetch collection_name: COLLECTION_NAME, collection_address: CONTRACT_ADDRESS
end
