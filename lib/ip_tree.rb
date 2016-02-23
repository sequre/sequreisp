# Monkeypatch IPAddr object to make the mask accesible
class IPAddr
  def cidr_mask
    @mask_addr.to_s(2).count("1")
  end

  def to_cidr
    [to_string,("/"+cidr_mask.to_s unless cidr_mask == 32)].compact.join
  end
end

# Parameters
#    ip_list: An array of IPAddr objects
#    prefix:  String to prepend in iptables rules and chains
#    leaf_prefix: String to prepend in iptables final tree targets
#    match: '-s' for source IP or '-d' for destination IP tree
#    indent: true or false. Indent output
#
#    The resulting tree will reach leave iptables chains with name
#     "#{leaf_prefix}.#{IPAddr.to_cidr}"
#
class IPTree
  require 'ipaddr'

  attr_reader :parent, :ip_list, :indent, :level, :prefix, :leaf_prefix, :match, :subnet, :nets

  LIMIT  = 4
  INDENT = 2

  def initialize(params)
    # Mass initialize instance variables
    params.each{|k,v| instance_variable_set("@#{k}", v)}

    fill_in
    validate
    sort_ip_list
    extract_nets
  end

  # Raise an error if there's something wrong which is not wight
  def validate
    raise("match should exists and be a string.") unless @match.is_a?(String)
    raise("match should be '-s' or '-d'.") if @match != "-d" and @match != "-s"
    raise("prefix should exists and be a string.") unless @prefix.is_a?(String)
    raise("leaf_prefix should be at most 12 chars long.") if @leaf_prefix.size > 12
    raise("prefix should be at most 10 chars long.") if @leaf_prefix.size > 10
  end

  # Set default values for undefined variables.
  # Usually from parent or from hardcoded constant default
  def fill_in
    @level  ||= (parent.nil? ?     0 : parent.level+1)
    @indent ||= (parent.nil? ? false : parent.indent)
    @prefix ||= (parent.nil? ?   nil : parent.prefix)
    @match  ||= (parent.nil? ?   nil : parent.match)

    # The prefix of the leaf is "leaf_prefix".
    # Modifiers goes first, noun at the end.
    # This class accepts "prefix_leaf" for compatibility
    # with old versions
    @leaf_prefix ||= @prefix_leaf

    @leaf_prefix  ||= (parent.nil? ? "#{@prefix}.leaf" : parent.leaf_prefix)
    @nets = []
  end

  def sort_ip_list
    @ip_list.sort! do |x,y|
      # First compare the addresses
      address_comparision=x.to_i <=> y.to_i
      if address_comparision == 0
        # If the addresses are the same sort by mask
        # Specific (bigger cidr_mask) first
        y.cidr_mask <=> x.cidr_mask
      else
        address_comparision
      end
    end.uniq!
  end

  def extract_nets
    # Extract nets bigger than the next split
    # Those nets will be identified at the end
    # of THIS branch.
    @nets=ip_list.select{|ip| ip.cidr_mask < split_mask}
    @ip_list=@ip_list-@nets
  end

  def indent_string
    indent ? " "*INDENT*level : ""
  end

  def extremes; @extremes ||= [ip_list.min,ip_list.max]; end

  def split_mask
    # the smaller CIDR mask that can split ip_list in two lists
    @split_mask ||= 33 - (extremes.first.to_i ^ extremes.last.to_i).to_s(2).size
  end

  def ch_subnets
    @ch_subnets ||= extremes.map{|e| IPAddr.new("#{e.to_s}/#{split_mask}")}
  end

  def childs
    @childs ||=
      (
        if ip_list.count <= LIMIT
          []
        else
          child_ip_list = [[],[]]
          ip_list.each{|ip| child_ip_list[ch=ch_subnets[0].include?(ip) ? 0 : 1] << ip}
          @ip_list=[]
          [0,1].map{|n| self.class.new(:ip_list => child_ip_list[n],:parent => self, :subnet => ch_subnets[n]) }
        end
    )
  end

  def chain_name; @chain_name ||= ( "#{prefix}-#{subnet ? subnet.to_cidr : "MAIN"}"); end

  def to_iptables
    o=[]

    if parent.nil? # Initial node
      o << "# IPTables Tree for #{ip_list.count} addresses"
      o << "#      PREFIX: #{prefix}"
      o << "# LEAF_PREFIX: #{leaf_prefix}"
      o << "#       MATCH: #{match}"
      o << "#      INDENT: #{indent}"
      o << "#"
      o << "#{indent_string}:#{chain_name} -"
      o << "#{indent_string}-F #{chain_name}"
    end

    # Child rules
    childs.each do |ch| # Child init rules, then the child sub-tree
      o << "#{indent_string}:#{ch.chain_name} -"
      o << "#{indent_string}-F #{ch.chain_name}"
      o << "#{indent_string}-A #{chain_name} #{match} #{ch.subnet.to_cidr} -j #{ch.chain_name}"
      o << ch.to_iptables
    end

    # Own IP rules (Child creation empties ip_list)
    ip_list.each do |ip|
      o << "#{indent_string}-A #{chain_name} #{match} #{ip.to_cidr} -j #{leaf_prefix}.#{ip.to_cidr}"
    end

    # Network bigger than current split
    nets.each do |net|
      o << "#{indent_string}-A #{chain_name} #{match} #{net.to_cidr} -j #{leaf_prefix}.#{net.to_cidr}"
    end

    o
  end
end
