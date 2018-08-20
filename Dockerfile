FROM ruby:2.4.3

WORKDIR /app

COPY Gemfile Gemfile.lock *.gemspec ./
COPY lib/pharos/version.rb ./lib/pharos/
RUN bundle install

COPY . .

CMD ["./bin/pharos-cluster"]
