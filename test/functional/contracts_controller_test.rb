require 'test_helper'

class ContractsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:contracts)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create contract" do
    assert_difference('Contract.count') do
      post :create, :contract => { }
    end

    assert_redirected_to contract_path(assigns(:contract))
  end

  test "should show contract" do
    get :show, :id => contracts(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => contracts(:one).to_param
    assert_response :success
  end

  test "should update contract" do
    put :update, :id => contracts(:one).to_param, :contract => { }
    assert_redirected_to contract_path(assigns(:contract))
  end

  test "should destroy contract" do
    assert_difference('Contract.count', -1) do
      delete :destroy, :id => contracts(:one).to_param
    end

    assert_redirected_to contracts_path
  end
end
