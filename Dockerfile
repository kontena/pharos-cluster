FROM ruby:2.5

WORKDIR /app

COPY Gemfile Gemfile.lock *.gemspec ./
COPY lib/pharos/version.rb ./lib/pharos/
RUN bundle install --without test --without development

COPY . .

ENTRYPOINT ["./bin/pharos-cluster"]
