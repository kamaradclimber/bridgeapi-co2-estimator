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

  class PasswordStore
    def initialize(file)
      @file = file
      @passwords = {}
      @passwords = JSON.parse(File.read(file)) if File.exist?(file)
    end

    def password_for(username)
      @passwords[username]
    end

    def store_for(username, password)
      @passwords[username] = password
      File.write(@file, JSON.pretty_generate(@passwords))
    end
  end

  class Client
    def initialize
      @client_secret = ENV['BRIDGEAPI_CLIENT_SECRET']
      @client_id = ENV['BRIDGEAPI_CLIENT_ID']
      raise 'BRIDGEAPI_CLIENT_SECRET should be set' unless @client_secret
    end

    def create_user(email)
      post('/v2/users', body: {
             # documentation says we need to uri encode the @ but returns a 400 if we do
             email: email,
             password: SecureRandom.hex
           })
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

    # @param id [Integer] the id of the bank
    def bank(id)
      get("/v2/banks/#{id}")
    end

    # @param token [Hash] a hash with, at least, access_token and expires_at keys
    # @return [Enumerable<Hash>] a list of categories
    def categories(token:)
      get_with_pagination('/v2/categories', token: token)
    end

    private

    # @param path [String] something like /v2/users
    # @param token [Hash] a hash with, at least, access_token and expires_at keys
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
    def get_with_access_token(path, token:)
      get(path, headers: {
            Authorization: "Bearer #{token.value}"
          })
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

    def post(path, body:, headers: {})
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

      JSON.parse(response.body)
    end
  end
end
