#
# Copyright (C) 2018 Ispirata Srl
#
# This file is part of Astarte.
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#

defmodule Astarte.VMQ.Plugin.Utils do
  @moduledoc """
  Utilities module
  """

  @doc """
  Return functions with the same format of the one returned by :vmq_reg.direct_plugin_exports.
  Useful to make sure we can run the application interactively without Verne
  """
  def empty_plugin_functions do
    empty_fun_0 = fn -> :ok end
    empty_fun_3 = fn _, _, _ -> :ok end

    {empty_fun_0, empty_fun_3, {nil, nil}}
  end
end
