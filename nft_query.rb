require_relative "env"

# https://opensea.io/collection/wizards-dragons-game-v2
# https://etherscan.io/address/0x999e88075692bcee3dbc07e7e64cd32f39a1d3ab
# https://wnd.game
WND_CONTRACT_ADDRESS = "0x999e88075692bCeE3dBC07e7E64cD32f39A1D3ab"
WND_COLLECTION_NAME = "wizards-dragons-game-v2"

MONACO_CONTRACT_ADDRESS = "0x21bf3da0cf0f28da27169239102e26d3d46956e5"
MONACO_COLLECTION_NAME = "monacoplanetyacht"

contract_address = MONACO_CONTRACT_ADDRESS

traits_fetch_num_start = 0
traits_fetch_num_end = 30

traits_fetch_num_start = 30
traits_fetch_num_end = 40

# top traits
puts "Top Traits"
top_traits = R.zrange "nfts:#{contract_address}:trait_counts", traits_fetch_num_start, traits_fetch_num_end
top_traits_scores = R.zrange "nfts:#{contract_address}:trait_counts", traits_fetch_num_start, traits_fetch_num_end, with_scores: true
pp top_traits_scores
puts "\n\n"

# top nfts of top traits
puts "top nfts of top traits"
puts "-" * 60
top_traits.each do |trait|
  puts "top nfts of top traits - trait: #{trait}"
  trait_nft_ids = R.smembers "nfts:#{contract_address}:traits:#{trait}:nft_links"
  trait_nft_ids.each do |trait_nft_id|
    nft = R.hgetall "nfts:#{contract_address}:idx:#{trait_nft_id}:details"
    # pp nft
    # puts nft.f "last_sale_payment_token_usd_price"
    puts "NFT:"
    puts nft["permalink"]
    puts "Owner:"
    puts "https://opensea.io/#{nft["owner_address"]}"
    price = nft["last_sale_total_price"]
    if price
      puts "Last Sale:"
      puts (price.to_i * 10**-18).to_f
      puts nft["last_sale_payment_token_symbol"]
      puts Time.parse(nft["last_sale_transaction_timestamp"]).strftime("%b %d - %H:%M")
    end
    puts "\n\n"
  end
end
