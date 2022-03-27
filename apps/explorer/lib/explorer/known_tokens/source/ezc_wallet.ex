defmodule Explorer.KnownTokens.Source.EZCWallet do
  @moduledoc """
  Adapter for fetching known tokens from EZCWallet's GitHub
  """

  alias Explorer.KnownTokens.Source

  @behaviour Source

  @impl Source
  def source_url do
    Application.get_env(:explorer, :ezc_tokens) || "https://raw.githubusercontent.com/kvhnuke/etherwallet/mercury/app/scripts/tokens/ethTokens.json"
  end
end
