  require 'ipaddr'
  class IPAddr
    def cidr_mask
      @mask_addr.to_s(2).count("1")
    end

    def to_cidr
      [to_string,("/"+cidr_mask.to_s unless cidr_mask == 32)].compact.join
    end
  end

  class Hash
    def +(the_other)
      self.merge(the_other){|key, oldval, newval| newval + oldval}
    end
    def -(the_other)
      self.merge(the_other){|key, oldval, newval| newval - oldval}
    end
    def /(number)
      self.each { |key, value| self[key] = value / number }
    end
    def *(number)
      self.each { |key, value| self[key] = value * number }
    end
    def sort_by_key
      ActiveSupport::OrderedHash[*self.sort_by{|k,v| k}.flatten]
    end
    def sort_by_value
      ActiveSupport::OrderedHash[*self.sort_by{|k,v| v}.flatten]
    end
  end

  class ActiveRecord::Base
    #instance method, E.g: Order.new.foo
    #class method, E.g: Order.top_ten
    def self.massive_creation(transactions)
      keys = transactions.first.keys.join(',')
      values = transactions.map{|t| "'#{t.values.join("','")}'" }.join('),(')
      connection.execute("INSERT INTO #{self.to_s.undescore.pluralize} (#{keys}) VALUES (#{values})")
    end

    def self.massive_update(transactions)
      connection.execute("UPDATE #{self.to_s.undescore.pluralize}
                          SET #{transactions[:update_attr]} = CASE #{transactions[:condition_attr]} " +
                          transactions[:values].map { |key, value| "WHEN #{key} THEN #{value}"}.join(' ') +
                         " END WHERE id IN (#{transactions[:values].keys.join(',')})")
    end

    def self.massive_sum(transactions)
      connection.execute("UPDATE #{self.to_s.undescore.pluralize}
                          SET #{transactions[:update_attr]} = #{transactions[:update_attr]} + CASE #{transactions[:condition_attr]} " +
                          transactions[:values].map { |key, value| "WHEN #{key} THEN #{value}"}.join(' ') +
                         " END WHERE id IN (#{transactions[:values].keys.join(',')})")
    end
  end
