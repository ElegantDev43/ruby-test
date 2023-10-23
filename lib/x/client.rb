require "forwardable"
require_relative "bearer_token_authenticator"
require_relative "connection"
require_relative "oauth_authenticator"
require_relative "redirect_handler"
require_relative "request_builder"
require_relative "response_handler"

module X
  # Main public interface
  class Client
    extend Forwardable

    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze

    attr_accessor :base_url

    def_delegators :@authenticator, :bearer_token, :api_key, :api_key_secret, :access_token, :access_token_secret
    def_delegators :@authenticator, :bearer_token=, :api_key=, :api_key_secret=, :access_token=, :access_token_secret=
    def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :proxy_url, :debug_output
    def_delegators :@connection, :open_timeout=, :read_timeout=, :write_timeout=, :proxy_url=, :debug_output=
    def_delegators :@redirect_handler, :max_redirects
    def_delegators :@redirect_handler, :max_redirects=
    def_delegators :@response_handler, :array_class, :object_class
    def_delegators :@response_handler, :array_class=, :object_class=

    def initialize(bearer_token: nil,
      api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
      base_url: DEFAULT_BASE_URL,
      open_timeout: Connection::DEFAULT_OPEN_TIMEOUT,
      read_timeout: Connection::DEFAULT_READ_TIMEOUT,
      write_timeout: Connection::DEFAULT_WRITE_TIMEOUT,
      proxy_url: nil,
      debug_output: nil,
      array_class: nil,
      object_class: nil,
      max_redirects: RedirectHandler::DEFAULT_MAX_REDIRECTS)

      @base_url = base_url
      initialize_authenticator(bearer_token, api_key, api_key_secret, access_token, access_token_secret)
      @connection = Connection.new(open_timeout: open_timeout, read_timeout: read_timeout,
        write_timeout: write_timeout, debug_output: debug_output, proxy_url: proxy_url)
      @request_builder = RequestBuilder.new
      @redirect_handler = RedirectHandler.new(authenticator: @authenticator, connection: @connection,
        request_builder: @request_builder, max_redirects: max_redirects)
      @response_handler = ResponseHandler.new(array_class: array_class, object_class: object_class)
    end

    def get(endpoint, headers: {})
      execute_request(:get, endpoint, headers: headers)
    end

    def post(endpoint, body = nil, headers: {})
      execute_request(:post, endpoint, body: body, headers: headers)
    end

    def put(endpoint, body = nil, headers: {})
      execute_request(:put, endpoint, body: body, headers: headers)
    end

    def delete(endpoint, headers: {})
      execute_request(:delete, endpoint, headers: headers)
    end

    private

    def initialize_authenticator(bearer_token, api_key, api_key_secret, access_token, access_token_secret)
      @authenticator = if bearer_token
        BearerTokenAuthenticator.new(bearer_token: bearer_token)
      elsif api_key && api_key_secret && access_token && access_token_secret
        OAuthAuthenticator.new(api_key: api_key, api_key_secret: api_key_secret, access_token: access_token,
          access_token_secret: access_token_secret)
      else
        Authenticator.new
      end
    end

    def execute_request(http_method, endpoint, headers:, body: nil)
      uri = URI.join(base_url, endpoint)
      request = @request_builder.build(authenticator: @authenticator, http_method: http_method, uri: uri, body: body,
        headers: headers)
      response = @connection.perform(request: request)
      response = @redirect_handler.handle(response: response, request: request, base_url: base_url)
      @response_handler.handle(response: response)
    end
  end
end
