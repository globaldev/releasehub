module Services

  class Sentry
    include HTTParty

    SENTRY_API_URI = ENV["SENTRY_API_URI"]
    SENTRY_API_TOKEN = ENV["SENTRY_API_TOKEN"]
    HEADERS = {"Authorization" => "Bearer #{SENTRY_API_TOKEN}", "Content-Type" => "application/json"}

    class Release

      def self.get(id)
        base_uri = "#{SENTRY_API_URI}releases/#{id}/"
        HTTParty.get(
            base_uri,
            headers: HEADERS
        )
      end

      def self.create(body)
        base_uri = "#{SENTRY_API_URI}releases/"
        HTTParty.post(
            base_uri,
            body: body.to_json,
            headers: HEADERS
        )
      end

      def self.delete(id)
        base_uri = "#{SENTRY_API_URI}releases/#{id}/"
        HTTParty.delete(
            base_uri,
            headers: HEADERS
        )
      end

      def self.deploy(body, id)
        base_uri = "#{SENTRY_API_URI}releases/#{id}/deploys/"
        HTTParty.post(
            base_uri,
            body: body.to_json,
            headers: HEADERS
        )
      end

    end
  end
end
