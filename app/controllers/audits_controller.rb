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
    format_date params

    export_to_csv if params.has_key?("to_csv")

    @search = Audit.search(params[:search])

    @audits = @search.paginate(:page => params[:page], :per_page => 10, :order => order )

    @models = Audit.all(:select => "DISTINCT auditable_type", :order => "auditable_type ASC")\
                        .map(&:auditable_type)\
                        .map do |m|
                          human_name = m.constantize.human_name rescue m
                          [human_name, m]
                        end
    @search.created_at_greater_than_or_equal_to = @search.created_at_greater_than_or_equal_to.to_date if @search.created_at_greater_than_or_equal_to
    @search.created_at_less_than_or_equal_to = @search.created_at_less_than_or_equal_to.to_date if @search.created_at_less_than_or_equal_to
  end

  def export_to_csv
    csv_string = FasterCSV.generate(:col_sep => ";") do |csv|
      csv << [t('activerecord.attributes.audit.created_at'),
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

  def self.action_select_options
    [
      [I18n.t('audits.create'),"create"],
      [I18n.t('audits.update'),"update"],
      [I18n.t('audits.destroy'),"destroy"]
    ]
  end

  def format_date params
    if params[:search][:created_at_greater_than_or_equal_to].present?
      array_date = params[:search][:created_at_greater_than_or_equal_to].split("/")
      month = array_date.slice!(1)
      params[:search][:created_at_greater_than_or_equal_to] = array_date.unshift(month).join("/")
      params[:search][:created_at_greater_than_or_equal_to] = params[:search][:created_at_greater_than_or_equal_to].to_datetime.change({:hour => 0, :min => 0, :sec => 0})
    end
    if params[:search][:created_at_less_than_or_equal_to].present?
      array_date = params[:search][:created_at_less_than_or_equal_to].split("/")
      month = array_date.slice!(1)
      params[:search][:created_at_less_than_or_equal_to] = array_date.unshift(month).join("/")
      params[:search][:created_at_less_than_or_equal_to] = params[:search][:created_at_less_than_or_equal_to].to_datetime.change({:hour => 23, :min => 59, :sec => 59})
    end
  end

end
