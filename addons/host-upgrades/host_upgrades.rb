# frozen_string_literal: true

version '0.1.0'
license 'Apache License 2.0'

struct {
  attribute :interval, Pharos::Types::String
}

schema {
  required(:interval).filled(:str?, :duration?)
}

def install
  apply_stack(
    interval: duration.parse(config.interval).to_sec
  )
end
