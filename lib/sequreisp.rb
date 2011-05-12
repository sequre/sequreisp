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
  def do_tc(tc, plan, c, parent_mayor, parent_minor, iface, direction, prefix=0)
    klass= c.class_hex
    klass_prio1 = c.class_prio1_hex
    klass_prio2 = c.class_prio2_hex
    klass_prio3 = c.class_prio3_hex
    mark_prio1 = c.mark_prio1_hex(prefix)
    mark_prio2 = c.mark_prio2_hex(prefix)
    mark_prio3 = c.mark_prio3_hex(prefix)
    # prefix == 0 significa que matcheo en las ifb donde tengo los clientes colgados directo del root
    # prefix != 0 significa que matcheo en las ifaces reales donde tengo un arbol x cada enlace
    mask = prefix == 0 ? "0000ffff" : "00ffffff"
    mtu = Configuration.mtu
    rate = plan["rate_" + direction] == 0 ?  0.024 : plan["rate_" + direction]
    rate_prio1 = rate == 0.024 ? rate/3 : rate*0.05
    rate_prio2 = rate == 0.024 ? rate/3 : rate*0.9
    rate_prio3 = rate == 0.024 ? rate/3 : rate*0.05
    ceil = plan["ceil_" + direction]
    quantum_factor = (plan["ceil_" + direction] + plan["rate_" + direction])/Configuration.quantum_factor.to_i 
    quantum_total = mtu * quantum_factor * 3
    quantum_prio1 = mtu * quantum_factor * 3
    quantum_prio2 = mtu * quantum_factor * 2
    quantum_prio3 = mtu
    #padre
    tc.puts "##{c.client.name}: #{c.id} #{c.klass.number}"
    tc.puts "class add dev #{iface} parent #{parent_mayor}:#{parent_minor} classid #{parent_mayor}:#{klass} htb rate #{rate}kbit ceil #{ceil}kbit quantum #{quantum_total}"
    #hijo prio1
    tc.puts "class add dev #{iface} parent #{parent_mayor}:#{klass} classid #{parent_mayor}:#{klass_prio1} htb rate #{rate_prio1}kbit ceil #{ceil}kbit prio 1 quantum #{quantum_prio1}"
    tc.puts "qdisc add dev #{iface} parent #{parent_mayor}:#{klass_prio1} sfq perturb 10" #saco el handle
    tc.puts "filter add dev #{iface} parent #{parent_mayor}: protocol all prio 200 handle 0x#{mark_prio1}/0x#{mask} fw classid #{parent_mayor}:#{klass_prio1}"
    #hijo prio2
    tc.puts "class add dev #{iface} parent #{parent_mayor}:#{klass} classid #{parent_mayor}:#{klass_prio2} htb rate #{rate_prio2}kbit ceil #{ceil}kbit prio 2 quantum #{quantum_prio2}"
    tc.puts "qdisc add dev #{iface} parent #{parent_mayor}:#{klass_prio2} sfq perturb 10" #saco el handle
    tc.puts "filter add dev #{iface} parent #{parent_mayor}: protocol all prio 200 handle 0x#{mark_prio2}/0x#{mask} fw classid #{parent_mayor}:#{klass_prio2}"
    #hijo prio3
    tc.puts "class add dev #{iface} parent #{parent_mayor}:#{klass} classid #{parent_mayor}:#{klass_prio3} htb rate #{rate_prio3}kbit ceil #{ceil*c.ceil_dfl_percent/100}kbit prio 3 quantum #{quantum_prio3}"
    tc.puts "qdisc add dev #{iface} parent #{parent_mayor}:#{klass_prio3} sfq perturb 10" #saco el handle
    tc.puts "filter add dev #{iface} parent #{parent_mayor}: protocol all prio 200 handle 0x#{mark_prio3}/0x#{mask} fw classid #{parent_mayor}:#{klass_prio3}"
  end
  tc_ifb_up = File.open(TC_FILE_PREFIX + IFB_UP, "w") 
  tc_ifb_down = File.open(TC_FILE_PREFIX + IFB_DOWN, "w") 
  # htb tree de clientes en gral en IFB
  f.puts "tc qdisc del dev #{IFB_UP} root"
  tc_ifb_up.puts "qdisc add dev #{IFB_UP} root handle 1 htb default 0"
  tc_ifb_up.puts "class add dev #{IFB_UP} parent 1: classid 1:1 htb rate 1000mbit"
  f.puts "tc qdisc del dev #{IFB_DOWN} root"
  tc_ifb_down.puts "qdisc add dev #{IFB_DOWN} root handle 1 htb default 0"
  tc_ifb_down.puts "class add dev #{IFB_DOWN} parent 1: classid 1:1 htb rate 1000mbit"
  Contract.descend_by_netmask.each do |c|
    do_tc tc_ifb_up, c.plan, c, 1, 1, IFB_UP, "up"
    do_tc tc_ifb_down, c.plan, c, 1, 1, IFB_DOWN, "down"
  end
  tc_ifb_up.close
  tc_ifb_down.close

  # htb tree up (en las ifaces de Provider) 
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
        if Configuration.tc_contracts_per_provider_in_wan
          Contract.descend_by_netmask.each do |c|
            do_tc tc, c.plan, c, p.class_hex, 1, iface, "up", p.mark
          end
        else
          tc.puts "filter add dev #{iface} parent #{p.class_hex}: protocol all prio 10 handle 0x#{p.class_hex}0000/0x00ff0000 fw classid #{p.class_hex}:1"
        end
      end 
    rescue Exception => e
      puts "Exception #{e.message}"
    end
  end
 
  # htb tree down (en las ifaces lan) 
  Interface.all(:conditions => { :kind => "lan" }).each do |interface|
    iface = interface.name
    f.puts "tc qdisc del dev #{iface} root"
    File.open(TC_FILE_PREFIX + iface, "w") do |tc| 
      tc.puts "qdisc add dev #{iface} root handle 1: prio bands 3 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
      tc.puts "filter add dev #{iface} parent 1: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev #{IFB_DOWN}"
      tc.puts "qdisc add dev #{iface} parent 1:1 handle 2: htb default 0"
      Provider.enabled.with_klass_and_interface.each do |p|
        #max quantum posible para este provider, necesito saberlo con anticipación
        quantum = Configuration.mtu * p.quantum_factor * 3
        tc.puts "class add dev #{iface} parent 2: classid 2:#{p.class_hex} htb rate #{p.rate_down}kbit quantum #{quantum}"
        tc.puts "filter add dev #{iface} parent 2: protocol all prio 10 handle 0x#{p.class_hex}0000/0x00ff0000 fw classid 2:#{p.class_hex}"
        if Configuration.tc_contracts_per_provider_in_lan
          tc.puts "qdisc add dev #{iface} parent 2:#{p.class_hex} handle #{p.class_hex}: htb default 0"
          tc.puts "class add dev #{iface} parent #{p.class_hex}: classid #{p.class_hex}:1 htb rate #{p.rate_down}kbit quantum #{quantum}"
          Contract.descend_by_netmask.each do |c|
            do_tc tc, c.plan, c, p.class_hex, 1, iface, "down", p.mark
          end
        end
      end
    end
  end
end

def gen_iptables
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
      Contract.descend_by_netmask(:include => [{ :plan => :provider_group }]).each do |c|
        if !c.public_address.nil?
          #evito triangulo de NAT si tiene full DNAT
          f.puts "-A avoid_nat_triangle -d #{c.public_address.ip} -j MARK --set-mark 0x01000000/0x01000000"
        end

        mark = c.public_address.nil? ? c.plan.provider_group.mark_hex : c.public_address.addressable.mark_hex
        f.puts "-A PREROUTING -s #{c.ip} -j MARK --set-mark 0x#{mark}/0x00ff0000"
        f.puts "-A PREROUTING -s #{c.ip} -j ACCEPT" 
      end
      # CONNMARK OUTPUT
      # restauro marka en OUTPUT pero que siga viajando
      f.puts "-A OUTPUT -j CONNMARK --restore-mark"
      f.puts "-A OUTPUT -m mark ! --mark 0 -j ACCEPT"
      if Configuration.transparent_proxy
        if Configuration.transparent_proxy_n_to_m
          Contract.descend_by_netmask.each do |c|
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
      Contract.descend_by_netmask.each do |c|
        mark_burst = "0x0000/0x0000ffff"
        mark_prio1 = "0x#{c.mark_prio1_hex}/0x0000ffff"
        mark_prio2 = "0x#{c.mark_prio2_hex}/0x0000ffff"
        mark_prio3 = "0x#{c.mark_prio3_hex}/0x0000ffff"
        prio_protos = c.prio_protos.blank? ? Configuration.default_prio_protos : c.prio_protos
        prio_helpers = c.prio_helpers.blank? ? Configuration.default_prio_helpers : c.prio_helpers
        tcp_prio_ports = c.tcp_prio_ports.blank? ? Configuration.default_tcp_prio_ports : c.tcp_prio_ports
        udp_prio_ports = c.udp_prio_ports.blank? ? Configuration.default_udp_prio_ports : c.udp_prio_ports
        # una chain por cada cliente
        chain="sequreisp.#{c.ip}"
        f.puts ":#{chain} - [0:0]"
        # redirección del trafico de este cliente hacia su propia chain
        f.puts "-A sequreisp.down -d #{c.ip} -j #{chain}"
        f.puts "-A sequreisp.up -s #{c.ip} -j #{chain}"
        if Configuration.transparent_proxy and Configuration.transparent_proxy_n_to_m
          f.puts "-A sequreisp.up -s #{c.proxy_bind_ip} -j #{chain}"
        end
        # separo el tráfico en las 3 class: prio1 prio2 prio3
        # prio1
        f.puts "-A #{chain} #{mark_if} -p tcp -m length --length 0:100 -j MARK --set-mark #{mark_prio1}"
        f.puts "-A #{chain} #{mark_if} -p tcp --dport 22 -j MARK --set-mark #{mark_prio1}"
        f.puts "-A #{chain} #{mark_if} -p tcp --sport 22 -j MARK --set-mark #{mark_prio1}"
        f.puts "-A #{chain} #{mark_if} -p udp --dport 53 -j MARK --set-mark #{mark_prio1}"
        f.puts "-A #{chain} #{mark_if} -p udp --sport 53 -j MARK --set-mark #{mark_prio1}"
        f.puts "-A #{chain} #{mark_if} -p icmp -j MARK --set-mark #{mark_prio1}"
        # prio2
        prio_protos.split(",").each do |proto|
          f.puts "-A #{chain} #{mark_if} -p #{proto} -j MARK --set-mark #{mark_prio2}"
        end
        prio_helpers.split(",").each do |helper|
          f.puts "-A #{chain} #{mark_if} -m helper --helper #{helper} -j MARK --set-mark #{mark_prio2}"
        end
        # solo 15 puertos por vez en multiport
        tcp_array = tcp_prio_ports.split(",")
        while !tcp_array.empty? do 
          ports = tcp_array.slice!(0..14).join(",")
          f.puts "-A #{chain} #{mark_if} -p tcp -m multiport --dports #{ports} -j MARK --set-mark #{mark_prio2}"
          f.puts "-A #{chain} #{mark_if} -p tcp -m multiport --sports #{ports} -j MARK --set-mark #{mark_prio2}"
        end
        udp_array = udp_prio_ports.split(",")
        while !udp_array.empty? do 
          ports = udp_array.slice!(0..14).join(",")
          f.puts "-A #{chain} #{mark_if} -p udp -m multiport --dports #{ports} -j MARK --set-mark #{mark_prio2}"
          f.puts "-A #{chain} #{mark_if} -p udp -m multiport --sports #{ports} -j MARK --set-mark #{mark_prio2}"
        end
        # prio3 (catch_all)
        f.puts "-A #{chain} #{mark_if} -j MARK --set-mark #{mark_prio3}"

        # long downloads/uploads limit
        if c.plan.long_download_max != 0
          f.puts "-A #{chain} -p tcp -m multiport --sports 80,443 -m connbytes --connbytes #{c.plan.long_download_max_to_bytes}: --connbytes-dir reply --connbytes-mode bytes -j MARK --set-mark #{mark_prio3}"
        end
        if c.plan.long_upload_max != 0
          f.puts "-A #{chain} -p tcp -m multiport --dports 80,443 -m connbytes --connbytes #{c.plan.long_upload_max_to_bytes}: --connbytes-dir original --connbytes-mode bytes -j MARK --set-mark #{mark_prio3}"
        end
        # if burst, sets mark to 0x0000, making the packet impact in provider class rather than contract's one
        if c.plan.burst_down != 0
          f.puts "-A #{chain} -p tcp -m multiport --sports 80,443 -m connbytes --connbytes 0:#{c.plan.burst_down_to_bytes} --connbytes-dir reply --connbytes-mode bytes -j MARK --set-mark #{mark_burst}"
        end
        if c.plan.burst_up != 0
          f.puts "-A #{chain} -p tcp -m multiport --dports 80,443 -m connbytes --connbytes 0:#{c.plan.burst_up_to_bytes} --connbytes-dir original --connbytes-mode bytes -j MARK --set-mark #{mark_burst}"
        end
        # guardo la marka para evitar pasar por todo esto de nuevo, salvo si impacto en la prio1
        # f.puts "-A #{chain} -m mark ! --mark #{mark_prio1} -j CONNMARK --save-mark"
        f.puts "-A #{chain} -j ACCEPT"
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

      Interface.all(:conditions => "kind = 'lan'").each do |i| 
        i.addresses.each do |a|
          f.puts "-A PREROUTING -i #{i.name} -d #{a.ip} -p tcp --dport 80 -j ACCEPT"
        end
      end
      Contract.descend_by_netmask.each do |c|
        # attribute: transparent_proxy
        if c.transparent_proxy? 
          f.puts "-A PREROUTING -s #{c.ip} -p tcp --dport 80 -j REDIRECT --to-port 3128"
        end
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
      Provider.enabled.with_klass_and_interface.each do |p|
        p.networks.each do |network|
          f.puts "-A POSTROUTING -o #{p.link_interface} -s #{network} -j ACCEPT"
        end
      	f.puts "-A POSTROUTING -o #{p.link_interface}  -j MASQUERADE"
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
      Provider.enabled.with_klass_and_interface.each do |p|
        f.puts "-A FORWARD -o #{p.link_interface} -j sequreisp-enabled"
        f.puts "-A INPUT -p tcp --dport 3128 -j sequreisp-enabled"
      end

      #
      Contract.descend_by_netmask.each do |c|
        # attribute: state
        #   estado del cliente enabled/alerted/disabled
        macrule = (Configuration.filter_by_mac_address and !c.mac_address.blank?) ? "-m mac --mac-source #{c.mac_address}" : ""
      
        unless c.disabled?
          f.puts "-A sequreisp-enabled #{macrule} -s #{c.ip} -j ACCEPT"
        end
      
      end
      f.puts "-A sequreisp-enabled -j DROP"
      f.puts "COMMIT"
      #---------#
      # /FILTER #
      #---------#
    # close iptables file
    end
  rescue Exception => e
    puts "Exception #{e.message}"
  end
end

def do_port_forwardings(f, fp, batch=true)
  prefix = batch ? "" : "iptables -t nat "
  unless fp.provider.ip.blank?
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
  rescue Exception => e
    puts "Exception #{e.message}"
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
  rescue Exception => e
    puts "Exception #{e.message}"
  end
end

def setup_dynamic_providers_hooks
  begin
    File.open("#{PPP_DIR}/ip-up.d/1sequreisp", 'w') do |f| 
      f.puts "#!/bin/sh" 
      f.puts "#{DEPLOY_DIR}/script/runner -e production #{DEPLOY_DIR}/bin/sequreisp_up_down_provider.rb up $PPP_IPPARAM $PPP_LOCAL 255.255.255.255 $PPP_REMOTE"
      f.chmod(0755)
    end
  rescue Exception => e
    puts "Exception #{e.message}"
  end

  begin
    File.open("#{PPP_DIR}/ip-down.d/1sequreisp", 'w') do |f| 
      f.puts "#!/bin/sh" 
      f.puts "#{DEPLOY_DIR}/script/runner -e production #{DEPLOY_DIR}/bin/sequreisp_up_down_provider.rb down $PPP_IPPARAM"
      f.chmod(0755)
    end
  rescue Exception => e
    puts "Exception #{e.message}"
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
  rescue Exception => e
    puts "Exception #{e.message}"
  end

  begin
    File.open("#{DHCPD_DIR}/dhclient-exit-hooks.d/1sequreisp", 'w') do |f| 
      f.puts 'if [ "$reason" != BOUND ] && [ "$reason" != RENEW ] && [ "$reason" != REBIND ] && [ "$reason" != REBOOT ] ;then'
      f.puts "  return"
      f.puts "fi"
      f.puts "#{DEPLOY_DIR}/script/runner -e production #{DEPLOY_DIR}/bin/sequreisp_up_down_provider.rb up $interface $new_ip_address $new_subnet_mask $gateway"
    end
  rescue Exception => e
    puts "Exception #{e.message}"
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
    rescue Exception => e
      puts "Exception #{e.message}"
    end
    
    #pgrep se ejecuta via 'sh -c' entonces siempre se ve a si mismo y la cuenta si o si arranca en 1
    pppd_running = `/usr/bin/pgrep -c -f 'pppd call #{p.interface.name}' 2>/dev/null`.chomp.to_i || 0
    #si NO esta corriendo pppd y NO existe la iface ppp"
    if pppd_running < 2  and not system("/sbin/ifconfig #{p.link_interface} 1>/dev/null 2>/dev/null")
      f.puts "/usr/bin/pon #{p.interface.name}"
    end
  when "dhcp"
    #pgrep se ejecuta via 'sh -c' entonces siempre se ve a si mismo y la cuenta si o si arranca en 1
    dhcp_running = `/usr/bin/pgrep -c -f 'dhclient.#{p.interface.name}' 2>/dev/null`.chomp.to_i || 0
    if dhcp_running < 2
      f.puts "dhclient3 -nw -pf /var/run/dhclient.#{p.link_interface}.pid -lf /var/lib/dhcp3/dhclient.#{p.link_interface}.leases #{p.link_interface}"
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
  # setup de squid para proxy q cada cliente salga por su grupo
  f.puts "modprobe dummy"
  f.puts "ip link set dummy0 up"
  begin
    File.open(SEQUREISP_SQUID_CONF, "w") do |fsquid| 
      if Configuration.transparent_proxy_n_to_m
        Contract.descend_by_netmask.each do |c|
          fsquid.puts "acl contract_#{c.klass.number} src #{c.ip}"
          fsquid.puts "tcp_outgoing_address #{c.proxy_bind_ip} contract_#{c.klass.number}"
          f.puts "ip address add #{c.proxy_bind_ip} dev dummy0"
        end
      else
        Contract.descend_by_netmask.each do |c|
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
    end
  rescue Exception => e
    puts "Exception #{e.message}"
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
      if p.kind == "adsl"
        f.puts "tc qdisc del dev #{p.link_interface} root"
        f.puts "tc -b #{TC_FILE_PREFIX + p.link_interface}"
      end
      f.chmod 0755
    end
  rescue Exception => e
    puts "Exception #{e.message}"
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
  rescue Exception => e
    puts "Exception #{e.message}"
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
  rescue Exception => e
    puts "Exception #{e.message}"
  end
end
def check_links
  Configuration.do_reload
  changes = false
  send_notification_mail = false
  readme = []
  writeme = []
  pid = []
  providers = Provider.ready
  providers.each do |p|
    readme[p.id], writeme[p.id] = IO.pipe
    pid[p.id] = fork {
        # child
        $stdout.reopen writeme[p.id]
        readme[p.id].close
        exec("fping -a -S#{p.ip} #{PINGABLE_SERVERS} 2>/dev/null | wc -l")
    }
    writeme[p.id].close
  end
  Process.waitall()
  providers.each do |p|
    #puts "#{p.id} #{readme[p.id].first}"
    online = readme[p.id].read.chomp.to_i > 0
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
  rescue Exception => e
    puts "Exception #{e.message}"
  end
  f = File.open("#{CHECK_LINKS_FILE}", "r")
  system "#{CHECK_LINKS_FILE} 2>&1 >#{CHECK_LINKS_LOG}" if f.readlines.length > 2
  f.close
  begin

    if send_notification_mail and Configuration.deliver_notifications
      AppMailer.deliver_check_links_email
    end
  rescue Exception => e
    puts "Exception #{e.message}"
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
  rescue Exception => e
    puts "Exception #{e.message}"
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
      gen_tc f
      gen_iptables
      gen_ip_ru
      gen_ip_ro
      f.puts "ip -batch #{IP_RU_FILE}"
      f.puts "ip -batch #{IP_RO_FILE}"
    
      f.puts "tc -b #{TC_FILE_PREFIX + IFB_UP}"
      f.puts "tc -b #{TC_FILE_PREFIX + IFB_DOWN}"
      Interface.all(:conditions => { :kind => "lan" }).each do |interface|
        f.puts "tc -b #{TC_FILE_PREFIX + interface.name}"
      end
      Provider.enabled.with_klass_and_interface.each do |p|
        #TODO si es adsl y el ppp no está disponible falla el comando igual no pasa nada 
        f.puts "tc -b #{TC_FILE_PREFIX + p.link_interface}" 
      end
      f.puts "[ -x #{IPTABLES_PRE_FILE} ] && #{IPTABLES_PRE_FILE}"
      f.puts "iptables-restore -n < #{IPTABLES_FILE}"
      f.puts "[ -x #{IPTABLES_POST_FILE} ] && #{IPTABLES_POST_FILE}"
      f.puts "#service squid reload"
      f.puts "squid -k reconfigure"
      f.puts "service bind9 reload"
      f.puts "[ -x #{SEQUREISP_POST_FILE} ] && #{SEQUREISP_POST_FILE}"
      f.chmod 0755
    end
  rescue Exception => e
    puts "Exception #{e.message}"
  end
  system "#{BOOT_FILE} 2>#{BOOT_LOG} 1>#{BOOT_LOG}" if run
end



