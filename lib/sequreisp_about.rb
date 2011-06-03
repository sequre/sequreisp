module SequreISP
  URL = "http://www.sequreisp.com/"

  class Version
    RELEASE = 2
    MAJOR = 2
    MINOR = 0

    def self.to_a
      [ RELEASE, MAJOR, MINOR ]
    end

    def self.to_s
      self.to_a.join(".")
    end
  end
end
