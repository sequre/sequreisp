# Sequreisp- - Copyright 2010, 2011 Luciano Ruete
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

require 'sequreisp_constants'
require 'command_context'

def create_dirs_if_not_present
  [BASE_SCRIPTS, DHCPD_DIR, PPP_DIR, DEPLOY_DIR, "#{PPP_DIR}/ip-up.d", "#{PPP_DIR}/ip-down.d", "#{DHCPD_DIR}/dhclient-enter-hooks.d",  "#{DHCPD_DIR}/dhclient-exit-hooks.d", "#{PPP_DIR}/peers"].each do |dir|
    dir.split("/").inject do |path, dir|
      new_dir = "#{path}/#{dir}"
      Dir.mkdir(new_dir) if not File.exist? new_dir
      new_dir
    end
  end
end

def gen_tc
  commands = []
  begin
    tc_ifb_up = File.open(TC_FILE_PREFIX + IFB_UP, "w")
    tc_ifb_down = File.open(TC_FILE_PREFIX + IFB_DOWN, "w")
    # Contracts tree on IFB_UP (upload control) and IFB_DOWN (download control)
    commands << "tc qdisc del dev #{IFB_UP} root 2> /dev/null"
    tc_ifb_up.puts "qdisc add dev #{IFB_UP} root handle 1 hfsc default fffe"
    commands << "tc qdisc del dev #{IFB_DOWN} root 2> /dev/null"
    tc_ifb_down.puts "qdisc add dev #{IFB_DOWN} root handle 1 hfsc default fffe"
    total_rate_up = ProviderGroup.total_rate_up
    total_rate_down = ProviderGroup.total_rate_down
    tc_ifb_up.puts "class add dev #{IFB_UP} parent 1: classid 1:1 hfsc ls m2 #{total_rate_up}kbit ul m2 #{total_rate_up}kbit"
    tc_ifb_up.puts "class add dev #{IFB_UP} parent 1: classid 1:fffe hfsc ls m2 1000mbit"
    tc_ifb_down.puts "class add dev #{IFB_DOWN} parent 1: classid 1:1 hfsc ls m2 #{total_rate_down}kbit ul m2 #{total_rate_down}kbit"
    tc_ifb_down.puts "class add dev #{IFB_DOWN} parent 1: classid 1:fffe hfsc ls m2 1000mbit"
    ProviderGroup.all.each do |pg|
      rate_factor_up = pg.rate_factor_up
      rate_factor_down = pg.rate_factor_down
      pg.contracts.not_disabled.descend_by_netmask.each do |c|
        tc_ifb_up.puts c.do_per_contract_prios_tc(1, 1, IFB_UP, "up", "add", rate_factor_up)
        tc_ifb_down.puts c.do_per_contract_prios_tc(1, 1, IFB_DOWN, "down", "add", rate_factor_down)
      end
    end
    tc_ifb_up.close
    tc_ifb_down.close
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::gen_tc(IFB_UP/IFB_DOWN) e=>#{e.inspect}"
  end

  # Per provider upload limit, on it's own interface
  Provider.enabled.with_klass_and_interface.each do |p|
    iface = p.link_interface
    commands << "tc qdisc del dev #{iface} root 2> /dev/null"
    commands << "tc qdisc show dev #{iface} | grep 'qdisc ingress' > /dev/null && tc qdisc del dev #{iface} ingress"
#    commands << "tc qdisc del dev #{iface} ingress 2> /dev/null"
    begin
      File.open(TC_FILE_PREFIX + iface, "w") do |tc|
        tc.puts "qdisc add dev #{iface} root handle 1: prio bands 3 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
        tc.puts "filter add dev #{iface} parent 1: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev #{IFB_UP}"
        tc.puts "qdisc add dev #{iface} parent 1:1 handle 2 hfsc default fffe"
        tc.puts "class add dev #{iface} parent 2: classid 2:fffe hfsc ls m2 1000mbit"
        tc.puts "class add dev #{iface} parent 2: classid 2:#{p.class_hex} hfsc ls m2 #{p.rate_up}kbit ul m2 #{p.rate_up}kbit"
        tc.puts "filter add dev #{iface} parent 2: protocol all prio 10 handle 0x#{p.class_hex}0000/0x00ff0000 fw classid 2:#{p.class_hex}"
      end
    rescue => e
      Rails.logger.error "ERROR in lib/sequreisp.rb::gen_tc(#per provider upload limit in #{iface}) e=>#{e.inspect}"
    end
  end

  # Per provider download limit, on LAN interfaces
  Interface.all(:conditions => { :kind => "lan" }).each do |interface|
    iface = interface.name
    commands << "tc qdisc del dev #{iface} root 2> /dev/null"
    begin
      File.open(TC_FILE_PREFIX + iface, "w") do |tc|
        tc.puts "qdisc add dev #{iface} root handle 1: prio bands 3 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
        tc.puts "filter add dev #{iface} parent 1: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev #{IFB_DOWN}"
        tc.puts "qdisc add dev #{iface} parent 1:1 handle 2 hfsc default fffe"
        tc.puts "class add dev #{iface} parent 2: classid 2:fffe hfsc ls m2 1000mbit"
        Provider.enabled.with_klass_and_interface.each do |p|
          tc.puts "class add dev #{iface} parent 2: classid 2:#{p.class_hex} hfsc ls m2 #{p.rate_down}kbit ul m2 #{p.rate_down}kbit"
          tc.puts "filter add dev #{iface} parent 2: protocol all prio 10 handle 0x#{p.class_hex}0000/0x00ff0000 fw classid 2:#{p.class_hex}"
        end
      end
    rescue => e
      Rails.logger.error "ERROR in lib/sequreisp.rb::gen_tc(#per provider download limit in #{iface}) e=>#{e.inspect}"
    end
  end
  exec_context_commands "setup_tc", commands
end

def gen_iptables
  # def do_prio_traffic_iptables(o={})
  #   o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p tcp -m length --length 0:100 -j MARK --set-mark #{o[:mark]}"
  #   o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p tcp --dport 22 -j MARK --set-mark #{o[:mark]}"
  #   o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p tcp --sport 22 -j MARK --set-mark #{o[:mark]}"
  #   o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p udp --dport 53 -j MARK --set-mark #{o[:mark]}"
  #   o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p udp --sport 53 -j MARK --set-mark #{o[:mark]}"
  #   o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p icmp -j MARK --set-mark #{o[:mark]}"
  # end
  # def do_prio_protos_iptables(o={})
  #   o[:protos].each do |proto|
  #     o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p #{proto} -j MARK --set-mark #{o[:mark]}"
  #   end
  # end
  # def do_prio_helpers_iptables(o={})
  #   o[:helpers].each do |helper|
  #     o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -m helper --helper #{helper} -j MARK --set-mark #{o[:mark]}"
  #   end
  # end
  # def do_prio_ports_iptables(o={})
  #   # solo 15 puertos por vez en multiport
  #   while !o[:ports].empty? do
  #     _ports = o[:ports].slice!(0..14).join(",")
  #     o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p #{o[:proto]} -m multiport --dports #{_ports} -j MARK --set-mark #{o[:mark]}"
  #     o[:file].puts "-A #{o[:chain]} #{o[:mark_if]} -p #{o[:proto]} -m multiport --sports #{_ports} -j MARK --set-mark #{o[:mark]}"
  #   end
  # end
  begin
    File.open("#{IPTABLES_FILE}.tmp", "w") do |f|
      #--------#
      # MANGLE #
      #--------#
      f.puts "*mangle"

      #Chain for unlimitd bandwidth traffic, jump here if you need it
      f.puts ":unlimited_bandwidth - [0:0]"
      f.puts "-A unlimited_bandwidth -j MARK --set-mark 0x0/0xffffff"
      f.puts "-A unlimited_bandwidth -j ACCEPT"

      if Configuration.clamp_mss_to_pmtu
        f.puts "-A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu"
        f.puts "-A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu"
      end
      # CONNMARK PREROUTING
      # Evito balanceo para los hosts configurados
      f.puts ":avoid_balancing - [0:0]"
      f.puts "-A PREROUTING -j avoid_balancing"
      AvoidBalancingHost.all.each do |abh|
        if abh.provider
          abh.ip_addresses.each do |ip|
            f.puts "-A avoid_balancing -d #{ip} -j MARK --set-mark 0x#{abh.provider.mark_hex}/0x00ff0000"
            f.puts "-A avoid_balancing -d #{ip} -j CONNMARK --save-mark"
          end
        end
      end
      # restauro marka en PREROUTING
      f.puts "-A PREROUTING -j CONNMARK --restore-mark --nfmask 0x1fffffff --ctmask 0x1fffffff"

      # acepto si ya se de que enlace es
      f.puts "-A PREROUTING -m mark ! --mark 0x0/0x1fffffff -j ACCEPT"
      # si viene desde internet marko segun el enlace por el que entró
      Provider.enabled.with_klass_and_interface.each do |p|
        f.puts "-A PREROUTING -i #{p.link_interface} -j MARK --set-mark 0x#{p.mark_hex}/0x00ff0000"
        f.puts "-A PREROUTING -i #{p.link_interface} -j CONNMARK --save-mark --nfmask 0x1fffffff --ctmask 0x1fffffff"
        f.puts "-A PREROUTING -i #{p.link_interface} -j ACCEPT"
      end
      # tabla para evitar triangulo de nat
      # como arriba ya hice ACCEPT de lo que entra por los
      # providers, esto solo impacta si la iface de entrada no es WAN
      f.puts ":avoid_nat_triangle - [0:0]"
      f.puts "-A PREROUTING -j avoid_nat_triangle"
      ForwardedPort.all(:include => [ :contract, :provider ]).each do |fp|
        do_port_forwardings_avoid_nat_triangle fp, f
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
      # Evito balanceo para los hosts configurados
      f.puts "-A OUTPUT -j avoid_balancing"
      # restauro marka en OUTPUT pero que siga viajando
      f.puts "-A OUTPUT -j CONNMARK --restore-mark  --nfmask 0x8fffffff --ctmask 0x8fffffff"
      f.puts "-A OUTPUT -m mark ! --mark 0x0/0x8fffffff -j ACCEPT"

      BootHook.run :hook => :mangle_after_ouput_hook, :iptables_script => f

      # CONNMARK POSTROUTING
      f.puts ":sequreisp_connmark - [0:0]"
      f.puts ":sequreisp.down - [0:0]"
      f.puts ":sequreisp.up - [0:0]"

      # apache traffic without restrictions for web interface
      f.puts "-A sequreisp.down -m owner --uid-owner www-data -j unlimited_bandwidth"

      BootHook.run :hook => :mangle_before_postrouting_hook, :iptables_script => f

      Provider.enabled.with_klass_and_interface.each do |p|
        f.puts "-A sequreisp_connmark  -o #{p.link_interface} -j MARK --set-mark 0x#{p.mark_hex}/0x00ff0000"
      end
      # si tiene marka de ProviderGroup voy a sequreisp_connmark
      ProviderGroup.enabled.with_klass.each do |pg|
        f.puts "-A POSTROUTING -m mark --mark 0x#{pg.mark_hex}/0x00ff0000 -j sequreisp_connmark"
      end
      # si no tiene ninguna marka de ruteo también va a sequreisp_connmark (lo de OUTPUT hit'ea aquí ej. bind DNS query)
      f.puts "-A POSTROUTING -m mark --mark 0x00000000/0x00ff0000 -j sequreisp_connmark"

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
        # separo el tráfico en las 3 class: prio1 prio2 prio3

        #prio1
        Configuration.first.traffic_prio.split(",").each do |action|
          Configuration::TRAFFIC_PRIO[action].each do |rule|
            f.puts "-A #{chain} #{mark_if} #{rule} -j MARK --set-mark #{mark_prio1}"
          end
        end

        #prio2
        (Configuration.default_prio_protos_array + c.prio_protos_array).uniq.each do |proto|
          f.puts "-A #{chain} #{mark_if} -p #{proto} -j MARK --set-mark #{mark_prio2}"
        end

        #prio2
        (Configuration.default_prio_helpers_array + c.prio_helpers_array).uniq do |helper|
          f.puts "-A #{chain} #{mark_if} -m helper --helper #{helper} -j MARK --set-mark #{ mark_prio2}"
        end

        #prio2
        ["tcp", "udp"].each do |proto|
          # solo 15 puertos por vez en multiport
          (Configuration.default_tcp_prio_ports_array + c.tcp_prio_ports_array).uniq.each_slice(15).to_a.each do |group|
            f.puts "-A #{chain} #{mark_if} -p #{proto} -m multiport --dports #{group.join(',')} -j MARK --set-mark #{mark_prio2}"
            f.puts "-A #{chain} #{mark_if} -p #{proto} -m multiport --sports #{group.join(',')} -j MARK --set-mark #{mark_prio2}"
          end
        end

        #do_prio_traffic_iptables :file => f, :chain => chain, :mark_if => mark_if, :mark => mark_prio1
        # prio2
        # do_prio_protos_iptables :protos => (Configuration.default_prio_protos_array + c.prio_protos_array).uniq,
        #                         :file => f, :chain => chain, :mark_if => mark_if, :mark => mark_prio2
        # do_prio_helpers_iptables :helpers => (Configuration.default_prio_helpers_array + c.prio_helpers_array).uniq,
        #                          :file => f, :chain => chain, :mark_if => mark_if, :mark => mark_prio2
        # do_prio_ports_iptables :ports => (Configuration.default_tcp_prio_ports_array + c.tcp_prio_ports_array).uniq,
        #                        :proto => "tcp", :file => f, :chain => chain, :mark_if => mark_if, :mark => mark_prio2
        # do_prio_ports_iptables :ports => (Configuration.default_udp_prio_ports_array + c.udp_prio_ports_array).uniq,
        #                        :proto => "udp", :file => f, :chain => chain, :mark_if => mark_if, :mark => mark_prio2
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
      f.puts "-A POSTROUTING -m mark ! --mark 0 -j CONNMARK --save-mark --nfmask 0x1fffffff --ctmask 0x1fffffff"
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
        end
      end
      # attribute: forwarded_ports
      #   forward de ports por Provider
      ForwardedPort.all(:include => [ :contract, :provider ]).each do |fp|
        do_port_forwardings fp, f
      end

      # VER CON EL ALFRED
      # Transparent PROXY rules (should be at the end of all others DNAT/REDIRECTS
      # Avoids tproxy to server ip's

      f.puts ":sequreisp-accepted-sites - [0:0]"
      f.puts "-A PREROUTING -j sequreisp-accepted-sites"

      # Allowing access from LAN to local ips to avoid notifications redirections
      listen_ports = Configuration.app_listen_port_available
      Interface.only_lan.each do |interface|
        interface.addresses.each do |addr|
          listen_ports.each do |port|
            f.puts "-A sequreisp-accepted-sites -d #{addr.ip} -p tcp --dport #{port} -j ACCEPT"
          end
        end
      end

      AlwaysAllowedSite.all.each do |site|
        site.ip_addresses.each do |ip|
          f.puts "-A sequreisp-accepted-sites -p tcp -d #{ip} -j ACCEPT"
        end
      end

      BootHook.run :hook => :nat_after_forwards_hook, :iptables_script => f

      Provider.enabled.with_klass_and_interface.each do |p|
        p.networks.each do |network|
          f.puts "-A POSTROUTING -o #{p.link_interface} -s #{network} -j ACCEPT"
        end
        # skip NAT for selected networks
        p.avoid_nat_addresses_as_ips.each do |ip|
          f.puts "-A POSTROUTING -o #{p.link_interface} -s #{ip} -j ACCEPT"
        end
        # do we have an ip yet?
        if p.ip.blank? or p.kind != 'static'
          f.puts "-A POSTROUTING -o #{p.link_interface}  -j MASQUERADE"
        else
          provider_ips = p.nat_pool_addresses
          if provider_ips.size > 1
            # find all contract ips for this provider
            contracts_ips = Contract.not_disabled.descend_by_ip_custom.all(:joins => :plan ,:conditions => ["provider_group_id = ?", p.provider_group_id]  , :select => :ip).collect { |c| c.ip.gsub(/\/.*/,"") }
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
      f.puts ":dns-query -"
      f.puts ":sequreisp-enabled - [0:0]"
      f.puts ":sequreisp-allowedsites - [0:0]"
      f.puts "-A FORWARD -j sequreisp-allowedsites"

      f.puts "-A OUTPUT -o lo -j ACCEPT"

      providers = Provider.enabled.with_klass_and_interface

      AlwaysAllowedSite.all.each do |site|
        site.ip_addresses.each do |ip|
          f.puts "-A sequreisp-allowedsites -p tcp -d #{ip} -j ACCEPT"
        end
      end

      BootHook.run :hook => :filter_before_all, :iptables_script => f

      f.puts "-A INPUT -p tcp -m multiport --dports #{Configuration.app_listen_port_available.join(',')} -j ACCEPT"

      providers.each do |p|
        if p.allow_dns_queries
          f.puts "-A INPUT -i #{p.link_interface} -p udp --dport 53 -j ACCEPT"
          f.puts "-A INPUT -i #{p.link_interface} -p tcp --dport 53 -j ACCEPT"
        end
      end

      f.puts "-A INPUT -p udp --dport 53 -j dns-query"
      f.puts "-A FORWARD -p udp --dport 53 -j dns-query"

      BootHook.run :hook => :filter_before_accept_dns_queries, :iptables_script => f

      Interface.only_lan.each do |i|
        ["INPUT","FORWARD"].each do |chain|
          f.puts "-A #{chain} -i #{i.name} -p udp --dport 53 -j ACCEPT"
          f.puts "-A #{chain} -i #{i.name} -p tcp --dport 53 -j ACCEPT"
        end
      end

      providers.each do |p|
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

def do_port_forwardings(fp, f=nil, boot=true)
  commands = []
  unless fp.provider.ip.blank? or fp.contract.nil?
    commands << "-A PREROUTING -d #{fp.provider.ip} -p tcp --dport #{fp.public_port} -j DNAT --to #{fp.contract.ip}:#{fp.private_port}" if fp.tcp
    commands << "-A PREROUTING -d #{fp.provider.ip} -p udp --dport #{fp.public_port} -j DNAT --to #{fp.contract.ip}:#{fp.private_port}" if fp.udp
  end
  f ? f.puts(commands) : exec_context_commands("do_port_forwardings", commands.map{|c| "iptables -t nat " + c }, boot)
end
def do_port_forwardings_avoid_nat_triangle(fp, f=nil, boot=true)
  commands = []
  unless fp.provider.ip.blank?
    commands << "-A avoid_nat_triangle -d #{fp.provider.ip} -p tcp --dport #{fp.public_port} -j MARK --set-mark 0x01000000/0x01000000" if fp.tcp
    commands << "-A avoid_nat_triangle -d #{fp.provider.ip} -p udp --dport #{fp.public_port} -j MARK --set-mark 0x01000000/0x01000000" if fp.udp
  end
  f ? f.puts(commands) : exec_context_commands("do_port_forwardings_avoid_nat_triangle", commands.map{|c| "iptables -t mangle " + c }, boot)
end

def gen_ip_ru
  begin
    File.open(IP_RU_FILE, "w") do |f|
      f.puts "rule flush"
      f.puts "rule add prio 10 lookup main"
      ProviderGroup.enabled.with_klass.each do |pg|
        f.puts "rule add fwmark 0x#{pg.mark_hex}/0x00ff0000 table #{pg.table} prio 200"
      end
      Provider.with_klass_and_interface.each do |p|
        f.puts "rule add fwmark 0x#{p.mark_hex}/0x00ff0000 table #{p.table} prio 300"
        p.networks.each do |network|
          f.puts "rule add from #{network} table #{p.table}  prio 100"
        end
        f.puts "rule add from #{p.ip}/32 table #{p.check_link_table} prio 90" if p.ip and not p.ip.empty?
      end
      f.puts "rule add prio 32767 from all lookup default"
      BootHook.run :hook => :gen_ip_ru, :ip_ru_script => f
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::gen_ip_ru e=>#{e.inspect}"
  end
end

def update_fallback_route(f=nil, force=false, boot=true)
  commands = []
  #tabla default (fallback de todos los enlaces)
  currentroute=`ip -oneline ro li table default | grep default`.gsub("\\\t","  ").strip
  if (currentroute != Provider.fallback_default_route and currentroute != Provider.fallback_default_route(true)) or force
    if Provider.fallback_default_route != ""
      #TODO por ahora solo cambio si hay ruta, sino no toco x las dudas
      commands << "ro re table default #{Provider.fallback_default_route}"
    end
    #TODO loguear? el cambio de estado en una bitactora
  end
  if commands.any?
    f ? f.puts(commands) : exec_context_commands("update_fallback_route", commands.map{|c| "ip " + c }, boot)
  end
end

def update_provider_group_route pg, f=nil, force=false, boot=true
  commands = []
  currentroute=`ip -oneline ro li table #{pg.table} | grep default`.gsub("\\\t","  ").strip
  if (currentroute != pg.default_route) or force
    if pg.default_route == ""
      commands << "ro del table #{pg.table} default"
    else
      commands << "ro re table #{pg.table} #{pg.default_route}"
    end
    #TODO loguear el cambio de estado en una bitactora
  end
  if commands.any?
    f ? f.puts(commands) : exec_context_commands("update_provider_group_route #{pg.id}", commands.map{|c| "ip " + c }, boot)
  end
end

def update_provider_route p, f=nil, force=false, boot=true
  commands = []
  currentroute=`ip -oneline ro li table #{p.table} | grep default`.gsub("\\\t","  ").strip
  default_route = p.online ? p.default_route : ""
  if (currentroute != default_route) or force
    if default_route == ""
      commands << "ro del table #{p.table} default"
    else
      commands << "ro re table #{p.table} #{p.default_route}"
    end
    #TODO loguear el cambio de estado en una bitactora
  end
  if commands.any?
    f ? f.puts(commands) : exec_context_commands("update_provider_route #{p.id}", commands.map{|c| "ip " + c }, boot)
  end
end

def gen_ip_ro
  begin
    File.open(IP_RO_FILE, "w") do |f|
      Provider.enabled.ready.with_klass_and_interface.each do |p|
        update_provider_route p, f, true
      end
      ProviderGroup.enabled.each do |pg|
        update_provider_group_route pg, f, true, true
      end
      update_fallback_route f, true, true
      BootHook.run :hook => :gen_ip_ro, :ip_ro_script => f
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
      Provider.all(:conditions => { :kind => 'dhcp', :dhcp_force_32_netmask => true }).each do |p|
        f.puts "[ \"$interface\" = \"#{p.interface.name}\" ] && new_subnet_arg=\"netmask 255.255.255.255\" new_subnet_mask=\"255.255.255.255\""
      end
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

def setup_clock
  tz_path = "/usr/share/zoneinfo/"
  tz_name = ActiveSupport::TimeZone.new(Configuration.time_zone).tzinfo.name
  if tz_name
    exec_context_commands "setup_clock", ["echo '#{tz_path}' > /etc/timezone", "cp #{File.join(tz_path, tz_name)} /etc/localtime"]
  end
end
def setup_proc
  # setup de params generales de sysctl
  exec_context_commands "setup_proc", [
    "echo 1 > /proc/sys/net/ipv4/ip_forward",
    "echo #{Configuration.nf_conntrack_max} > /proc/sys/net/nf_conntrack_max",
    "echo #{Configuration.nf_conntrack_max/4} > /sys/module/nf_conntrack/parameters/hashsize",
    "echo #{Configuration.gc_thresh1} > /proc/sys/net/ipv4/neigh/default/gc_thresh1",
    "echo #{Configuration.gc_thresh2} > /proc/sys/net/ipv4/neigh/default/gc_thresh2",
    "echo #{Configuration.gc_thresh3} > /proc/sys/net/ipv4/neigh/default/gc_thresh3"
    ]
end

def setup_proxy_arp
  commands = []
  Contract.find(:all, :conditions => "proxy_arp = 1 and proxy_arp_interface_id is not null").each do |c|
    p = c.proxy_arp_provider.present? ? c.proxy_arp_provider : c.guess_proxy_arp_provider
    if p
      g = c.proxy_arp_gateway.present? ? c.proxy_arp_gateway : p.gateway
      route = c.proxy_arp_use_lan_gateway ? "via #{c.proxy_arp_lan_gateway}" : "dev #{c.proxy_arp_interface.name}"
      commands << "arp -i #{p.interface.name} -Ds #{c.ip} #{p.interface.name} pub"
      commands << "ip ro re #{c.ip} #{route}"
      commands << "arp -i #{c.proxy_arp_interface.name} -Ds #{g} #{c.proxy_arp_interface.name} pub"
    end
  end
  exec_context_commands "setup_proxy_arp", commands
end

def do_provider_up(p)
  commands = []
  commands << "ip rule add from #{p.network} table #{p.table} prio 100"
  commands << "ip rule add from #{p.ip}/32 table #{p.check_link_table} prio 90"
  #pongo solo la ruta en check_link, si esta todo ok, el chequeador despues la pone para el balanceo
  commands << "ip ro re table #{p.check_link_table} #{p.default_route}"

  # Direct route in case of force /32bit netmask
  # delete this on do_provider_down is not necesary because routes disapears after interface goes down
  if p.dhcp_force_32_netmask
    commands << "ip ro re #{p.gateway} dev #{p.link_interface} table #{p.check_link_table}"
    commands << "ip ro re #{p.gateway} dev #{p.link_interface} table #{p.table}"
  end

  ForwardedPort.all(:conditions => { :provider_id => p.id }, :include => [ :contract, :provider ]).each do |fp|
    do_port_forwardings fp, nil, false
    do_port_forwardings_avoid_nat_triangle fp, nil, false
  end
  # if we have aditional ips...
  p.addresses.each do |a|
    commands << "ip address add #{a.ip}/#{a.netmask} dev #{p.link_interface}"
    commands << "ip route re #{a.network} dev #{p.link_interface}"
    #ips << "#{a.ruby_ip.to_s}"
  end
  if p.kind == "adsl"
    commands << "tc qdisc del dev #{p.link_interface} root"
    commands << "tc qdisc del dev #{p.link_interface} ingress"
    commands << "tc -b #{TC_FILE_PREFIX + p.link_interface}"
  end
  exec_context_commands "do_provider_up #{p.id}", commands, false
end

def do_provider_down(p)
  commands = []
  commands << "ip rule del from #{p.network} table #{p.table} prio 100"
  commands << "ip rule del from #{p.ip}/32 table #{p.check_link_table} prio 90"
  p.online = false
  p.ip = p.netmask = p.gateway = nil
  p.save(false)
  update_provider_route p, nil, false, false
  update_provider_group_route p.provider_group, nil, false, false
  update_fallback_route nil, false, false

  exec_context_commands "do_provider_down #{p.id}", commands, false
end

def check_physical_links
  changes = false
  readme = []
  writeme = []
  pid = []
  Interface.all(:conditions => "vlan = 0").each do |i|
    physical_link = i.current_physical_link
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

  Provider.with_klass_and_interface.each do |p|
    setup_provider_interface p, false if not p.online?
    update_provider_route p, nil, false, false
  end
  ProviderGroup.enabled.each do |pg|
    update_provider_group_route pg, nil, false, false
  end
  update_fallback_route nil, false, false
  begin
    if send_notification_mail and Configuration.deliver_notifications
      AppMailer.deliver_check_links_email
    end
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::check_links(AppMailer) e=>#{e.inspect}"
  end
end

def setup_queued_commands
  commands = []
  QueuedCommand.pending.each do |qc|
    commands << qc.command
    qc.executed = true
    qc.save
  end
  exec_context_commands "queued_commands", commands
end

def exec_context_commands context_name, commands, boot=true
  if boot
    BootCommandContext.new(context_name, commands).exec_commands
  else
    CommandContext.new(context_name, commands).exec_commands
  end
end

def setup_nf_modules
  modules = %w{nf_nat_ftp nf_nat_amanda nf_nat_pptp nf_nat_proto_gre nf_nat_sip nf_nat_irc 8021q}
  exec_context_commands "modprobe", modules.collect{|m| "modprobe #{m}" }
end

def setup_adsl_interface(p)
  begin
    File.open("#{PPP_DIR}/peers/#{p.interface.name}", 'w') {|peer| peer.write(p.to_ppp_peer) }
  rescue => e
    Rails.logger.error "ERROR in lib/sequreisp.rb::setup_provider_interface(PPP_DIR) e=>#{e.inspect}"
  end

  commands = "/usr/bin/pgrep -f 'pppd call #{p.interface.name} ' >/dev/null || (ip link list #{p.link_interface} &>/dev/null && /usr/bin/pon #{p.interface.name})"

  if p.online?
    p.addresses.each do |a|
      commands << "ip address | grep \"#{a.ip_in_cidr} .* #{i.name}\" || ip address replace #{a.ip_in_cidr} dev #{p.link_interface}"
      commands << "ip route replace #{a.network} dev #{p.link_interface}"
    end
  end
  commands
end

def setup_dhcp_interface(p)
  commands = []
  commmands = "/usr/bin/pgrep -f 'dhclient.#{p.interface.name}' &>/dev/null || dhclient3 -nw -pf /var/run/dhclient.#{p.link_interface}.pid -lf /var/lib/dhcp3/dhclient.#{p.link_interface}.leases #{p.link_interface}"
  if p.online?
    p.addresses.each do |a|
      commands << "ip address | grep \"#{a.ip_in_cidr} .* #{i.name}\" || ip address add #{a.ip_in_cidr} dev #{p.link_interface}"
      commands << "ip route re #{a.network} dev #{p.link_interface}"
    end
  end
  commands
end

def setup_static_interface(p)
  commands = []
  commands << "ip address | grep \"#{p.ip_in_cidr} .* #{p.link_interface}\" || ip address replace #{p.ip_in_cidr} dev #{p.link_interface}"
  p.addresses.each do |a|
    commands << "ip address | grep \"#{a.ip_in_cidr} .* #{i.name}\" || ip address replace #{a.ip_in_cidr} dev #{p.link_interface}"
    commands << "ip route replace #{a.network} dev #{p.link_interface} src #{a.ip}"
  end
  commands << "ip route replace #{p.network} dev #{p.link_interface} src #{p.ip}"
  commands << "ip route replace table #{p.check_link_table} #{p.gateway} dev #{p.link_interface}"
  commands << "ip route replace table #{p.check_link_table} #{p.default_route}"
end

def setup_provider_interface p, boot=true
  commands = []
  commands << "echo #{p.arp_ignore ? 1 : 0 } > /proc/sys/net/ipv4/conf/#{p.interface.name}/arp_ignore"
  commands << "echo #{p.arp_announce ? 1 : 0 } > /proc/sys/net/ipv4/conf/#{p.interface.name}/arp_announce"
  commands << "echo #{p.arp_filter ? 1 : 0 } > /proc/sys/net/ipv4/conf/#{p.interface.name}/arp_filter"

  case p.kind
  when "adsl"
    commands << setup_adsl_interface(p)
  when "dhcp"
    commands << setup_dhcp_interface(p)
  when "static"
    commands << setup_static_interface(p)
  end
  exec_context_commands "setup_provider_interface #{p.id}", commands, boot
end

def setup_lan_interface(i)
  commands = []
  i.addresses.each do |a|
    commands << "ip address | grep \"#{a.ip_in_cidr} .* #{i.name}\" || ip address replace #{a.ip_in_cidr} dev #{i.name}"
    commands << "ip route replace #{a.network} dev #{i.name} src #{a.ip}"
  end
  commands << "initctl emit -n net-device-up \"IFACE=#{i.name}\" \"LOGICAL=#{i.name}\" \"ADDRFAM=inet\" \"METHOD=static\""
end

def setup_interfaces
  Interface.all.each do |i|
    commands = []
    commands << "ip link list #{i.name} &>/dev/null || vconfig add #{i.vlan_interface.name} #{i.vlan_id}" if i.vlan?
    #commands << "ip link set dev #{i.name} down" SOLO SI ES NECESARIO CAMBIAR LA MAC
    commands << "ip -o link list #{i.name} | grep -o -i #{i.mac_address} >/dev/null || ip link set dev #{i.name} down && ip link set #{i.name} address #{i.mac_address}"
    #commands << "ip link set #{i.name} address #{i.mac_address}" if mac_address.present?
    commands << "ip -o link list #{i.name} | grep -o ',UP' >/dev/null || ip link set dev #{i.name} up"
    if i.lan?
      commands << setup_lan_interface(i)
      exec_context_commands("setup_lan_interface_#{i.name}", commands.flatten)
    elsif i.wan?
      commands << setup_provider_interface(i.provider) if i.wan?
      exec_context_commands("setup_wan_interfaces_#{i.name}", commands.flatten)
    end
  end
end

def setup_static_routes
  exec_context_commands "setup_static_routes", Iproute.all.collect{|ipr| "ip ro re #{ipr.route}" }
end

def setup_ifbs
  exec_context_commands "setup_ifbs", [
    "modprobe ifb numifbs=3",
    "ip link set #{IFB_UP} up",
    "ip link set #{IFB_UP} txqueuelen #{Interface::DEFAULT_TX_QUEUE_LEN_FOR_IFB}",
    "ip link set #{IFB_DOWN} up",
    "ip link set #{IFB_DOWN} txqueuelen #{Interface::DEFAULT_TX_QUEUE_LEN_FOR_IFB}",
    "ip link set #{IFB_INGRESS} up",
    "ip link set #{IFB_INGRESS} txqueuelen #{Interface::DEFAULT_TX_QUEUE_LEN_FOR_IFB}"
  ]
end

def setup_tc
  gen_tc
  commands = []
  commands << "tc -b #{TC_FILE_PREFIX + IFB_UP}"
  commands << "tc -b #{TC_FILE_PREFIX + IFB_DOWN}"

  Interface.all(:conditions => { :kind => "lan" }).each do |interface|
    commands << "tc -b #{TC_FILE_PREFIX + interface.name}"
  end
  Provider.enabled.with_klass_and_interface.each do |p|
    #TODO si es adsl y el ppp no está disponible falla el comando igual no pasa nada
    commands << "tc -b #{TC_FILE_PREFIX + p.link_interface}"
  end
  exec_context_commands "setup_tc", commands
end

def setup_ip_ro
  gen_ip_ro
  exec_context_commands "ip_ro", ["ip route del default table main", "ip -batch #{IP_RO_FILE}"]
end
def setup_ip_ru
  gen_ip_ru
  exec_context_commands "ip_ru", "ip -batch #{IP_RU_FILE}"
end
# def setup_providers_interfaces
#   Provider.with_klass_and_interface.each do |p|
#     setup_provider_interface p
#   end
# end
def setup_iptables
  gen_iptables
  status = exec_context_commands "setup_iptables", [
    "[ -x #{IPTABLES_PRE_FILE} ] && #{IPTABLES_PRE_FILE}",
    "iptables-restore -n < #{IPTABLES_FILE}.tmp",
    "[ -x #{IPTABLES_POST_FILE} ] && #{IPTABLES_POST_FILE}"
  ]
  if status
    exec_context_commands "create_iptables_file", [
        "mv #{IPTABLES_FILE}.tmp #{IPTABLES_FILE}"
    ]
  else
    exec_context_commands "restore_old_iptables", [
      "[ -x #{IPTABLES_PRE_FILE} ] && #{IPTABLES_PRE_FILE}",
      "iptables-restore -n < #{IPTABLES_FILE}",
      "[ -x #{IPTABLES_POST_FILE} ] && #{IPTABLES_POST_FILE}"
    ]
  end
end

def setup_mail_relay
  if Configuration.first.mail_relay_manipulated_for_sequreisp?
    commands = []
    commands << "postmap #{PATH_SASL_PASSWD}" if Configuration.first.generate_postfix_main
    commands << "service postfix restart"
    exec_context_commands("setup_mail_relay_create", commands)
  end
end

def boot(run=true)
  BootCommandContext.run = run
  BootCommandContext.clear_boot_file
  create_dirs_if_not_present if Rails.env.development?
  Configuration.do_reload
  exec_context_commands "create_tmp_file", ["touch #{DEPLOY_DIR}/tmp/apply_changes.lock"]
  #begin
    exec_context_commands  "sequreisp_pre", "[ -x #{SEQUREISP_PRE_FILE} ] && #{SEQUREISP_PRE_FILE}"

    setup_queued_commands
    setup_clock
    setup_proc
    setup_nf_modules
    setup_interfaces
    setup_dynamic_providers_hooks
#    setup_providers_interfaces
    setup_proxy_arp
    setup_static_routes
    setup_ifbs
    setup_ip_ru
    setup_ip_ro
    setup_tc
    setup_iptables
    setup_mail_relay

    #General configuration hook, plugins seems to use it to write updated conf files
    BootHook.run :hook => :general
    Configuration.first.generate_bind_dns_named_options
    exec_context_commands "bind_reload", "service bind9 reload"

    #Service restart hook
    BootHook.run :hook => :service_restart

    exec_context_commands "sequreisp_post", "[ -x #{SEQUREISP_POST_FILE} ] && #{SEQUREISP_POST_FILE}"
    exec_context_commands "delete_tmp_file", ["rm #{DEPLOY_DIR}/tmp/apply_changes.lock"]
  #rescue => e
  #  Rails.logger.error "ERROR in lib/sequreisp.rb::boot e=>#{e.inspect}"
  #end
end
