require 'test_helper'

class PlansControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:plans)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create plan" do
    assert_difference('Plan.count') do
      post :create, :plan => { }
    end

    assert_redirected_to plan_path(assigns(:plan))
  end

  test "should show plan" do
    get :show, :id => plans(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => plans(:one).to_param
    assert_response :success
  end

  test "should update plan" do
    put :update, :id => plans(:one).to_param, :plan => { }
    assert_redirected_to plan_path(assigns(:plan))
  end

  test "should destroy plan" do
    assert_difference('Plan.count', -1) do
      delete :destroy, :id => plans(:one).to_param
    end

    assert_redirected_to plans_path
  end
end
