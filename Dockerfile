FROM elixir:1.3.3

RUN mix local.hex --force
RUN mix deps.get
RUN mix compile

WORKDIR /app