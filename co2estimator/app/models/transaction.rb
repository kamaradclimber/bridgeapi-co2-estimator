class Transaction < ApplicationRecord
  belongs_to :bridge_api_account

  def self.child_classes
    ObjectSpace
      .each_object(Class)
      .select { |klass| klass < self }
      .reject { |klass| klass.to_s =~ /#<Class:#/ } # ugly way to remove dynamic classes built by rails
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
    "#{date}: #{description} #{full_amount}"
  end

  def icon
    amount.negative? ? '🔻' : '➕'
  end

  def full_amount
    short_currency = currency_code == 'EUR' ? '€' : currency_code
    "#{amount}#{short_currency}"
  end

  def to_s
    co2 = ", 🏭 #{co2_kg.round(2)}kg" if co2_kg&.positive?
    "#{icon} #{date} #{description} (#{category_name}): #{full_amount} #{co2}"
  end

  def category_name
    BridgeApi::Dependencies.resolve(:categories)[category_id]['name']
  rescue StandardError
    # we are likely falling in a case where `category_id` has been set to nil instead of equality comparison
    "unknown category #{category_id}"
  end
end

class Electricity < Transaction
  def self.match?(transaction)
    transaction.category_id == 217
  end

  def co2_kg
    # approximation: in france, electricity emits 50gCO2/kWh
    # cost of kWh is 0.1740€/kWh (at least for EDF, my own provider is much cheaper)
    # note: we don't count subscription cost
    # note: this is an estimation from the money transfer. People interested in their CO2 emission
    #       are likely to measure their own electricity consumption
    emission_per_euro_in_kg = 50.0 / 1000 / 0.1740
    amount.abs * emission_per_euro_in_kg
  end

  def icon
    '💡'
  end
end

class InternetAccess < Transaction
  def self.match?(transaction)
    transaction.category_id == 180
  end

  def co2_kg
    # approximation: 3.95kgCO2/month according to ademe
    # subscription for 1month costs 39.99€ (on free website at least)
    # of course, we could simply associate one transaction to 3.95kg
    # source: https://adsl.free.fr/co2.pl
    emission_per_euro_in_kg = 3.95 / 39.99
    amount.abs * emission_per_euro_in_kg
  end

  def icon
    '🕸'
  end
end

class FreeInternetAccess < InternetAccess
  def self.match?(transaction)
    super && transaction.description =~ /Free Telecom/
  end

  def co2_kg
    # approximation: 1.7kgCO2/month according to free
    # subscription for 1month costs 39.99€ (on free website)
    # of course, we could simply associate one transaction to 1.7kg
    # source: https://adsl.free.fr/co2.pl
    emission_per_euro_in_kg = 1.7 / 39.99
    amount.abs * emission_per_euro_in_kg
  end

  def icon
    '🕸'
  end
end

class Mobile < Transaction
  def self.match?(transaction)
    transaction.category_id == 277
  end

  def co2_kg
    # approximation: 50gCO2/GB according to ademe
    # subscription for 110GB costs 12€ (on free website)
    # source: https://mobile.free.fr/account/conso-et-factures/empreinte-carbone + prices on free.fr
    # source: https://expertises.ademe.fr/economie-circulaire/consommer-autrement/passer-a-laction/reconnaitre-produit-plus-respectueux-lenvironnement/dossier/laffichage-environnemental/affichage-environnemental-secteur-numerique
    emission_per_euro_in_kg = 50.0 / 1000 * 110 / 12
    amount.abs * emission_per_euro_in_kg
  end

  def icon
    '📶'
  end
end

class FreeMobile < Mobile
  def self.match?(transaction)
    super && transaction.description =~ /Free Mobile/
  end

  def co2_kg
    # approximation: 24.3gCO2/GB according to free mobile website
    # subscription for 110GB costs 12€ => 222.75gCO2/€
    # source: https://mobile.free.fr/account/conso-et-factures/empreinte-carbone + prices on free.fr
    emission_per_euro_in_kg = 24.3 / 1000 * 110 / 12
    amount.abs * emission_per_euro_in_kg
  end
end

class Withdrawals < Transaction
  def self.match?(transaction)
    transaction.category_id == 85
  end

  def co2_kg
    # it's very hard to estimate what cash has been used to.
    # Here we'll assume paying in cash is to pay small services or local products
    # but that's a guess of course
    0
  end

  def icon
    '🤷️'
  end
end

class TrainTransaction < Transaction
  def self.match?(transaction)
    transaction.category_id == 197 ||
      (transaction.description =~ /Trainline/ && transaction.category_id == 249)
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

class Leetchi < Transaction
  def self.match?(transaction)
    transaction.category_id == 183 && transaction.description =~ /leetchi/i
  end

  def co2_kg
    # approximation: We can't know how this money will be used. Let's ignore it for now
    0
  end

  def icon
    '🎁'
  end
end

class AmazonDelivery < Transaction
  def self.match?(transaction)
    (transaction.category_id == 186 && transaction.description =~ /amzn/i) ||
      (transaction.category_id == 184 && transaction.description =~ /amzn mktp/i)
  end

  def co2_kg
    # approximation:
    # in 2021, amazon emmitted 60.64B kg of CO2 (source: https://fortune.com/2021/06/30/amazon-carbon-footprint-pollution-grew/)
    # in 2020, its revenue was $386B, so 351B€
    # raw estimation is 0.1727 kgCO2/$
    # of course we are just taking into account amazon value here (instead of the product fabrication)
    amount.abs * 0.1727
  end

  def icon
    '📦'
  end
end

class BarCoffee < Transaction
  def self.match?(transaction)
    [227, 313].include?(transaction.category_id)
  end

  def co2_kg
    # we assume this does not emit any CO2
    0
  end

  def icon
    '🍸🥳'
  end
end

class Salary < Transaction
  def self.match?(transaction)
    transaction.category_id == 230
  end

  def co2_kg
    # taking emissions from Criteo (10k TEQ CO2) divided by income: $2B
    amount * 10_000_000 / 2_000_000_000.0
  end

  def icon
    '🏢'
  end
end

class InternalTransfert < Transaction
  def self.match?(transaction)
    transaction.category_id == 326
  end

  def co2_kg
    0
  end

  def icon
    '🔄'
  end
end

# goal is to allow to ignore some transactions based on regexp
class IgnoredTransaction < Transaction
  def self.match?(transaction)
    [
      /Virement Sepa Recu .*/
    ].any? { |r| transaction.description =~ r }
  end

  def co2_kg
    0
  end

  def icon
    '🙈'
  end
end
