require_relative "client_error"

module X
  # Rate limit error
  class TooManyRequests < ClientError
    def initialize(msg, response)
      @response = response
      super(msg)
    end

    def limit
      @response["x-rate-limit-limit"].to_i
    end

    def remaining
      @response["x-rate-limit-remaining"].to_i
    end

    def reset_at
      Time.at(@response["x-rate-limit-reset"].to_i)
    end

    def reset_in
      [(reset_at - Time.now).ceil, 0].max
    end

    alias_method :retry_after, :reset_in
  end
end
