class AntiAbuseRulesController < ApplicationController
  before_filter :require_user
  permissions :anti_abuse_rules

  # GET /anti_abuse_rules
  # GET /anti_abuse_rules.xml
  def index
    params[:search] ||= {}
    params[:search][:order] ||= 'ascend_by_name'
    @search = AntiAbuseRule.search(params[:search])
    @anti_abuse_rules = @search.paginate(:page => params[:page],:per_page => 30)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @anti_abuse_rules }
    end
  end

  # GET /anti_abuse_rules/1
  # GET /anti_abuse_rules/1.xml
  def show
    @anti_abuse_rule = object
  end

  # GET /anti_abuse_rules/new
  # GET /anti_abuse_rules/new.xml
  def new
    @anti_abuse_rule = AntiAbuseRule.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @anti_abuse_rule }
    end
  end

  # GET /anti_abuse_rules/1/edit
  def edit
    @anti_abuse_rule = object
  end

  # POST /anti_abuse_rules
  # POST /anti_abuse_rules.xml
  def create
    @anti_abuse_rule = AntiAbuseRule.new(params[:anti_abuse_rule])

    respond_to do |format|
      if @anti_abuse_rule.save
        flash[:notice] = t 'controllers.successfully_created'
        format.html { redirect_back_from_edit_or_to(anti_abuse_rules_path) }
        format.xml  { render :xml => @anti_abuse_rule, :status => :created, :location => @anti_abuse_rule }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @anti_abuse_rule.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /anti_abuse_rules/1
  # PUT /anti_abuse_rules/1.xml
  def update
    @anti_abuse_rule = object

    respond_to do |format|
      if @anti_abuse_rule.update_attributes(params[:anti_abuse_rule])
        flash[:notice] = t 'controllers.successfully_updated'
        format.html { redirect_back_from_edit_or_to(anti_abuse_rules_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @anti_abuse_rule.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /anti_abuse_rules/1
  # DELETE /anti_abuse_rules/1.xml
  def destroy
    @anti_abuse_rule = object
    @anti_abuse_rule.destroy
    redirect_back_from_edit_or_to anti_abuse_rules_url
  end
  private
  def object
    @object ||= AntiAbuseRule.find(params[:id])
  end
end
