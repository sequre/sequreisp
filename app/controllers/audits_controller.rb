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
    export_to_csv if params.has_key?("to_csv")

    @search = Audit.search(params[:search])
    @audits = @search.paginate(:page => params[:page], :per_page => 10, :order => 'created_at DESC' )
  end

  def export_to_csv
    csv_string = FasterCSV.generate(:col_sep => ";") do |csv|
      csv << [ "",
              t('activerecord.attributes.audit.created_at'),
              t('activerecord.attributes.audit.auditable_type'),
              t('activerecord.attributes.audit.user'),
              t('activerecord.attributes.audit.action'),
              t('activerecord.attributes.audit.changes')]
      Audit.search(params[:search]).all.each do |audit|
       csv << [audit.id,
               audit.created_at,
               audit.auditable_type,
               audit.user.try(:name),
               audit.action,
               audit.changes.to_yaml(:UseBlock => true, :UseHeader => false, :Separator => "", :ExplicitTypes => true, :UseFold => true) ]
      end
    end
      send_data csv_string,
      :type => 'text/csv; charset=UTF-8; header=present',
      :disposition => "attachment; filename=audits_#{Time.now.strftime("%Y-%m-%d")}.csv"
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

end
