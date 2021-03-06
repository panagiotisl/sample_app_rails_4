class ShippingCompaniesController < ApplicationController
  
  before_filter :signed_in_user,     only: [:index, :show]
  before_filter :admin_user,     only: [:destroy]
  before_filter :authorized_sce, only: [:mercury_update]
  before_action :get_fleets,     only: [:index, :show]
  
  def index
    @shipping_companies = ShippingCompany.reorder("name ASC").paginate(page: params[:page])
  end
  
  def show
    @shipping_company = ShippingCompany.find(params[:id])
    @ships = @shipping_company.ships.paginate(page: params[:page])
    @voyages = @shipping_company.voyages.paginate(page: params[:page])
    if params[:page_id]
      @page = @shipping_company.pages.find(params[:page_id])
    else
      @page = @shipping_company.pages.first
    end
  end
  
  def new
    @shipping_company = ShippingCompany.new
  end
  
  def create
    @shipping_company = ShippingCompany.new(shipping_company_params)
    if verify_recaptcha(@shipping_company) && @shipping_company.save
      flash[:success] = "Shipping Company Saved!"
      redirect_to @shipping_company
    else
      render 'new'
    end
  end
  
  def destroy
    ShippingCompany.find(params[:id]).destroy
    flash[:success] = "Shipping Company destroyed."
    redirect_to shipping_companies_url
  end
  
  def mercury_update
    page = Page.find(params[:page_id])
    page.name = params[:content][:page_name][:value]
    page.content = params[:content][:page_content][:value]
    page.save!
    render text: ""
  end
  
  private
  
  def shipping_company_params
    params.require(:shipping_company).permit(:name, :email, :address, :telephone, :country_id)
  end
  
  def admin_user
    unless current_user && current_user.admin?
      flash[:error] = "You do not have permission to view this page!"
      redirect_to(root_url)
    end
  end
  
end
