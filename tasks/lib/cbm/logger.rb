module Cbm
  # logger proxy for puts so we can avoid spamming log messages in specs
  module Logger
    def log(msg)
      puts msg
    end
  end
end
