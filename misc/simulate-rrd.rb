require 'rrd'
require 'ruby-debug'

REQUIRED_FOLDERS = ["public/images/rrd", "db/rrd"]

REQUIRED_FOLDERS.each do |folder|
  Dir.mkdir(folder) if not File.exist? folder
end

#require 'ftools'
RRD_DIR=RAILS_ROOT + "/db/rrd"
sim = []
sim[0]=5.5
sim[1]=2.7
sim[2]=2.2
sim[3]=2.1
sim[4]=1.5
sim[5]=1.4
sim[6]=1.5
sim[7]=1.9
sim[8]=3.3
sim[9]=4.5
sim[10]=6
sim[11]=9.9
sim[12]=13.5
sim[13]=14.2
sim[14]=9.8
sim[15]=8.9
sim[16]=10.2
sim[17]=12.3
sim[18]=12.7
sim[19]=10.3
sim[20]=9.4
sim[21]=11.2
sim[22]=13.4
sim[23]=12.9
#tamaño de las descargas de los users, son 23
packets=[1, 2, 3, 4, 5, 6, 7, 8 ,9 , 11, 13, 17 ,23 ,29 ,35, 47, 53, 91, 133, 167, 241, 419, 637] 
INTERVAL=300
# le puedo pasar el nro de horas para que cree el histórico
if not ARGV[0].nil? 
  time=Time.now-ARGV[0].to_i.hours
else
  time=Time.now
end

def rrd_create(path, time)
  RRD::Wrapper.create '--start', (time - 60.seconds).strftime("%s"), path, 
    "-s", "#{INTERVAL.to_s}",
    # max = 1*1024*1024*1024*600 = 1Gbit/s * 600s
    "DS:down_prio:DERIVE:600:0:644245094400",
    "DS:down_dfl:DERIVE:600:0:644245094400",
    "DS:up_prio:DERIVE:600:0:644245094400",
    "DS:up_dfl:DERIVE:600:0:644245094400",
    #(24x60x60/300)*30dias
    "RRA:AVERAGE:0.5:1:8640",
    #(24x60x60x30/300)*12meses
    "RRA:AVERAGE:0.5:30:3456",
    #(24x60x60x30x12/300)*10años
    "RRA:AVERAGE:0.5:360:2880"
end

def rrd_update(o, time, down_prio, down_dfl, up_prio, up_dfl)
  rrd_path = RRD_DIR + "/#{o.class.name}.#{o.id.to_s}.rrd"
  rrd_create(rrd_path, time) unless File.exists?(rrd_path)
  RRD::Wrapper.update rrd_path, "-t", "down_prio:down_dfl:up_prio:up_dfl", "#{time.strftime("%s")}:#{down_prio}:#{down_dfl}:#{up_prio}:#{up_dfl}"
  #puts "#{o.klass.number.to_s(16)} #{rrd_path} #{time.strftime("%s")}:#{down_prio}:#{down_dfl}:#{up_prio}:#{up_dfl}"
end


while time < Time.now do
  pg_total_down = 0
  pg_total_up = 0
  ProviderGroup.all(:include => [{:plans => :contracts}, :providers]).each do |pg|
    total_down_prio = pg.rate_down * INTERVAL * 0.90
    total_down_dfl = pg.rate_down * INTERVAL * 0.10
    total_up_prio = pg.rate_up * INTERVAL * 0.90
    total_up_dfl = pg.rate_up * INTERVAL * 0.10
    total_pretended_down_prio = 0
    total_pretended_up_prio = 0
    total_pretended_down_dfl = 0
    total_pretended_up_dfl = 0
    consumption_down_prio = 0
    consumption_up_prio = 0
    consumption_down_dfl = 0
    consumption_up_dfl = 0
    down_prio=[]
    up_prio=[]
    down_dfl=[]
    up_dfl=[]
    pretended_down_prio=[]
    pretended_up_prio=[]
    pretended_down_dfl=[]
    pretended_up_dfl=[]
    pg.plans.each do |plan|
      ceil_down = plan.ceil_down * INTERVAL
      ceil_up = plan.ceil_up * INTERVAL
      Contract.transaction do
        plan.contracts.each do |c|
          #lanzo las descargas por cada cliente
          if sim[time.hour] > rand(100)
            #debugger
            # si paso la barrera de simultaneadad encolo los kbits respectivos
            c.queue_down_prio += packets[rand(23)]*1024*8
            c.queue_up_prio += (packets[rand(23)]*1024*8)/5
          end
          if sim[time.hour] > rand(100)
            # si paso la barrera de simultaneadad encolo los kbits respectivos
            c.queue_down_dfl += packets[rand(23)]*1024*8
            c.queue_up_dfl += (packets[rand(23)]*1024*8)/5
          end 

          ceil_down_prio =  c.queue_down_dfl > ceil_down * 0.10 ?  ceil_down * 0.90 : ceil_down - c.queue_down_dfl
          pretended_down_prio[c.id] = c.queue_down_prio > ceil_down_prio ? ceil_down_prio : c.queue_down_prio
          
          ceil_down_dfl = ceil_down - pretended_down_prio[c.id] > ceil_down*c.ceil_dfl_percent/100 ? ceil_down*c.ceil_dfl_percent/100 : ceil_down - pretended_down_prio[c.id]
          pretended_down_dfl[c.id] = c.queue_down_dfl > ceil_down_dfl ? ceil_down_dfl : c.queue_down_dfl

          ceil_up_prio =  c.queue_up_dfl > ceil_up * 0.10 ?  ceil_up * 0.90 : ceil_up - c.queue_up_dfl
          pretended_up_prio[c.id] = c.queue_up_prio > ceil_up_prio ? ceil_up_prio : c.queue_up_prio
          
          ceil_up_dfl = ceil_up - pretended_up_prio[c.id] > ceil_up*c.ceil_dfl_percent/100 ? ceil_up*c.ceil_dfl_percent/100 : ceil_up - pretended_up_prio[c.id]
          pretended_up_dfl[c.id] = c.queue_up_dfl > ceil_up_dfl ? ceil_up_dfl : c.queue_up_dfl
          
          total_pretended_down_prio += pretended_down_prio[c.id] 
          total_pretended_up_prio += pretended_up_prio[c.id]
          total_pretended_down_dfl += pretended_down_dfl[c.id] 
          total_pretended_up_dfl += pretended_up_dfl[c.id]
          c.save(false)
        end
      end
    end
    free_down_prio = 0
    free_down_dfl = 0
    free_up_prio = 0
    free_up_dfl = 0
    free_down_prio = (total_down_prio - total_pretended_down_prio) if total_pretended_down_prio < total_down_prio 
    free_down_dfl = (total_down_dfl - total_pretended_down_dfl) if total_pretended_down_dfl < total_down_dfl 
    free_up_prio = (total_up_prio - total_pretended_up_prio) if total_pretended_up_prio < total_up_prio 
    free_up_dfl = (total_up_dfl - total_pretended_up_dfl) if total_pretended_up_dfl < total_up_dfl 

    total_down_prio += free_down_dfl
    total_down_dfl += free_down_prio
    percent_down_prio = 1
    percent_down_dfl = 1
    percent_down_prio = total_down_prio / total_pretended_down_prio if total_pretended_down_prio > total_down_prio
    percent_down_dfl = total_down_dfl / total_pretended_down_dfl if total_pretended_down_dfl > total_down_dfl
    
    total_up_prio += free_up_dfl
    total_up_dfl += free_up_prio
    percent_up_prio = 1
    percent_up_dfl = 1
    percent_up_prio = total_up_prio / total_pretended_up_prio if total_pretended_up_prio > total_up_prio
    percent_up_dfl = total_up_dfl / total_pretended_up_dfl if total_pretended_up_dfl > total_up_dfl
    #puts "total_pretended_down_prio: #{total_pretended_down_prio} total_pretended_up_prio: #{total_pretended_up_prio} total_pretended_down_dfl: #{total_pretended_down_dfl} total_pretended_up_dfl: #{total_pretended_up_dfl}"
    #puts "percent use: #{percent_down_prio}"
    #puts "percent use: #{percent_down_dfl}"
    
    pg.plans.each do |plan|
      Contract.transaction do
        plan.contracts.each do |c|
          down_prio[c.id] = pretended_down_prio[c.id] * percent_down_prio 
          down_dfl[c.id] = pretended_down_dfl[c.id] * percent_down_dfl
          up_prio[c.id] = pretended_up_prio[c.id] * percent_up_prio 
          up_dfl[c.id] = pretended_up_dfl[c.id] * percent_up_dfl
          
          c.queue_down_prio -= down_prio[c.id]
          c.queue_up_prio -= up_prio[c.id]
          c.queue_down_dfl -= down_dfl[c.id]
          c.queue_up_dfl -= up_dfl[c.id]
          
          c.consumption_down_prio += down_prio[c.id] * 1024 / 8
          c.consumption_up_prio += up_prio[c.id] * 1024 / 8
          c.consumption_down_dfl += down_dfl[c.id] * 1024 / 8
          c.consumption_up_dfl += up_dfl[c.id] * 1024 / 8
           
          #puts "Queue:     contract #{c.id} down_prio: #{c.queue_down_prio}   up_prio: #{c.queue_up_prio}   down_dfl: #{c.queue_down_dfl}   up_dfl: #{c.queue_up_dfl}"
          #puts "Pretended: contract #{c.id} down_prio: #{pretended_down_prio[c.id]} up_prio: #{pretended_up_prio[c.id]} down_dfl: #{pretended_down_dfl[c.id]} up_dfl: #{pretended_up_dfl[c.id]}"
          #puts "Consumed:  contract #{c.id} down_prio: #{down_prio[c.id]}           up_prio: #{up_prio[c.id]}           down_dfl: #{down_dfl[c.id]}           up_dfl: #{up_dfl[c.id]}"
           
          rrd_update c, time, c.consumption_down_prio, c.consumption_down_dfl, c.consumption_up_prio, c.consumption_up_dfl

          consumption_down_prio += down_prio[c.id]
          consumption_up_prio += up_prio[c.id]
          consumption_down_dfl += down_dfl[c.id]
          consumption_up_dfl += up_dfl[c.id]
          c.save(false) 
        end
      end
    end
    pg.consumption_down_prio += consumption_down_prio * 1024 / 8
    pg.consumption_down_dfl += consumption_down_dfl * 1024 / 8
    pg.consumption_up_prio += consumption_up_prio * 1024 / 8
    pg.consumption_up_dfl += consumption_up_dfl * 1024 / 8
    rrd_update pg, time, pg.consumption_down_prio + pg.consumption_down_dfl, 0, pg.consumption_up_prio + pg.consumption_up_dfl, 0
    pg_total_down += pg.consumption_down_prio + pg.consumption_down_dfl 
    pg_total_up += pg.consumption_up_prio + pg.consumption_up_dfl 

    #puts "#{time.strftime("%s")}:#{pg.consumption_down_prio}:#{pg.consumption_down_dfl}:#{pg.consumption_up_prio}:#{pg.consumption_up_dfl}"
    Provider.transaction do
      pg.providers.each do |p|
        p.consumption_down_prio += p.rate_down * consumption_down_prio / pg.rate_down * 1024 / 8
        p.consumption_down_dfl += p.rate_down * consumption_down_dfl / pg.rate_down * 1024 / 8
        p.consumption_up_prio += p.rate_up * consumption_up_prio / pg.rate_up * 1024 / 8
        p.consumption_up_dfl += p.rate_up * consumption_up_dfl / pg.rate_up * 1024 / 8
        rrd_update p, time, p.consumption_down_prio + p.consumption_down_dfl, 0, p.consumption_up_prio + p.consumption_up_dfl, 0
        rrd_update p.interface, time, p.consumption_down_prio + p.consumption_down_dfl, 0, p.consumption_up_prio + p.consumption_up_dfl, 0
        p.save(false)
      end
    end
    pg.save(false)
  end
  lan_ifaces = Interface.all(:conditions => { :kind => "lan" })
  lan_ifaces.each do |i|
    rrd_update i, time, pg_total_down/lan_ifaces.count, 0, pg_total_up/lan_ifaces.count, 0
  end
  Interface.all(:conditions => { :kind => "wan" }).each do |i| 
    rrd_update i, time, 0, 0, 0, 0 if i.provider.nil?
  end
  time += INTERVAL.seconds
end


