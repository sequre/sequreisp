require 'test_helper'

class InterfacesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:interfaces)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create interface" do
    assert_difference('Interface.count') do
      post :create, :interface => { }
    end

    assert_redirected_to interface_path(assigns(:interface))
  end

  test "should show interface" do
    get :show, :id => interfaces(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => interfaces(:one).to_param
    assert_response :success
  end

  test "should update interface" do
    put :update, :id => interfaces(:one).to_param, :interface => { }
    assert_redirected_to interface_path(assigns(:interface))
  end

  test "should destroy interface" do
    assert_difference('Interface.count', -1) do
      delete :destroy, :id => interfaces(:one).to_param
    end

    assert_redirected_to interfaces_path
  end
end
