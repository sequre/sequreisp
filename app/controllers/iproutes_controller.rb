class IproutesController < ApplicationController
  before_filter :require_user
  permissions :iproutes

  # GET /iproutes
  # GET /iproutes.xml
  def index
    params[:search] ||= {}
    #params[:search][:order] ||= 'ascend_by_name'
    @search = Iproute.search(params[:search])
    @iproutes = @search.paginate(:page => params[:page],:per_page => 30)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @iproutes }
    end
  end

  # GET /iproutes/1
  # GET /iproutes/1.xml
  def show
    @iproute = object
    render :action => "edit"
  end

  # GET /iproutes/new
  # GET /iproutes/new.xml
  def new
    @iproute = Iproute.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @iproute }
    end
  end

  # GET /iproutes/1/edit
  def edit
    @iproute = object
  end

  # POST /iproutes
  # POST /iproutes.xml
  def create
    @iproute = Iproute.new(params[:iproute])

    respond_to do |format|
      if @iproute.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(iproutes_path) }
        format.xml  { render :xml => @iproute, :status => :created, :location => @iproute }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @iproute.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /iproutes/1
  # PUT /iproutes/1.xml
  def update
    @iproute = object

    respond_to do |format|
      if @iproute.update_attributes(params[:iproute])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(iproutes_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @iproute.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /iproutes/1
  # DELETE /iproutes/1.xml
  def destroy
    @iproute = object
    @iproute.destroy
    redirect_to(iproutes_url)
  end
  private
  def object
    @object ||= Iproute.find(params[:id])
  end
end
