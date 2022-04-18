# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'cgi'
require 'securerandom'
require 'json'
require 'time'

module BridgeApi
  # a class wrapping access token to allow to refresh it
  class AccessToken
    # @return [Time]
    attr_reader :expires_at

    # @return [String]
    attr_reader :username

    # @param client [BridgeApi::Client]
    # @param username [String]
    # @param password [String]
    def initialize(client, username, password)
      @client = client
      @username = username
      @password = password
      refresh!
    end

    # @return [String] the access token
    def value
      refresh! if expires_at < Time.now
      @value
    end

    def refresh!
      puts "Refreshing access token for #{@username}"
      result = @client.authenticate(@username, @password)
      @value = result['access_token']
      @expires_at = Time.parse(result['expires_at'])
    end
  end

  class Client
    def initialize
      @client_secret = ENV['BRIDGEAPI_CLIENT_SECRET']
      @client_id = ENV['BRIDGEAPI_CLIENT_ID']
      raise 'BRIDGEAPI_CLIENT_SECRET should be set' unless @client_secret
    end

    def create_user(email)
      password = SecureRandom.hex
      result = post('/v2/users', body: {
                      # documentation says we need to uri encode the @ but returns a 400 if we do
                      email: email,
                      password: password
                    })
      result.merge({ 'password' => password })
    end

    def delete_user(uuid, password)
      post("/v2/users/#{uuid}/delete", body: {
             password: password
           }, body_expected: false)
    end

    def authenticate(email, password)
      post('/v2/authenticate', body: {
             # documentation says we need to uri encode the @ but returns a 400 if we do
             email: email,
             password: password
           })
    end

    # @param since [Time]
    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    # @return [Enumerable<Hash>] a list of transaction
    def transactions(since:, token:)
      get_with_pagination("/v2/transactions?since=#{since.strftime('%Y-%m-%d')}", token: token)
    end

    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    # @return [Enumerable<Hash>] a list of items (i.e connection to the banks)
    def items(token:)
      get_with_pagination('/v2/items', token: token)
    end

    # @param id [Integer] item id 
    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    def item(id:, token:)
      get_with_access_token("/v2/items/#{id}", token: token)
    end

    # @param id [Integer] the id of the bank
    def bank(id)
      get("/v2/banks/#{id}")
    end

    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    # @return [Enumerable<Hash>] a list of categories
    def categories
      get_with_pagination('/v2/categories', token: nil)
    end

    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    # @return [Hash] a hash with redirect_url key
    def connect_new_account(token:)
      post_with_access_token('/v2/connect/items/add', body: { country: 'fr', prefill_email: token.username }, token: token)
    end

    # @param since [Time]
    # @param account_id [Integer]
    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    # @return [Enumerable<Hash>] a list of transaction
    def updated_transactions(since:, account_id:, token:)
      get_with_pagination("/v2/accounts/#{account_id}/transactions/updated?since=#{since.utc.strftime('%FT%T.%LZ')}", token: token)
    end

    def account(account_id, token:)
      get_with_access_token("/v2/accounts/#{account_id}", token: token)
    end

    private

    # @param path [String] something like /v2/users
    # @param token [Hash, nil] a hash with, at least, access_token and expires_at keys. Can be nil if we don't have a token
    # @return [Enumerable<Hash>]
    def get_with_pagination(path, token:, &block)
      return to_enum(:get_with_pagination, path, token: token) unless block_given?

      next_uri = path
      while next_uri
        result = get_with_access_token(next_uri, token: token)
        result['resources'].each(&block)
        next_uri = (result['pagination']['next_uri'] if result['pagination'])
      end
    end

    # @param path [String] something like /v2/users
    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    def get_with_access_token(path, token: nil)
      headers = {}
      headers[:Authorization] = "Bearer #{token.value}" if token
      get(path, headers: headers)
    end

    def get(path, headers: {})
      uri = URI.parse("https://api.bridgeapi.io#{path}")
      request = Net::HTTP::Get.new(uri)
      request['Bridge-Version'] = '2021-06-01'
      request['Client-Id'] = @client_id
      request['Client-Secret'] = @client_secret
      headers.each { |k, v| request[k] = v }

      req_options = {
        use_ssl: uri.scheme == 'https'
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      unless (200..299).include?(response.code.to_i)
        raise "Error while GET-ing to #{path}, code was #{response.code} (answer: #{response.body})"
      end

      JSON.parse(response.body)
    end

    # @param path [String] something like /v2/users
    # @param body [Hash]
    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    def post_with_access_token(path, body:, token:)
      post(path, body: body, headers: {
             Authorization: "Bearer #{token.value}"
           })
    end

    def post(path, body:, headers: {}, body_expected: true)
      uri = URI.parse("https://api.bridgeapi.io#{path}")
      request = Net::HTTP::Post.new(uri)
      request.content_type = 'application/json'
      request['Bridge-Version'] = '2021-06-01'
      request['Client-Id'] = @client_id
      request['Client-Secret'] = @client_secret
      headers.each { |k, v| request[k] = v }
      request.body = body.to_json
      puts request.body

      req_options = {
        use_ssl: uri.scheme == 'https'
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      unless (200..299).include?(response.code.to_i)
        raise "Error while POST-ing to #{path}, code was #{response.code} (answer: #{response.body})"
      end

      JSON.parse(response.body) if body_expected
    end
  end
end
