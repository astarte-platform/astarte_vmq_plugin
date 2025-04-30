#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.VMQ.Plugin.Test.Helpers.PayloadGenerator do
  use ExUnitProperties

  alias Astarte.Core.Mapping
  alias Astarte.Common.Generators.Timestamp

  @doc """
  Generates a valid Astarte data payload as described in
  https://docs.astarte-platform.org/astarte/latest/080-mqtt-v1-protocol.html#payload-format
  The optional `mapping` parameter allows to generate
  valid payloads for a given mapping.
  """
  def payload(opts \\ []) do
    mapping = Keyword.get(opts, :mapping)

    if mapping != nil do
      payload_for(mapping)
    else
      generic_payload()
    end
  end

  defp payload_for(%Mapping{} = mapping) do
    generator =
      case mapping.value_type do
        :double -> float()
        :integer -> integer()
        :boolean -> boolean()
        :longinteger -> integer()
        :string -> string(:utf8)
        :binaryblob -> binary()
        :datetime -> Timestamp.timestamp()
        :doublearray -> list_of(float())
        :integerarray -> list_of(integer())
        :booleanarray -> list_of(boolean())
        :longintegerarray -> list_of(integer())
        :stringarray -> list_of(string(:utf8))
        :binaryblobarray -> list_of(binary())
        :datetimearray -> list_of(Timestamp.timestamp())
      end

    gen all(
          value <- generator,
          timestamp <- Timestamp.timestamp()
        ) do
      {:ok, bson} = Cyanide.encode(%{"v" => value, "t" => timestamp})
      bson
    end
  end

  defp generic_payload() do
    gen all(
          value <-
            one_of([
              integer(),
              float(),
              binary(),
              string(:utf8),
              boolean(),
              Timestamp.timestamp(),
              list_of(integer()),
              list_of(float()),
              list_of(binary()),
              list_of(string(:utf8)),
              list_of(boolean()),
              list_of(Timestamp.timestamp())
            ]),
          timestamp <- Timestamp.timestamp()
        ) do
      {:ok, bson} = Cyanide.encode(%{"v" => value, "t" => timestamp})
      bson
    end
  end
end
