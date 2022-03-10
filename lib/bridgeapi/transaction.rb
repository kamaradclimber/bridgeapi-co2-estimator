require_relative 'dependencies'

module BridgeApi
  module Transaction
    class Transaction
      def initialize(transaction_hash)
        @description = transaction_hash['clean_description']
        @full_description = transaction_hash['bank_description']
        @amount = transaction_hash['amount']
        @currency_code = transaction_hash['currency_code']
        @date = Date.parse(transaction_hash['date'])
        @category_id = transaction_hash['category_id']
        @original_hash = transaction_hash
      end

      # @return [String]
      attr_reader :description

      # @return [String]
      attr_reader :full_description

      # @return [Float]
      attr_reader :amount

      # @return [String]
      attr_reader :currency_code

      # @return [Date]
      attr_reader :date

      # @return [String]
      attr_reader :category_id

      # @param transaction_hash [Hash]
      # @return [BridgeApi::Transaction::Transaction] hopefully a subclass of Transaction
      def self.build(transaction_hash)
        transaction = Transaction.new(transaction_hash)
        matching_classes = child_classes.select do |klass|
          klass.match?(transaction)
        end
        matching = matching_classes.min do |k1, k2|
          if k1 < k2
            -1
          elsif k2 < k1
            1
          else
            0
          end
        end
        # puts "Found #{matching_classes.size} classes matching #{transaction.short_s}, selecting #{matching} as the most precise"
        transaction = matching.new(transaction_hash) if matching
        transaction
      end

      def self.child_classes
        ObjectSpace.each_object(Class).select { |klass| klass < self }
      end

      # @param _transaction [BridgeApi::Transaction::Transaction]
      # @return [Boolean] true if the class recognized the transaction
      def self.match?(_transaction)
        raise NotImplementedError
      end

      # @return [Float, nil] estimation of co2 impact or nil if don't know
      def co2_kg
        nil
      end

      def short_s
        short_currency = currency_code == 'EUR' ? '€' : currency_code
        "#{date}: #{description} #{amount}#{short_currency}"
      end

      def icon
        amount.negative? ? '🔻' : '➕'
      end

      def to_s
        short_currency = currency_code == 'EUR' ? '€' : currency_code
        co2 = ", 🏭 #{co2_kg.round(2)}kg" if co2_kg&.positive?
        "#{icon} #{date} #{description} (#{category_name}): #{amount}#{short_currency} #{co2}"
      end

      def category_name
        Dependencies.resolve(:categories)[category_id]['name']
      end
    end

    class TrainTransaction < Transaction
      def self.match?(transaction)
        transaction.category_id == 197
      end

      def co2_kg
        # approximation: 2.12km/€ (based on Chartres-Strasbourg-Chartres at 277€ for 2), 1.73gCo2/km
        # source: https://www.sncf-connect.com/aide/calcul-des-emissions-de-co2-sur-votre-trajet-en-train
        amount.abs * 2.12 * 1.73 / 1000
      end

      def icon
        '🚄'
      end
    end

    class TER < TrainTransaction
      def self.match?(transaction)
        # FIXME: we should probably detect if the transaction is recuring
        # currently detection is only based on price
        TrainTransaction.match?(transaction) && transaction.amount < -30
      end

      def co2_kg
        # approximation: 7.82km/€, 24.81 gCO2/km
        # source: https://www.sncf-connect.com/aide/calcul-des-emissions-de-co2-sur-votre-trajet-en-train
        amount.abs * 7.82 * 24.81 / 1000
      end

      def icon
        '🚃'
      end
    end

    class VehiculeFuel < Transaction
      def self.match?(transaction)
        transaction.category_id == 87
      end

      def co2_kg
        # approximation:
        # - my car (Toyota Prius+ from 2014) emits 96g/km
        # - my car consumes (in theory) 4.20L/100km
        # - price of SP98: 1.7€/L in Jan 2022
        # FIXME: price is highly variable so date should be factored in to have a more precise estimation
        amount.abs / 1.7 * (100 / 4.20) * 96 / 1000
      end

      def icon
        '🚗'
      end
    end

    class Groceries < Transaction
      def self.match?(transaction)
        transaction.category_id == 273
      end

      def co2_kg
        # approximation:
        # - assuming all groceries come from carrefour (https://www.carrefour.com/en/csr/commitment/reducing-ghg-emissions)
        # - the group generated 2B kgCO2 in 2019
        # - it generated 80B€ of revenue in 2019
        # raw estimation is 0.025kgCO2/€
        # FIXME: how could we differentiate between "local" buying and supermarkets?
        amount.abs * 0.025
      end

      def icon
        '🧺'
      end
    end

    class Taxes < Transaction
      def self.match?(transaction)
        [159, 206, 208, 302].include?(transaction.category_id) || transaction.description =~ /Dgfip Finances Publiques/i
      end

      def co2_kg
        # approximation: I estimate that paying taxes is 0 impact.
        0
      end

      def icon
        '🇫'
      end
    end

    class AmazonDelivery < Transaction
      def self.match?(transaction)
        # FIXME: we should probably detect if the transaction is recuring
        # currently detection is only based on price
        transaction.category_id == 186 && transaction.description =~ /amzn/i
      end

      def co2_kg
        # approximation:
        # in 2021, amazon emmitted 60.64B kg of CO2 (source: https://fortune.com/2021/06/30/amazon-carbon-footprint-pollution-grew/)
        # in 2020, its revenue was $386B, so 351B€
        # raw estimation is 0.1727 kgCO2/$
        amount.abs * 0.1727
      end

      def icon
        '📦'
      end
    end
  end
end
