require 'dry/container'

module BridgeApi
  class Dependencies
    extend Dry::Container::Mixin

    def self.setup(client, token)
      # here should go all initialization

      puts '📑 Fetching all categories for future reference'
      register(:categories, memoize: true) do
        # categories, indexed by their id
        client.categories(token: token)
              .flat_map { |top_level| [top_level, top_level['categories']].flatten }
              .group_by { |category| category['id'] }
              .transform_values(&:first)
      end
    end
  end
end
