  require 'ipaddr'
  class IPAddr
    def cidr_mask
      @mask_addr.to_s(2).count("1")
    end

    def to_cidr
      [to_string,("/"+cidr_mask.to_s unless cidr_mask == 32)].compact.join
    end
  end
