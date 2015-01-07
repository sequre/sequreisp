Configuration.create!(
 :default_tcp_prio_ports => "20,21,22,25,80,110,143,443,587,993,995,1755,1863,1864,3128,5222,5223",
 :default_udp_prio_ports => "",
 :default_prio_protos =>  "udp,icmp,igmp,esp,ah,gre",
 :default_prio_helpers =>  "ftp,irc,sip",
 :nf_conntrack_max => 1048576,
 :gc_thresh1 => 2048,
 :gc_thresh2 => 4096,
 :gc_thresh3 => 8192,
 :language => "en",
 :transparent_proxy => false,
 :transparent_proxy_zph_enabled => false,
 :last_changes_applied_at => DateTime.now
)

Configuration.do_reload

User.create!(
  :name => "Admin",
  :email => "admin@sequre.com.ar",
  :password => "1234",
  :password_confirmation => "1234",
  :role_name => "admin"
)
# no la cargo acá xq ya la carga environment.rb
#require 'ar-extensions'
require 'ar-extensions/adapters/mysql'
require 'ar-extensions/import/mysql'
# tc class de los clientes(contratos) 4 por c/u, total 65536/4 = 16383 clientes
#i=1
#Klass.transaction do
# while (i+4)<65536 do
#   Klass.create!( :number => i )
#   i+=4
# end
#end
klass = []
(4..(2**16-4)).step(4).each {|i| klass << Klass.new( :number =>  i) }
#((2**16/4)-1).times{ |i| klass << Klass.new( :number =>  (i*4)+1) }
Klass.import klass, :optimize=>true

# tc class y ip ro table name de los provider y provider_groups
# arranco en 10 hasta 250 para no tener conflifctos con /etc/iproute2/rt_tables
# un máximo de 240 proveedores parece más que suficiente para un solo server
#ProviderKlass.transaction do
#  for i in 10..250 do
#    ProviderKlass.create!(:number => i)
#  end
#end
providerklass = []
(10..250).each { |i| providerklass << ProviderKlass.new( :number =>  i) }
ProviderKlass.import providerklass, :optimize=>true

first=true
Interface.scan.each do |name|
  if first
    i = Interface.create!(
     :name => name,
     :kind => 'lan',
     :vlan => false
    )
    i.addresses.create!(
     :ip => '192.168.100.100',
     :netmask => '255.255.255.0'
    )
    first=false
  else
    Interface.create!(
     :name => name,
     :kind => 'wan',
     :vlan => false
    )
  end
end

ProviderGroup.create!( :name => "Default")

Plan.create!(
  :name => "256/128",
  :provider_group => ProviderGroup.find_by_name("Default"),
  :rate_down => 0,
  :ceil_down => 256,
  :rate_up => 0,
  :ceil_up => 128,
  :transparent_proxy => true
)
Plan.create!(
  :name => "512/256",
  :provider_group => ProviderGroup.find_by_name("Default"),
  :rate_down => 0,
  :ceil_down => 512,
  :rate_up => 0,
  :ceil_up => 256,
  :transparent_proxy => true
)
Plan.create!(
  :name => "1024/512",
  :provider_group => ProviderGroup.find_by_name("Default"),
  :rate_down => 0,
  :ceil_down => 1024,
  :rate_up => 0,
  :ceil_up => 512,
  :transparent_proxy => true
)

ProhibitedForwardPort.create [{:port => 22000}, {:port => 80},
                              {:port => 81}, {:port => 82},
                              {:port => 10050},
                              {:port => 53, :udp => true}
]
