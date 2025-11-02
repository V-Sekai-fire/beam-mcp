defmodule BeamMcp.AuthorizationModelTest do
  use ExUnit.Case

  alias BeamMcp.AuthorizationModel

  describe "role hierarchy" do
    test "admin can access admin functions" do
      assert AuthorizationModel.can_access?(:admin, :net_kernel, :connect_node, 1)
    end

    test "admin can access user functions" do
      assert AuthorizationModel.can_access?(:admin, :Enum, :map, 2)
    end

    test "user cannot access admin functions" do
      refute AuthorizationModel.can_access?(:user, :net_kernel, :connect_node, 1)
    end

    test "user can access user functions" do
      assert AuthorizationModel.can_access?(:user, :Enum, :map, 2)
    end

    test "viewer can access viewer functions" do
      assert AuthorizationModel.can_access?(:viewer, :String, :upcase, 1)
    end

    test "viewer cannot access admin functions" do
      refute AuthorizationModel.can_access?(:viewer, :net_kernel, :connect_node, 1)
    end
  end

  describe "get_available_roles" do
    test "admin has admin, user, viewer roles" do
      roles = AuthorizationModel.get_available_roles(:admin)
      assert :admin in roles
      assert :user in roles
      assert :viewer in roles
    end

    test "user has user and viewer roles" do
      roles = AuthorizationModel.get_available_roles(:user)
      assert :user in roles
      assert :viewer in roles
      refute :admin in roles
    end

    test "viewer has only viewer role" do
      roles = AuthorizationModel.get_available_roles(:viewer)
      assert :viewer in roles
      assert length(roles) == 1
    end
  end

  describe "list_functions_for_role" do
    test "admin can list all functions" do
      functions = AuthorizationModel.list_functions_for_role(:admin)
      assert {:net_kernel, :connect_node, 1} in functions
      assert {:Enum, :map, 2} in functions
    end

    test "user can list non-admin functions" do
      functions = AuthorizationModel.list_functions_for_role(:user)
      refute {:net_kernel, :connect_node, 1} in functions
      assert {:Enum, :map, 2} in functions
    end

    test "viewer can list limited functions" do
      functions = AuthorizationModel.list_functions_for_role(:viewer)
      assert {:String, :upcase, 1} in functions
      refute {:Enum, :map, 2} in functions
    end
  end

  describe "unauthorized access" do
    test "unknown function returns empty role list" do
      roles = AuthorizationModel.get_authorized_roles(:UnknownModule, :unknown_func, 999)
      assert roles == []
    end

    test "cannot access unknown function with any role" do
      refute AuthorizationModel.can_access?(:admin, :UnknownModule, :unknown_func, 999)
      refute AuthorizationModel.can_access?(:user, :UnknownModule, :unknown_func, 999)
    end
  end
end
