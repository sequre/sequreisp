# Sequreisp - Copyright 2010, 2011 Luciano Ruete
#
# This file is part of Sequreisp.
#
# Sequreisp is free software: you can redistribute it and/or modify
# it under the terms of the GNU Afero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sequreisp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Afero General Public License for more details.
#
# You should have received a copy of the GNU Afero General Public License
# along with Sequreisp.  If not, see <http://www.gnu.org/licenses/>.

#PPP_PEER_DIR="/etc/ppp/peer"
BASE=SequreispConfig::CONFIG["base_dir"]
PPP_DIR=SequreispConfig::CONFIG["ppp_dir"]
DHCPD_DIR=SequreispConfig::CONFIG["dhcpd_dir"]
PINGABLE_SERVERS=SequreispConfig::CONFIG["pingable_servers"]
IFB_UP=SequreispConfig::CONFIG["ifb_up"]
IFB_DOWN=SequreispConfig::CONFIG["ifb_down"]
IFB_INGRESS=SequreispConfig::CONFIG["ifb_ingress"]
DEPLOY_DIR=SequreispConfig::CONFIG["deploy_dir"]
BASE_SCRIPTS="#{BASE}/scripts"
SEQUREISP_SQUID_CONF=Rails.env.production? ? "/etc/squid/sequreisp.squid.conf" : "/tmp/sequreisp/squid.conf"
TC_FILE_PREFIX="#{BASE_SCRIPTS}/tc_"
IP_FILE_PREFIX="#{BASE_SCRIPTS}/ip_"
PROVIDER_UP_FILE_PREFIX= "#{BASE_SCRIPTS}/provider_up_"
PROVIDER_DOWN_FILE_PREFIX= "#{BASE_SCRIPTS}/provider_down_"
ARP_FILE="#{BASE_SCRIPTS}/arp"
IP_RU_FILE="#{BASE_SCRIPTS}/ip_ru"
IP_RO_FILE="#{BASE_SCRIPTS}/ip_ro"
IPTABLES_FILE="#{BASE_SCRIPTS}/iptables"
IPTABLES_PRE_FILE="#{BASE}/etc/iptables_pre.sh"
IPTABLES_POST_FILE="#{BASE}/etc/iptables_post.sh"
SEQUREISP_PRE_FILE="#{BASE}/etc/sequreisp_pre.sh"
SEQUREISP_POST_FILE="#{BASE}/etc/sequreisp_post.sh"
BOOT_FILE="#{BASE_SCRIPTS}/boot.sh"
QUEUED_COMMANDS_FILE="#{BASE_SCRIPTS}/queued_commands.sh"
BOOT_LOG="#{BOOT_FILE}.log"
CHECK_LINKS_FILE="#{BASE_SCRIPTS}/check_links.sh"
CHECK_LINKS_LOG="#{CHECK_LINKS_FILE}.log"

def create_dirs_if_not_present
  [BASE_SCRIPTS, DHCPD_DIR, PPP_DIR, DEPLOY_DIR, "#{PPP_DIR}/ip-up.d", "#{PPP_DIR}/ip-down.d", "#{DHCPD_DIR}/dhclient-enter-hooks.d",  "#{DHCPD_DIR}/dhclient-exit-hooks.d", "#{PPP_DIR}/peers"].each do |dir|
    dir.split("/").inject do |path, dir|
      new_dir = "#{path}/#{dir}"
      Dir.mkdir(new_dir) if not File.exist? new_dir
      new_dir
    end
  end
end

def gen_tc(f)
  def tc_class_qdisc_filter(o = {})
    classid = "#{o[:parent_mayor]}:#{o[:current_minor]}"
    tc = o[:file]
    tc.puts "class add dev #{o[:iface]} parent #{o[:parent_mayor]}:#{o[:parent_minor]} classid #{classid} " +
            "htb rate #{o[:rate]}kbit ceil #{o[:ceil]}kbit prio #{o[:prio]} quantum #{o[:quantum]}"
    tc.puts "qdisc add dev #{o[:iface]} parent #{classid} sfq perturb 10" #saco el handle
    tc.puts "filter add dev #{o[:iface]} parent #{o[:parent_mayor]}: protocol all prio 200 handle 0x#{o[:mark]}/0x#{o[:mask]} fw classid #{classid}"
  end
  def do_global_prios_tc(file, iface, parent_mayor, parent_minor, rate, quantum)
    mask = "f0000000"
    #TODO tc_global ceil_prio3 quantum mark, etc
    #prio1
    tc_class_qdisc_filter :file => file, :iface => iface, :parent_mayor => parent_mayor, :parent_minor => parent_minor, :current_minor => "a",
                          :rate => rate * 0.4 , :ceil => rate , :prio => 1, :quantum => quantum, :mark => "a0000000", :mask => mask
    #prio2
    tc_class_qdisc_filter :file => file, :iface => iface, :parent_mayor => parent_mayor, :parent_minor => parent_minor, :current_minor => "b",
                          :rate => rate * 0.5 , :ceil => rate , :prio => 2, :quantum => quantum, :mark => "b0000000", :mask => mask
    #prio3
    tc_class_qdisc_filter :file => file, :iface => iface, :parent_mayor => parent_mayor, :parent_minor => parent_minor, :current_minor => "c",
                          :rate => rate * 0.1 , :ceil => rate * 0.3 , :prio => 3, :quantum => quantum / 3, :mark => "c0000000", :mask => mask
  end
  def do_per_contract_prios_tc(tc, plan, c, parent_mayor, parent_minor, iface, direction, prefix=0)
    contract_min_rate = 0.024
    klass = c.class_hex
    # prefix == 0 significa que matcheo en las ifb donde tengo los clientes colgados directo del root
    # prefix != 0 significa que matcheo en las ifaces reales donde tengo un arbol x cada enlace
    mask = prefix == 0 ? "0000ffff" : "00ffffff"
    rate = plan["rate_" + direction] == 0 ?  contract_min_rate : plan["rate_" + direction]
    rate_prio1 = rate == contract_min_rate ? rate/3 : rate*0.05
    rate_prio2 = rate == contract_min_rate ? rate/3 : rate*0.9
    rate_prio3 = rate == contract_min_rate ? rate/3 : rate*0.05
    ceil = plan["ceil_" + direction]
    mtu = Configuration.mtu
    quantum_factor = (plan["ceil_" + direction] + plan["rate_" + direction])/Configuration.quantum_factor.to_i
    quantum_factor = 1 if quantum_factor <= 0
    quantum_total = mtu * quantum_factor * 3

    #padre
    tc.puts "##{c.client.name}: #{c.id} #{c.klass.number}"
    tc.puts "class add dev #{iface} parent #{parent_mayor}:#{parent_minor} classid #{parent_mayor}:#{klass} htb rate #{rate}kbit ceil #{ceil}kbit quantum #{quantum_total}"
    if Configuration.use_global_prios
      #huérfano, solo el filter
      tc.puts "filter add dev #{iface} parent #{parent_mayor}: protocol all prio 200 handle 0x#{klass}/0x#{mask} fw classid #{parent_mayor}:#{klass}"
    else
      #hijos
      #prio1
      tc_class_qdisc_filter :prio => 1, :file => tc, :iface => iface,
                            :parent_mayor => parent_mayor, :parent_minor => klass, :current_minor => c.class_prio1_hex,
                            :rate => rate_prio1, :ceil => ceil,
                            :quantum => mtu * quantum_factor * 3,
                            :mark => c.mark_prio1_hex(prefix), :mask => mask
      #prio2
      tc_class_qdisc_filter :prio => 2, :file => tc, :iface => iface,
                            :parent_mayor => parent_mayor, :parent_minor => klass, :current_minor => c.class_prio2_hex,
                            :rate => rate_prio2, :ceil => ceil,
                            :quantum => mtu * quantum_factor * 2,
                            :mark => c.mark_prio2_hex(prefix), :mask => mask
      #prio3
      tc_class_qdisc_filter :prio => 3, :file => tc, :iface => iface,
                            :parent_mayor => parent_mayor, :parent_minor => klass, :current_minor => c.class_prio3_hex,
                            :rate => rate_prio3, :ceil => ceil * c.ceil_dfl_percent / 100,
                            :quantum => mtu,
                            :mark => c.mark_prio3_hex(prefix), :mask => mask
    end
  end
  begin
    tc_ifb_up = File.open(TC_FILE_PREFIX + IFB_UP, "w")
    tc_ifb_down = File.open(TC_FILE_PREFIX + IFB_DOWN, "w")
    tc_ifb_ingres = File.open(TC_FILE_PREFIX + IFB_INGRESS, "w")
    # htb tree de clientes en gral en IFB
    f.puts "tc qdisc del dev #{IFB_UP} root"
    tc_ifb_up.puts "qdisc add dev #{IFB_UP} root handle 1 htb default 0"
    tc_ifb_up.puts "class add dev #{IFB_UP} parent 1: classid 1:1 htb rate 1000mbit"
    f.puts "tc qdisc del dev #{IFB_DOWN} root"
    tc_ifb_down.puts "qdisc add dev #{IFB_DOWN} root handle 1 htb default 0"
    tc_ifb_down.puts "class add dev #{IFB_DOWN} parent 1: classid 1:1 htb rate 1000mbit"
    Contract.not_disabled.descend_by_netmask.each do |c|
      do_per_contract_prios_tc tc_ifb_up, c.plan, c, 1, 1, IFB_UP, "up"
      do_per_contract_prios_tc tc_ifb_down, c.plan, c, 1, 1, IFB_DOWN, "down"
    end
    tc_ifb_up.close
    tc_ifb_down.close

    # htb tree ingress IFB (htb providers + sfq)
    divisor = 2
    target = Contract.count
    divisor *= 2 while target > divisor
    f.puts "tc qdisc del dev #{IFB_INGRESS} root"
    tc_ifb_ingres.puts "qdisc add dev #{IFB_INGRESS} root handle 1: htb default 0"
    Provider.enabled.all(:conditions => { :shape_rate_down_on_ingress => true }).each do |p|
      tc_ifb_ingres.puts "class add dev #{IFB_INGRESS} parent 1: classid 1:#{p.class_hex} htb rate #{p.rate_down}kbit"
      tc_ifb_ingres.puts "filter add dev #{IFB_INGRESS} parent 1: protocol ip prio 10 u32 match ip dst #{p.ip}/#{p.netmask_suffix} classid 1:#{p.class_hex}"
      p.addresses.each do |a|
        tc_ifb_ingres.puts "filter add dev #{IFB_INGRESS} parent 1: protocol ip prio 10 u32 match ip dst #{a.ip}/#{a.netmask_suffix} classid 1:#{p.class_hex}"
      end
      tc_ifb_ingres.puts "qdisc add dev #{IFB_INGRESS} parent 1:#{p.class_hex} handle #{p.class_hex} sfq"
      tc_ifb_ingres.puts "filter add dev #{IFB_INGRESS} parent #{p.class_hex}: protocol ip pref 1 handle 0x#{p.class_hex} flow hash keys nfct-dst divisor #{divisor}"
    end
    tc_ifb_ingres.close
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::gen_tc(IFB_UP/IFB_DOWN) e=>#{e.inspect}"
  end

  # htb tree up + ingress redirect filter (en las ifaces de Provider)
  Provider.enabled.with_klass_and_interface.each do |p|
    #max quantum posible para este provider, necesito saberlo con anticipación
    quantum = Configuration.mtu * p.quantum_factor * 3
    iface = p.link_interface
    f.puts "tc qdisc del dev #{iface} root"
    f.puts "tc qdisc del dev #{iface} ingress"
    begin
      File.open(TC_FILE_PREFIX + iface, "w") do |tc|
        tc.puts "qdisc add dev #{iface} root handle 1: prio bands 3 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
        tc.puts "filter add dev #{iface} parent 1: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev #{IFB_UP}"
        tc.puts "qdisc add dev #{iface} parent 1:1 handle #{p.class_hex}: htb default 0"
        tc.puts "class add dev #{iface} parent #{p.class_hex}: classid #{p.class_hex}:1 htb rate #{p.rate_up}kbit quantum #{quantum}"
        if Configuration.use_global_prios
          do_global_prios_tc tc, iface, p.class_hex, 1, p.rate_up, quantum
        else
          if Configuration.tc_contracts_per_provider_in_wan
            Contract.not_disabled.descend_by_netmask.each do |c|
              do_per_contract_prios_tc tc, c.plan, c, p.class_hex, 1, iface, "up", p.mark
            end
          else
            tc.puts "filter add dev #{iface} parent #{p.class_hex}: protocol all prio 10 handle 0x#{p.class_hex}0000/0x00ff0000 fw classid #{p.class_hex}:1"
          end
        end
        # real iface setup
        tc.puts "qdisc add dev #{iface} ingress"
        if p.shape_rate_down_on_ingress
          # this is supposed to match ack packets with size < 64bytes (from http://lartc.org/howto/lartc.adv-filter.html)
          tc.puts "filter add dev #{iface} parent ffff: protocol ip prio 1 u32  match ip protocol 6 0xff match u8 0x10 0xff at nexthdr+13 match u16 0x0000 0xffc0 at 2 action pass"
          # redirect traffic to the ifb
          tc.puts "filter add dev #{iface} parent ffff: protocol ip prio 1 u32 match u32 0 0 action mirred egress redirect dev #{IFB_INGRESS}"
        else
          tc.puts "filter add dev #{iface} parent ffff: protocol ip prio 1 handle 1 flow hash keys nfct-dst divisor 1024"
        end
      end
    rescue => e
      Rails.logger.error "ERROR in lib/sequreisp.rb::gen_tc(#htb tree up) e=>#{e.inspect}"
    end
  end

  # htb tree down (en las ifaces lan) 
  Interface.all(:conditions => { :kind => "lan" }).each do |interface|
    iface = interface.name
    f.puts "tc qdisc del dev #{iface} root"
    begin
      File.open(TC_FILE_PREFIX + iface, "w") do |tc|
        tc.puts "qdisc add dev #{iface} root handle 1: prio bands 3 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
        tc.puts "filter add dev #{iface} parent 1: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev #{IFB_DOWN}"
        tc.puts "qdisc add dev #{iface} parent 1:1 handle 2: htb default 0"
        Provider.enabled.with_klass_and_interface.each do |p|
          #max quantum posible para este provider, necesito saberlo con anticipación
          quantum = Configuration.mtu * p.quantum_factor * 3
          tc.puts "class add dev #{iface} parent 2: classid 2:#{p.class_hex} htb rate #{p.rate_down}kbit quantum #{quantum}"
          tc.puts "filter add dev #{iface} parent 2: protocol all prio 10 handle 0x#{p.class_hex}0000/0x00ff0000 fw classid 2:#{p.class_hex}"
          if Configuration.use_global_prios
            tc.puts "qdisc add dev #{iface} parent 2:#{p.class_hex} handle #{p.class_hex}: htb default 0"
            tc.puts "class add dev #{iface} parent #{p.class_hex}: classid #{p.class_hex}:1 htb rate #{p.rate_down}kbit quantum #{quantum}"
            do_global_prios_tc tc, iface, p.class_hex, 1, p.rate_down, quantum
          elsif Configuration.tc_contracts_per_provider_in_lan
            tc.puts "qdisc add dev #{iface} parent 2:#{p.class_hex} handle #{p.class_hex}: htb default 0"
            tc.puts "class add dev #{iface} parent #{p.class_hex}: classid #{p.class_hex}:1 htb rate #{p.rate_down}kbit quantum #{quantum}"
            Contract.not_disabled.descend_by_netmask.each do |c|
              do_per_contract_prios_tc tc, c.plan, c, p.class_hex, 1, iface, "down", p.mark
            end
          end
        end
      end
    rescue => e
      Rails.logger.error "ERROR in lib/sequreisp.rb::gen_tc(#htb tree down) e=>#{e.inspect}"
    end
  end
end

def gen_iptables
  def do_prio_traffic_iptables(o={})
    o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p tcp -m length --length 0:100 -j MARK --set-mark #{o[:mark]}"
    o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p tcp --dport 22 -j MARK --set-mark #{o[:mark]}"
    o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p tcp --sport 22 -j MARK --set-mark #{o[:mark]}"
    o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p udp --dport 53 -j MARK --set-mark #{o[:mark]}"
    o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p udp --sport 53 -j MARK --set-mark #{o[:mark]}"
    o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p icmp -j MARK --set-mark #{o[:mark]}"
  end
  def do_prio_protos_iptables(o={})
    o[:protos].each do |proto|
      o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p #{proto} -j MARK --set-mark #{o[:mark]}"
    end
  end
  def do_prio_helpers_iptables(o={})
    o[:helpers].each do |helper|
      o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -m helper --helper #{helper} -j MARK --set-mark #{o[:mark]}"
    end
  end
  def do_prio_ports_iptables(o={})
    # solo 15 puertos por vez en multiport
    while !o[:ports].empty? do
      _ports = o[:ports].slice!(0..14).join(",")
      o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p #{o[:proto]} -m multiport --dports #{_ports} -j MARK --set-mark #{o[:mark]}"
      o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p #{o[:proto]} -m multiport --sports #{_ports} -j MARK --set-mark #{o[:mark]}"
    end
  end
  begin
    File.open(IPTABLES_FILE, "w") do |f|
      #--------#
      # MANGLE #
      #--------#
      f.puts "*mangle"
      if Configuration.clamp_mss_to_pmtu
        f.puts "-A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu"
        f.puts "-A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu"
      end
      # CONNMARK PREROUTING
      # restauro marka en PREROUTING
      f.puts "-A PREROUTING -j CONNMARK --restore-mark"

      # acepto si ya se de que enlace es
      f.puts "-A PREROUTING -m mark ! --mark 0 -j ACCEPT"
      # si viene desde internet marko segun el enlace por el que entró
      Provider.enabled.with_klass_and_interface.each do |p|
        f.puts "-A PREROUTING -i #{p.link_interface} -j MARK --set-mark 0x#{p.mark_hex}/0x00ff0000"
        f.puts "-A PREROUTING -i #{p.link_interface} -j CONNMARK --save-mark"
        f.puts "-A PREROUTING -i #{p.link_interface} -j ACCEPT" 
      end
      # tabla para evitar triangulo de nat
      # como arriba ya hice ACCEPT de lo que entra por los
      # providers, esto solo impacta si la iface de entrada no es WAN
      f.puts ":avoid_nat_triangle - [0:0]"
      f.puts "-A PREROUTING -j avoid_nat_triangle"
      ForwardedPort.all(:include => [ :contract, :provider ]).each do |fp|
        do_port_forwardings_avoid_nat_triangle f, fp
      end

      # sino marko por cliente segun el ProviderGroup al que pertenezca
      Contract.not_disabled.descend_by_netmask(:include => [{ :plan => :provider_group}, :unique_provider, :public_address ]).each do |c|
        if !c.public_address.nil?
          #evito triangulo de NAT si tiene full DNAT
          f.puts "-A avoid_nat_triangle -d #{c.public_address.ip} -j MARK --set-mark 0x01000000/0x01000000"
        end

        mark = if not c.public_address.nil?
                 c.public_address.addressable.mark_hex
               elsif not c.unique_provider.nil?
                 # marko los contratos que salen por un único provider
                 c.unique_provider.mark_hex
               else
                 c.plan.provider_group.mark_hex
              end
        f.puts "-A PREROUTING -s #{c.ip} -j MARK --set-mark 0x#{mark}/0x00ff0000"
        f.puts "-A PREROUTING -s #{c.ip} -j ACCEPT" 
      end
      # CONNMARK OUTPUT
      # restauro marka en OUTPUT pero que siga viajando
      f.puts "-A OUTPUT -j CONNMARK --restore-mark"
      f.puts "-A OUTPUT -m mark ! --mark 0 -j ACCEPT"
      if Configuration.transparent_proxy
        if Configuration.transparent_proxy_n_to_m
          Contract.not_disabled.descend_by_netmask.each do |c|
            mark = c.public_address.nil? ? c.plan.provider_group.mark_hex : c.public_address.addressable.mark_hex
            f.puts "-A OUTPUT -s #{c.proxy_bind_ip} -j MARK --set-mark 0x#{mark}/0x00ff0000"
          end
        else
          ProviderGroup.enabled.with_klass.each do |pg|
            # marko provider_group según tcp_outgoing_address de squid
            f.puts "-A OUTPUT -s #{pg.proxy_bind_ip} -j MARK --set-mark 0x#{pg.mark_hex}/0x00ff0000"
          end
        end
      end 
      # CONNMARK POSTROUTING
      f.puts ":sequreisp_connmark - [0:0]"
      Provider.enabled.with_klass_and_interface.each do |p|
        f.puts "-A sequreisp_connmark  -o #{p.link_interface} -j MARK --set-mark 0x#{p.mark_hex}/0x00ff0000"
      end
      # si tiene marka de ProviderGroup voy a sequreisp_connmark
      ProviderGroup.enabled.with_klass.each do |pg|
        f.puts "-A POSTROUTING -m mark --mark 0x#{pg.mark_hex}/0x00ff0000 -j sequreisp_connmark"
      end
      # si no tiene ninguna marka de ruteo también va a sequreisp_connmark (lo de OUTPUT hit'ea aquí ej. bind DNS query)
      f.puts "-A POSTROUTING -m mark --mark 0x00000000/0x00ff0000 -j sequreisp_connmark"
      
      if Configuration.transparent_proxy and Configuration.transparent_proxy_zph_enabled
        f.puts "-A POSTROUTING -p tcp --sport 3128 -m tos --tos 0x10 -j ACCEPT"
      end

      f.puts ":sequreisp.down - [0:0]"
      f.puts ":sequreisp.up - [0:0]"
      
      #speed-up MARKo solo si no estaba a restore'ada x CONNMARK
      mark_if="-m mark --mark 0x0/0xffff" 
      Interface.all(:conditions => { :kind => "lan" }).each do |interface|
        f.puts "-A POSTROUTING #{mark_if} -o #{interface.name} -j sequreisp.down"
      end
      Provider.enabled.with_klass_and_interface.each do |p|
        f.puts "-A POSTROUTING #{mark_if} -o #{p.link_interface} -j sequreisp.up"
      end

      def build_iptables_tree(f, parent_net, parent_chain, way, cuartet, mask)
        return if cuartet == 0
        base_net = IP.new parent_net.gsub(/\/.*/, "") + "/#{mask}"
        (0..15).each do |n|
          child_net = (base_net + n * 16**cuartet).to_s
          chain="sq.#{way[:prefix]}.#{child_net}"
          f.puts ":#{chain} - [0:0]"
          f.puts "-A #{parent_chain} -#{way[:dir]} #{child_net} -j #{chain}"
          build_iptables_tree f, child_net, chain, way, cuartet - 1, mask + 4
        end
      end
      if Configuration.iptables_tree_optimization_enabled?
        Contract.slash_16_networks.each do |n16|
          [{:prefix =>'up', :dir => 's'},{:prefix => 'down', :dir => 'd'}].each do |way|
            chain="sq.#{way[:prefix]}.#{n16}"
            f.puts ":#{chain} - [0:0]"
            f.puts "-A sequreisp.#{way[:prefix]} -#{way[:dir]} #{n16} -j #{chain}"
            build_iptables_tree f, n16, chain, way, 3, 20
          end
        end
      end
      if Configuration.use_global_prios
        #mark_burst = "0x0000/0x0000ffff"
        mark_prio1 = "0xa0000000/0xf0000000"
        mark_prio2 = "0xb0000000/0xf0000000"
        mark_prio3 = "0xc0000000/0xf0000000"
        mark_if="-m mark --mark 0x0/0xf0000000"
        Contract.not_disabled.descend_by_netmask.each do |c|
          mark = "0x#{c.mark_hex}/0x0000ffff"
          f.puts "-A #{c.mangle_chain("up")} -s #{c.ip} -j MARK --set-mark #{mark}"
          if Configuration.transparent_proxy and Configuration.transparent_proxy_n_to_m
            f.puts "-A #{c.mangle_chain("up")} -s #{c.proxy_bind_ip} -j MARK --set-mark #{mark}"
          end
          f.puts "-A #{c.mangle_chain("down")} -d #{c.ip} -j MARK --set-mark #{mark}"
        end
        # una chain global
        ["sequreisp.up", "sequreisp.down"].each do |chain|
          # separo el tráfico en las 3 class: prio1 prio2 prio3
          # prio1
          do_prio_traffic_iptables :file => f, :chain => chain, :mark_if => mark_if, :mark => mark_prio1
          # prio2
          do_prio_protos_iptables :file => f, :protos => Configuration.default_prio_protos_array, :chain => chain, :mark => mark_prio2
          do_prio_helpers_iptables :file => f, :helpers => Configuration.default_prio_helpers_array, :chain => chain, :mark => mark_prio2
          do_prio_ports_iptables :file => f, :ports => Configuration.default_tcp_prio_ports_array, :proto => "tcp", :chain => chain, :mark => mark_prio2
          do_prio_ports_iptables :file => f, :ports => Configuration.default_udp_prio_ports_array, :proto => "udp", :chain => chain, :mark => mark_prio2
          # prio3 (catch_all)
          f.puts "-A #{chain} #{mark_if} -j MARK --set-mark #{mark_prio3}"

          # long downloads/uploads limit
          # TODO global_tc plan.long_download
          #if c.plan.long_download_max != 0
          #  f.puts "-A #{chain} -p tcp -m multiport --sports 80,443,3128 -m connbytes --connbytes #{c.plan.long_download_max_to_bytes}: --connbytes-dir reply --connbytes-mode bytes -j MARK --set-mark #{mark_prio3}"
          #end
          #if c.plan.long_upload_max != 0
          #  f.puts "-A #{chain} -p tcp -m multiport --dports 80,443 -m connbytes --connbytes #{c.plan.long_upload_max_to_bytes}: --connbytes-dir original --connbytes-mode bytes -j MARK --set-mark #{mark_prio3}"
          #end
          ## if burst, sets mark to 0x0000, making the packet impact in provider class rather than contract's one
          #if c.plan.burst_down != 0
          #  f.puts "-A #{chain} -p tcp -m multiport --sports 80,443,3128 -m connbytes --connbytes 0:#{c.plan.burst_down_to_bytes} --connbytes-dir reply --connbytes-mode bytes -j MARK --set-mark #{mark_burst}"
          #end
          #if c.plan.burst_up != 0
          #  f.puts "-A #{chain} -p tcp -m multiport --dports 80,443 -m connbytes --connbytes 0:#{c.plan.burst_up_to_bytes} --connbytes-dir original --connbytes-mode bytes -j MARK --set-mark #{mark_burst}"
          #end
          # guardo la marka para evitar pasar por todo esto de nuevo, salvo si impacto en la prio1
          # f.puts "-A #{chain} -m mark ! --mark #{mark_prio1} -j CONNMARK --save-mark"
          f.puts "-A #{chain} -j ACCEPT"
        end
      else
        Contract.not_disabled.descend_by_netmask.each do |c|
          mark_burst = "0x0000/0x0000ffff"
          mark_prio1 = "0x#{c.mark_prio1_hex}/0x0000ffff"
          mark_prio2 = "0x#{c.mark_prio2_hex}/0x0000ffff"
          mark_prio3 = "0x#{c.mark_prio3_hex}/0x0000ffff"
          # una chain por cada cliente
          chain="sq.#{c.ip}"
          f.puts ":#{chain} - [0:0]"
          # redirección del trafico de este cliente hacia su propia chain
          f.puts "-A #{c.mangle_chain("down")} -d #{c.ip} -j #{chain}"
          f.puts "-A #{c.mangle_chain("up")} -s #{c.ip} -j #{chain}"
          if Configuration.transparent_proxy and Configuration.transparent_proxy_n_to_m
            f.puts "-A sequreisp.up -s #{c.proxy_bind_ip} -j #{chain}"
          end
          # separo el tráfico en las 3 class: prio1 prio2 prio3
          # prio1
          do_prio_traffic_iptables :file => f, :chain => chain, :mark_if => mark_if, :mark => mark_prio1
          # prio2
          do_prio_protos_iptables :protos => (Configuration.default_prio_protos_array + c.prio_protos_array).uniq,
                                  :file => f, :chain => chain, :mark => mark_prio2
          do_prio_helpers_iptables :helpers => (Configuration.default_prio_helpers_array + c.prio_helpers_array).uniq,
                                   :file => f, :chain => chain, :mark => mark_prio2
          do_prio_ports_iptables :ports => (Configuration.default_tcp_prio_ports_array + c.tcp_prio_ports_array).uniq,
                                 :proto => "tcp", :file => f, :chain => chain, :mark => mark_prio2
          do_prio_ports_iptables :ports => (Configuration.default_udp_prio_ports_array + c.udp_prio_ports_array).uniq,
                                 :proto => "udp", :file => f, :chain => chain, :mark => mark_prio2
          # prio3 (catch_all)
          f.puts "-A #{chain} #{mark_if} -j MARK --set-mark #{mark_prio3}"

          # long downloads/uploads limit
          if c.plan.long_download_max != 0
            f.puts "-A #{chain} -p tcp -m multiport --sports 80,443,3128 -m connbytes --connbytes #{c.plan.long_download_max_to_bytes}: --connbytes-dir reply --connbytes-mode bytes -j MARK --set-mark #{mark_prio3}"
          end
          if c.plan.long_upload_max != 0
            f.puts "-A #{chain} -p tcp -m multiport --dports 80,443 -m connbytes --connbytes #{c.plan.long_upload_max_to_bytes}: --connbytes-dir original --connbytes-mode bytes -j MARK --set-mark #{mark_prio3}"
          end
          # if burst, sets mark to 0x0000, making the packet impact in provider class rather than contract's one
          if c.plan.burst_down != 0
            f.puts "-A #{chain} -p tcp -m multiport --sports 80,443,3128 -m connbytes --connbytes 0:#{c.plan.burst_down_to_bytes} --connbytes-dir reply --connbytes-mode bytes -j MARK --set-mark #{mark_burst}"
          end
          if c.plan.burst_up != 0
            f.puts "-A #{chain} -p tcp -m multiport --dports 80,443 -m connbytes --connbytes 0:#{c.plan.burst_up_to_bytes} --connbytes-dir original --connbytes-mode bytes -j MARK --set-mark #{mark_burst}"
          end
          # guardo la marka para evitar pasar por todo esto de nuevo, salvo si impacto en la prio1
          # f.puts "-A #{chain} -m mark ! --mark #{mark_prio1} -j CONNMARK --save-mark"
          f.puts "-A #{chain} -j ACCEPT"
        end
      end
      f.puts "-A POSTROUTING -m mark ! --mark 0 -j CONNMARK --save-mark"
      f.puts "COMMIT"
      #---------#
      # /MANGLE #
      #---------#
      
      #-----#
      # NAT #
      #-----#
      f.puts "*nat"

      Contract.not_disabled.descend_by_netmask.each do |c|
        # attribute: public_address
        #   a cada ip publica asignada le hago un DNAT completo
        #   a cada ip publica asignada le hago un SNAT a su respectiva ip
        if !c.public_address.nil?
          f.puts "-A PREROUTING -d #{c.public_address.ip} -j DNAT --to-destination #{c.ip}"

          f.puts "-A POSTROUTING -s #{c.ip} -o #{c.public_address.addressable.link_interface} -j SNAT --to-source #{c.public_address.ip}"
          if Configuration.transparent_proxy and Configuration.transparent_proxy_n_to_m
            f.puts "-A POSTROUTING -s #{c.proxy_bind_ip} -o #{c.public_address.addressable.link_interface} -j SNAT --to-source #{c.public_address.ip}"
          end
        end
      end
      # attribute: forwarded_ports
      #   forward de ports por Provider
      ForwardedPort.all(:include => [ :contract, :provider ]).each do |fp|
        do_port_forwardings f, fp
      end

      # Transparent PROXY rules (should be at the end of all others DNAT/REDIRECTS
      # Avoids tproxy to server ip's
      Interface.all(:conditions => "kind = 'lan'").each do |i| 
        i.addresses.each do |a|
          f.puts "-A PREROUTING -i #{i.name} -d #{a.ip} -p tcp --dport 80 -j ACCEPT"
        end
        #TODO ver que pasa con provider dinamicos que cambian la ip
        Provider.enabled.ready.each do |p|
          f.puts "-A PREROUTING -i #{i.name} -d #{p.ip} -p tcp --dport 80 -j ACCEPT"
          p.addresses.each do |a|
            f.puts "-A PREROUTING -i #{i.name} -d #{a.ip} -p tcp --dport 80 -j ACCEPT"
          end
        end
      end

      BootHook.run :hook => :nat_after_forwards_hook, :iptables_script => f

      Contract.not_disabled.descend_by_netmask.each do |c|
        # attribute: transparent_proxy
        if c.transparent_proxy?
          f.puts "-A PREROUTING -s #{c.ip} -p tcp --dport 80 -j REDIRECT --to-port 3128"
        end
      end
      Provider.enabled.with_klass_and_interface.each do |p|
        p.networks.each do |network|
          f.puts "-A POSTROUTING -o #{p.link_interface} -s #{network} -j ACCEPT"
        end
        # do we have an ip yet?
        if p.ip.blank? or p.kind != 'static'
          f.puts "-A POSTROUTING -o #{p.link_interface}  -j MASQUERADE"
        else
          provider_ips = p.nat_pool_addresses
          if provider_ips.size > 1
            # find all contract ips for this provider
            contracts_ips = Contract.not_disabled.descend_by_ip_custom.all(:joins => :plan ,:conditions => ["provider_group_id = ?", p.provider_group_id]  , :select => :ip).collect(&:ip)
            # need to know if we have more ip than contracts
            start_at = 0
            if contracts_ips.size > provider_ips.size
              slice =  contracts_ips.size / provider_ips.size
              loops = provider_ips.size
              start_at = 1
            else
              #more contracts, one ip per contract then
              slice = 1
              loops = contracts_ips.size
              start_at = 0
            end
            to="255.255.255.255"
            (loops-1).times do |i|
              from=contracts_ips[slice*(i+start_at)]
              f.puts "-A POSTROUTING -o #{p.link_interface} -m iprange --src-range #{from}-#{to} -j SNAT --to-source #{provider_ips[i]}"
              to=from
            end
            f.puts "# last ip #{contracts_ips[-1]}"
          end
          f.puts "-A POSTROUTING -o #{p.link_interface} -j SNAT --to-source #{provider_ips[-1]}"
          #addresses.each_with_index do |ip,i|
          #  f.puts "-A POSTROUTING -o #{p.link_interface} -m statistic --mode nth --every #{total-i} -j SNAT --to-source #{ip}"
          #end

        end
      end
      f.puts "-A POSTROUTING -m mark --mark 0x01000000/0x01000000 -j MASQUERADE"
      f.puts "COMMIT"
      #-------#
      # /NAT  #
      #-------#
      #---------#
      # FILTER  #
      #---------#
      f.puts "*filter"
      f.puts ":sequreisp-enabled - [0:0]"
      f.puts "-A INPUT -i lo -j ACCEPT"
      f.puts "-A OUTPUT -o lo -j ACCEPT"
      f.puts "-A INPUT -p tcp --dport 3128 -j sequreisp-enabled"
      Provider.enabled.with_klass_and_interface.each do |p|
        f.puts "-A FORWARD -o #{p.link_interface} -j sequreisp-enabled"
      end

      #
      Contract.not_disabled.descend_by_netmask.each do |c|
        BootHook.run :hook => :iptables_contract_filter, :iptables_script => f, :contract => c
        # attribute: state
        #   estado del cliente enabled/alerted/disabled
        macrule = (Configuration.filter_by_mac_address and !c.mac_address.blank?) ? "-m mac --mac-source #{c.mac_address}" : ""
        f.puts "-A sequreisp-enabled #{macrule} -s #{c.ip} -j ACCEPT"
      end
      f.puts "-A sequreisp-enabled -j DROP"
      f.puts "COMMIT"
      #---------#
      # /FILTER #
      #---------#
    # close iptables file
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::gen_iptables e=>#{e.inspect}"
  end
end

def do_port_forwardings(f, fp, batch=true)
  prefix = batch ? "" : "iptables -t nat "
  unless fp.provider.ip.blank? or fp.contract.nil?
    f.puts prefix + "-A PREROUTING -d #{fp.provider.ip} -p tcp --dport #{fp.public_port} -j DNAT --to #{fp.contract.ip}:#{fp.private_port}" if fp.tcp
    f.puts prefix + "-A PREROUTING -d #{fp.provider.ip} -p udp --dport #{fp.public_port} -j DNAT --to #{fp.contract.ip}:#{fp.private_port}" if fp.udp
  end
end
def do_port_forwardings_avoid_nat_triangle(f, fp, batch=true)
  prefix = batch ? "" : "iptables -t mangle "
  unless fp.provider.ip.blank?
    f.puts prefix + "-A avoid_nat_triangle -d #{fp.provider.ip} -p tcp --dport #{fp.public_port} -j MARK --set-mark 0x01000000/0x01000000" if fp.tcp
    f.puts prefix + "-A avoid_nat_triangle -d #{fp.provider.ip} -p udp --dport #{fp.public_port} -j MARK --set-mark 0x01000000/0x01000000" if fp.udp
  end
end

def gen_ip_ru
  begin
    File.open(IP_RU_FILE, "w") do |f| 
      f.puts "rule flush"
      f.puts "rule add prio 1 lookup main"
      ProviderGroup.enabled.with_klass.each do |pg|
        f.puts "rule add fwmark 0x#{pg.mark_hex}/0x00ff0000 table #{pg.table} prio 200"
      end
      Provider.enabled.with_klass_and_interface.each do |p|
        f.puts "rule add fwmark 0x#{p.mark_hex}/0x00ff0000 table #{p.table} prio 300"
        p.networks.each do |network|
          f.puts "rule add from #{network} table #{p.table}  prio 100"
        end
        f.puts "rule add from #{p.ip}/32 table #{p.check_link_table} prio 90" if p.ip and not p.ip.empty?
      end
      f.puts "rule add prio 32767 from all lookup default"
    end 
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::gen_ip_ru e=>#{e.inspect}"
  end
end

def update_fallback_route(f, batch=true, force=false)
  prefix = batch ? "" : "ip " 
  #tabla default (fallback de todos los enlaces)
	currentroute=`ip -oneline ro li table default | grep default`.gsub("\\\t","  ").strip
  if (currentroute != Provider.fallback_default_route) or force
    if Provider.fallback_default_route != ""
      #TODO por ahora solo cambio si hay ruta, sino no toco x las dudas
      f.puts prefix + "ro re table default #{Provider.fallback_default_route}" 
    end
    #TODO loguear? el cambio de estado en una bitactora
  end
end

def update_provider_group_route(f, pg, batch=true, force=false)
  prefix = batch ? "" : "ip " 
  currentroute=`ip -oneline ro li table #{pg.table} | grep default`.gsub("\\\t","  ").strip
  if (currentroute != pg.default_route) or force
    if pg.default_route == ""
      f.puts prefix + "ro del table #{pg.table} default"
    else
      f.puts prefix + "ro re table #{pg.table} #{pg.default_route}" 
    end
    #TODO loguear el cambio de estado en una bitactora
  end
end

def update_provider_route(f, p, batch=true, force=false)
  prefix = batch ? "" : "ip " 
  currentroute=`ip -oneline ro li table #{p.table} | grep default`.gsub("\\\t","  ").strip
  default_route = p.online ? p.default_route : ""
  if (currentroute != default_route) or force
    if default_route == ""
      f.puts prefix + "ro del table #{p.table} default"
    else
      f.puts prefix + "ro re table #{p.table} #{p.default_route}" 
    end
    #TODO loguear el cambio de estado en una bitactora
  end
end

def gen_ip_ro
  begin
    File.open(IP_RO_FILE, "w") do |f| 
      Provider.enabled.ready.with_klass_and_interface.each do |p|
        update_provider_route f, p, true, true
      end
      ProviderGroup.enabled.each do |pg| 
        update_provider_group_route f, pg, true, true
      end
      update_fallback_route f, true, true
    end 
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::gen_ip_ro e=>#{e.inspect}"
  end
end

def setup_dynamic_providers_hooks
  begin
    File.open("#{PPP_DIR}/ip-up.d/1sequreisp", 'w') do |f| 
      f.puts "#!/bin/sh" 
      f.puts "#{DEPLOY_DIR}/script/runner -e production #{DEPLOY_DIR}/bin/sequreisp_up_down_provider.rb up $PPP_IPPARAM $PPP_LOCAL 255.255.255.255 $PPP_REMOTE"
      f.chmod(0755)
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::setup_dynamic_providers_hooks(PPP_DIR/ip-up) e=>#{e.inspect}"
  end

  begin
    File.open("#{PPP_DIR}/ip-down.d/1sequreisp", 'w') do |f| 
      f.puts "#!/bin/sh" 
      f.puts "#{DEPLOY_DIR}/script/runner -e production #{DEPLOY_DIR}/bin/sequreisp_up_down_provider.rb down $PPP_IPPARAM"
      f.chmod(0755)
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::setup_dynamic_providers_hooks(PPP_DIR/ip-down) e=>#{e.inspect}"
  end

  begin
    File.open("#{DHCPD_DIR}/dhclient-enter-hooks.d/1sequreisp", 'w') do |f| 
      f.puts "#!/bin/sh" 
      f.puts "gateway=$new_routers"
      f.puts "unset new_routers"
      f.puts "unset new_domain_name"
      f.puts "unset new_domain_search"
      f.puts "unset new_domain_name_servers"
      f.puts "unset new_host_name"
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::setup_dynamic_providers_hooks(DHCPD_DIR/enter-hooks) e=>#{e.inspect}"
  end

  begin
    File.open("#{DHCPD_DIR}/dhclient-exit-hooks.d/1sequreisp", 'w') do |f| 
      f.puts 'if [ "$reason" != BOUND ] && [ "$reason" != RENEW ] && [ "$reason" != REBIND ] && [ "$reason" != REBOOT ] ;then'
      f.puts "  return"
      f.puts "fi"
      f.puts "#{DEPLOY_DIR}/script/runner -e production #{DEPLOY_DIR}/bin/sequreisp_up_down_provider.rb up $interface $new_ip_address $new_subnet_mask $gateway"
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::setup_dynamic_providers_hooks(DHCPD_DIR/exit-hooks) e=>#{e.inspect}"
  end
end

def setup_provider_interface(f, p)
  if p.interface.vlan?
    #f.puts "vconfig rem #{p.interface.name}"
    f.puts "vconfig add #{p.interface.vlan_interface.name} #{p.interface.vlan_id}"
  end
  # x si necesitamos mac_address única para evitar problemas en proveedores que bridgean
  if p.unique_mac_address?
    f.puts "#ip link set dev #{p.interface.name} down"
    f.puts "ip link set  #{p.interface.name} address #{p.mac_address}"
  end
  f.puts "ip link set dev #{p.interface.name} up"
  # x no queremos que se mezclen los paquetes de una iface a la otra
  f.puts "echo #{p.arp_ignore ? 1 : 0 } > /proc/sys/net/ipv4/conf/#{p.interface.name}/arp_ignore"
  f.puts "echo #{p.arp_announce ? 1 : 0 } > /proc/sys/net/ipv4/conf/#{p.interface.name}/arp_announce"
  f.puts "echo #{p.arp_filter ? 1 : 0 } > /proc/sys/net/ipv4/conf/#{p.interface.name}/arp_filter"
  case p.kind
  when "adsl"
    begin
      File.open("#{PPP_DIR}/peers/#{p.interface.name}", 'w') {|peer| peer.write(p.to_ppp_peer) }
    rescue => e
      Rails.logger.error "ERROR in lib/sequreisp.rb::setup_provider_interface(PPP_DIR) e=>#{e.inspect}"
    end

    #pgrep se ejecuta via 'sh -c' entonces siempre se ve a si mismo y la cuenta si o si arranca en 1
    pppd_running = `/usr/bin/pgrep -c -f 'pppd call #{p.interface.name}' 2>/dev/null`.chomp.to_i || 0
    #si NO esta corriendo pppd y NO existe la iface ppp"
    if pppd_running < 2  and not system("/sbin/ifconfig #{p.link_interface} 1>/dev/null 2>/dev/null")
      f.puts "/usr/bin/pon #{p.interface.name}"
    end
    if p.online?
      p.addresses.each do |a|
        f.puts "ip address add #{a.ip}/#{a.netmask} dev #{p.link_interface}"
        f.puts "ip route re #{a.network} dev #{p.link_interface}"
      end
    end
  when "dhcp"
    #pgrep se ejecuta via 'sh -c' entonces siempre se ve a si mismo y la cuenta si o si arranca en 1
    dhcp_running = `/usr/bin/pgrep -c -f 'dhclient.#{p.interface.name}' 2>/dev/null`.chomp.to_i || 0
    if dhcp_running < 2
      f.puts "dhclient3 -nw -pf /var/run/dhclient.#{p.link_interface}.pid -lf /var/lib/dhcp3/dhclient.#{p.link_interface}.leases #{p.link_interface}"
    end
    if p.online?
      p.addresses.each do |a|
        f.puts "ip address add #{a.ip}/#{a.netmask} dev #{p.link_interface}"
        f.puts "ip route re #{a.network} dev #{p.link_interface}"
      end
    end
  when "static"
    #current_ips = `ip address show dev #{p.link_interface} 2>/dev/null`.scan(/inet ([\d.\/]+) /).flatten.collect { |ip| (IP.new ip).to_s }
    #ips = []
    f.puts "ip address add #{p.ip}/#{p.netmask} dev #{p.link_interface}" 
    #ips << "#{p.ruby_ip.to_s}"
    p.addresses.each do |a|
      f.puts "ip address add #{a.ip}/#{a.netmask} dev #{p.link_interface}" 
      f.puts "ip route re #{a.network} dev #{p.link_interface} src #{a.ip}"
      #ips << "#{a.ruby_ip.to_s}"
    end
    #(current_ips - ips).each do |ip|
    #  f.puts "ip address del #{ip} dev #{p.link_interface}"
    #end
    # la pongo al final para que quede el src de la ip ppal
    f.puts "ip route re #{p.network} dev #{p.link_interface} src #{p.ip}"
    f.puts "ip route re table #{p.check_link_table} #{p.gateway} dev #{p.link_interface}"
    f.puts "ip route re table #{p.check_link_table} #{p.default_route}"
  end
end
def setup_proc(f)
  # setup de params generales de sysctl
  f.puts "echo 1 > /proc/sys/net/ipv4/ip_forward"
  f.puts "echo #{Configuration.nf_conntrack_max} > /proc/sys/net/nf_conntrack_max"
  f.puts "echo #{Configuration.nf_conntrack_max/4} > /sys/module/nf_conntrack/parameters/hashsize"
  f.puts "echo #{Configuration.gc_thresh1} > /proc/sys/net/ipv4/neigh/default/gc_thresh1"
  f.puts "echo #{Configuration.gc_thresh2} > /proc/sys/net/ipv4/neigh/default/gc_thresh2"
  f.puts "echo #{Configuration.gc_thresh3} > /proc/sys/net/ipv4/neigh/default/gc_thresh3"
end
def setup_proxy(f)
  squid_file = '/etc/init/squid.conf'
  squid_file_off = squid_file + '.disabled'
  if Configuration.transparent_proxy
    f.puts "[ -f #{squid_file_off} ] && mv #{squid_file_off} #{squid_file}"
    #relodearlo si ya está corriendo, arrancarlo sino
    f.puts 'if [[ -n "$(pidof squid)" ]] ; then  squid -k reconfigure ; else service squid start ; fi'
    # dummy iface con ips para q cada cliente salga por su grupo
    f.puts "modprobe dummy"
    f.puts "ip link set dummy0 up"
    begin
      File.open(SEQUREISP_SQUID_CONF, "w") do |fsquid|
        if Configuration.transparent_proxy_n_to_m
          Contract.not_disabled.descend_by_netmask.each do |c|
            fsquid.puts "acl contract_#{c.klass.number} src #{c.ip}"
            fsquid.puts "tcp_outgoing_address #{c.proxy_bind_ip} contract_#{c.klass.number}"
            f.puts "ip address add #{c.proxy_bind_ip} dev dummy0"
          end
        else
          Contract.not_disabled.descend_by_netmask.each do |c|
            fsquid.puts "acl pg_#{c.plan.provider_group.klass.number} src #{c.ip}"
          end
          ProviderGroup.enabled.with_klass.each do |pg|
            fsquid.puts "#Dummy address para salir via #{pg.name}"
            fsquid.puts "#empty acl por si no hay contratos"
            fsquid.puts "acl pg_#{pg.klass.number} src"
            fsquid.puts "tcp_outgoing_address #{pg.proxy_bind_ip} pg_#{pg.klass.number}"
            f.puts "ip address add #{pg.proxy_bind_ip} dev dummy0"
          end
        end
        #TODO Option disabled for all clients
        #if Configuration.transparent_proxy_windows_update_hack
        #  fsquid.puts "#Windows update hacks see http://wiki.squid-cache.org/SquidFaq/WindowsUpdate"
        #  fsquid.puts "range_offset_limit -1"
        #  fsquid.puts "quick_abort_min -1"
        #end
        BootHook.run :hook => :setup_proxy, :boot_script => f, :proxy_script => fsquid
      end
    rescue => e
      Rails.logger.error "ERROR in lib/sequreisp.rb::setup_proxy e=>#{e.inspect}"
    end
  else
    f.puts "service squid stop"
    #ensure that squid gets stoped
    f.puts "kill -9 $(pidof squid)"
    f.puts "[ -f #{squid_file} ] && mv #{squid_file} #{squid_file_off}"
  end
end

def setup_proxy_arp(f,arp)
  Contract.find(:all, :conditions => "proxy_arp = 1 and proxy_arp_interface_id is not null").each do |c|
    p = c.proxy_arp_provider
    if p
      arp.puts "arp -i #{p.interface.name} -Ds #{c.ip} #{p.interface.name} pub"
      f.puts "ip ro re #{c.ip} dev #{c.proxy_arp_interface.name}"
      arp.puts "arp -i #{c.proxy_arp_interface.name} -Ds #{p.gateway} #{c.proxy_arp_interface.name} pub"
    end
  end
end

def do_provider_up(p)
  begin
    File.open(PROVIDER_UP_FILE_PREFIX + p.interface.name, 'w') do |f|
      f.puts "#!/bin/bash"
      f.puts("PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games")
      f.puts "ip rule add from #{p.network} table #{p.table} prio 100"
      f.puts "ip rule add from #{p.ip}/32 table #{p.check_link_table} prio 90"
      f.puts "ip ro re table #{p.check_link_table} #{p.default_route}"

      ForwardedPort.all(:conditions => { :provider_id => p.id }, :include => [ :contract, :provider ]).each do |fp|
        do_port_forwardings f, fp, false
        do_port_forwardings_avoid_nat_triangle f, fp, false
      end
      # if we have aditional ips...
      p.addresses.each do |a|
        f.puts "ip address add #{a.ip}/#{a.netmask} dev #{p.link_interface}"
        f.puts "ip route re #{a.network} dev #{p.link_interface}"
        #ips << "#{a.ruby_ip.to_s}"
      end
      if p.kind == "adsl"
        f.puts "tc qdisc del dev #{p.link_interface} root"
        f.puts "tc qdisc del dev #{p.link_interface} ingress"
        f.puts "tc -b #{TC_FILE_PREFIX + p.link_interface}"
      end
      f.chmod 0755
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::do_provider_up e=>#{e.inspect}"
  end

  system "#{PROVIDER_UP_FILE_PREFIX + p.interface.name}"
end

def do_provider_down(p)
  begin
    File.open(PROVIDER_DOWN_FILE_PREFIX + p.interface.name, 'w') do |f|
      f.puts "#!/bin/bash"
      f.puts("PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games")
      f.puts "ip rule del from #{p.network} table #{p.table} prio 100"
      f.puts "ip rule del from #{p.ip}/32 table #{p.check_link_table} prio 90"
      p.online = false
      p.ip = p.netmask = p.gateway = nil
      p.save(false)
      update_provider_route f, p, false
      update_provider_group_route f, p.provider_group, false
      update_fallback_route f, false
      f.chmod 0755
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::do_provider_down e=>#{e.inspect}"
  end

  system "#{PROVIDER_DOWN_FILE_PREFIX + p.interface.name}"
end
def check_physical_links
  changes = false
  readme = []
  writeme = []
  pid = []
  Interface.all(:conditions => "vlan = 0").each do |i|
    physical_link = `ip link show dev #{i.name} 2>/dev/null`.scan(/state (\w+) /).flatten[0] == "UP" || `mii-tool #{i.name} 2>/dev/null`.scan(/link ok/).flatten[0] == "link ok" || `ethtool #{i.name} 2>/dev/null`.scan(/Link detected: yes/).flatten[0] == "Link detected: yes"
    if i.physical_link != physical_link
      changes = true
      i.physical_link = physical_link
      i.save(false)
      #TODO loguear el cambio de estado en una bitactora
    end
  end
  begin
    if Configuration.deliver_notifications
      AppMailer.deliver_check_physical_links_email if changes
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::check_physical_links e=>#{e.inspect}"
  end
end
def check_links
  Configuration.do_reload
  changes = false
  send_notification_mail = false
  providers = Provider.ready.all(:include => :interface)
  threads = {}

  providers.each do |p|
    threads[p.id] = Thread.new do
      Thread.current['online'] = begin
        # 1st by rate, if offline, then by ping
        # (r)etry=3 (t)iemout=500 (B)ackoff=1.5 (defualts)_
        p.is_online_by_rate? || `fping -a -S#{p.ip} #{PINGABLE_SERVERS} 2>/dev/null | wc -l`.chomp.to_i > 0
      end
    end
  end

  # waith for threads
  threads.each do |k,t| t.join end

  providers.each do |p|
    #puts "#{p.id} #{readme[p.id].first}"
    online = threads[p.id]['online']
    p.online = online 
    #TODO loguear el cambio de estado en una bitactora
    
    if !online and !p.notification_flag and p.offline_time > Configuration.notification_timeframe
      p.notification_flag = true
      send_notification_mail = true

    elsif online and p.notification_flag
      p.notification_flag = false
      send_notification_mail = true
    end

    p.save(false) if p.changed?

    #TODO refactorizar esto de alguna manera
    # la idea es killear el dhcp si esta caido más de 30 segundos
    # pero solo hacer kill en la primer pasada cada minuto, para darle tiempo de levantar
    # luego lo de abajo lo va a levantar
    offline_time = p.offline_time
    if p.kind == "dhcp" and offline_time > 30 and (offline_time-30)%120 < 16
      system "/usr/bin/pkill -f 'dhclient.#{p.interface.name}'"
    end
  end

  begin
    File.open(CHECK_LINKS_FILE, "w") do |f| 
      f.puts("#!/bin/bash")
      f.puts("PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games")
      Provider.with_klass_and_interface.each do |p|
        setup_provider_interface(f,p) if not p.online?
        update_provider_route f, p, false
      end
      ProviderGroup.enabled.each do |pg|
        update_provider_group_route f, pg, false
      end
      update_fallback_route f, false
      f.chmod 0755
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::check_links(CHECK_LINKS_FILE) e=>#{e.inspect}"
  end
  f = File.open("#{CHECK_LINKS_FILE}", "r")
  system "#{CHECK_LINKS_FILE} 2>&1 >#{CHECK_LINKS_LOG}" if f.readlines.length > 2
  f.close
  begin

    if send_notification_mail and Configuration.deliver_notifications
      AppMailer.deliver_check_links_email
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::check_links(AppMailer) e=>#{e.inspect}"
  end
end

def setup_queued_commands
  begin
    File.open(QUEUED_COMMANDS_FILE, "w") do |f|
      f.puts "#!/bin/bash"
      f.puts("PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games")
      QueuedCommand.pending.each do |qc|
        f.puts qc.command
        qc.executed = true
        qc.save
      end
      f.puts "mv $0 $0.executed"
      f.chmod 0755
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::setup_queued_commands e=>#{e.inspect}"
  end
end

def boot(run=true)
  create_dirs_if_not_present if Rails.env.development?
  Configuration.do_reload
  setup_queued_commands
  begin
    File.open(BOOT_FILE, "w") do |f|
      f.puts "#!/bin/bash"
      f.puts("PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games")
      f.puts "#set -x"
      f.puts "[ -x #{SEQUREISP_PRE_FILE} ] && #{SEQUREISP_PRE_FILE}"
      f.puts "[ -x #{QUEUED_COMMANDS_FILE} ] && #{QUEUED_COMMANDS_FILE}"
      f.puts "#modulos"
      %w{nf_nat_ftp nf_nat_amanda nf_nat_pptp nf_nat_proto_gre nf_nat_sip nf_nat_irc 8021q}.each do |m|
        f.puts "modprobe #{m}"
      end
      setup_proc f 
      setup_proxy f 
      Interface.all(:conditions => "vlan = 0").each do |i|
        f.puts "ip link set dev #{i.name} up"
      end
      Interface.all(:conditions => "kind = 'lan'").each do |i| 
        #current_ips = `ip address show dev #{i.name} 2>/dev/null`.scan(/inet ([\d.\/]+) /).flatten.collect { |ip| (IP.new ip).to_s }
        #ips = []
        if i.vlan?
          #f.puts "vconfig rem #{p.interface.name}"
          f.puts "vconfig add #{i.vlan_interface.name} #{i.vlan_id}"
        end
        f.puts "ip link set dev #{i.name} up"
        i.addresses.each do |a|
          f.puts "ip address add #{a.ip}/#{a.netmask} dev #{i.name}" 
          f.puts "ip route re #{a.network} dev #{i.name} src #{a.ip}"
          #ips << "#{a.ruby_ip.to_s}"
        end
        #(current_ips - ips).each do |ip|
        #  f.puts "ip address del #{ip} dev #{i.name}"
        #end
        #emito evento de upstart, por ej. /etc/init/squid lo necesita
        f.puts "initctl emit -n net-device-up \"IFACE=#{i.name}\" \"LOGICAL=#{i.name}\" \"ADDRFAM=inet\" \"METHOD=static\""
      end
      # borro el default gw de main
      f.puts "ip route del default table main"
      setup_dynamic_providers_hooks
      Provider.enabled.with_klass_and_interface.each do |p|
        setup_provider_interface f,p
      end
      File.open(ARP_FILE, "w") do |arp| 
        arp.puts "#!/bin/bash"
        arp.puts("PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games")
        setup_proxy_arp f,arp 
        arp.chmod 0755
      end
      f.puts "#{ARP_FILE}"
      # setup de las ifb
      f.puts "modprobe ifb numifbs=3"
      f.puts "ip link set #{IFB_UP} up"
      f.puts "ip link set #{IFB_DOWN} up"
      f.puts "ip link set #{IFB_INGRESS} up"
      gen_tc f
      gen_iptables
      gen_ip_ru
      gen_ip_ro
      f.puts "ip -batch #{IP_RU_FILE}"
      f.puts "ip -batch #{IP_RO_FILE}"
    
      f.puts "tc -b #{TC_FILE_PREFIX + IFB_UP}"
      f.puts "tc -b #{TC_FILE_PREFIX + IFB_DOWN}"
      f.puts "tc -b #{TC_FILE_PREFIX + IFB_INGRESS}"
      Interface.all(:conditions => { :kind => "lan" }).each do |interface|
        f.puts "tc -b #{TC_FILE_PREFIX + interface.name}"
      end
      Provider.enabled.with_klass_and_interface.each do |p|
        #TODO si es adsl y el ppp no está disponible falla el comando igual no pasa nada 
        f.puts "tc -b #{TC_FILE_PREFIX + p.link_interface}" 
      end

      #General configuration hook
      BootHook.run :hook => :general, :run => run, :boot_script => f

      f.puts "[ -x #{IPTABLES_PRE_FILE} ] && #{IPTABLES_PRE_FILE}"
      f.puts "iptables-restore -n < #{IPTABLES_FILE}"
      f.puts "[ -x #{IPTABLES_POST_FILE} ] && #{IPTABLES_POST_FILE}"
      f.puts "service bind9 reload"

      #Service restart hook
      BootHook.run :hook => :service_restart, :run => run, :boot_script => f

      f.puts "[ -x #{SEQUREISP_POST_FILE} ] && #{SEQUREISP_POST_FILE}"
      f.chmod 0755
    end
    system "#{BOOT_FILE} 2>#{BOOT_LOG} 1>#{BOOT_LOG}" if run
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::boot e=>#{e.inspect}"
  end
end



