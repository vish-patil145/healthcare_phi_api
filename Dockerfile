# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.2

# ── Base ────────────────────────────────────────────────────
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

ENV BUNDLE_PATH=/usr/local/bundle

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libpq-dev \
    libvips \
    libyaml-0-2 \
    && rm -rf /var/lib/apt/lists/*

# ── Build ────────────────────────────────────────────────────
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    nodejs \
    pkg-config \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ${BUNDLE_PATH}/ruby/*/cache \
    ${BUNDLE_PATH}/ruby/*/bundler/gems/*/.git

COPY . .

RUN bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# ── Production ──────────────────────────────────────────────
FROM base AS production

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test

COPY --from=build ${BUNDLE_PATH} ${BUNDLE_PATH}
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp

USER rails

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]

# ── Development (Rails + Sidekiq share this) ─────────────────
FROM ruby:${RUBY_VERSION}-slim AS development

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    libvips \
    nodejs \
    libyaml-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=""

# Only copy Gemfile — code comes from bind mount at runtime
COPY Gemfile Gemfile.lock ./

EXPOSE 3000
# Default CMD — overridden per service in docker-compose
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]