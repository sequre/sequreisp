Contract.all.each do |c|
  unless c.traffics.empty?
    init = c.traffics.first.from_date
    final = c.traffics.last.to_date
    while init <= final
      traffic = Traffic.first(:conditions => ["from_date = '#{init.strftime('%Y-%m-%d')}' and contract_id = #{c.id}"])
      unless traffic.nil?
        Traffic.delete_all(["to_date = '#{traffic.to_date.strftime('%Y-%m-%d')}' and from_date = '#{traffic.from_date.strftime('%Y-%m-%d')}' and contract_id = #{c.id} and id != #{traffic.id}"])
      end
      init = (init + 1.month).beginning_of_month
    end
  end
end
