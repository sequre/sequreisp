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
      begin
        transactions.each{|transaction| transaction.stringify_keys!.merge!({"created_at" => DateTime.now.utc.to_s(:db), "updated_at" => DateTime.now.utc.to_s(:db) })}
        keys = transactions.first.keys.map(&:to_s).join(',')
        values = transactions.map{|t| t.values.map{|v| v.nil? ? 'NULL' : "'#{v.to_s}'"}.join(',') }.join('),(')
        connection.execute("INSERT INTO #{self.to_s.underscore.pluralize} (#{keys}) VALUES (#{values})")
      rescue => e
        $application_logger.error(e)
      end
    end

    def self.massive_update(transactions)
      begin
        connection.execute("UPDATE #{self.to_s.underscore.pluralize}
                            SET #{transactions[:update_attr]} = CASE #{transactions[:condition_attr]} " +
                            transactions[:values].map { |key, value| "WHEN #{key} THEN #{value}"}.join(' ') +
                           " END, updated_at = '#{DateTime.now.utc.to_s(:db)}' WHERE id IN (#{transactions[:values].keys.join(',')})")
      rescue => e
        $application_logger.error(e)
      end
    end

    def self.massive_sum(transactions)
      begin
        connection.execute("UPDATE #{self.to_s.underscore.pluralize}
                            SET #{transactions[:update_attr]} = #{transactions[:update_attr]} + CASE #{transactions[:condition_attr]} " +
                            transactions[:values].map { |key, value| "WHEN #{key} THEN #{value}"}.join(' ') +
                           " END, updated_at = '#{DateTime.now.utc.to_s(:db)}' WHERE id IN (#{transactions[:values].keys.join(',')})")
      rescue => e
        $application_logger.error(e)
      end
    end
  end
