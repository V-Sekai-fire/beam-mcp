defmodule BeamMcp.AuthorizationModel do
  @moduledoc """
  Role-based authorization model inspired by pgFGA.
  
  Defines which functions are accessible to which roles with support for:
  - Role hierarchy (role inheritance)
  - Function whitelisting
  - Schema versioning for policy management
  """

  require Logger

  @type role :: :admin | :user | :viewer
  @type schema_version :: non_neg_integer()

  # Role hierarchy - defines which roles imply other roles.
  # Example: admin can do everything a user can do.
  @role_hierarchy %{
    admin: [:user, :viewer],
    user: [:viewer],
    viewer: []
  }

  # Function allowlist - comprehensive whitelist of known functions
  # Format: {module, function, arity} => [roles...]
  @function_allowlist %{
    # Admin-only: Distributed & RPC functions
    {:net_kernel, :connect_node, 1} => [:admin],
    {:net_kernel, :disconnect, 1} => [:admin],
    {:net_kernel, :get_net_ticktime, 0} => [:admin],
    {:net_kernel, :set_net_ticktime, 1} => [:admin],
    {:rpc, :call, 4} => [:admin],
    {:rpc, :call, 5} => [:admin],
    {:rpc, :cast, 4} => [:admin],
    {:rpc, :multicall, 3} => [:admin],
    {:rpc, :multicall, 4} => [:admin],
    {:rpc, :multicall, 5} => [:admin],
    {:rpc, :eval_everywhere, 3} => [:admin],
    {:erpc, :call, 2} => [:admin],
    {:erpc, :call, 3} => [:admin],
    {:erpc, :cast, 2} => [:admin],
    {:erpc, :cast, 3} => [:admin],
    {:erlang, :nodes, 0} => [:admin],
    {:erlang, :nodes, 1} => [:admin],
    {:erlang, :monitor_node, 2} => [:admin],

    # User-level: Code inspection & system info
    {:code, :all_loaded, 0} => [:user, :viewer],
    {:code, :get_path, 0} => [:user, :viewer],
    {:code, :get_doc, 1} => [:user, :viewer],
    {:erlang, :loaded, 0} => [:user, :viewer],
    {:erlang, :module_info, 1} => [:user, :viewer],
    {:erlang, :module_info, 2} => [:user, :viewer],
    {:erlang, :system_info, 1} => [:user, :viewer],
    {:erlang, :memory, 0} => [:user, :viewer],
    {:erlang, :memory, 1} => [:user, :viewer],
    {:erlang, :statistics, 1} => [:user, :viewer],

    # Enum - all read operations
    {:Enum, :all?, 1} => [:user, :viewer],
    {:Enum, :all?, 2} => [:user, :viewer],
    {:Enum, :any?, 1} => [:user, :viewer],
    {:Enum, :any?, 2} => [:user, :viewer],
    {:Enum, :at, 2} => [:user, :viewer],
    {:Enum, :at, 3} => [:user, :viewer],
    {:Enum, :chunk_every, 2} => [:user, :viewer],
    {:Enum, :chunk_every, 3} => [:user, :viewer],
    {:Enum, :chunk_every, 4} => [:user, :viewer],
    {:Enum, :concat, 1} => [:user, :viewer],
    {:Enum, :concat, 2} => [:user, :viewer],
    {:Enum, :count, 1} => [:user, :viewer],
    {:Enum, :count, 2} => [:user, :viewer],
    {:Enum, :dedup, 1} => [:user, :viewer],
    {:Enum, :dedup_by, 2} => [:user, :viewer],
    {:Enum, :drop, 2} => [:user, :viewer],
    {:Enum, :drop_while, 2} => [:user, :viewer],
    {:Enum, :each, 2} => [:user, :viewer],
    {:Enum, :empty?, 1} => [:user, :viewer],
    {:Enum, :filter, 2} => [:user, :viewer],
    {:Enum, :find, 2} => [:user, :viewer],
    {:Enum, :find, 3} => [:user, :viewer],
    {:Enum, :find_index, 2} => [:user, :viewer],
    {:Enum, :flat_map, 2} => [:user, :viewer],
    {:Enum, :frequencies, 1} => [:user, :viewer],
    {:Enum, :frequencies_by, 2} => [:user, :viewer],
    {:Enum, :group_by, 2} => [:user, :viewer],
    {:Enum, :intersperse, 2} => [:user, :viewer],
    {:Enum, :join, 1} => [:user, :viewer],
    {:Enum, :join, 2} => [:user, :viewer],
    {:Enum, :map, 2} => [:user, :viewer],
    {:Enum, :map_every, 3} => [:user, :viewer],
    {:Enum, :max, 1} => [:user, :viewer],
    {:Enum, :max_by, 2} => [:user, :viewer],
    {:Enum, :min, 1} => [:user, :viewer],
    {:Enum, :min_by, 2} => [:user, :viewer],
    {:Enum, :random, 1} => [:user, :viewer],
    {:Enum, :reduce, 2} => [:user, :viewer],
    {:Enum, :reduce, 3} => [:user, :viewer],
    {:Enum, :reject, 2} => [:user, :viewer],
    {:Enum, :reverse, 1} => [:user, :viewer],
    {:Enum, :reverse, 2} => [:user, :viewer],
    {:Enum, :shuffle, 1} => [:user, :viewer],
    {:Enum, :slice, 2} => [:user, :viewer],
    {:Enum, :slice, 3} => [:user, :viewer],
    {:Enum, :sort, 1} => [:user, :viewer],
    {:Enum, :sort, 2} => [:user, :viewer],
    {:Enum, :sort_by, 2} => [:user, :viewer],
    {:Enum, :sort_by, 3} => [:user, :viewer],
    {:Enum, :split, 2} => [:user, :viewer],
    {:Enum, :split_while, 2} => [:user, :viewer],
    {:Enum, :sum, 1} => [:user, :viewer],
    {:Enum, :take, 2} => [:user, :viewer],
    {:Enum, :take_every, 2} => [:user, :viewer],
    {:Enum, :take_while, 2} => [:user, :viewer],
    {:Enum, :to_list, 1} => [:user, :viewer],
    {:Enum, :uniq, 1} => [:user, :viewer],
    {:Enum, :uniq_by, 2} => [:user, :viewer],
    {:Enum, :with_index, 1} => [:user, :viewer],
    {:Enum, :with_index, 2} => [:user, :viewer],
    {:Enum, :zip, 1} => [:user, :viewer],
    {:Enum, :zip, 2} => [:user, :viewer],

    # String operations
    {:String, :capitalize, 1} => [:user, :viewer],
    {:String, :chunk, 2} => [:user, :viewer],
    {:String, :contains?, 2} => [:user, :viewer],
    {:String, :downcase, 1} => [:user, :viewer],
    {:String, :downcase, 2} => [:user, :viewer],
    {:String, :duplicate, 2} => [:user, :viewer],
    {:String, :ends_with?, 2} => [:user, :viewer],
    {:String, :first, 1} => [:user, :viewer],
    {:String, :graphemes, 1} => [:user, :viewer],
    {:String, :length, 1} => [:user, :viewer],
    {:String, :match, 2} => [:user, :viewer],
    {:String, :myers_difference, 2} => [:user, :viewer],
    {:String, :next_codepoint, 1} => [:user, :viewer],
    {:String, :next_grapheme, 1} => [:user, :viewer],
    {:String, :pad_leading, 2} => [:user, :viewer],
    {:String, :pad_leading, 3} => [:user, :viewer],
    {:String, :pad_trailing, 2} => [:user, :viewer],
    {:String, :pad_trailing, 3} => [:user, :viewer],
    {:String, :replace, 3} => [:user, :viewer],
    {:String, :replace, 4} => [:user, :viewer],
    {:String, :reverse, 1} => [:user, :viewer],
    {:String, :slice, 2} => [:user, :viewer],
    {:String, :split, 1} => [:user, :viewer],
    {:String, :split, 2} => [:user, :viewer],
    {:String, :split, 3} => [:user, :viewer],
    {:String, :splitter, 2} => [:user, :viewer],
    {:String, :starts_with?, 2} => [:user, :viewer],
    {:String, :to_atom, 1} => [:user, :viewer],
    {:String, :to_charlist, 1} => [:user, :viewer],
    {:String, :to_existing_atom, 1} => [:user, :viewer],
    {:String, :to_float, 1} => [:user, :viewer],
    {:String, :to_integer, 1} => [:user, :viewer],
    {:String, :to_integer, 2} => [:user, :viewer],
    {:String, :trim, 1} => [:user, :viewer],
    {:String, :trim_leading, 1} => [:user, :viewer],
    {:String, :trim_leading, 2} => [:user, :viewer],
    {:String, :trim_trailing, 1} => [:user, :viewer],
    {:String, :trim_trailing, 2} => [:user, :viewer],
    {:String, :upcase, 1} => [:user, :viewer],
    {:String, :upcase, 2} => [:user, :viewer],
    {:String, :valid?, 1} => [:user, :viewer],

    # Kernel - arithmetic, comparison, type checks, introspection
    {:Kernel, :+, 2} => [:user, :viewer],
    {:Kernel, :-, 2} => [:user, :viewer],
    {:Kernel, :*, 2} => [:user, :viewer],
    {:Kernel, :/, 2} => [:user, :viewer],
    {:Kernel, :div, 2} => [:user, :viewer],
    {:Kernel, :rem, 2} => [:user, :viewer],
    {:Kernel, :<, 2} => [:user, :viewer],
    {:Kernel, :>, 2} => [:user, :viewer],
    {:Kernel, :<=, 2} => [:user, :viewer],
    {:Kernel, :>=, 2} => [:user, :viewer],
    {:Kernel, :==, 2} => [:user, :viewer],
    {:Kernel, :!=, 2} => [:user, :viewer],
    {:Kernel, :===, 2} => [:user, :viewer],
    {:Kernel, :!==, 2} => [:user, :viewer],
    {:Kernel, :and, 2} => [:user, :viewer],
    {:Kernel, :or, 2} => [:user, :viewer],
    {:Kernel, :not, 1} => [:user, :viewer],
    {:Kernel, :abs, 1} => [:user, :viewer],
    {:Kernel, :ceil, 1} => [:user, :viewer],
    {:Kernel, :floor, 1} => [:user, :viewer],
    {:Kernel, :round, 1} => [:user, :viewer],
    {:Kernel, :trunc, 1} => [:user, :viewer],
    {:Kernel, :max, 2} => [:user, :viewer],
    {:Kernel, :min, 2} => [:user, :viewer],
    {:Kernel, :inspect, 1} => [:user, :viewer],
    {:Kernel, :inspect, 2} => [:user, :viewer],
    {:Kernel, :is_atom, 1} => [:user, :viewer],
    {:Kernel, :is_binary, 1} => [:user, :viewer],
    {:Kernel, :is_bitstring, 1} => [:user, :viewer],
    {:Kernel, :is_boolean, 1} => [:user, :viewer],
    {:Kernel, :is_float, 1} => [:user, :viewer],
    {:Kernel, :is_function, 1} => [:user, :viewer],
    {:Kernel, :is_function, 2} => [:user, :viewer],
    {:Kernel, :is_integer, 1} => [:user, :viewer],
    {:Kernel, :is_list, 1} => [:user, :viewer],
    {:Kernel, :is_map, 1} => [:user, :viewer],
    {:Kernel, :is_nil, 1} => [:user, :viewer],
    {:Kernel, :is_number, 1} => [:user, :viewer],
    {:Kernel, :is_pid, 1} => [:user, :viewer],
    {:Kernel, :is_port, 1} => [:user, :viewer],
    {:Kernel, :is_reference, 1} => [:user, :viewer],
    {:Kernel, :is_tuple, 1} => [:user, :viewer],
    {:Kernel, :length, 1} => [:user, :viewer],
    {:Kernel, :map_size, 1} => [:user, :viewer],
    {:Kernel, :tuple_size, 1} => [:user, :viewer],
    {:Kernel, :byte_size, 1} => [:user, :viewer],
    {:Kernel, :bit_size, 1} => [:user, :viewer],

    # List operations
    {:List, :delete, 2} => [:user, :viewer],
    {:List, :delete_at, 2} => [:user, :viewer],
    {:List, :duplicate, 2} => [:user, :viewer],
    {:List, :first, 1} => [:user, :viewer],
    {:List, :flatten, 1} => [:user, :viewer],
    {:List, :flatten, 2} => [:user, :viewer],
    {:List, :foldl, 3} => [:user, :viewer],
    {:List, :foldr, 3} => [:user, :viewer],
    {:List, :insert_at, 3} => [:user, :viewer],
    {:List, :keyfind, 3} => [:user, :viewer],
    {:List, :keysort, 2} => [:user, :viewer],
    {:List, :keyreplace, 4} => [:user, :viewer],
    {:List, :last, 1} => [:user, :viewer],
    {:List, :length, 1} => [:user, :viewer],
    {:List, :myers_difference, 2} => [:user, :viewer],
    {:List, :pop_at, 2} => [:user, :viewer],
    {:List, :pop_at, 3} => [:user, :viewer],
    {:List, :replace_at, 3} => [:user, :viewer],
    {:List, :starts_with?, 2} => [:user, :viewer],
    {:List, :to_atom, 1} => [:user, :viewer],
    {:List, :to_charlist, 1} => [:user, :viewer],
    {:List, :to_string, 1} => [:user, :viewer],
    {:List, :zip, 1} => [:user, :viewer],
    {:List, :zip, 2} => [:user, :viewer],

    # Map operations
    {:Map, :delete, 2} => [:user, :viewer],
    {:Map, :drop, 2} => [:user, :viewer],
    {:Map, :equal?, 2} => [:user, :viewer],
    {:Map, :fetch, 2} => [:user, :viewer],
    {:Map, :fetch!, 2} => [:user, :viewer],
    {:Map, :filter, 2} => [:user, :viewer],
    {:Map, :from_struct, 1} => [:user, :viewer],
    {:Map, :get, 2} => [:user, :viewer],
    {:Map, :get, 3} => [:user, :viewer],
    {:Map, :get_lazy, 3} => [:user, :viewer],
    {:Map, :has_key?, 2} => [:user, :viewer],
    {:Map, :keys, 1} => [:user, :viewer],
    {:Map, :merge, 2} => [:user, :viewer],
    {:Map, :merge, 3} => [:user, :viewer],
    {:Map, :new, 0} => [:user, :viewer],
    {:Map, :new, 1} => [:user, :viewer],
    {:Map, :pop, 2} => [:user, :viewer],
    {:Map, :pop, 3} => [:user, :viewer],
    {:Map, :pop_lazy, 3} => [:user, :viewer],
    {:Map, :put, 3} => [:user, :viewer],
    {:Map, :put_new, 3} => [:user, :viewer],
    {:Map, :put_new_lazy, 3} => [:user, :viewer],
    {:Map, :reject, 2} => [:user, :viewer],
    {:Map, :replace, 3} => [:user, :viewer],
    {:Map, :replace!, 3} => [:user, :viewer],
    {:Map, :split, 2} => [:user, :viewer],
    {:Map, :take, 2} => [:user, :viewer],
    {:Map, :to_list, 1} => [:user, :viewer],
    {:Map, :update, 3} => [:user, :viewer],
    {:Map, :update!, 3} => [:user, :viewer],
    {:Map, :values, 1} => [:user, :viewer],

    # Tuple operations
    {:Tuple, :append, 2} => [:user, :viewer],
    {:Tuple, :delete_at, 2} => [:user, :viewer],
    {:Tuple, :duplicate, 2} => [:user, :viewer],
    {:Tuple, :insert_at, 3} => [:user, :viewer],
    {:Tuple, :product, 1} => [:user, :viewer],
    {:Tuple, :sum, 1} => [:user, :viewer],
    {:Tuple, :to_list, 1} => [:user, :viewer],

    # Atom operations
    {:Atom, :to_charlist, 1} => [:user, :viewer],
    {:Atom, :to_string, 1} => [:user, :viewer],

    # Integer operations
    {:Integer, :digits, 1} => [:user, :viewer],
    {:Integer, :digits, 2} => [:user, :viewer],
    {:Integer, :gcd, 2} => [:user, :viewer],
    {:Integer, :is_even, 1} => [:user, :viewer],
    {:Integer, :is_odd, 1} => [:user, :viewer],
    {:Integer, :mod, 2} => [:user, :viewer],
    {:Integer, :parse, 1} => [:user, :viewer],
    {:Integer, :parse, 2} => [:user, :viewer],
    {:Integer, :to_charlist, 1} => [:user, :viewer],
    {:Integer, :to_charlist, 2} => [:user, :viewer],
    {:Integer, :to_string, 1} => [:user, :viewer],
    {:Integer, :to_string, 2} => [:user, :viewer],
    {:Integer, :undigits, 1} => [:user, :viewer],
    {:Integer, :undigits, 2} => [:user, :viewer],

    # Float operations
    {:Float, :ceil, 1} => [:user, :viewer],
    {:Float, :ceil, 2} => [:user, :viewer],
    {:Float, :floor, 1} => [:user, :viewer],
    {:Float, :floor, 2} => [:user, :viewer],
    {:Float, :parse, 1} => [:user, :viewer],
    {:Float, :ratio, 1} => [:user, :viewer],
    {:Float, :round, 1} => [:user, :viewer],
    {:Float, :round, 2} => [:user, :viewer],
    {:Float, :to_charlist, 1} => [:user, :viewer],
    {:Float, :to_charlist, 2} => [:user, :viewer],
    {:Float, :to_string, 1} => [:user, :viewer],
    {:Float, :to_string, 2} => [:user, :viewer],

    # DateTime & Time operations
    {:DateTime, :now, 1} => [:user, :viewer],
    {:DateTime, :utc_now, 0} => [:user, :viewer],
    {:DateTime, :from_unix, 1} => [:user, :viewer],
    {:DateTime, :from_unix, 2} => [:user, :viewer],
    {:DateTime, :from_unix!, 1} => [:user, :viewer],
    {:DateTime, :from_unix!, 2} => [:user, :viewer],
    {:DateTime, :to_unix, 1} => [:user, :viewer],
    {:DateTime, :to_unix, 2} => [:user, :viewer],
    {:DateTime, :to_date, 1} => [:user, :viewer],
    {:DateTime, :to_time, 1} => [:user, :viewer],
    {:DateTime, :to_iso8601, 1} => [:user, :viewer],
    {:DateTime, :to_iso8601, 2} => [:user, :viewer],
    {:DateTime, :from_iso8601, 1} => [:user, :viewer],
    {:Date, :new, 3} => [:user, :viewer],
    {:Date, :utc_today, 0} => [:user, :viewer],
    {:Date, :to_iso8601, 1} => [:user, :viewer],
    {:Date, :from_iso8601, 1} => [:user, :viewer],
    {:Date, :day_of_week, 1} => [:user, :viewer],
    {:Date, :days_in_month, 1} => [:user, :viewer],
    {:Time, :new, 3} => [:user, :viewer],
    {:Time, :new, 4} => [:user, :viewer],
    {:Time, :utc_now, 0} => [:user, :viewer],
    {:Time, :utc_now, 1} => [:user, :viewer],
    {:Time, :to_iso8601, 1} => [:user, :viewer],
    {:Time, :to_iso8601, 2} => [:user, :viewer],
    {:Time, :from_iso8601, 1} => [:user, :viewer]
  }

  @current_schema_version 1

  def get_authorized_roles(module, function, arity) do
    key = {module, function, arity}
    Map.get(@function_allowlist, key, [])
  end

  def can_access?(role, module, function, arity) do
    authorized_roles = get_authorized_roles(module, function, arity)
    can_access_any_role?(role, authorized_roles)
  end

  def can_access_any_role?(role, authorized_roles) do
    all_available_roles = get_available_roles(role)
    Enum.any?(authorized_roles, &(&1 in all_available_roles))
  end

  def get_available_roles(role) do
    [role | expand_role_hierarchy(role)]
  end

  defp expand_role_hierarchy(role) do
    case Map.get(@role_hierarchy, role) do
      nil -> []
      inherited_roles -> Enum.flat_map(inherited_roles, &get_available_roles/1)
    end
  end

  def current_schema_version do
    @current_schema_version
  end

  def list_functions_for_role(role) do
    available_roles = get_available_roles(role)

    @function_allowlist
    |> Enum.filter(fn {_key, roles} ->
      Enum.any?(roles, &(&1 in available_roles))
    end)
    |> Enum.map(fn {{module, function, arity}, _roles} ->
      {module, function, arity}
    end)
  end

  def audit_log(role, module, function, arity, allowed?) do
    level = if allowed?, do: :info, else: :warn
    Logger.log(level, "Authorization: role=#{role} func=#{inspect({module, function, arity})} allowed=#{allowed?}")
  end

  def function_count do
    map_size(@function_allowlist)
  end

  def functions_by_module do
    @function_allowlist
    |> Enum.group_by(fn {{module, _function, _arity}, _roles} -> module end)
    |> Enum.map(fn {module, entries} -> {module, length(entries)} end)
    |> Enum.sort()
  end
end
