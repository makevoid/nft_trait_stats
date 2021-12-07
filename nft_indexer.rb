require_relative "env"

class Indexer
  def self.create_index(collection_name:, collection_address:)
    new(collection_name: collection_name, collection_address: collection_address).create_index
  end

  attr_reader :collection_name, :collection_address

  def initialize(collection_name:, collection_address:)
    @collection_name    = collection_name
    @collection_address = collection_address
  end

  def collection_count
    index = R.get "collections:name:#{collection_name}:count"
    index.to_i
  end

  def create_index
    index_traits
    index_nft_trait_links
  end

  def index_nft_trait_links
    1.upto(collection_count) do |idx|
      puts "Indexing Link ##{idx}"
      index_nft_trait_link nft_idx: idx
    end
  end

  def index_nft_trait_link(nft_idx:)
    nft_key = "nfts:#{collection_address}:idx:#{nft_idx}:details"
    link_key = "nfts:#{collection_address}:nft:#{nft_idx}:trait_links"
    traits = R.hget nft_key, "traits"
    return if !traits || traits.empty?
    traits = JSON.parse traits

    traits.each do |trait|
      name = trait.f "name"
      trait_name = trait_transform_name name: name

      # add trait_links to nft
      R.sadd link_key, trait_name

      # link nfts to traits
      trait_key = "nfts:#{collection_address}:traits:#{trait_name}:nft_links"
      R.sadd trait_key, nft_idx
    end
  end

  def index_traits
    1.upto(collection_count) do |idx|
      puts "Indexing ##{idx}"
      index_traits_nft nft_idx: idx
    end
  end

  def trait_transform_name(name:)
    name.downcase.gsub /\s+/, "_"
  end

  def index_traits_nft(nft_idx:)
    nft_key = "nfts:#{collection_address}:idx:#{nft_idx}:details"
    traits = R.hget nft_key, "traits"
    return if !traits || traits.empty?
    traits = JSON.parse traits

    traits.each do |trait|
      name = trait.f "name"
      name = trait_transform_name name: name
      trait_count = trait.f "trait_count"
      R.zadd "nfts:#{collection_address}:trait_counts", trait_count, name
    end
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
  Indexer.create_index collection_name: COLLECTION_NAME, collection_address: CONTRACT_ADDRESS
end
