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

class AuditsController < ApplicationController
  before_filter :require_user
  permissions :audits
  def index
    params[:search][:order] ||= 'descend_by_created_at'
    @search = Audit.search(params[:search])

    if params[:search] &&  !params[:search][:auditable_id_equals].blank?
      #search by id
      @audits = Audit.paginate :page => params[:page], :per_page => 10,
                   :conditions => {
                      :auditable_type => params[:search][:auditable_type_is],
                      :auditable_id => params[:search][:auditable_id_equals]
                    }
    else
      @audits = @search.paginate(:page => params[:page], :per_page => 10)
    end

    @models = Audit.all(:select => "DISTINCT auditable_type", :order => "auditable_type ASC").map(&:auditable_type)
  end
end
