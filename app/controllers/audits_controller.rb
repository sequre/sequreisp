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
    params[:search] ||= {}
    order = 'created_at DESC'
    @search = Audit.search(params[:search])

    if !params[:search][:auditable_id_equals].blank?
      #search by id
      @audits = Audit.paginate :page => params[:page], :per_page => 10, :order => order,
                   :conditions => {
                      :auditable_type => params[:search][:auditable_type_is],
                      :auditable_id => params[:search][:auditable_id_equals]
                    }
    else
      @audits = @search.paginate(:page => params[:page], :per_page => 10, :order => order )
    end

    @models = Audit.all(:select => "DISTINCT auditable_type", :order => "auditable_type ASC")\
                        .map(&:auditable_type)\
                        .map{|m| [m.constantize.human_name, m]}
  end

  def go_back
    audit = Audit.find(params[:id])
    object = audit.revision
    if audit.auditable and audit.action == 'update'
      eval "@#{audit.auditable.class.table_name.singularize} = object"
      @commit_text = t 'audits.go_back'
      render "#{audit.auditable.class.table_name}/edit"
    else
      flash[:error] = t 'audits.error_on_reversion'
      redirect_to audits_path
    end
  end

  def self.action_select_options
    [
      [I18n.t('audits.create'),"create"],
      [I18n.t('audits.update'),"update"],
      [I18n.t('audits.destroy'),"destroy"]
    ]
  end
end
