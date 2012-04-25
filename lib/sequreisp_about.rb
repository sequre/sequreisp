module SequreISP
  URL = "http://www.sequreisp.com/"

  class Version
    RELEASE = 2
    MAJOR = 7
    MINOR = 1

    def self.to_a
      [ RELEASE, MAJOR, MINOR ]
    end

    def self.to_s
      self.to_a.join(".")
    end
    def self.to_big_decimal
      BigDecimal.new ("0." + (RELEASE + 1000).to_s[1..3] + (MAJOR + 1000).to_s[1..3] + (MINOR + 1000).to_s[1..3])
    end
  end
end
