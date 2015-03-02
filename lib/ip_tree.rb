class IPTree
  require 'ipaddr'

  attr_accessor :parent, :ips, :mask

  LIMIT = 5

  def initialize(argument)
    @parent = argument[:parent]
    @prefix = argument[:prefix]
    @match = argument[:match]
    @mask = argument[:mask] || "MAIN"
    @ips = argument[:ip_list]
    @prefix_leaf = argument[:prefix_leaf]
  end

  def prefix; @prefix || (parent && parent.prefix) || "PREFIX"; end
  def match; @match || (parent && parent.match) || ""; end
  def prefix_leaf; @prefix_leaf ; end

  def extremes; @extremes ||= [ips.min,ips.max]; end

  def split_mask
    @sm ||= split_mask = 33 - (extremes.first.to_i ^ extremes.last.to_i).to_s(2).size
  end

  def ch_masks
    @ch_masks ||= extremes.map{|e| IPAddr.new("#{e.to_s}/#{split_mask}").to_cidr}
  end

  def childs
    return [] if ips.count <= LIMIT
    @childs ||= (
      ch = [[],[]]
      ips.each{|ip| IPAddr.new(ch_masks[0]).include?(ip) ? ch[0] << ip : ch[1] << ip }
      [0,1].map{|n| self.class.new(:ip_list => ch[n],:parent => self, :mask => ch_masks[n], :prefix_leaf => prefix_leaf) }
    )
  end

  def chain; @chain ||= ( "#{prefix}-#{mask}"); end

  def to_iptables
    o=[]
    if parent.nil? # Cadena del nodo inicial
      o << ":#{chain} -"
      o << "-F #{chain}"
    end
    childs.each do |ch| # cadena de cada hijo, seguida de las iptables de cada hijo
      o << ":#{ch.chain} -"
      o << "-F #{ch.chain}"
      o << "-A #{chain} #{match} #{ch.mask} -j #{ch.chain}"
      o << ch.to_iptables
    end
    if ips.count <= LIMIT # Si hay LIMIT IPs o menos aplica salto a la ip hoja
      ips.each do |ip|
        o << "-A #{chain} #{match} #{ip.to_cidr} -j #{prefix_leaf}.#{ip.to_cidr}"
        # o << "-A #{chain} #{match} #{ip.to_cidr} -j sq.#{ip.to_cidr}"
      end
    end
    o
  end
end
