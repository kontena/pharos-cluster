require 'clamp'

module Kuntena
  class Command < Clamp::Command

    def with_spinner(title)
      spinner = TTY::Spinner.new("[:spinner] #{title}")
      spinner.auto_spin
      spinner.start
      yield(spinner)
    ensure
      spinner.stop
    end
  end
end
