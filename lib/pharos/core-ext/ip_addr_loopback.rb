# frozen_string_literal: true

module Pharos
  module CoreExt
    module IPAddrLoopback
      # Backported from Ruby 2.5
      refine IPAddr do
        # Returns true if the ipaddr is a loopback address.
        def loopback?
          case @family
          when Socket::AF_INET
            @addr & 0xff000000 == 0x7f000000
          when Socket::AF_INET6
            @addr == 1
          else
            # Ruby 2.5 raises here
            false
          end
        end
      end
    end
  end
end
