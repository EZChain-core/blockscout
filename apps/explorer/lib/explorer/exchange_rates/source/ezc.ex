defmodule Explorer.ExchangeRates.Source.EZC do
  @moduledoc """
  Adapter for fetching exchange rates from https://price.ezchain.com
  """

  alias Explorer.Chain
  alias Explorer.ExchangeRates.{Source, Token}

  import Source, only: [to_decimal: 1]

  @behaviour Source

  @impl Source
  def format_data(%{"data" => _} = json_data) do
    market_data = json_data["data"]

    last_updated = market_data["updated_at"]
    current_price = to_decimal(market_data["current_price"])

    id = json_data["id"]
    btc_value = nil #get_btc_value(id, market_data)

    circulating_supply_data = market_data && market_data["circulating_supply"] + (market_data["vesting"] |> Decimal.new |> Decimal.to_float || 0)
    total_supply_data = market_data && market_data["total_supply"]
    market_cap_data_usd = market_data && market_data["market_cap"]
    total_volume_data_usd = market_data && market_data["total_volume"]
    [
      %Token{
        available_supply: to_decimal(circulating_supply_data),
        total_supply: to_decimal(total_supply_data) || to_decimal(circulating_supply_data),
        btc_value: btc_value,
        id: id,
        last_updated: last_updated,
        market_cap_usd: to_decimal(market_cap_data_usd),
        name: market_data["name"],
        symbol: String.upcase(market_data["symbol"]),
        usd_value: current_price,
        volume_24h_usd: to_decimal(total_volume_data_usd)
      }
    ]
  end

  @impl Source
  def format_data(_), do: []

  # defp get_last_updated(market_data) do
  #   last_updated_data = market_data && market_data["last_updated"]

  #   if last_updated_data do
  #     {:ok, last_updated, 0} = DateTime.from_iso8601(last_updated_data)
  #     last_updated
  #   else
  #     nil
  #   end
  # end

  # defp get_current_price(market_data) do
  #   if market_data["current_price"] do
  #     to_decimal(market_data["current_price"]["usd"])
  #   else
  #     1
  #   end
  # end

  # defp get_btc_value(id, market_data) do
  #   case get_btc_price() do
  #     {:ok, price} ->
  #       btc_price = to_decimal(price)
  #       current_price = get_current_price(market_data)

  #       if id != "btc" && current_price && btc_price do
  #         Decimal.div(current_price, btc_price)
  #       else
  #         1
  #       end

  #     _ ->
  #       1
  #   end
  # end

  @impl Source
  def source_url do
    explicit_coin_id = Application.get_env(:explorer, :ezc_coin_symbol_id)

    {:ok, id} =
      if explicit_coin_id do
        {:ok, explicit_coin_id}
      else
        case coin_id() do
          {:ok, id} ->
            {:ok, id}

          _ ->
            {:ok, nil}
        end
      end

    if id, do: "#{base_url()}/service/token?symbol=#{id}", else: nil
  end

  @impl Source
  def source_url(input) do
    case Chain.Hash.Address.cast(input) do
      {:ok, _} ->
        address_hash_str = input
        "#{base_url()}/service/token/contract=#{address_hash_str}"

      _ ->
        symbol = input

        id =
          case coin_id(symbol) do
            {:ok, id} ->
              id

            _ ->
              nil
          end

        if id, do: "#{base_url()}/service/token?symbol=#{id}", else: nil
    end
  end

  defp base_url do
    config(:base_url) || "https://price.ezchain.com/v1"
  end

  def coin_id do
    symbol = String.downcase(Explorer.coin())

    coin_id(symbol)
  end

  def coin_id(symbol) do
    id_mapping = bridged_token_symbol_to_id_mapping_to_get_price(symbol)

    if id_mapping do
      {:ok, id_mapping}
    else
      url = "#{base_url()}/service/tokens"

      symbol_downcase = String.downcase(symbol)

      case Source.http_request(url) do
        {:ok, data} = resp ->
          if is_list(data) do
            symbol_data =
              Enum.find(data, fn item ->
                item["symbol"] == symbol_downcase
              end)

            if symbol_data do
              {:ok, symbol_data["id"]}
            else
              {:error, :not_found}
            end
          else
            resp
          end

        resp ->
          resp
      end
    end
  end

  # defp get_btc_price(currency \\ "usd") do
  #   url = "#{base_url()}/exchange_rates"

  #   case Source.http_request(url) do
  #     {:ok, data} = resp ->
  #       if is_map(data) do
  #         current_price = data["rates"][currency]["value"]

  #         {:ok, current_price}
  #       else
  #         resp
  #       end

  #     resp ->
  #       resp
  #   end
  # end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  defp bridged_token_symbol_to_id_mapping_to_get_price(symbol) do
    case symbol do
      "UNI" -> "uniswap"
      "SURF" -> "surf-finance"
      _symbol -> nil
    end
  end
end
