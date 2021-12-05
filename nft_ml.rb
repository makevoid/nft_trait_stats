require_relative "env"

module MoralisHeaders
  def moralis_headers
    {
      "X-API-Key": MORALIS_API_KEY,
    }
  end
end

class Collection
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
    JSON.parse resp
  end

  def nfts(collection_address:, limit: 12, offset: 0)
    cache "collectors:address:#{collection_address}:offset:#{offset}" do
      collection_nfts collection_address: collection_address, limit: limit, offset: offset
    end
  end
end


DEBUG = true

class CollectionFetcher
  def self.fetch(collection:)
    new(collection: collection).fetch
  end

  attr_reader :collection

  def initialize(collection:)
    @collection = collection
  end

  def fetch
    collection_id = collection
    nfts = NFT.fetch collection: collection
    nfts.each do |nft|
      # nft is an hash containing these arguments:
      #  "token_address": "0x057Ec652A4F150f7FF94f089A38008f49a0DF88e",
      #  "token_id": "15",
      #  "contract_type": "ERC721",
      #  "token_uri": "string",
      #  "metadata": "string",
      #  "synced_at": "string",
      #  "amount": "1",
      #  "name": "CryptoKitties",
      #  "symbol": "RARI"
      R.hset "nft:#{nft.f "token_address"}:token_id", "token_id", nft.f("token_id")
      R.hset "nft:#{nft.f "token_address"}:contract_type", "contract_type", nft.f("contract_type")
      R.hset "nft:#{nft.f "token_address"}:token_uri", "token_uri", nft.f("token_uri")
      R.hset "nft:#{nft.f "token_address"}:metadata", "metadata", nft.f("metadata")
      R.hset "nft:#{nft.f "token_address"}:synced_at", "synced_at", nft.f("synced_at")
      R.hset "nft:#{nft.f "token_address"}:amount", "amount", nft.f("amount")
      R.hset "nft:#{nft.f "token_address"}:name", "name", nft.f("name")
      R.hset "nft:#{nft.f "token_address"}:symbol", "symbol", nft.f("symbol")
    end
    nfts
  end
end

if $0 == __FILE__
  CollectionFetcher.fetch collection: "CryptoKitties"
end
