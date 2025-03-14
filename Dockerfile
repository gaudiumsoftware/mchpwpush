# Setting global arguments
ARG BUNDLE_WITHOUT=""
ARG BUNDLE_DEPLOYMENT=false

FROM ruby:3.4-alpine AS build-env

# include global args
ARG BUNDLE_WITHOUT
ARG BUNDLE_DEPLOYMENT

LABEL org.opencontainers.image.authors='pglombardo@hey.com'

# Pacotes necessários para build e desenvolvimento
RUN apk add --no-cache \
    git \
    build-base \
    musl-dev \
    libc6-compat \
    libpq-dev \
    mariadb-dev \
    nodejs \
    sqlite-dev \
    tzdata \
    yaml-dev \
    yarn \
    pkgconf \
    openssl-dev

# Atualiza RubyGems para a versão mais recente (ou pula se já for compatível)
RUN gem update --system --no-document

ENV APP_ROOT=/opt/PasswordPusher
WORKDIR ${APP_ROOT}

COPY Gemfile Gemfile.lock package.json yarn.lock ./

ENV RACK_ENV=development RAILS_ENV=development

# Configura o Bundler e instala dependências, incluindo Git
RUN bundle config set without "${BUNDLE_WITHOUT}" \
    && bundle config set deployment "${BUNDLE_DEPLOYMENT}" \
    && bundle install --jobs 4 --retry 3

COPY ./ ${APP_ROOT}/

RUN yarn install \
    && yarn build \
    && bundle exec rails assets:precompile

################## Build done ##################

FROM ruby:3.4-alpine

# include global args
ARG BUNDLE_WITHOUT
ARG BUNDLE_DEPLOYMENT

LABEL maintainer='pglombardo@hey.com'

RUN apk add --no-cache \
    bash \
    curl \
    libc6-compat \
    libpq \
    mariadb-connector-c \
    nodejs \
    tzdata \
    yarn \
    jemalloc

ENV LC_CTYPE=UTF-8 LC_ALL=en_US.UTF-8
ENV APP_ROOT=/opt/PasswordPusher
WORKDIR ${APP_ROOT}
ENV RACK_ENV=development RAILS_ENV=development
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

ARG UID=1000
ARG GID=1000
RUN addgroup -g "${GID}" pwpusher \
    && adduser -D -u "${UID}" -G pwpusher pwpusher \
    && chown -R pwpusher:pwpusher ${APP_ROOT}

ENV SECRET_KEY_BASE=783ff1544b9612d8bceb8e26a0bab0cf22543eec658a498e7ef9e1d617976f960092005c8a54cb588759dc6dd8fd054bc4eca4a94dd7b96c6efda4a14a01bfbd

COPY --from=build-env --chown=pwpusher:pwpusher ${APP_ROOT} ${APP_ROOT}/

RUN bundle config set without "${BUNDLE_WITHOUT}" \
    && bundle config set deployment "${BUNDLE_DEPLOYMENT}"

USER pwpusher
EXPOSE 5100
ENTRYPOINT ["containers/docker/entrypoint.sh"]