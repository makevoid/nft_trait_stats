desc "Run Fetch"
task :run_fetch do
  sh "bundle exec ruby nft_fetch.rb"
end

desc "Run ML"
task :run_ml do
  sh "bundle exec ruby nft_ml.rb"
end

desc "Run"
task :run_indexer do
  sh "bundle exec ruby nft_indexer.rb"
end

desc "Run Query"
task :run_query do
  sh "bundle exec ruby nft_query.rb"
end

desc "Console"
task :console do
  sh "irb -r ./env.rb"
end

task run: :run_indexer
task default: :run
