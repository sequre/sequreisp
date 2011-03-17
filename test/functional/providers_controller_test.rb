require 'test_helper'

class ProvidersControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:providers)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create provider" do
    assert_difference('Provider.count') do
      post :create, :provider => { }
    end

    assert_redirected_to provider_path(assigns(:provider))
  end

  test "should show provider" do
    get :show, :id => providers(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => providers(:one).to_param
    assert_response :success
  end

  test "should update provider" do
    put :update, :id => providers(:one).to_param, :provider => { }
    assert_redirected_to provider_path(assigns(:provider))
  end

  test "should destroy provider" do
    assert_difference('Provider.count', -1) do
      delete :destroy, :id => providers(:one).to_param
    end

    assert_redirected_to providers_path
  end
end
