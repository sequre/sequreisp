Contract.all(:include => :traffics).each do |c|
  unless c.traffics.empty?
    init = c.traffics.first.from_date
    final = c.traffics.last.to_date
    while init <= final
      last = init.end_of_month
      traffics = []
      c.traffics.each do |t|
        traffics << t if t.from_date >= init and t.to_date <= last
      end
      traffics.shift
      traffics.collect(&:delete)
      init = init + 1.month
    end
  end
end
