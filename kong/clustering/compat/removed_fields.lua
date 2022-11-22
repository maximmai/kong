
return {
  -- 3.1.0
  [3001000000] = {
    acme = {
      "enable_ipv4_common_name",
      "storage_config.redis.ssl",
      "storage_config.redis.ssl_verify",
      "storage_config.redis.ssl_server_name",
    },
    rate_limiting = {
      "error_code",
      "error_message",
    },
    response_ratelimiting = {
      "redis_ssl",
      "redis_ssl_verify",
      "redis_server_name",
    },
    datadog = {
      "retry_count",
      "queue_size",
      "flush_timeout",
    },
    statsd = {
      "retry_count",
      "queue_size",
      "flush_timeout",
    },
    session = {
      "cookie_persistent",
    },
    zipkin = {
      "default_service_name",
      "http_response_header_for_traceid",
    },
  },
}
