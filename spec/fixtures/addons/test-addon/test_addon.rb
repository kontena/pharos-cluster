version "0.2.2"
license "MIT"

struct {
  attribute :foo, Pharos::Types::String
  attribute :bar, Pharos::Types::String.default('baz')
}

schema {
  required(:foo).filled(:str?)
  optional(:bar).filled(:str?)
}
