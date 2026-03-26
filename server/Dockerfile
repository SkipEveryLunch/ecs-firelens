FROM ruby:3.3.4-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev git \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without "development test" \
    && bundle install --jobs 4 --retry 3

COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# ---

FROM ruby:3.3.4-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

RUN useradd -m rails && chown -R rails:rails /app
USER rails

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
