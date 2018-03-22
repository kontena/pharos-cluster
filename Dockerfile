FROM ruby:2.4.3

WORKDIR /app

COPY Gemfile Gemfile.lock *.gemspec ./
COPY lib/kupo/version.rb ./lib/kupo/
RUN bundle install

COPY . .

CMD ["./bin/kupo"]
