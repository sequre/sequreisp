module SequreISP
  URL = "http://www.sequreisp.com/"

  class Version
    RELEASE = 3
    MAJOR = 4
    MINOR = 15

    attr_accessor :release, :major, :minor

    def initialize(version="#{RELEASE}.#{MAJOR}.#{MINOR}")
      @release, @major, @minor = version.split(".").map(&:to_i)
    end

    def self.to_a
      [ RELEASE, MAJOR, MINOR ]
    end

    def self.to_s
      self.to_a.join(".")
    end

    def to_s
      [ @release, @major, @minor ].join(".")
    end

    def self.to_big_decimal
      BigDecimal.new("0." + (RELEASE + 1000).to_s[1..3] + (MAJOR + 1000).to_s[1..3] + (MINOR + 1000).to_s[1..3])
    end


    def <(v)
      release < v.release or (release == v.release and (major < v.major or (major == v.major and minor < v.minor)))
    end

    def >(v)
      release > v.release or (release == v.release and (major > v.major or (major == v.major and minor > v.minor)))
    end

    def >=(v)
      not self<v
    end

    def <=(v)
      not self>v
    end

    def ==(v)
      release == v.release and major == v.major and minor == v.minor
    end

  end
end
