require 'dry/container'

module BridgeApi
  class Dependencies
    extend Dry::Container::Mixin

    def self.setup(client)
      # here should go all initialization

      register(:client, memoize: true) do
        # we can reuse this client everywhere
        client
      end

      puts '📑 Fetching all categories for future reference'
      register(:categories, memoize: true) do
        # categories, indexed by their id
        client.categories
              .flat_map { |top_level| [top_level, top_level['categories']].flatten }
              .group_by { |category| category['id'] }
              .transform_values(&:first)
      end
    end
  end
end
