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

class GraphsController < ApplicationController
  before_filter :require_user
  permissions :graphs
  # GET /graphs
  # GET /graphs.xml
  def index
    #@graphs = graph.all

    #respond_to do |format|
    #  format.html # index.html.erb
    #  format.xml  { render :xml => @graphs }
    #end
  end

  # GET /graphs/1
  # GET /graphs/1.xml
  def show
    @graph = object 
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @graph }
    end
  end
  private
  def object
    @object ||= Graph.new(:class => params[:class], :id => params[:id])
  end
end
