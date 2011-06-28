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

module ContractsHelper
  def client_name_plus_detail_cpe_node_label
    "#{t('activerecord.attributes.client.name')} " +
    "(#{t('activerecord.attributes.contract.detail')}/" +
    "#{t('activerecord.attributes.contract.cpe')}/" +
    "#{t('activerecord.attributes.contract.node')})"
  end
  def detail_cpe_node(contract)
    if not contract.detail.blank? or not contract.cpe.blank? or not contract.node.blank?
      "(#{contract.detail}/#{contract.cpe}/#{contract.node})"
    else
      ""
    end
  end
end
