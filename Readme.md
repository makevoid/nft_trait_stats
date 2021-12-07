# nft-trait-stats

Opensea NFT traits / stats analyzer

Status: Early stage development


Featuring:
- Ruby
- Redis
- OpenSea NFT API

### Configuration

Replace `CONTRACT_ADDRESS` and `COLLECTION_NAME` configs with the correct values from the NFT collection.

### Prerequisites

Run redis (e.g. by running the server command)

    redis-server

### Usage

Run the commands in this order:

    rake run_fetch

This will fetch the NFT data and populate your redis database

    rake run_indexer

This will index the data including traits

    rake run_query

This command will execute a query on the top traits giving you a summary of the NFT data and of owners of the top NFTs of the collection.


---


If you like the project please give it a star :)


Ask questions on twitter / DMs and open a github issue if you find a problem with the tool.

Enjoy!

@makevoid
