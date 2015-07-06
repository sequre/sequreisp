class DeviceBrandsController < ApplicationController
  # GET /device_brands
  # GET /device_brands.xml
  def index
    @device_brands = DeviceBrand.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @device_brands }
    end
  end

  # GET /device_brands/new
  # GET /device_brands/new.xml
  def new
    @device_brand = DeviceBrand.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @device_brand }
    end
  end

  # GET /device_brands/1/edit
  def edit
    @device_brand = object
  end

  # POST /device_brands
  # POST /device_brands.xml
  def create
    @device_brand = DeviceBrand.new(params[:device_brand])

    respond_to do |format|
      if @device_brand.save
        format.html { redirect_to(device_brands_path, :notice => 'Device Brand was successfully created.') }
        format.xml  { render :xml => @device_brand, :status => :created, :location => @device_brand }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @device_brand.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /device_brands/1
  # PUT /device_brands/1.xml
  def update
    @device_brand = object

    respond_to do |format|
      if @device_brand.update_attributes(params[:device_brand])
        format.html { redirect_to(@device_brand, :notice => 'DeviceBrand was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @device_brand.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /device_brands/1
  # DELETE /device_brands/1.xml
  def destroy
    @device_brand = object
    @device_brand.destroy

    respond_to do |format|
      format.html { redirect_to(device_brands_path) }
      format.xml  { head :ok }
    end
  end

  private
    def object
      DeviceBrand.find(params[:id])
    end
end
