defmodule Explorer.Chain.Supply.EZC do
  @moduledoc """
  Defines the supply API for calculating supply for coins from exchange_rate..
  """

  use Explorer.Chain.Supply
  alias HTTPoison.{Error, Response}

  @last_update_key :circulating_time
  @cache_name :circulating

  def circulating do
    if cache_expired?() do
      case HTTPoison.get("#{Application.get_env(:explorer, :ezc_market_url)}/service/supplies", headers()) do
        {:ok, %Response{body: body, status_code: 200}} ->
          {:ok, %{
            "data" => %{
              "circulating_supply" => circulating_supply,
              "max_supply" => _,
              "total_supply" => _
            },
            "error_code" => _,
            "message" => _,
            "success" => _,
          }} = parse_http_success_response(body)
          put_into_cache(@last_update_key, current_time())
          put_into_cache(@cache_name, circulating_supply)
          {:ok, circulating_supply}

        {:ok, %Response{body: _, status_code: status_code}} when status_code in 400..526 ->
          {:error, 0}
          #parse_http_error_response(body)

        {:ok, %Response{status_code: status_code}} when status_code in 300..308 ->
          {:error, "Source redirected"}

        {:ok, %Response{status_code: _status_code}} ->
          {:error, "Source unexpected status code"}

        {:error, %Error{reason: reason}} ->
          {:error, reason}

        {:error, :nxdomain} ->
          {:error, "Source is not responsive"}

        {:error, _} ->
          {:error, "Source unknown response"}
      end
    else
      fetch_from_cache(@cache_name)
    end

  end

  def total do

  end

  def headers do
    [{"Content-Type", "application/json"}]
  end

  def decode_json(data) do
    Jason.decode!(data)
  rescue
    _ -> data
  end

  defp parse_http_success_response(body) do
    body_json = decode_json(body)

    cond do
      is_map(body_json) ->
        {:ok, body_json}

      is_list(body_json) ->
        {:ok, body_json}

      true ->
        {:ok, body}
    end
  end

  # defp parse_http_error_response(body) do
  #   body_json = decode_json(body)

  #   if is_map(body_json) do
  #     {:error, body_json["error"]}
  #   else
  #     {:error, body}
  #   end
  # end

  defp cache_expired? do
    cache_period = cache_period()
    updated_at = fetch_from_cache(@last_update_key)

    cond do
      is_nil(updated_at) -> true
      current_time() - updated_at > cache_period -> true
      true -> false
    end
  end

  defp fetch_from_cache(key) do
    ConCache.get(@cache_name, key)
  end

  defp put_into_cache(key, value) do
    ConCache.put(@cache_name, key, value)
  end

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end

  defp cache_period do
    case Integer.parse(System.get_env("CIRCULATING_HISTORY_CACHE_PERIOD", "")) do
      {secs, ""} -> :timer.seconds(secs)
      _ -> :timer.minutes(5)
    end
  end

  def cache_name, do: @cache_name

end
