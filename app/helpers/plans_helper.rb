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

module PlansHelper

  def select_cir_strategy
    [ [I18n.t("messages.plan.automatic"), Plan::CIR_STRATEGY_AUTOMATIC],
      [I18n.t("messages.plan.percentage"), Plan::CIR_STRATEGY_PERCENTAGE],
      [I18n.t("messages.plan.reuse"), Plan::CIR_STRATEGY_REUSE],
      [I18n.t("messages.plan.plan_total"), Plan::CIR_STRATEGY_PLAN_TOTAL] ]
  end

end
