class Transaction < ApplicationRecord
  belongs_to :bridge_api_account

  # this method allows to take a hash from the bridge_api and hydrate transaction fields
  # @param [Hash] a hash representing the transaction in the bridge_api model
  def hydrate_from(transaction_hash)
    self.description = transaction_hash['clean_description']
    self.full_description = transaction_hash['bank_description']
    self.amount = transaction_hash['amount']
    self.currency_code = transaction_hash['currency_code']
    self.date = Date.parse(transaction_hash['date'])
    self.category_id = transaction_hash['category_id']
    self.original_hash = transaction_hash.to_json
  end

  # @return [Boolean] true if the user has updated manually a field
  # currently this method is not used but could be useful in the future!
  def user_updated?
    transaction_hash = JSON.parse(original_hash || '{}')
    return true if description != transaction_hash['clean_description']
    return true if full_description != transaction_hash['bank_description']
    return true if amount != transaction_hash['amount']
    return true if currency_code != transaction_hash['currency_code']
    return true if date != (transaction_hash['date'] ? Date.parse(transaction_hash['date']) : nil)
    return true if category_id != transaction_hash['category_id']

    false
  end

  # reset transaction in pristine condition, as it was before user modification
  # @return [Transaction] self or the new transaction object
  def pristine!
    hydrate_from(JSON.parse(original_hash))
    save!
    refresh_subclass
  end

  # self must be reloaded after calling this method, to make sure we get the proper class
  # @return [Transaction] self or the new transaction object
  def refresh_subclass
    matching_classes = Transaction.child_classes.select do |klass|
      klass.match?(self)
    rescue NotImplementedError
      false
    end
    matching = matching_classes.min { |k1, k2| (k1 <=> k2) || 0 }
    puts "Found #{matching_classes.size} classes matching #{short_s}, selecting #{matching} as the most precise"
    if matching
      self.type = matching
      save!
      # we need to reload the transaction to get the correct class
      # we can probably avoid the write-then-read pattern but it's quite convenient for now
      return Transaction.find(id)
    end
    self
  end

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

  # @return [String, nil] an explaination of the co2 impact, or nil if not relevant
  def explaination_html
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

class Spotify < Transaction
  def self.match?(transaction)
    transaction.description =~ /spotify/i
  end

  def co2_kg
    emission_per_euro_in_kg = 169_000_000.0 / 8_337_000_000
    amount.abs * emission_per_euro_in_kg
  end

  def explaination_html
    <<~HTML
      Spotify emited 169000tCO2 in 2020 (<a href="https://www.lifeatspotify.com/diversity-equity-impact/climate-action">source</a>) for a revenue of 9B$ (8337M€) in 2020.
    HTML
  end

  def icon
    '🎶'
  end
end

class Toll < Transaction
  def self.match?(transaction)
    transaction.category_id == 309
  end

  def co2_kg
    emission_per_euro_in_kg = 7_071_000 / 1_460_000_000.0
    amount.abs * emission_per_euro_in_kg
  end

  def explaination_html
    <<~HTML
      Taking cofiroute GHG <a href="https://bilans-ges.ademe.fr/fr/bilanenligne/detail/index/idElement/4116/back/bilans">summary</a>, we can see emissions in 2019 are 7071 tCO2 (excluding scope 3 which includes clients emissions, already taken into account with gaz spending). Toll <a href="https://www.vinci.com/publi/vinci_autoroutes/cofiroute/2019-cofiroute-financial-report.pdf">revenue</a> in 2019 was 1460M€. It gives 0.00484kgCO2/€
    HTML
  end

  def icon
    '🚧'
  end
end

class Gas < Transaction
  def self.match?(transaction)
    transaction.category_id == 218
  end

  def co2_kg
    emission_per_euro_in_kg = 0.227 / 16.33
    amount.abs * emission_per_euro_in_kg
  end

  def explaination_html
    <<~HTML
      In France, <a href="https://bilans-ges.ademe.fr/documentation/UPLOAD_DOC_FR/index.htm?gaz.htm">according</a> to ADEME, gas has an equivalent of 0.227kgCO2/kWh (from production to combustion).
      Gas price from my <a href="http://www.rseipc.fr/particuliers/tarifs_gaz.php">provider</a> is 16.33€/kWh.
    HTML
  end

  def icon
    ''
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
    -amount * emission_per_euro_in_kg
  end

  def explaination_html
    <<~HTML
      In France, electricity emits <samp>50gCO2/kWh</samp>. EDF charges <samp>0.1740€/kWh</samp> (my own provider is much cheaper though).
      We don't count subscription though.
      Note: people interested in precise CO2 emission should likely monitor electritity consumption more precisely than using price (to account for variability in electricity emission).
    HTML
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
    emission_per_euro_in_kg = 3.95 / 39.99
    amount.abs * emission_per_euro_in_kg
  end

  def explaination_html
    <<~HTML
      ADEME <a href="https://adsl.free.fr/co2.pl">estimates</a> internet access in France to emits <samp>3.95kgCO2/month</samp>.
      We estimate internet access to be <samp>40€/month</samp> in France.
    HTML
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
    emission_per_euro_in_kg = 1.7 / 39.99
    amount.abs * emission_per_euro_in_kg
  end

  def explaination_html
    <<~HTML
      Free <a href="https://adsl.free.fr/co2.pl">estimates</a> its internet access to emits <samp>1.7kgCO2/month</samp>.
      We estimate internet access to be <samp>40€/month</samp> in France.
    HTML
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
    # source: https://mobile.free.fr/account/conso-et-factures/empreinte-carbone + prices on free.fr
    emission_per_euro_in_kg = 50.0 / 1000 * 110 / 12
    amount.abs * emission_per_euro_in_kg
  end

  def explaination_html
    <<~HTML
      ADME <a href="https://expertises.ademe.fr/economie-circulaire/consommer-autrement/passer-a-laction/reconnaitre-produit-plus-respectueux-lenvironnement/dossier/laffichage-environnemental/affichage-environnemental-secteur-numerique">estimates</a> co2 emission of a mobile line to emit <samp>50gCO2/GB</samp> of data. In France, 100GB costs ~12€ (at least with free mobile).
    HTML
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

  def explaination_html
    <<~HTML
      Free <a href="https://mobile.free.fr/account/conso-et-factures/empreinte-carbone">estimates</a> co2 emission of its mobile line to emit <samp>24.3gCO2/GB</samp> of data. 100GB costs ~12€ (at least with free mobile).
    HTML
  end
end

class Withdrawals < Transaction
  def self.match?(transaction)
    transaction.category_id == 85
  end

  def co2_kg
    0
  end

  def explaination_html
    <<~HTML
      It's impossible to know what cash has been used to. We assume paying in cash is reserved from small services and local products. So a cost of zero. That's wishful thinking of course.
    HTML
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
    amount.abs * 2.12 * 1.73 / 1000
  end

  def explaination_html
    # ticket "sampling" has been done on two tickets Chartres-Strasbourg-Chartres.
    <<~HTML
      According to <a href="https://www.sncf-connect.com/aide/calcul-des-emissions-de-co2-sur-votre-trajet-en-train">SNCF</a> long distance train emits <samp>1.73gCO2/km</samp>. Train prices are highly volatile so we assume <samp>2.12km/€</samp> based on a sample of tickets.
    HTML
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
    amount.abs * 7.82 * 24.81 / 1000
  end

  def explaination_html
    <<~HTML
      According to <a href="https://www.sncf-connect.com/aide/calcul-des-emissions-de-co2-sur-votre-trajet-en-train">SNCF</a> short distance train emits <samp>24.81gCO2/km</samp>. TER train prices are roughly kilometric: <samp>7.82km/€</samp> based on local train prices.
    HTML
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

  def explaination_html
    <<~HTML
      My car (toyota prius+ from 2014) emits <samp>96g/km</samp>, it consumes <samp>4.20L/100km</samp>, price of SP98 is <samp>1.7€/L</samp> as of Jan 2022.
      Of course prices of gaz is extremely volatile so date should be factored to have a more precise estimation.
    HTML
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
    # FIXME: how could we differentiate between "local" buying and supermarkets?
    amount.abs * 0.025
  end

  def explaination_html
    <<~HTML
      Assuming all groceries come from carrefour: the group generated 2B kgCO2 in 2019, it generated 80B€ of revenue in 2019 => estimation is <samp>0.025kgCO2/€</samp>. <a href="https://www.carrefour.com/en/csr/commitment/reducing-ghg-emissions">source</a>
      Of course this does not factor the product themselves, only the added emissions from carrefour.
    HTML
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

  def explaination_html
    <<~HTML
      I estimate paying taxes has no emission attached.
    HTML
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
    0
  end

  def explaination_html
    <<~HTML
      We can't know how this money will be used, let's ignore it for now.
    HTML
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
    amount.abs * 0.1727
  end

  def explaination_html
    <<~HTML
      In 2021, Amazon emitted 60.64B kgCO2 <a href="https://fortune.com/2021/06/30/amazon-carbon-footprint-pollution-grew/ttps://fortune.com/2021/06/30/amazon-carbon-footprint-pollution-grew/">source</a>. In 2020, its revenue was 351B€. A raw estimation is <samp>0.1727 kgCO2/€</samp>.
      Of course we are just taking into account Amazon added emissions, not the products themselves.
    HTML
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
    0
  end

  def explaination_html
    <<~HTML
      We assume going to a bar does not emit CO2. This is a wishful thinking of course!
    HTML
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
    amount * 10_000_000 / 1_849_390_000
  end

  def explaination_html
    <<~HTML
      Taking emissions of my employer Criteo (10k TEQ CO2) divided by income: $2B (1.849B€).
    HTML
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

  def explaination_html
    <<~HTML
      This transaction has been ignored based on a regular expression on its title.
    HTML
  end

  def icon
    '🙈'
  end
end
