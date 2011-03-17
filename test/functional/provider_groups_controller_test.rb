require 'test_helper'

class ProviderGroupsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:provider_groups)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create provider_group" do
    assert_difference('ProviderGroup.count') do
      post :create, :provider_group => { }
    end

    assert_redirected_to provider_group_path(assigns(:provider_group))
  end

  test "should show provider_group" do
    get :show, :id => provider_groups(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => provider_groups(:one).to_param
    assert_response :success
  end

  test "should update provider_group" do
    put :update, :id => provider_groups(:one).to_param, :provider_group => { }
    assert_redirected_to provider_group_path(assigns(:provider_group))
  end

  test "should destroy provider_group" do
    assert_difference('ProviderGroup.count', -1) do
      delete :destroy, :id => provider_groups(:one).to_param
    end

    assert_redirected_to provider_groups_path
  end
end
